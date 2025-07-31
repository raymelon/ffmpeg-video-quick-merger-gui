Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === CONFIGURATION ===
$configFile = Join-Path -Path $PSScriptRoot -ChildPath "ffmpeg-gui.ini"

function Load-Config {
    if (-not (Test-Path $configFile)) {
        Set-Content -Path $configFile -Value "ffmpeg_path=C:\\ffmpeg\\bin"
    }
    $config = Get-Content $configFile | Where-Object { $_ -match "=" } | ForEach-Object { $_ -replace '\\', '\\\\' } | ConvertFrom-StringData
    return $config.ffmpeg_path
}

function Save-Config {
    param($path)
    Set-Content -Path $configFile -Value "ffmpeg_path=$path"
}

function Write-Log {
    param($msg)
    $gmtTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
    $logEntry = "[$gmtTimestamp] $msg"
    
    # Write to GUI
    $outputBox.AppendText("`n$logEntry")
    
    # Write to log file
    try {
        Add-Content -Path $script:logFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {
        # Silently continue if log file write fails
    }
}

# Global path values
$script:ffmpegDir = Load-Config
$script:ffmpegPath = ""
$script:ffprobePath = ""
$outputPath = "$PSScriptRoot\\merged_output.mp4"

# Logging setup
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$script:logFile = Join-Path -Path $PSScriptRoot -ChildPath "ffmpeg-gui_$timestamp.log"

function Refresh-FFmpegPaths {
    $script:ffmpegPath = Join-Path $script:ffmpegDir "ffmpeg.exe"
    $script:ffprobePath = Join-Path $script:ffmpegDir "ffprobe.exe"
}
Refresh-FFmpegPaths

function Parse-Framerate {
    param($framerate)
    if ($framerate -match "/") {
        $parts = $framerate -split "/"
        return [double]$parts[0] / [double]$parts[1]
    } else {
        return [double]$framerate
    }
}

function Get-VideoInfo {
    param($file)
    Write-Host "Running ffprobe on: $file" -ForegroundColor Yellow
    Write-Log "Running ffprobe on: $file"
    
    $ffprobeOutput = & $script:ffprobePath -v quiet -print_format json -show_streams "$file" 2>&1
    
    # Output ffprobe results to both terminal and GUI
    Write-Host "FFprobe output:" -ForegroundColor Cyan
    Write-Host $ffprobeOutput -ForegroundColor Gray
    Write-Log "FFprobe output: $ffprobeOutput"
    
    try {
        $json = $ffprobeOutput | ConvertFrom-Json
        $videoStream = $json.streams | Where-Object { $_.codec_type -eq "video" }
        $audioStream = $json.streams | Where-Object { $_.codec_type -eq "audio" }

        $result = @{
            Codec      = $videoStream.codec_name
            Width      = $videoStream.width
            Height     = $videoStream.height
            Framerate  = $videoStream.avg_frame_rate
            FramerateVal = Parse-Framerate $videoStream.avg_frame_rate
            AudioCodec = $audioStream.codec_name
        }
        
        Write-Log "Parsed video info: Codec=$($result.Codec), Resolution=$($result.Width)x$($result.Height), Framerate=$($result.Framerate), AudioCodec=$($result.AudioCodec)"
        
        return $result
    }
    catch {
        Write-Host "Error parsing ffprobe output: $_" -ForegroundColor Red
        Write-Log "Error parsing ffprobe output: $_"
        return $null
    }
}

function Check-Compatibility {
    param($files)
    $ref = Get-VideoInfo -file $files[0]
    $hasWarnings = $false

    foreach ($file in $files) {
        $info = Get-VideoInfo -file $file

        if ($info.Codec -ne $ref.Codec -or
            $info.Width -ne $ref.Width -or
            $info.Height -ne $ref.Height -or
            $info.AudioCodec -ne $ref.AudioCodec) {
            return @{ Compatible = $false; Warning = $true }
        }

        $delta = [math]::Abs($ref.FramerateVal - $info.FramerateVal)
        $tolerance = $ref.FramerateVal * 0.03
        if ($delta -gt $tolerance) {
            $hasWarnings = $true
        }
    }
    return @{ Compatible = $true; Warning = $hasWarnings }
}

# === GUI SETUP ===
$form = New-Object Windows.Forms.Form
$form.Text = "Video Merger"
$form.Size = New-Object Drawing.Size(500, 690)
$form.MinimumSize = New-Object Drawing.Size(500, 690)
$form.StartPosition = "CenterScreen"

# === OUTPUT BOX ===
$outputBox = New-Object Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ReadOnly = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Size = New-Object Drawing.Size(460, 160)
$outputBox.Location = New-Object Drawing.Point(10, 390)
$form.Controls.Add($outputBox)

# Initialize logging
Write-Log "=== FFmpeg GUI Session Started ==="
Write-Log "Log file: $script:logFile"


# === FFMPEG PATH INPUT + SAVE/CLEAR ===
$pathLabel = New-Object Windows.Forms.Label
$pathLabel.Text = "FFmpeg Directory:"
$pathLabel.Location = New-Object Drawing.Point(10, 10)
$pathLabel.AutoSize = $true
$form.Controls.Add($pathLabel)

$pathBox = New-Object Windows.Forms.TextBox
$pathBox.Size = New-Object Drawing.Size(270, 20)
$pathBox.Location = New-Object Drawing.Point(120, 8)
$pathBox.Text = $script:ffmpegDir
$form.Controls.Add($pathBox)

$savePathButton = New-Object Windows.Forms.Button
$savePathButton.Text = "Save"
$savePathButton.Size = New-Object Drawing.Size(60, 22)
$savePathButton.Location = New-Object Drawing.Point(400, 6)
$form.Controls.Add($savePathButton)

$clearPathButton = New-Object Windows.Forms.Button
$clearPathButton.Text = "Clear"
$clearPathButton.Size = New-Object Drawing.Size(60, 22)
$clearPathButton.Location = New-Object Drawing.Point(400, 30)
$form.Controls.Add($clearPathButton)

$savePathButton.Add_Click({
    $script:ffmpegDir = $pathBox.Text
    Save-Config -path $script:ffmpegDir
    Refresh-FFmpegPaths
    Write-Log "✅ Saved and applied FFmpeg path: $script:ffmpegDir"
})

$clearPathButton.Add_Click({
    $pathBox.Text = ""
    $script:ffmpegDir = ""
    Save-Config -path ""
    Refresh-FFmpegPaths
    Write-Log "🧹 Cleared FFmpeg path"
})

# === FILE LIST ===
$label = New-Object Windows.Forms.Label
$label.Text = "Drag and drop videos below:"
$label.AutoSize = $true
$label.Location = New-Object Drawing.Point(10, 60)
$form.Controls.Add($label)

$listBox = New-Object Windows.Forms.ListBox
$listBox.Size = New-Object Drawing.Size(460, 240)
$listBox.Location = New-Object Drawing.Point(10, 80)
$listBox.AllowDrop = $true
$listBox.Add_DragEnter({
    if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
        $_.Effect = [Windows.Forms.DragDropEffects]::Copy
    }
})
$listBox.Add_DragDrop({
    $dropped = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
    foreach ($file in $dropped) {
        if ($file -like "*.mp4") {
            $listBox.Items.Add($file)
        }
    }
})
$form.Controls.Add($listBox)

