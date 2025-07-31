# ffmpeg-video-quick-merger-gui

A simple Windows GUI tool for quickly merging multiple `.mp4` videos using FFmpeg, without re-encoding. Designed for fast concatenation of long videos.

## Features

- Drag-and-drop interface for adding videos
- Checks video compatibility (codec, resolution, framerate, audio)
- Option to override minor stream mismatches
- No re-encoding: merges videos as-is for speed
- Logging and cleanup utilities

## Demo

Watch below or on [YouTube](#same-demo-on-youtube)
  
https://github.com/user-attachments/assets/665e7d74-d6a5-48d6-9e11-6889985804d3

### Same demo on YouTube:

[![ ffmeg-video-quick-merger-gui Demo 2025 08 01 05 31 30 1](https://markdown-videos-api.jorgenkh.no/url?url=https%3A%2F%2Fyoutu.be%2FfnAvmgr0POk)](https://youtu.be/fnAvmgr0POk)

## Why No Re-Encoding?

This tool is intended for merging hours-long videos quickly. Re-encoding is intentionally omitted to save time and system resources. If you need re-encoding or format conversion, feel free to fork and extend!

## Why allow to override minor stream mismatches?

FFmpeg allows merging videos with small differences in stream properties, such as framerate (FPS). Overriding minor mismatches (e.g., up to 0.5 FPS difference) enables fast concatenation without re-encoding, which is useful for videos recorded on similar devices or settings. However, merging files with larger differences can cause audio/video sync issues or playback glitches.

**Disclaimer:** Only override stream mismatches if the FPS difference is 1-3 FPS (e.g., 27.5 vs 30.0). Merging videos with greater differences may result in audio/video de-synchronization or playback problems. Always preview the merged output before sharing or archiving.

## Dependencies & System Requirements

- **Windows** (PowerShell 5.1+ recommended)
- [.NET Framework](https://dotnet.microsoft.com/download/dotnet-framework) (for Windows Forms, usually included out of the box in Windows 10 and above)
- [FFmpeg](https://ffmpeg.org/download.html) (must have `ffmpeg.exe` and `ffprobe.exe`)
- PowerShell (tested on Windows PowerShell 5.1 and PowerShell Core 6+)

## How Tos

Watch this [rickroll demo](#Demo)

[![ ffmeg-video-quick-merger-gui Demo 2025 08 01 05 31 30 1](https://markdown-videos-api.jorgenkh.no/url?url=https%3A%2F%2Fyoutu.be%2FfnAvmgr0POk)](https://youtu.be/fnAvmgr0POk)

Or:

### Configuration

- On first run, set the FFmpeg directory in the GUI or make/edit [`ffmpeg-gui.ini`](ffmpeg-gui.ini) from [`ffmpeg-gui.ini.local`](ffmpeg-gui.ini.local).
- Example config:
  ```
  ffmpeg_path=C:\ffmpeg\bin
  ```
- Output is saved as `merged_output.mp4` in the script directory.

### Usage

1. Launch [`ffmpeg-gui.ps1`](ffmpeg-gui.ps1) in PowerShell.
2. Set the FFmpeg directory if not auto-detected.
3. Drag and drop at least two `.mp4` files.
4. Click "Merge Videos".

## WIP / Disclaimer

- **WIP:** Custom output path selection is planned.
- Only merges videos; does **not** re-encode.
- For fast merging of compatible videos.
- Feel free to fork and add new features!

---

**Note:** If videos are not compatible, you may need to re-encode them. Use `ffmpeg` for that.
