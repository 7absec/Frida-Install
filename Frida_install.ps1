#region Helper: Check Dependencies
function Check-Command {
    param (
        [string]$name,
        [string]$command
    )
    try {
        Get-Command $command -ErrorAction Stop | Out-Null
        Write-Host "[✓] $name is installed." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[X] $name is not installed or not in PATH." -ForegroundColor Red
        return $false
    }
}

# Check required tools
$adbOK = Check-Command "ADB" "adb"
$pythonOK = Check-Command "Python" "python"
$pipOK = Check-Command "pip" "pip"
$sevenZipOK = Check-Command "7-Zip (7z)" "7z"
$curlOK = Check-Command "curl" "curl"

if (-not ($adbOK -and $pythonOK -and $pipOK -and $sevenZipOK -and $curlOK)) {
    Write-Host "❌ One or more dependencies are missing. Please install the missing tools and try again." -ForegroundColor Red
    exit
}
#endregion

#region Helper: Get Frida Versions from PyPI
function Get-FridaPyPI-Versions {
    param (
        [string]$majorInput
    )

    $url = "https://pypi.org/pypi/frida/json"
    Write-Host "Fetching available frida versions from $url..."

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $response = Invoke-RestMethod -Uri $url -UseBasicParsing

        if (-not $response -or -not $response.releases) {
            throw "Response or 'releases' section missing."
        }

        $versionKeys = $response.releases.PSObject.Properties.Name

        if (-not $versionKeys -or $versionKeys.Count -eq 0) {
            Write-Host "`n❌ No versions retrieved from PyPI." -ForegroundColor Red
            return @()
        }

        Write-Host "`nTotal Versions Fetched: $($versionKeys.Count)"
        $filtered = $versionKeys |
            Where-Object { $_ -match "^\d+\.\d+\.\d+$" -and $_ -like "$majorInput.*" } |
            Sort-Object -Descending

        if (-not $filtered) {
            Write-Host "❌ No matching versions found for major version '$majorInput'" -ForegroundColor Red
            return @()
        } else {
            Write-Host "✅ Found $($filtered.Count) matching versions for '$majorInput':"
            $filtered | ForEach-Object { Write-Host " - $_" }
            return $filtered
        }
    }
    catch {
        Write-Host "❌ Exception occurred: $_" -ForegroundColor Red
        return @()
    }
}
#endregion

#region Helper: Get Device Architecture
function Get-AndroidArch {
    Write-Host "\nDetecting connected Android device architecture..."
    try {
        $arch = adb shell getprop ro.product.cpu.abi | Out-String
        $arch = $arch.Trim()
        if ($arch) {
            Write-Host "✅ Detected architecture: $arch"
            return $arch
        } else {
            throw "Architecture not detected."
        }
    } catch {
        Write-Host "❌ Failed to detect architecture via ADB: $_" -ForegroundColor Red
        return $null
    }
}
#endregion

#region Helper: Install Frida Server on Android
function Install-FridaServer {
    param (
        [string]$version
    )

    $archMap = @{
        "arm64-v8a" = "arm64"
        "armeabi-v7a" = "arm"
        "x86_64" = "x86_64"
        "x86" = "x86"
    }

    $deviceArch = Get-AndroidArch
    if (-not $deviceArch -or -not $archMap.ContainsKey($deviceArch)) {
        Write-Host "❌ Unsupported or undetected architecture: $deviceArch" -ForegroundColor Red
        return
    }

    $fridaArch = $archMap[$deviceArch]
    $fileName = "frida-server-$version-android-$fridaArch.xz"
    $url = "https://github.com/frida/frida/releases/download/$version/$fileName"
    $outputDir = $env:TEMP

    if (-not (Test-Path $outputDir)) {
        try {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        } catch {
            Write-Host "❌ Failed to create temp directory: $_" -ForegroundColor Red
            return
        }
    }

    $downloadPath = Join-Path $outputDir $fileName
    $versionedName = "frida-server-$version-$fridaArch"
    $versionedPath = Join-Path $outputDir $versionedName

    Write-Host "\nDownloading frida-server from: $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $downloadPath -ErrorAction Stop

        if (-Not (Test-Path $downloadPath)) {
            Write-Host "❌ Failed to download: $downloadPath" -ForegroundColor Red
            return
        }
    } catch {
        Write-Host "❌ Failed to download frida-server: $_" -ForegroundColor Red
        return
    }

    Write-Host "Extracting .xz file..."
    & 7z e $downloadPath -o"$outputDir" -y > $null

    # Find the extracted binary
    $extractedBinary = Get-ChildItem -Path $outputDir -Filter "frida-server-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $extractedBinary -or -not (Test-Path $extractedBinary.FullName)) {
        Write-Host "❌ Extraction failed or frida-server binary not found." -ForegroundColor Red
        return
    }

    # Rename with version and arch to prevent overwrite
    Rename-Item -Path $extractedBinary.FullName -NewName $versionedName -Force

    Write-Host "Pushing $versionedName to device..."
    $remotePath = "/data/local/tmp/$versionedName"
    adb push "$versionedPath" $remotePath
    adb shell chmod +x $remotePath
    Write-Host "✅ Frida server installed successfully." -ForegroundColor Green
    Write-Host "✅ Use command to interact with Frida server: adb shell /data/local/tmp/$versionedName" -ForegroundColor Green
}
#endregion

