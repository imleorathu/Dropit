use bytes::Bytes;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tokio::sync::mpsc;

/// Channel capacity used when normalizing a file-backed [`FileContent`] into a stream.
const FILE_CHANNEL_CAPACITY: usize = 16;

/// Buffer size used when reading a file into chunks (kept below 1 MiB so
/// per-chunk allocations stay in user-space allocator caches rather than
/// triggering OS VM page faults).
const READ_BUFFER_SIZE: usize = 512 * 1024;

/// The binary content of a file provided by the application for a transfer.
///
/// Shared by the HTTP client (upload) and server (download API) so both can
/// obtain a file's content as an in-memory stream of chunks, from a regular
/// file path, or, on Android, directly from a raw file descriptor.
#[derive(Debug)]
pub enum FileContent {
    /// A stream of binary chunks. The channel is closed once the file has been
    /// fully provided.
    Stream(mpsc::Receiver<Bytes>),

    /// A path to a regular file the content is read from.
    Path(PathBuf),

    /// A raw file descriptor the content is read from (Android only).
    #[cfg(target_os = "android")]
    Fd(std::os::fd::RawFd),
}

impl FileContent {
    /// Normalizes the content into a stream of binary chunks.
    ///
    /// [`FileContent::Stream`] is returned as-is. For [`FileContent::Path`] and
    /// [`FileContent::Fd`], a background task reads the file and forwards the
    /// chunks; the channel is closed on EOF or on an I/O error.
    pub fn into_receiver(self) -> mpsc::Receiver<Bytes> {
        match self {
            FileContent::Stream(rx) => {
                tracing::info!("Reading file content via byte stream from application");
                rx
            }
            FileContent::Path(path) => {
                tracing::info!("Reading file content from path: {}", path.display());
                let (tx, rx) = mpsc::channel(FILE_CHANNEL_CAPACITY);
                tokio::task::spawn_blocking(move || match std::fs::File::open(&path) {
                    Ok(file) => stream_std_file_range(file, tx, 0, None),
                    Err(e) => tracing::error!("Failed to open {}: {e}", path.display()),
                });
                rx
            }
            #[cfg(target_os = "android")]
            FileContent::Fd(fd) => {
                use std::os::fd::FromRawFd;

                tracing::info!("Reading file content from file descriptor: {fd}");
                let (tx, rx) = mpsc::channel(FILE_CHANNEL_CAPACITY);
                // SAFETY: the descriptor is owned by this transfer; wrapping it in
                // a File transfers that ownership so it is closed once reading finishes.
                let std_file = unsafe { std::fs::File::from_raw_fd(fd) };
                tokio::task::spawn_blocking(move || stream_std_file_range(std_file, tx, 0, None));
                rx
            }
        }
    }

    /// Streams at most `length` bytes beginning at `offset`.
    ///
    /// File-backed content seeks before reading, so resuming a large browser
    /// download does not read or copy the skipped prefix. Application-provided
    /// streams are consumed and discarded up to the offset using the same
    /// bounded channel; this fallback remains bounded but cannot seek.
    pub fn into_range_receiver(self, offset: u64, length: u64) -> mpsc::Receiver<Bytes> {
        match self {
            FileContent::Stream(rx) => range_stream_receiver(rx, offset, length),
            FileContent::Path(path) => {
                tracing::info!(
                    "Reading file range from path: {} (offset: {offset}, length: {length})",
                    path.display()
                );
                let (tx, rx) = mpsc::channel(FILE_CHANNEL_CAPACITY);
                tokio::task::spawn_blocking(move || match std::fs::File::open(&path) {
                    Ok(file) => stream_std_file_range(file, tx, offset, Some(length)),
                    Err(e) => tracing::error!("Failed to open {}: {e}", path.display()),
                });
                rx
            }
            #[cfg(target_os = "android")]
            FileContent::Fd(fd) => {
                use std::os::fd::FromRawFd;

                tracing::info!(
                    "Reading file descriptor range (offset: {offset}, length: {length})"
                );
                let (tx, rx) = mpsc::channel(FILE_CHANNEL_CAPACITY);
                // SAFETY: the descriptor is owned by this transfer and is closed
                // when the resulting File is dropped.
                let std_file = unsafe { std::fs::File::from_raw_fd(fd) };
                tokio::task::spawn_blocking(move || {
                    stream_std_file_range(std_file, tx, offset, Some(length));
                });
                rx
            }
        }
    }
}