# === WARNING LABEL ===
$warningLabel = New-Object Windows.Forms.Label
$warningLabel.Text = ""
$warningLabel.ForeColor = [Drawing.Color]::Red
$warningLabel.Location = New-Object Drawing.Point(10, 285)
$warningLabel.Size = New-Object Drawing.Size(460, 30)
$form.Controls.Add($warningLabel)

# === MERGE BUTTON ===
$mergeButton = New-Object Windows.Forms.Button
$mergeButton.Text = "Merge Videos"
$mergeButton.Size = New-Object Drawing.Size(120, 30)
$mergeButton.Location = New-Object Drawing.Point(10, 355)
$form.Controls.Add($mergeButton)

# === OVERRIDE CHECKBOX (Moved below warning label and before merge button) ===
$overrideCheck = New-Object Windows.Forms.CheckBox
$overrideCheck.Text = "Allow merge despite stream parameter mismatches (may cause audio/video sync issues)"
$overrideCheck.Location = New-Object Drawing.Point(10, 325)
$overrideCheck.Size = New-Object Drawing.Size(460, 30)
$form.Controls.Add($overrideCheck)


# === CLEANUP BUTTONS ===
$clearFilelistButton = New-Object Windows.Forms.Button
$clearFilelistButton.Text = "Clear filelist.txt"
$clearFilelistButton.Size = New-Object Drawing.Size(120, 25)
$clearFilelistButton.Location = New-Object Drawing.Point(10, 560)
$form.Controls.Add($clearFilelistButton)

