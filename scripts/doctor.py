#!/usr/bin/env python3
"""Non-destructive host checks for the LocalSend-based Flutter build."""
import json
import platform
import shutil
import subprocess
from pathlib import Path


def command_version(binary: str, args: list[str]) -> str:
    exe = shutil.which(binary)
    if not exe:
        return "NOT INSTALLED"
    try:
        process = subprocess.run([exe, *args], capture_output=True, text=True, timeout=15)
        lines = (process.stdout or process.stderr).strip().splitlines()
        return (lines[0] if lines else f"exit {process.returncode}")[:160]
    except Exception as exc:
        return f"UNKNOWN: {exc}"


def main() -> None:
    report = {
        "host_os": platform.platform(),
        "git": command_version("git", ["--version"]),
        "flutter": command_version("flutter", ["--version"]),
        "fvm": command_version("fvm", ["--version"]),
        "rustc": command_version("rustc", ["--version"]),
        "cargo": command_version("cargo", ["--version"]),
        "xcodebuild": command_version("xcodebuild", ["-version"]),
        "java": command_version("java", ["-version"]),
    }
    print(json.dumps(report, indent=2))
    print("Note: macOS/iOS require a Mac with Xcode; Windows builds require Windows + Visual Studio C++.")


if __name__ == "__main__":
    main()