/// Streams `[offset, offset + length)` (or to EOF when `length` is `None`)
/// on a dedicated blocking thread, avoiding per-read async pool hops and
/// staging-buffer copies inside `tokio::fs::File`.
fn stream_std_file_range(
    mut file: std::fs::File,
    tx: mpsc::Sender<Bytes>,
    offset: u64,
    length: Option<u64>,
) {
    use std::io::{Read, Seek};

    if offset > 0 {
        if let Err(e) = file.seek(std::io::SeekFrom::Start(offset)) {
            tracing::error!("Failed to seek file content to offset {offset}: {e}");
            return;
        }
    }

    let mut remaining = length.unwrap_or(u64::MAX);
    let mut total: u64 = 0;
    let buf_cap = length.map_or(READ_BUFFER_SIZE, |len| {
        (len as usize).clamp(1, READ_BUFFER_SIZE)
    });
    let mut scratch = vec![0u8; buf_cap];

    while remaining > 0 {
        let max_read = (remaining.min(buf_cap as u64)) as usize;
        let read = loop {
            match file.read(&mut scratch[..max_read]) {
                Ok(n) => break n,
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                Err(e) => {
                    tracing::error!("Failed to read file content: {e}");
                    return;
                }
            }
        };
        if read == 0 {
            break;
        }
        let chunk = Bytes::copy_from_slice(&scratch[..read]);
        total += read as u64;
        if length.is_some() {
            remaining -= read as u64;
        }
        if tx.blocking_send(chunk).is_err() {
            break;
        }
    }
    tracing::info!("Finished reading file content ({total} bytes)");
}