$clearLogButton = New-Object Windows.Forms.Button
$clearLogButton.Text = "Clear log files"
$clearLogButton.Size = New-Object Drawing.Size(120, 25)
$clearLogButton.Location = New-Object Drawing.Point(140, 560)
$form.Controls.Add($clearLogButton)

$clearFilelistButton.Add_Click({
    try {
        $filelistPattern = "$env:TEMP\\filelist*.txt"
        $filelistFiles = Get-ChildItem -Path $filelistPattern -ErrorAction SilentlyContinue
        
        if ($filelistFiles) {
            foreach ($file in $filelistFiles) {
                Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "Deleted: $($file.FullName)" -ForegroundColor Green
            }
            Write-Log "🧹 Cleared filelist files: $($filelistFiles.Count) files deleted"
        } else {
            Write-Log "🧹 No filelist files found to clear"
        }
    } catch {
        Write-Log "❌ Error clearing filelist files: $_"
    }
})

$clearLogButton.Add_Click({
    try {
        $logPattern = "$PSScriptRoot\\ffmpeg-gui_*.log"
        $logFiles = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
        
        if ($logFiles) {
            foreach ($file in $logFiles) {
                # Don't delete the current session's log file
                if ($file.FullName -ne $script:logFile) {
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host "Deleted: $($file.FullName)" -ForegroundColor Green
                }
            }
            $deletedCount = $logFiles.Count
            if ($logFiles | Where-Object { $_.FullName -eq $script:logFile }) {
                $deletedCount--
            }
            Write-Log "🧹 Cleared log files: $deletedCount files deleted (current session log preserved)"
        } else {
            Write-Log "🧹 No log files found to clear"
        }
    } catch {
        Write-Log "❌ Error clearing log files: $_"
    }
})

function Get-UniqueFilePath {
    param($basePath)
    $counter = 0
    $testPath = $basePath
    
    while (Test-Path $testPath) {
        $counter++
        $directory = [System.IO.Path]::GetDirectoryName($basePath)
        $filename = [System.IO.Path]::GetFileNameWithoutExtension($basePath)
        $extension = [System.IO.Path]::GetExtension($basePath)
        $testPath = Join-Path $directory "$filename-$counter$extension"
    }
    
    return $testPath
}

