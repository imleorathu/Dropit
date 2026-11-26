'use client';

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  GlassButton,
  GlassCard,
  GlassInput,
  GlassNav,
  GlassSegmented,
  GlassSheet,
  GlassSlider,
  GlassSwitch,
  setGlassQuality,
} from '@zakisheriff/liquid-glass';

const API = {
  register: '/api/dropit/browser/register',
  heartbeat: '/api/dropit/browser/heartbeat',
  events: '/api/dropit/browser/events',
  offerResponse: '/api/dropit/browser/offer-response',
  download: '/api/dropit/browser/download',
  prepareUpload: '/api/localsend/v2/prepare-upload',
  upload: '/api/localsend/v2/upload',
  prepareDownload: '/api/localsend/v2/prepare-' + 'download',
  v2Download: '/api/localsend/v2/download',
};

const STORAGE_CLIENT = 'dropit.browser.clientId';
const STORAGE_SESSION = 'dropit.browser.session';
const STORAGE_MODE = 'dropit.browser.mode';
const STORAGE_THEME = 'dropit.browser.theme';

export interface PortalFile {
  id: string;
  fileName: string;
  size: number;
  fileType?: string;
}

export interface PortalOffer {
  offerId: string;
  files: PortalFile[];
  accepted?: boolean;
  createdAtMs?: number;
}

export interface UploadEntry {
  id: string;
  file: File;
  state: 'queued' | 'preparing' | 'uploading' | 'done' | 'error';
  progress: number;
  speedBps?: number;
  error?: string;
}