fn range_stream_receiver(
    mut source: mpsc::Receiver<Bytes>,
    offset: u64,
    length: u64,
) -> mpsc::Receiver<Bytes> {
    let (tx, rx) = mpsc::channel(FILE_CHANNEL_CAPACITY);
    tokio::spawn(async move {
        let mut skip = offset;
        let mut remaining = length;
        while remaining > 0 {
            let Some(mut chunk) = source.recv().await else {
                break;
            };
            if skip >= chunk.len() as u64 {
                skip -= chunk.len() as u64;
                continue;
            }
            if skip > 0 {
                chunk = chunk.slice(skip as usize..);
                skip = 0;
            }
            if chunk.len() as u64 > remaining {
                chunk = chunk.slice(..remaining as usize);
            }
            remaining -= chunk.len() as u64;
            if tx.send(chunk).await.is_err() {
                break;
            }
        }
    });
    rx
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileDto {
    pub id: String,
    pub file_name: String,
    pub size: u64,
    pub file_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sha256: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preview: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<FileMetadata>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileMetadata {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub modified: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub accessed: Option<String>,
}

#[cfg(feature = "http")]
impl FileMetadata {
    /// The timestamps of the file at `path`, or `None` when the file cannot be
    /// inspected or provides no timestamps.
    pub fn from_path(path: &std::path::Path) -> Option<Self> {
        Self::from_fs_metadata(&std::fs::metadata(path).ok()?)
    }

    /// See [`FileMetadata::from_path`], on an already obtained [`std::fs::Metadata`].
    pub fn from_fs_metadata(metadata: &std::fs::Metadata) -> Option<Self> {
        let modified = metadata.modified().ok().and_then(format_timestamp);
        let accessed = metadata.accessed().ok().and_then(format_timestamp);
        if modified.is_none() && accessed.is_none() {
            return None;
        }
        Some(Self { modified, accessed })
    }

    /// The `modified` timestamp parsed as a [`std::time::SystemTime`],
    /// or `None` when absent or not parsable.
    pub fn modified_time(&self) -> Option<std::time::SystemTime> {
        parse_timestamp(self.modified.as_deref()?)
    }

    /// The `accessed` timestamp parsed as a [`std::time::SystemTime`],
    /// or `None` when absent or not parsable.
    pub fn accessed_time(&self) -> Option<std::time::SystemTime> {
        parse_timestamp(self.accessed.as_deref()?)
    }
}

/// Parses an RFC 3339 timestamp (e.g. `2026-08-01T10:20:30.456Z`), the format
/// the protocol uses for file metadata.
#[cfg(feature = "http")]
fn parse_timestamp(value: &str) -> Option<std::time::SystemTime> {
    match time::OffsetDateTime::parse(value, &time::format_description::well_known::Rfc3339) {
        Ok(parsed) => Some(parsed.into()),
        Err(e) => {
            tracing::warn!("Could not parse file timestamp {value:?}: {e}");
            None
        }
    }
}

/// Formats a timestamp as RFC 3339 with nanosecond precision.
#[cfg(feature = "http")]
fn format_timestamp(value: std::time::SystemTime) -> Option<String> {
    match time::OffsetDateTime::from(value).format(&time::format_description::well_known::Rfc3339) {
        Ok(formatted) => Some(formatted),
        Err(e) => {
            tracing::warn!("Could not format file timestamp: {e}");
            None
        }
    }
}

#[cfg(all(test, feature = "http"))]
mod tests {
    use super::*;
    use std::time::{Duration, SystemTime};

    fn metadata(modified: &str) -> FileMetadata {
        FileMetadata {
            modified: Some(modified.to_string()),
            accessed: None,
        }
    }

    #[test]
    fn parses_utc_timestamp() {
        assert_eq!(
            metadata("2000-01-01T00:00:00Z").modified_time(),
            Some(SystemTime::UNIX_EPOCH + Duration::from_secs(946_684_800)),
        );
    }

    #[test]
    fn parses_fractional_seconds() {
        // The Dart implementation sends `DateTime.toIso8601String()` of a UTC
        // value, which includes fractional seconds: 1970-01-01T00:00:00.500Z.
        assert_eq!(
            metadata("1970-01-01T00:00:00.500Z").modified_time(),
            Some(SystemTime::UNIX_EPOCH + Duration::from_millis(500)),
        );
    }

    #[test]
    fn parses_offset_timestamp() {
        assert_eq!(
            metadata("2000-01-01T01:00:00+01:00").modified_time(),
            Some(SystemTime::UNIX_EPOCH + Duration::from_secs(946_684_800)),
        );
    }

    #[test]
    fn ignores_invalid_timestamp() {
        assert_eq!(metadata("yesterday").modified_time(), None);
        assert_eq!(metadata("2000-01-01T00:00:00").modified_time(), None);
    }

    #[test]
    fn formats_nanosecond_timestamp() {
        let time = SystemTime::UNIX_EPOCH + Duration::from_nanos(123_456_789);
        let formatted = format_timestamp(time).unwrap();
        assert_eq!(formatted, "1970-01-01T00:00:00.123456789Z");
        assert_eq!(parse_timestamp(&formatted), Some(time));
    }

    #[test]
    fn reads_file_timestamps() {
        let path =
            std::env::temp_dir().join(format!("localsend-metadata-{}", uuid::Uuid::new_v4()));
        std::fs::write(&path, b"hello").unwrap();
        // 100 ns aligned, so the values are exactly representable on NTFS.
        let modified = SystemTime::UNIX_EPOCH + Duration::new(1_600_000_000, 123_456_700);
        let accessed = SystemTime::UNIX_EPOCH + Duration::new(1_600_000_001, 987_654_300);
        let file = std::fs::File::options().write(true).open(&path).unwrap();
        file.set_times(
            std::fs::FileTimes::new()
                .set_modified(modified)
                .set_accessed(accessed),
        )
        .unwrap();
        drop(file);

        let metadata = FileMetadata::from_path(&path).unwrap();
        std::fs::remove_file(&path).unwrap();
        assert_eq!(metadata.modified_time(), Some(modified));
        assert_eq!(metadata.accessed_time(), Some(accessed));
    }

    #[test]
    fn reads_no_metadata_from_missing_file() {
        assert!(
            FileMetadata::from_path(std::path::Path::new("/nonexistent/localsend-test")).is_none()
        );
    }

    #[test]
    fn ignores_absent_timestamp() {
        let metadata = FileMetadata {
            modified: None,
            accessed: None,
        };
        assert_eq!(metadata.modified_time(), None);
        assert_eq!(metadata.accessed_time(), None);
    }

    #[tokio::test]
    async fn streams_only_the_requested_file_range() {
        let path = std::env::temp_dir().join(format!("localsend-range-{}", uuid::Uuid::new_v4()));
        std::fs::write(&path, b"0123456789").unwrap();

        let mut receiver = FileContent::Path(path.clone()).into_range_receiver(3, 4);
        let mut received = Vec::new();
        while let Some(chunk) = receiver.recv().await {
            received.extend_from_slice(&chunk);
        }

        std::fs::remove_file(path).unwrap();
        assert_eq!(received, b"3456");
    }

    #[tokio::test]
    async fn seeks_past_four_gibibytes_without_offset_overflow() {
        use std::io::{Seek, Write};

        let path =
            std::env::temp_dir().join(format!("localsend-large-range-{}", uuid::Uuid::new_v4()));
        let offset = 5_u64 * 1024 * 1024 * 1024;
        let mut file = std::fs::File::create(&path).unwrap();
        file.set_len(offset + 4).unwrap();
        file.seek(std::io::SeekFrom::Start(offset)).unwrap();
        file.write_all(b"tail").unwrap();
        drop(file);

        let mut receiver = FileContent::Path(path.clone()).into_range_receiver(offset, 4);
        let mut received = Vec::new();
        while let Some(chunk) = receiver.recv().await {
            received.extend_from_slice(&chunk);
        }

        std::fs::remove_file(path).unwrap();
        assert_eq!(received, b"tail");
    }
}
