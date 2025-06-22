# Prompt for root directory
$root = Read-Host "Enter the full path to the directory"

# Validate directory
if (-not (Test-Path $root)) {
    Write-Host "Directory does not exist. Please check the path." -ForegroundColor Red
    exit
}

# 7-Zip path
$sevenZip = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) {
    Write-Host "7-Zip not found at: $sevenZip" -ForegroundColor Red
    exit
}

# Supported extensions
$supportedExtensions = @(".zip", ".tar", ".gz", ".tgz", ".7z")

# Tracking
$processed = @{}

# Archive extractor
function Extract-Archive {
    param ($file)

    $ext = $file.Extension.ToLower()
    $destination = Join-Path $file.Directory.FullName $file.BaseName

    if (-not (Test-Path $destination)) {
        New-Item -ItemType Directory -Path $destination | Out-Null
    }

    $extracted = $false

    try {
        switch ($ext) {
            ".zip" {
                Expand-Archive -Path $file.FullName -DestinationPath $destination -Force
                $extracted = $true
            }
            ".tar" {
                tar -xf $file.FullName -C $destination
                $extracted = $true
            }
            ".gz" {
                if ($file.Name -like "*.tar.gz" -or $ext -eq ".tgz") {
                    $tempTar = Join-Path $file.Directory.FullName "$($file.BaseName)"
                    gunzip -c $file.FullName > "$tempTar"
                    tar -xf $tempTar -C $destination
                    Remove-Item $tempTar -Force
                    $extracted = $true
                }
            }
            ".7z" {
                & "$sevenZip" x "`"$($file.FullName)`"" -o"`"$destination`"" -y > $null
                $extracted = $true
            }
        }

        if ($extracted) {
            Write-Host "Extracted: $($file.FullName)" -ForegroundColor Cyan

            # Check if extraction produced any files and remove original archive if so
            if ((Get-ChildItem -Path $destination -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0) {
                Remove-Item $file.FullName -Force
                Write-Host "Deleted original archive: $($file.Name)" -ForegroundColor DarkGray
            }
        }
    }
    catch {
        Write-Host "Failed to extract: $($file.FullName)" -ForegroundColor Red
    }
}

# Keep scanning until no more unprocessed archives
do {
    $archives = Get-ChildItem -Path $root -Recurse -File | Where-Object {
        ($supportedExtensions -contains $_.Extension.ToLower()) -and (-not $processed.ContainsKey($_.FullName))
    }

    foreach ($archive in $archives) {
        Extract-Archive -file $archive
        $processed[$archive.FullName] = $true
    }
} while ($archives.Count -gt 0)

Write-Host "`n✅ All nested archives extracted and originals removed where appropriate." -ForegroundColor Green