$mergeButton.Add_Click({
    $files = @()
    foreach ($item in $listBox.Items) {
        $files += $item.ToString()
    }

    if ($files.Count -lt 2) {
        Write-Log "❌ Add at least two videos."
        return
    }

    if (-not (Test-Path $script:ffmpegPath) -or -not (Test-Path $script:ffprobePath)) {
        Write-Log "❌ ffmpeg.exe or ffprobe.exe not found in: $script:ffmpegDir"
        return
    }

    Write-Log "Checking compatibility..."
    $checkResult = Check-Compatibility -files $files

    if ((-not $checkResult.Compatible -or $checkResult.Warning) -and -not $overrideCheck.Checked) {
        if (-not $checkResult.Compatible) {
            $warningLabel.Text = "⚠️ Videos are NOT compatible. Re-encode may be required."
            Write-Log "❌ Incompatible parameters. Aborting."
        } elseif ($checkResult.Warning) {
            $warningLabel.Text = "⚠️ Stream parameters differ slightly. May cause sync issues."
            Write-Log "❌ Minor parameter differences detected. Aborting."
        }
        return
    }

    if ($checkResult.Warning -and $overrideCheck.Checked) {
        $warningLabel.Text = "⚠️ Override enabled: proceeding despite parameter mismatches."
        Write-Log "⚠️ Override enabled. Merging despite minor differences."
    } else {
        $warningLabel.Text = ""
    }

    $listFile = "$env:TEMP\\filelist.txt"
    Remove-Item $listFile -Force -ErrorAction SilentlyContinue
    
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell 6+ has UTF8NoBOM
        foreach ($file in $files) {
            Add-Content $listFile ("file '$file'") -Encoding UTF8NoBOM
        }
    } else {
        # PowerShell 5.1 fallback - use System.IO.File for UTF-8 without BOM
        $fileListContent = @()
        foreach ($file in $files) {
            $fileListContent += "file '$file'"
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        $content = $fileListContent -join "`n"
        [System.IO.File]::WriteAllText($listFile, $content, $utf8NoBom)
    }

    Write-Log "Merging videos..."
    Write-Host "Starting FFmpeg merge process..." -ForegroundColor Yellow
    
    $ffmpegCmd = "`"$script:ffmpegPath`" -f concat -safe 0 -i `"$listFile`" -c copy `"$outputPath`""
    Write-Log "Command: $ffmpegCmd"
    Write-Host "Command: $ffmpegCmd" -ForegroundColor Cyan
    
    try {
        # Use Start-Process to capture output and exit code
        $process = Start-Process -FilePath $script:ffmpegPath -ArgumentList "-f", "concat", "-safe", "0", "-i", $listFile, "-c", "copy", $outputPath -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\ffmpeg_stdout.txt" -RedirectStandardError "$env:TEMP\ffmpeg_stderr.txt"
        
        # Read and display output
        $stdout = Get-Content "$env:TEMP\ffmpeg_stdout.txt" -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content "$env:TEMP\ffmpeg_stderr.txt" -Raw -ErrorAction SilentlyContinue
        
        if ($stdout) {
            Write-Host "FFmpeg stdout:" -ForegroundColor Green
            Write-Host $stdout -ForegroundColor Gray
            Write-Log "FFmpeg stdout: $stdout"
        }
        
        if ($stderr) {
            Write-Host "FFmpeg stderr:" -ForegroundColor Magenta
            Write-Host $stderr -ForegroundColor Gray
            Write-Log "FFmpeg stderr: $stderr"
        }
        
        Write-Host "FFmpeg process exit code: $($process.ExitCode)" -ForegroundColor Yellow
        Write-Log "FFmpeg process exit code: $($process.ExitCode)"
        
        if ($process.ExitCode -eq 0) {
            Write-Log "🎉 Done! Output: $outputPath"
            Write-Host "🎉 SUCCESS! Output saved to: $outputPath" -ForegroundColor Green
        } else {
            Write-Log "❌ FFmpeg failed with exit code: $($process.ExitCode)"
            Write-Host "❌ FFmpeg failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        }
        
        # Clean up temp files
        Remove-Item "$env:TEMP\ffmpeg_stdout.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\ffmpeg_stderr.txt" -Force -ErrorAction SilentlyContinue
        
    } catch {
        $errorMsg = "Error running FFmpeg: $_"
        Write-Log $errorMsg
        Write-Host $errorMsg -ForegroundColor Red
    }
})

[void]$form.ShowDialog()