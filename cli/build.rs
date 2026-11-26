fn main() {
    // VERSIONINFO metadata for the Windows exe, mirroring app/windows/runner/Runner.rc.
    // SignPath requires ProductName/ProductVersion on all signed binaries.
    if std::env::var_os("CARGO_CFG_WINDOWS").is_some() {
        let mut res = winresource::WindowsResource::new();
        res.set("ProductName", "Dropit");
        res.set("FileDescription", "Dropit CLI");
        res.set("CompanyName", "Aanantharasa Rathursikan");
        res.set("OriginalFilename", "dropit-cli.exe");
        res.set("InternalName", "dropit-cli");
        res.set(
            "LegalCopyright",
            "Copyright (C) 2022-2026 Aanantharasa Rathursikan",
        );
        // FileVersion/ProductVersion are derived from CARGO_PKG_VERSION automatically.
        res.compile().expect("failed to compile Windows resources");
    }
}