function getClientId(): string {
  try {
    const existing = localStorage.getItem(STORAGE_CLIENT);
    if (existing) return existing;
    const created =
      typeof crypto !== 'undefined' && crypto.randomUUID
        ? crypto.randomUUID()
        : `client-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    localStorage.setItem(STORAGE_CLIENT, created);
    return created;
  } catch {
    return `client-${Date.now()}`;
  }
}

function detectDeviceType(): string {
  if (typeof navigator === 'undefined') return 'desktop';
  const ua = navigator.userAgent;
  if (/iPad|Tablet/i.test(ua) || (/Android/i.test(ua) && !/Mobile/i.test(ua))) return 'tablet';
  if (/iPhone|iPod|Android|Mobile/i.test(ua)) return 'mobile';
  return 'desktop';
}

function detectPlatform(): string {
  if (typeof navigator === 'undefined') return 'Unknown';
  const ua = navigator.userAgent;
  if (/iPhone|iPad|iPod/i.test(ua)) return 'iOS';
  if (/Android/i.test(ua)) return 'Android';
  if (/Windows/i.test(ua)) return 'Windows';
  if (/Macintosh|Mac OS X/i.test(ua)) return 'macOS';
  if (/CrOS/i.test(ua)) return 'ChromeOS';
  if (/Linux|X11/i.test(ua)) return 'Linux';
  return 'Unknown';
}

export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes < 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  const units = ['KB', 'MB', 'GB', 'TB'];
  let value = bytes / 1024;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return `${value >= 10 ? value.toFixed(0) : value.toFixed(1)} ${units[unit]}`;
}

export function formatRate(bytesPerSec?: number): string {
  if (!bytesPerSec || !Number.isFinite(bytesPerSec) || bytesPerSec <= 0) return '';
  const mbps = bytesPerSec / (1000 * 1000);
  return mbps >= 100 ? `${mbps.toFixed(0)} MB/s` : `${mbps.toFixed(1)} MB/s`;
}

export function fileBadge(fileName = '', fileType = ''): 'IMG' | 'VID' | 'AUD' | 'ZIP' | 'DOC' | 'FILE' {
  const type = fileType.toLowerCase();
  const name = fileName.toLowerCase();
  if (type.startsWith('image/') || /\.(png|jpe?g|gif|webp|heic|svg)$/.test(name)) return 'IMG';
  if (type.startsWith('video/') || /\.(mp4|mov|mkv|webm)$/.test(name)) return 'VID';
  if (type.startsWith('audio/') || /\.(mp3|wav|flac|m4a)$/.test(name)) return 'AUD';
  if (/\.(zip|rar|7z|tar|gz)$/.test(name)) return 'ZIP';
  if (/\.(pdf|docx?|xlsx?|pptx?|txt|md|csv)$/.test(name)) return 'DOC';
  return 'FILE';
}

const IconUpload = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 16V4" />
    <path d="m7 9 5-5 5 5" />
    <path d="M20 16v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2" />
  </svg>
);

const IconDownload = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 4v12" />
    <path d="m7 11 5 5 5-5" />
    <path d="M20 18v2H4v-2" />
  </svg>
);

const IconQueue = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="4" width="18" height="6" rx="2" />
    <rect x="3" y="14" width="18" height="6" rx="2" />
  </svg>
);

const IconControls = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="4" y1="7" x2="20" y2="7" />
    <line x1="4" y1="17" x2="20" y2="17" />
    <circle cx="9" cy="7" r="2.5" />
    <circle cx="15" cy="17" r="2.5" />
  </svg>
);

const IconSparkle = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9L12 3z" />
  </svg>
);

const IconRefresh = (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 12a9 9 0 1 1-2.64-6.36" />
    <polyline points="21 3 21 9 15 9" />
  </svg>
);

export function DropitGlassApp({ initialMode }: { initialMode?: 'send' | 'receive' }) {
  const [alias, setAlias] = useState('Dropit');
  const [deviceHint, setDeviceHint] = useState('Connecting over local Wi-Fi…');
  const [statusKind, setStatusKind] = useState<'connecting' | 'online' | 'offline'>('connecting');
  const [statusText, setStatusText] = useState('Connecting');
  const [banner, setBanner] = useState<{ text: string; kind: 'info' | 'error' } | null>(null);

  // 0 = Send to Device, 1 = Send via Browser (Receive from device), 2 = Queue & Search
  const [activeNav, setActiveNav] = useState<number>(initialMode === 'receive' ? 1 : 0);
  const mode = activeNav === 1 ? 'receive' : 'send';

  // Liquid Glass controls & theme
  const [themeIndex, setThemeIndex] = useState<number>(0); // 0: System, 1: Light, 2: Dark
  const [intensity, setIntensity] = useState<number>(6);
  const [chunkStreams, setChunkStreams] = useState<number>(4);
  const [autoAccept, setAutoAccept] = useState<boolean>(false);
  const [hapticsEnabled, setHapticsEnabled] = useState<boolean>(true);
  const [highQualityLens, setHighQualityLens] = useState<boolean>(true);
  const [controlsOpen, setControlsOpen] = useState<boolean>(false);

  // Search & category filter
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [categoryFilter, setCategoryFilter] = useState<number>(0); // 0: All, 1: Media, 2: Docs, 3: Archives

  // PIN keypad sheet
  const [pinRequired, setPinRequired] = useState<boolean>(false);
  const [pinBuffer, setPinBuffer] = useState<string>('');

  // Offers & Uploads
  const [offers, setOffers] = useState<PortalOffer[]>([]);
  const [webSendSessionId, setWebSendSessionId] = useState<string | null>(null);
  const [webSendFiles, setWebSendFiles] = useState<PortalFile[]>([]);
  const [uploads, setUploads] = useState<UploadEntry[]>([]);
  const [dragOver, setDragOver] = useState<boolean>(false);
  const [showTrustLink, setShowTrustLink] = useState<boolean>(false);

  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const offersRef = useRef<PortalOffer[]>([]);
  offersRef.current = offers;
  const autoAcceptedIdsRef = useRef<Set<string>>(new Set());
  const uploadQueueRef = useRef<Promise<void>>(Promise.resolve());
  const chunkStreamsRef = useRef<number>(chunkStreams);
  chunkStreamsRef.current = chunkStreams;
  const sessionRef = useRef<{
    clientId: string;
    sessionId: string | null;
    sessionToken: string | null;
    pin: string;
    heartbeatInterval: number;
    heartbeatTimer: number;
    eventSource: EventSource | null;
    reconnectAttempts: number;
  }>({
    clientId: getClientId(),
    sessionId: null,
    sessionToken: null,
    pin: typeof location !== 'undefined' ? new URLSearchParams(location.search).get('pin') || '' : '',
    heartbeatInterval: 5000,
    heartbeatTimer: 0,
    eventSource: null,
    reconnectAttempts: 0,
  });

  // Apply theme attribute on <html>: follow system or set data-theme="light" | "dark"
  useEffect(() => {
    if (typeof document === 'undefined') return;
    const html = document.documentElement;
    if (themeIndex === 1) {
      html.setAttribute('data-theme', 'light');
    } else if (themeIndex === 2) {
      html.setAttribute('data-theme', 'dark');
    } else {
      html.removeAttribute('data-theme');
    }
    try {
      localStorage.setItem(STORAGE_THEME, String(themeIndex));
    } catch {
      /* ignore */
    }
  }, [themeIndex]);

  useEffect(() => {
    setGlassQuality(highQualityLens ? 'high' : 'low');
  }, [highQualityLens]);

  const apiRequest = useCallback(async (url: string, options?: RequestInit) => {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(options?.headers || {}),
      },
      cache: 'no-store',
    });
    const text = await response.text();
    let data: any = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = null;
    }
    if (!response.ok) {
      const err: any = new Error(data?.message || data?.error || `Request failed (${response.status})`);
      err.status = response.status;
      throw err;
    }
    return data;
  }, []);

  const checkWebSendFiles = useCallback(async () => {
    try {
      const pinQuery = sessionRef.current.pin ? `?pin=${encodeURIComponent(sessionRef.current.pin)}` : '';
      const data = await apiRequest(API.prepareDownload + pinQuery, { method: 'POST' });
      if (data && data.sessionId && data.files) {
        setWebSendSessionId(data.sessionId);
        setWebSendFiles(Object.values(data.files));
      } else {
        setWebSendSessionId(null);
        setWebSendFiles([]);
      }
    } catch {
      setWebSendSessionId(null);
      setWebSendFiles([]);
    }
  }, [apiRequest]);

  const switchMode = useCallback(
    (nextMode: 'send' | 'receive', persist = false) => {
      setActiveNav(nextMode === 'receive' ? 1 : 0);
      if (nextMode === 'receive') {
        checkWebSendFiles();
      }
      if (persist) {
        try {
          localStorage.setItem(STORAGE_MODE, nextMode);
        } catch {
          /* ignore */
        }
      }
    },
    [checkWebSendFiles],
  );

  const registerSession = useCallback(async () => {
    setStatusKind('connecting');
    setStatusText('Connecting');
    let saved: { sessionId?: string; sessionToken?: string } | null = null;
    try {
      const raw = sessionStorage.getItem(STORAGE_SESSION);
      saved = raw ? JSON.parse(raw) : null;
    } catch {
      saved = null;
    }

    const body = {
      clientId: sessionRef.current.clientId,
      token: saved?.sessionToken || null,
      sessionId: saved?.sessionId || null,
      userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : 'Browser',
      deviceType: detectDeviceType(),
      platform: detectPlatform(),
      pin: sessionRef.current.pin || null,
    };

    try {
      const data = await apiRequest(API.register, {
        method: 'POST',
        body: JSON.stringify(body),
      });
      sessionRef.current.sessionId = data.sessionId;
      sessionRef.current.sessionToken = data.sessionToken;
      sessionRef.current.heartbeatInterval = data.heartbeatIntervalMs || 5000;
      try {
        sessionStorage.setItem(
          STORAGE_SESSION,
          JSON.stringify({ sessionId: data.sessionId, sessionToken: data.sessionToken }),
        );
      } catch {
        /* ignore */
      }

      setAlias(data.alias || 'Dropit');
      setDeviceHint(
        data.browserName
          ? `${data.browserName}${data.platform ? ` on ${data.platform}` : ''} · ${
              data.resumed ? 'Reconnected' : 'Connected'
            }`
          : 'Connected over local Wi-Fi',
      );
      setPinRequired(false);
      setBanner(null);
      setStatusKind('online');
      setStatusText('Connected');

      // Open SSE EventSource
      if (sessionRef.current.eventSource) {
        sessionRef.current.eventSource.close();
      }
      const es = new EventSource(
        `${API.events}?sessionId=${encodeURIComponent(data.sessionId)}&token=${encodeURIComponent(data.sessionToken)}`,
      );
      sessionRef.current.eventSource = es;

      es.addEventListener('connected', (event: MessageEvent) => {
        sessionRef.current.reconnectAttempts = 0;
        setStatusKind('online');
        setStatusText('Connected');
        setBanner(null);
        try {
          const payload = JSON.parse(event.data);
          if (payload.alias) setAlias(payload.alias);
          if (payload.heartbeatIntervalMs) sessionRef.current.heartbeatInterval = payload.heartbeatIntervalMs;
        } catch {
          /* ignore */
        }
      });

      es.addEventListener('offer', (event: MessageEvent) => {
        try {
          const incoming: PortalOffer = JSON.parse(event.data);
          setOffers((prev) => {
            const filtered = prev.filter((o) => o.offerId !== incoming.offerId);
            return [{ ...incoming, accepted: false }, ...filtered];
          });
          setActiveNav(1);
        } catch {
          /* ignore */
        }
      });

      es.addEventListener('offer_cancelled', (event: MessageEvent) => {
        try {
          const payload = JSON.parse(event.data);
          setOffers((prev) => prev.filter((o) => o.offerId !== payload.offerId));
        } catch {
          /* ignore */
        }
      });

      es.addEventListener('session_closed', () => {
        setStatusKind('offline');
        setStatusText('Disconnected');
        es.close();
        window.setTimeout(registerSession, 1500);
      });

      if (data.capabilities?.offers) {
        await checkWebSendFiles();
        if (!initialMode) {
          setActiveNav(1);
        }
      }
    } catch (error: any) {
      if (error?.status === 401) {
        setPinRequired(true);
        setPinBuffer('');
        setStatusKind('offline');
        setStatusText('PIN required');
        setBanner({
          text: sessionRef.current.pin ? 'Incorrect PIN. Please try again.' : 'This device requires a PIN to connect.',
          kind: sessionRef.current.pin ? 'error' : 'info',
        });
        sessionRef.current.pin = '';
        return;
      }
      if (error?.status === 429) {
        setStatusKind('offline');
        setStatusText('Blocked');
        setBanner({ text: 'Too many attempts. Please wait or restart sharing in Dropit.', kind: 'error' });
        return;
      }
      // Fallback for v2-only web send mode if /api/dropit/browser/register is not mounted
      await checkWebSendFiles();
      setStatusKind('online');
      setStatusText('Ready');
    }
  }, [apiRequest, checkWebSendFiles, initialMode]);

  const sendHeartbeat = useCallback(async () => {
    const { sessionId, sessionToken } = sessionRef.current;
    if (!sessionId || !sessionToken) return;
    try {
      const data = await apiRequest(API.heartbeat, {
        method: 'POST',
        body: JSON.stringify({ sessionId, token: sessionToken }),
      });
      if (data?.heartbeatIntervalMs) {
        sessionRef.current.heartbeatInterval = data.heartbeatIntervalMs;
      }
      if (Array.isArray(data?.offers) && data.offers.length > 0) {
        setOffers((prev) => {
          const existingIds = new Set(prev.map((o) => o.offerId));
          const merged = [...prev];
          for (const offer of data.offers) {
            if (!existingIds.has(offer.offerId)) {
              merged.unshift({ ...offer, accepted: true });
            }
          }
          return merged;
        });
      }
      setStatusKind('online');
      setStatusText('Connected');
    } catch {
      /* next interval will retry */
    }
  }, [apiRequest]);

  useEffect(() => {
    if (typeof location !== 'undefined' && typeof document !== 'undefined') {
      if (location.protocol === 'https:' && document.body.dataset.browserListener === 'true') {
        setShowTrustLink(true);
      }
      try {
        const savedTheme = Number(localStorage.getItem(STORAGE_THEME) || '0');
        if (savedTheme === 1 || savedTheme === 2) setThemeIndex(savedTheme);
      } catch {
        /* ignore */
      }
    }
    registerSession();
    const timer = window.setInterval(sendHeartbeat, 5000);
    return () => {
      window.clearInterval(timer);
      sessionRef.current.eventSource?.close();
    };
  }, [registerSession, sendHeartbeat]);

  const downloadUrl = useCallback((offerId: string, fileId: string) => {
    const { sessionId } = sessionRef.current;
    return (
      `${API.download}?sessionId=${encodeURIComponent(sessionId || '')}` +
      `&offerId=${encodeURIComponent(offerId)}` +
      `&fileId=${encodeURIComponent(fileId)}`
    );
  }, []);

  const answerOffer = useCallback(
    async (offerId: string, accept: boolean) => {
      const { sessionId, sessionToken } = sessionRef.current;
      try {
        await apiRequest(API.offerResponse, {
          method: 'POST',
          body: JSON.stringify({
            sessionId,
            token: sessionToken,
            offerId,
            accept,
          }),
        });
        if (accept) {
          setOffers((prev) => prev.map((o) => (o.offerId === offerId ? { ...o, accepted: true } : o)));
          const found = offersRef.current.find((o) => o.offerId === offerId);
          if (found && found.files.length === 1) {
            const a = document.createElement('a');
            a.href = downloadUrl(offerId, found.files[0].id);
            a.setAttribute('download', found.files[0].fileName);
            document.body.appendChild(a);
            a.click();
            a.remove();
          }
        } else {
          autoAcceptedIdsRef.current.delete(offerId);
          setOffers((prev) => prev.filter((o) => o.offerId !== offerId));
        }
      } catch (error: any) {
        autoAcceptedIdsRef.current.delete(offerId);
        setBanner({ text: error?.message || 'Failed to respond to transfer offer.', kind: 'error' });
      }
    },
    [apiRequest, downloadUrl],
  );

  // Auto-accept incoming offers when GlassSwitch is enabled
  useEffect(() => {
    if (!autoAccept) return;
    for (const offer of offers) {
      if (!offer.accepted && !autoAcceptedIdsRef.current.has(offer.offerId)) {
        autoAcceptedIdsRef.current.add(offer.offerId);
        answerOffer(offer.offerId, true);
      }
    }
  }, [autoAccept, offers, answerOffer]);

  const uploadPreparedFile = useCallback(
    async (sessionId: string, fileId: string, entryId: string, file: File, token: string) => {
      setUploads((prev) => prev.map((u) => (u.id === entryId ? { ...u, state: 'uploading', progress: 0 } : u)));
      const startedAt = performance.now();
      let lastUiUpdate = 0;

      await new Promise<void>((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open(
          'POST',
          `${API.upload}?sessionId=${encodeURIComponent(sessionId)}&fileId=${encodeURIComponent(
            fileId,
          )}&token=${encodeURIComponent(token)}`,
        );
        xhr.setRequestHeader('Content-Type', 'application/octet-stream');
        xhr.upload.onprogress = (ev) => {
          if (ev.lengthComputable && ev.total > 0) {
            const now = performance.now();
            const isComplete = ev.loaded >= ev.total;
            // Throttle React state updates to ~10 Hz so progress renders never
            // stall the main thread or delay network writes during fast transfers.
            if (!isComplete && now - lastUiUpdate < 100) {
              return;
            }
            lastUiUpdate = now;
            const elapsedSec = Math.max((now - startedAt) / 1000, 0.001);
            const speedBps = ev.loaded / elapsedSec;
            const p = ev.loaded / ev.total;
            setUploads((prev) =>
              prev.map((u) => (u.id === entryId ? { ...u, progress: p, speedBps } : u)),
            );
          }
        };
        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) {
            resolve();
          } else {
            reject(new Error(`Upload failed (${xhr.status})`));
          }
        };
        xhr.onerror = () => reject(new Error('Network connection interrupted during upload.'));
        xhr.send(file);
      });

      const finalElapsed = Math.max((performance.now() - startedAt) / 1000, 0.001);
      const finalSpeedBps = file.size / finalElapsed;
      setUploads((prev) =>
        prev.map((u) => (u.id === entryId ? { ...u, state: 'done', progress: 1, speedBps: finalSpeedBps } : u)),
      );
    },
    [],
  );

  const uploadBatch = useCallback(
    async (incoming: UploadEntry[]) => {
      if (incoming.length === 0) return;
      const entryIds = new Set(incoming.map((item) => item.id));
      setUploads((prev) => prev.map((u) => (entryIds.has(u.id) ? { ...u, state: 'preparing' } : u)));

      try {
        const filesMap: Record<string, any> = {};
        const fileIdByEntryId = new Map<string, string>();
        for (const item of incoming) {
          const fileId = `file-${item.id}`;
          fileIdByEntryId.set(item.id, fileId);
          filesMap[fileId] = {
            id: fileId,
            fileName: item.file.name,
            size: item.file.size,
            fileType: item.file.type || 'application/octet-stream',
            sha256: null,
            preview: null,
            metadata: null,
          };
        }

        const prepareBody = {
          info: {
            alias: 'Browser',
            version: '2.0',
            deviceModel: typeof navigator !== 'undefined' ? navigator.userAgent : 'Browser',
            deviceType: detectDeviceType(),
            fingerprint: sessionRef.current.sessionId || sessionRef.current.clientId,
            port: 0,
            protocol: typeof location !== 'undefined' && location.protocol === 'https:' ? 'https' : 'http',
            download: false,
          },
          files: filesMap,
        };

        const pinQuery = sessionRef.current.pin ? `?pin=${encodeURIComponent(sessionRef.current.pin)}` : '';
        let prepared: any;
        try {
          prepared = await apiRequest(API.prepareUpload + pinQuery, {
            method: 'POST',
            body: JSON.stringify(prepareBody),
          });
        } catch (err: any) {
          // Brief retry if the previous session is still tearing down on the server
          if (err?.status === 409) {
            await new Promise((r) => setTimeout(r, 200));
            prepared = await apiRequest(API.prepareUpload + pinQuery, {
              method: 'POST',
              body: JSON.stringify(prepareBody),
            });
          } else {
            throw err;
          }
        }

        const sessionId = prepared?.sessionId;
        const tokensByFileId = prepared?.files || {};
        const acceptedQueue: Array<{ item: UploadEntry; fileId: string; token: string }> = [];

        for (const item of incoming) {
          const fileId = fileIdByEntryId.get(item.id)!;
          const token = tokensByFileId[fileId];
          if (!token) {
            setUploads((prev) =>
              prev.map((u) =>
                u.id === item.id ? { ...u, state: 'error', error: 'The receiving device declined this file.' } : u,
              ),
            );
          } else {
            acceptedQueue.push({ item, fileId, token });
          }
        }

        if (!sessionId || acceptedQueue.length === 0) {
          throw new Error('The receiving device declined the upload.');
        }

        // Stream large files (>= 32 MiB) sequentially to maximize single-stream throughput
        // and avoid disk head/channel contention; pipeline multi-file batches using chunkStreams.
        const hasLargeFile = acceptedQueue.some(({ item }) => item.file.size >= 32 * 1024 * 1024);
        const concurrency = hasLargeFile
          ? 1
          : Math.max(1, Math.min(chunkStreamsRef.current || 4, 8, acceptedQueue.length));

        let cursor = 0;
        const worker = async () => {
          while (cursor < acceptedQueue.length) {
            const next = acceptedQueue[cursor++];
            try {
              await uploadPreparedFile(sessionId, next.fileId, next.item.id, next.item.file, next.token);
            } catch (error: any) {
              const message = error?.message || 'Upload failed';
              setUploads((prev) =>
                prev.map((u) => (u.id === next.item.id ? { ...u, state: 'error', error: message } : u)),
              );
              setBanner({ text: message, kind: 'error' });
            }
          }
        };

        await Promise.all(Array.from({ length: concurrency }, () => worker()));
      } catch (error: any) {
        const message = error?.message || 'Upload failed';
        setUploads((prev) =>
          prev.map((u) => (entryIds.has(u.id) ? { ...u, state: 'error', error: message } : u)),
        );
        setBanner({ text: message, kind: 'error' });
      }
    },
    [apiRequest, uploadPreparedFile],
  );

  const handleSelectedFiles = useCallback(
    (fileList: FileList | null) => {
      if (!fileList || fileList.length === 0) return;
      const baseTs = Date.now();
      const incoming: UploadEntry[] = Array.from(fileList).map((file, idx) => ({
        id: `browser-${baseTs}-${idx}`,
        file,
        state: 'queued' as const,
        progress: 0,
      }));
      setUploads((prev) => [...incoming, ...prev]);
      uploadQueueRef.current = uploadQueueRef.current
        .catch(() => {})
        .then(() => uploadBatch(incoming));
    },
    [uploadBatch],
  );

  const matchesFilter = useCallback(
    (fileName: string, fileType = '') => {
      const q = searchQuery.trim().toLowerCase();
      if (q && !fileName.toLowerCase().includes(q)) return false;
      if (categoryFilter === 0) return true;
      const badge = fileBadge(fileName, fileType);
      if (categoryFilter === 1) return badge === 'IMG' || badge === 'VID' || badge === 'AUD';
      if (categoryFilter === 2) return badge === 'DOC';
      if (categoryFilter === 3) return badge === 'ZIP';
      return true;
    },
    [searchQuery, categoryFilter],
  );

  const filteredUploads = useMemo(
    () => uploads.filter((u) => matchesFilter(u.file.name, u.file.type)),
    [uploads, matchesFilter],
  );

  const filteredWebSendFiles = useMemo(
    () => webSendFiles.filter((f) => matchesFilter(f.fileName, f.fileType)),
    [webSendFiles, matchesFilter],
  );

  const filteredOfferFiles = useMemo(
    () =>
      offers.flatMap((offer) =>
        offer.files
          .filter((f) => matchesFilter(f.fileName, f.fileType))
          .map((file) => ({ offer, file })),
      ),
    [offers, matchesFilter],
  );

  useEffect(() => {
    if (!pinRequired) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      if (/^[0-9]$/.test(event.key)) {
        event.preventDefault();
        setPinBuffer((prev) => (prev.length < 12 ? prev + event.key : prev));
      } else if (event.key === 'Backspace') {
        event.preventDefault();
        setPinBuffer((prev) => prev.slice(0, -1));
      } else if (event.key === 'Enter' && pinBuffer) {
        event.preventDefault();
        sessionRef.current.pin = pinBuffer;
        setPinBuffer('');
        registerSession();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [pinRequired, pinBuffer, registerSession]);

  return (
    <div className="dp-stage">
      {/* Colorful multi-orb ambient backdrop so Liquid Glass bends rich gradients */}
      <div className="dp-StageBackdrop" aria-hidden="true">
        <div className="dp-orb dp-orb--one" />
        <div className="dp-orb dp-orb--two" />
        <div className="dp-orb dp-orb--three" />
      </div>

      <div className="dp-shell">
        {/* Device Header GlassCard */}
        <GlassCard intensity={intensity} radius="28px" padding="18px 22px">
          <div className="dp-header-row">
            <div className="dp-brand-mark" aria-hidden="true">
              D
            </div>
            <div className="dp-header-titles">
              <h1 id="deviceName">{alias}</h1>
              <p className="dp-subtitle" id="deviceHint">
                {deviceHint}
              </p>
              <div className="dp-badges">
                <span className="dp-sec-pill">&#128274; Direct Local Wi-Fi &bull; Peer-to-Peer LAN</span>
                <span
                  id="status"
                  className={`dp-status-pill ${statusKind === 'online' ? 'online' : statusKind === 'offline' ? 'offline' : ''}`}
                >
                  <span className="dp-status-dot" />
                  <span id="statusLabel">{statusText}</span>
                </span>
              </div>
            </div>
            <GlassButton
              variant="glass"
              size="sm"
              intensity={intensity}
              icon={IconControls}
              onClick={() => setControlsOpen(true)}
            >
              Glass &amp; Controls
            </GlassButton>
          </div>
        </GlassCard>

        {banner && (
          <GlassCard
            intensity={intensity}
            radius="20px"
            padding="12px 18px"
            tint={banner.kind === 'error' ? '#ff3b30' : '#0088ff'}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
              <span style={{ fontWeight: 600, fontSize: 13.5 }}>{banner.text}</span>
              <GlassButton variant="clear" size="sm" onClick={() => setBanner(null)}>
                Dismiss
              </GlassButton>
            </div>
          </GlassCard>
        )}

        {/* Mode Switcher Bar: GlassSegmented + semantic IDs for integration test compatibility */}
        <div className="dp-mode-bar" id="modeSwitch">
          {activeNav !== 2 && (
            <GlassSegmented
              intensity={intensity}
              options={[
                { label: 'Send', icon: IconUpload },
                { label: 'Receive', icon: IconDownload },
              ]}
              value={mode === 'receive' ? 1 : 0}
              onChange={(idx) => switchMode(idx === 1 ? 'receive' : 'send', true)}
              aria-label="Transfer direction"
            />
          )}
          <GlassSegmented
            size="sm"
            intensity={intensity}
            options={['System', 'Light', 'Dark']}
            value={themeIndex}
            onChange={setThemeIndex}
            aria-label="Theme mode"
          />
          {/* Hidden semantic buttons preserving #modeSend and #modeReceive IDs */}
          <div className="dp-sr-tabs" aria-hidden="true">
            <button
              id="modeSend"
              type="button"
              aria-selected={activeNav !== 2 && mode === 'send'}
              onClick={() => switchMode('send', true)}
            >
              Send to Device
            </button>
            <button
              id="modeReceive"
              type="button"
              aria-selected={activeNav !== 2 && mode === 'receive'}
              onClick={() => switchMode('receive', true)}
            >
              Send via browser
            </button>
          </div>
        </div>

        {/* Mode A: Send files from Browser to Device */}
        {activeNav === 0 && (
          <GlassCard id="uploadCard" intensity={intensity} radius="28px" padding="22px">
            <div className="dp-card-head">
              <div>
                <h2>Send files to this device</h2>
                <span className="dp-card-hint">Files transfer directly over local Wi-Fi into Dropit</span>
              </div>
              {uploads.length > 0 && (
                <GlassButton
                  variant="tinted"
                  size="sm"
                  intensity={intensity}
                  onClick={() => setActiveNav(2)}
                >
                  Queue ({uploads.length})
                </GlassButton>
              )}
            </div>

            <div
              id="dropZone"
              className={`dp-dropzone ${dragOver ? 'over' : ''}`}
              role="button"
              tabIndex={0}
              aria-label="Choose files or drop them here"
              onClick={() => fileInputRef.current?.click()}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  fileInputRef.current?.click();
                }
              }}
              onDragEnter={(e) => {
                e.preventDefault();
                setDragOver(true);
              }}
              onDragOver={(e) => {
                e.preventDefault();
                setDragOver(true);
              }}
              onDragLeave={(e) => {
                e.preventDefault();
                setDragOver(false);
              }}
              onDrop={(e) => {
                e.preventDefault();
                setDragOver(false);
                if (e.dataTransfer?.files?.length) {
                  handleSelectedFiles(e.dataTransfer.files);
                }
              }}
            >
              <div className="dp-drop-icon" aria-hidden="true">
                {IconUpload}
              </div>
              <strong>Drop files here to send</strong>
              <p>or choose photos, videos, documents, and archives from your device</p>
              <div className="dp-drop-actions" onClick={(e) => e.stopPropagation()}>
                <GlassButton
                  id="chooseFilesBtn"
                  variant="filled"
                  size="md"
                  intensity={intensity}
                  icon={IconUpload}
                  onClick={() => fileInputRef.current?.click()}
                >
                  Choose Files
                </GlassButton>
                <GlassButton
                  variant="glass"
                  size="md"
                  intensity={intensity}
                  icon={IconDownload}
                  onClick={() => switchMode('receive', true)}
                >
                  Receive from Device
                </GlassButton>
              </div>
              <input
                ref={fileInputRef}
                id="fileInput"
                type="file"
                multiple
                hidden
                onChange={(e) => {
                  handleSelectedFiles(e.target.files);
                  e.target.value = '';
                }}
              />
            </div>

            {filteredUploads.length > 0 && (
              <div className="dp-list" id="uploadList">
                {filteredUploads.map((item) => (
                  <div className="dp-file-row" key={item.id}>
                    <div className="dp-file-badge">{fileBadge(item.file.name, item.file.type)}</div>
                    <div className="dp-file-info">
                      <p className="dp-file-name">{item.file.name}</p>
                      <div className="dp-file-meta">
                        {formatBytes(item.file.size)} &bull;{' '}
                        {item.state === 'uploading'
                          ? `${Math.round(item.progress * 100)}%`
                          : item.state === 'done'
                          ? 'Delivered'
                          : item.state === 'error'
                          ? item.error || 'Failed'
                          : 'Preparing…'}
                      </div>
                      {(item.state === 'uploading' || item.state === 'done') && (
                        <div className="dp-progress">
                          <span style={{ width: `${Math.round(item.progress * 100)}%` }} />
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </GlassCard>
        )}

        {/* Mode B: Send via Browser (Receive files from Dropit device) */}
        {activeNav === 1 && (
          <GlassCard id="offersCard" intensity={intensity} radius="28px" padding="22px">
            <div className="dp-card-head">
              <div>
                <h2>Receive files from device (Send via browser)</h2>
                <span className="dp-card-hint">Download files shared from Dropit to this browser</span>
              </div>
              <GlassButton
                id="refreshOffersBtn"
                variant="glass"
                size="sm"
                intensity={intensity}
                icon={IconRefresh}
                onClick={() => {
                  sendHeartbeat();
                  checkWebSendFiles();
                }}
              >
                Check for files
              </GlassButton>
            </div>

            <div className="dp-toolbar" style={{ marginBottom: 12 }}>
              <GlassSegmented
                size="sm"
                intensity={intensity}
                options={['All', 'Media', 'Docs', 'Archives']}
                value={categoryFilter}
                onChange={setCategoryFilter}
                aria-label="Filter files by category"
              />
            </div>

            <div id="offersBody" className="dp-list">
              {offers.map((offer) => {
                const visibleFiles = offer.files.filter((f) => matchesFilter(f.fileName, f.fileType));
                const totalBytes = visibleFiles.reduce((acc, f) => acc + (f.size || 0), 0);
                return (
                  <div className="dp-offer-box" key={offer.offerId}>
                    <div className="dp-offer-head">
                      <div>
                        <strong style={{ fontSize: 15 }}>
                          {visibleFiles.length === 1
                            ? visibleFiles[0].fileName
                            : `${visibleFiles.length} files offered from ${alias}`}
                        </strong>
                        <div className="dp-file-meta">{formatBytes(totalBytes)}</div>
                      </div>
                      {!offer.accepted && (
                        <div className="dp-offer-actions">
                          <GlassButton
                            variant="filled"
                            tint="#0F7A38"
                            size="sm"
                            intensity={intensity}
                            icon={IconDownload}
                            onClick={() => answerOffer(offer.offerId, true)}
                          >
                            Accept &amp; Download
                          </GlassButton>
                          <GlassButton
                            variant="tinted"
                            destructive
                            size="sm"
                            intensity={intensity}
                            onClick={() => answerOffer(offer.offerId, false)}
                          >
                            Decline
                          </GlassButton>
                        </div>
                      )}
                    </div>
                    {visibleFiles.map((file) => (
                      <div className="dp-file-row" key={file.id}>
                        <div className="dp-file-badge">{fileBadge(file.fileName, file.fileType)}</div>
                        <div className="dp-file-info">
                          <p className="dp-file-name">{file.fileName}</p>
                          <div className="dp-file-meta">{formatBytes(file.size || 0)}</div>
                        </div>
                        {offer.accepted && (
                          <GlassButton
                            variant="tinted"
                            size="sm"
                            intensity={intensity}
                            href={downloadUrl(offer.offerId, file.id)}
                            download={file.fileName}
                          >
                            Download
                          </GlassButton>
                        )}
                      </div>
                    ))}
                  </div>
                );
              })}

              {webSendSessionId && filteredWebSendFiles.length > 0 && (
                <div className="dp-offer-box">
                  <div className="dp-offer-head">
                    <div>
                      <strong style={{ fontSize: 15 }}>
                        {filteredWebSendFiles.length === 1
                          ? filteredWebSendFiles[0].fileName
                          : `${filteredWebSendFiles.length} shared files ready`}
                      </strong>
                      <div className="dp-file-meta">Shared via Dropit Send via Browser</div>
                    </div>
                  </div>
                  {filteredWebSendFiles.map((file) => {
                    const pinParam = sessionRef.current.pin
                      ? `&pin=${encodeURIComponent(sessionRef.current.pin)}`
                      : '';
                    const href = `${API.v2Download}?sessionId=${encodeURIComponent(
                      webSendSessionId,
                    )}&fileId=${encodeURIComponent(file.id)}${pinParam}`;
                    return (
                      <div className="dp-file-row" key={file.id}>
                        <div className="dp-file-badge">{fileBadge(file.fileName, file.fileType)}</div>
                        <div className="dp-file-info">
                          <p className="dp-file-name">{file.fileName}</p>
                          <div className="dp-file-meta">{formatBytes(file.size || 0)}</div>
                        </div>
                        <GlassButton
                          variant="filled"
                          size="sm"
                          intensity={intensity}
                          icon={IconDownload}
                          href={href}
                          download={file.fileName}
                        >
                          Download
                        </GlassButton>
                      </div>
                    );
                  })}
                </div>
              )}

              {offers.length === 0 && (!webSendSessionId || filteredWebSendFiles.length === 0) && (
                <div className="dp-empty" id="offersEmpty">
                  <strong>Ready to receive files from {alias}</strong>
                  Select this browser under <b>Connected Browsers</b> in Dropit&apos;s <b>Send</b> tab, or open{' '}
                  <b>Browser sharing &rarr; Send via browser</b> to push files directly to this page.
                </div>
              )}
            </div>
          </GlassCard>
        )}

        {/* Tab 3: Search & Transfer Queue */}
        {activeNav === 2 && (
          <GlassCard intensity={intensity} radius="28px" padding="22px">
            <div className="dp-card-head">
              <div>
                <h2>Transfer Queue &amp; File Search</h2>
                <span className="dp-card-hint">Filter uploaded and received files in this session</span>
              </div>
              {uploads.some((u) => u.state === 'done') && (
                <GlassButton
                  variant="clear"
                  size="sm"
                  intensity={intensity}
                  onClick={() => setUploads((prev) => prev.filter((u) => u.state !== 'done'))}
                >
                  Clear Completed
                </GlassButton>
              )}
            </div>

            <div className="dp-toolbar">
              <GlassInput
                type="search"
                intensity={intensity}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onClear={() => setSearchQuery('')}
                placeholder="Search files by name…"
              />
              <GlassSegmented
                size="sm"
                intensity={intensity}
                options={['All', 'Media', 'Docs', 'Archives']}
                value={categoryFilter}
                onChange={setCategoryFilter}
                aria-label="Category filter"
              />
            </div>

            <div className="dp-list">
              {filteredUploads.length === 0 &&
              filteredWebSendFiles.length === 0 &&
              filteredOfferFiles.length === 0 ? (
                <div className="dp-empty">
                  <strong>No matching transfers yet</strong>
                  Files you upload or receive during this session will appear here.
                </div>
              ) : (
                <>
                  {filteredOfferFiles.map(({ offer, file }) => (
                    <div className="dp-file-row" key={`offer-${offer.offerId}-${file.id}`}>
                      <div className="dp-file-badge">{fileBadge(file.fileName, file.fileType)}</div>
                      <div className="dp-file-info">
                        <p className="dp-file-name">{file.fileName}</p>
                        <div className="dp-file-meta">
                          {formatBytes(file.size || 0)} &bull; {offer.accepted ? 'OFFER ACCEPTED' : 'INCOMING OFFER'}
                        </div>
                      </div>
                      {offer.accepted ? (
                        <GlassButton
                          variant="tinted"
                          size="sm"
                          intensity={intensity}
                          href={downloadUrl(offer.offerId, file.id)}
                          download={file.fileName}
                        >
                          Download
                        </GlassButton>
                      ) : (
                        <GlassButton
                          variant="filled"
                          tint="#0F7A38"
                          size="sm"
                          intensity={intensity}
                          onClick={() => answerOffer(offer.offerId, true)}
                        >
                          Accept
                        </GlassButton>
                      )}
                    </div>
                  ))}

                  {webSendSessionId &&
                    filteredWebSendFiles.map((file) => {
                      const pinParam = sessionRef.current.pin
                        ? `&pin=${encodeURIComponent(sessionRef.current.pin)}`
                        : '';
                      const href = `${API.v2Download}?sessionId=${encodeURIComponent(
                        webSendSessionId,
                      )}&fileId=${encodeURIComponent(file.id)}${pinParam}`;
                      return (
                        <div className="dp-file-row" key={`websend-${file.id}`}>
                          <div className="dp-file-badge">{fileBadge(file.fileName, file.fileType)}</div>
                          <div className="dp-file-info">
                            <p className="dp-file-name">{file.fileName}</p>
                            <div className="dp-file-meta">{formatBytes(file.size || 0)} &bull; SHARED FROM DEVICE</div>
                          </div>
                          <GlassButton
                            variant="filled"
                            size="sm"
                            intensity={intensity}
                            icon={IconDownload}
                            href={href}
                            download={file.fileName}
                          >
                            Download
                          </GlassButton>
                        </div>
                      );
                    })}

                  {filteredUploads.map((item) => (
                    <div className="dp-file-row" key={item.id}>
                      <div className="dp-file-badge">{fileBadge(item.file.name, item.file.type)}</div>
                      <div className="dp-file-info">
                        <p className="dp-file-name">{item.file.name}</p>
                        <div className="dp-file-meta">
                          {formatBytes(item.file.size)} &bull; {item.state.toUpperCase()}
                        </div>
                      </div>
                    </div>
                  ))}
                </>
              )}
            </div>
          </GlassCard>
        )}

        <footer className="dp-footer">
          <span>Files transfer directly over your local Wi-Fi network without internet or cloud storage.</span>
          <a id="trustLink" href="/dropit-ca.crt" download="dropit-ca.crt" hidden={!showTrustLink}>
            Install Local HTTPS Certificate
          </a>
        </footer>
      </div>

      {/* Bottom Liquid Glass Navigation Dock */}
      <div className="dp-bottom-dock">
        <GlassNav
          intensity={intensity}
          activeIndex={controlsOpen ? 3 : activeNav}
          onChange={(index) => {
            if (index === 3) {
              setControlsOpen(true);
            } else {
              setControlsOpen(false);
              if (index === 0) switchMode('send', true);
              else if (index === 1) switchMode('receive', true);
              else setActiveNav(index);
            }
          }}
          items={[
            { label: 'Send', icon: IconUpload },
            { label: 'Receive', icon: IconDownload },
            { label: 'Queue', icon: IconQueue },
            { label: 'Controls', icon: IconControls },
          ]}
          aria-label="Portal Navigation"
        />
      </div>

      {/* Control Center & Liquid Glass Settings Bottom Sheet */}
      <GlassSheet
        open={controlsOpen}
        onClose={() => setControlsOpen(false)}
        intensity={intensity}
        aria-label="Liquid Glass Control Center"
      >
        <div className="dp-controls-grid">
          <div className="dp-card-head" style={{ marginBottom: 4 }}>
            <div style={{ minWidth: 0, flex: '1 1 200px' }}>
              <h2>Liquid Glass Control Center</h2>
              <span className="dp-card-hint">Tune optical refraction, transfer streams, and preferences</span>
            </div>
            <GlassButton variant="clear" size="sm" onClick={() => setControlsOpen(false)}>
              Done
            </GlassButton>
          </div>

          {/* Control Center Block Slider (showThumb={false}) */}
          <GlassSlider
            showThumb={false}
            min={1}
            max={10}
            step={1}
            value={intensity}
            onChange={setIntensity}
            intensity={intensity}
            icon={IconSparkle}
            label="Glass Refraction"
          />

          {/* Standard Lens-Thumb GlassSlider */}
          <div className="dp-setting-row" style={{ display: 'grid', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
              <div className="dp-setting-text">
                <strong>Parallel Transfer Streams</strong>
                <span>Concurrent local Wi-Fi chunk pipelines</span>
              </div>
              <strong style={{ fontSize: 14, flexShrink: 0 }}>{chunkStreams}x</strong>
            </div>
            <GlassSlider
              showThumb={true}
              min={1}
              max={8}
              step={1}
              value={chunkStreams}
              onChange={setChunkStreams}
              intensity={intensity}
              aria-label="Parallel transfer streams"
            />
          </div>

          <div className="dp-setting-row">
            <div className="dp-setting-text">
              <strong>Auto-Accept Incoming Files</strong>
              <span>Automatically start downloading offers sent from {alias}</span>
            </div>
            <GlassSwitch checked={autoAccept} onChange={setAutoAccept} intensity={intensity} />
          </div>

          <div className="dp-setting-row">
            <div className="dp-setting-text">
              <strong>High-Refraction Optical Lens</strong>
              <span>Full Snell&apos;s-law chromatic dispersion &amp; specular rim</span>
            </div>
            <GlassSwitch checked={highQualityLens} onChange={setHighQualityLens} intensity={intensity} />
          </div>

          <div className="dp-setting-row">
            <div className="dp-setting-text">
              <strong>Tactile Haptics</strong>
              <span>Spring-coupled haptic feedback on touch devices</span>
            </div>
            <GlassSwitch checked={hapticsEnabled} onChange={setHapticsEnabled} intensity={intensity} />
          </div>
        </div>
      </GlassSheet>

      {/* Button-only PIN Keypad GlassSheet (zero <form>/<input> on HTTP) */}
      <GlassSheet
        open={pinRequired}
        onClose={() => setPinRequired(false)}
        intensity={intensity}
        aria-label="Enter Device PIN"
      >
        <div className="dp-pin-wrap">
          <div style={{ textAlign: 'center' }}>
            <h2 style={{ margin: '0 0 4px', fontSize: 18 }}>Enter Transfer PIN</h2>
            <span className="dp-card-hint">Required by {alias} to authorize this browser</span>
          </div>
          <div className="dp-pin-display" id="pinDisplay" aria-live="polite">
            {pinBuffer ? pinBuffer : '••••'}
          </div>
          <div className="dp-pin-grid" id="pinGrid">
            {['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((digit) => (
              <GlassButton
                key={digit}
                variant="glass"
                size="md"
                intensity={intensity}
                onClick={() => setPinBuffer((prev) => (prev.length < 12 ? prev + digit : prev))}
              >
                {digit}
              </GlassButton>
            ))}
            <GlassButton
              variant="clear"
              size="md"
              intensity={intensity}
              onClick={() => setPinBuffer('')}
            >
              Clear
            </GlassButton>
            <GlassButton
              variant="glass"
              size="md"
              intensity={intensity}
              onClick={() => setPinBuffer((prev) => (prev.length < 12 ? prev + '0' : prev))}
            >
              0
            </GlassButton>
            <GlassButton
              variant="glass"
              size="md"
              intensity={intensity}
              onClick={() => setPinBuffer((prev) => prev.slice(0, -1))}
            >
              &#9003;
            </GlassButton>
          </div>
          <GlassButton
            variant="filled"
            size="lg"
            intensity={intensity}
            disabled={!pinBuffer}
            onClick={() => {
              if (!pinBuffer) return;
              sessionRef.current.pin = pinBuffer;
              setPinBuffer('');
              registerSession();
            }}
          >
            Connect to {alias}
          </GlassButton>
        </div>
      </GlassSheet>
    </div>
  );
}
export default DropitGlassApp;