#region Main Frida Installation Flow
function Install-FridaTools {
    Write-Host "\n[Frida Installation]" -ForegroundColor Cyan

    $fridaVersion = & frida --version 2>$null
    $skipClientUpdate = $false

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] Frida client already installed: v$fridaVersion" -ForegroundColor Green
        Write-Host "  [1] Keep current version"
        Write-Host "  [2] Update to latest"
        Write-Host "  [3] Install specific version"
        $choice = Read-Host "Select option (1, 2 or 3)"

        if ($choice -eq "2") {
            Write-Host "Updating frida-client via pip..."
            & pip install -U frida frida-tools
        } elseif ($choice -eq "3") {
            $majorInput = Read-Host "Enter Frida major version (e.g., 14)"
            $allFridaVersions = Get-FridaPyPI-Versions -majorInput $majorInput
            if ($allFridaVersions.Count -eq 0) {
                Write-Host "No matching versions found for $majorInput" -ForegroundColor Red
                exit 1
            }
            $selectedVersion = Read-Host "Type the exact Frida version you want to install from above list"
            $currentFrida = & pip show frida 2>$null | Select-String "^Version:" | ForEach-Object { ($_ -split ":\s*")[1] }
            if ($currentFrida -and $currentFrida -ne $selectedVersion) {
                $confirm = Read-Host "A different Frida version ($currentFrida) is installed. Uninstall it first? (y/n)"
                if ($confirm -eq "y") {
                    pip uninstall frida -y
                } else {
                    Write-Host "Cancelled by user. Exiting..." -ForegroundColor Yellow
                    return
                }
            }
            & pip install frida==$selectedVersion
            & pip install frida-tools --upgrade
        } else {
            Write-Host "Keeping current Frida client."
            $skipClientUpdate = $true
            $selectedVersion = $fridaVersion
        }
    } else {
        Write-Host "[✗] Frida client not found. Installing..." -ForegroundColor Yellow
        $major = Read-Host "Enter Frida major version (e.g., 14, 16)"
        $matchedVersions = Get-FridaPyPI-Versions -majorInput $major

        if ($matchedVersions.Count -gt 0) {
            $selectedVersion = Read-Host "Type the exact Frida version you want to install from above list"
            Write-Host "Installing frida==$selectedVersion and latest frida-tools..."
            pip install frida==$selectedVersion
            pip install frida-tools --upgrade
        }
        else {
            Write-Host "No matching versions found or failed to fetch versions." -ForegroundColor Red
            return
        }
    }

    $installServer = Read-Host "Do you want to install Frida Server on your Android device? (y/n)"
    if ($installServer -eq 'y') {
        Write-Host "  [1] Use same version as client"
        Write-Host "  [2] Update to latest"
        Write-Host "  [3] Install specific version"
        $serverChoice = Read-Host "Select Frida server version option (1, 2 or 3)"

        if ($serverChoice -eq "2") {
            $serverVersion = (Get-FridaPyPI-Versions -majorInput ($selectedVersion.Split('.')[0]))[0]
        } elseif ($serverChoice -eq "3") {
            $majorInput = Read-Host "Enter Frida major version (e.g., 14)"
            $allServerVersions = Get-FridaPyPI-Versions -majorInput $majorInput
            if ($allServerVersions.Count -eq 0) {
                Write-Host "No matching versions found for $majorInput" -ForegroundColor Red
                return
            }
            $serverVersion = Read-Host "Type the exact Frida server version you want to install from above list"
        } else {
            $serverVersion = $selectedVersion
        }
        Install-FridaServer -version $serverVersion
    }

    Write-Host "✅ Frida client, tools, and server (if selected) installation complete." -ForegroundColor Green

}

# Start installation
Install-FridaTools
#endregion
