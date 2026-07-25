#Requires -Version 5.1
<#
.SYNOPSIS
Installs a verified portable GNU Emacs build for Windows.

.DESCRIPTION
Downloads the complete Windows ZIP from an official GNU mirror, verifies it
against the GNU SHA-256 file, extracts it under runtime, and optionally adds the
repository root to the current user's PATH.

The PATH update reads the registry value without expanding embedded variables,
then writes it back using its original registry value type. This avoids replacing
values such as %USERPROFILE% with expanded absolute paths.

.PARAMETER Version
GNU Emacs release to install. The default is 30.2.

.PARAMETER Mirror
Preferred GNU mirror. Auto tries the GNU redirector, Berkeley, Waterloo, and the
main GNU server in that order. A named mirror is tried first, then the remaining
mirrors are used as fallbacks.

.PARAMETER Force
Replace an existing installation of the same version after the archive has
been verified.

.PARAMETER SkipPathPrompt
Do not offer to update the current user's PATH.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+$')]
    [string]$Version = '30.2',

    [ValidateSet('Auto', 'Berkeley', 'Waterloo', 'GNU')]
    [string]$Mirror = 'Auto',

    [switch]$Force,
    [switch]$SkipPathPrompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This installer currently supports Windows only.'
}

. (Join-Path $PSScriptRoot 'lib\Ed.Common.ps1')

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkCyan
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "  [ .. ] $Message" -ForegroundColor Gray
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "  [ OK ] $Message" -ForegroundColor Green
}

function Read-Confirmation {
    param([Parameter(Mandatory)][string]$Question)
    $answer = Read-Host "$Question [y/N]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $false
    }
    return $answer.Trim().ToLowerInvariant() -in @('y', 'yes')
}

function Join-UriPath {
    param(
        [Parameter(Mandatory)][string]$BaseUri,
        [Parameter(Mandatory)][string[]]$Segments
    )
    $value = $BaseUri.TrimEnd([char]47)
    foreach ($segment in $Segments) {
        $value += '/' + $segment.Trim([char]47)
    }
    return $value
}

function Invoke-FileDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination
    )

    $partial = "$Destination.partial"
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $partial -UseBasicParsing -TimeoutSec 900
        if (-not (Test-Path -LiteralPath $partial -PathType Leaf)) {
            throw 'The download command completed without creating a file.'
        }
        Move-Item -LiteralPath $partial -Destination $Destination -Force
    }
    finally {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    }
}

function Get-ExpectedHash {
    param(
        [Parameter(Mandatory)][string]$ChecksumFile,
        [Parameter(Mandatory)][string]$ArchiveName
    )

    $escapedName = [Regex]::Escape($ArchiveName)
    foreach ($line in Get-Content -LiteralPath $ChecksumFile) {
        if ($line -match "^(?<hash>[0-9A-Fa-f]{64})\s+\*?$escapedName\s*$") {
            return $Matches.hash.ToUpperInvariant()
        }
    }
    throw "The checksum file does not contain an entry for $ArchiveName."
}

function Get-MirrorOrder {
    param([Parameter(Mandatory)][string]$Preferred)

    $all = @('Auto', 'Berkeley', 'Waterloo', 'GNU')
    if ($Preferred -eq 'Auto') {
        return $all
    }
    return @($Preferred) + @($all | Where-Object { $_ -ne $Preferred })
}

$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    $repoRoot = (Get-Location).Path
}
$runtimeRoot = Join-Path $repoRoot 'runtime'
$downloadRoot = Join-Path $repoRoot 'downloads'
$majorVersion = ($Version -split '\.')[0]
$archiveName = "emacs-$Version.zip"
$checksumName = "emacs-$Version-sha256sum.txt"
$versionRoot = Join-Path $runtimeRoot "emacs-$Version"
$currentBinFile = Join-Path $runtimeRoot 'current-bin.txt'
$archivePath = Join-Path $downloadRoot $archiveName
$checksumPath = Join-Path $downloadRoot $checksumName

$mirrorBases = [ordered]@{
    Auto      = 'https://ftpmirror.gnu.org'
    Berkeley  = 'https://mirrors.ocf.berkeley.edu/gnu'
    Waterloo  = 'https://mirror.csclub.uwaterloo.ca/gnu'
    GNU       = 'https://ftp.gnu.org/gnu'
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

Write-Section 'Portable GNU Emacs installer'
Write-Step "Repository: $repoRoot"
Write-Step "Version: $Version"

$existingExecutable = Find-EdEmacsExecutable -Root $versionRoot
$binDir = $null

if ((Test-Path -LiteralPath $versionRoot) -and -not $existingExecutable -and -not $Force) {
    throw "The destination exists but does not contain Emacs: $versionRoot. Use -Force to replace it."
}

if ($existingExecutable -and -not $Force) {
    $binDir = Split-Path -Parent $existingExecutable.FullName
    Write-Ok "Emacs $Version is already installed at $binDir"
}
else {
    Write-Host ''
    Write-Host "  Archive: $archiveName" -ForegroundColor White
    Write-Host "  Download folder: $downloadRoot" -ForegroundColor White
    Write-Host "  Preferred mirror: $Mirror" -ForegroundColor White
    Write-Host ''

    if (-not (Read-Confirmation -Question "Download and install GNU Emacs $Version")) {
        Write-Host 'Installation cancelled. No download was started.' -ForegroundColor Yellow
        exit 2
    }

    $downloadSucceeded = $false
    $lastError = $null

    foreach ($mirrorName in (Get-MirrorOrder -Preferred $Mirror)) {
        $baseUri = $mirrorBases[$mirrorName]
        $releasePath = "emacs/windows/emacs-$majorVersion"
        $checksumUri = Join-UriPath -BaseUri $baseUri -Segments @($releasePath, $checksumName)
        $archiveUri = Join-UriPath -BaseUri $baseUri -Segments @($releasePath, $archiveName)

        Write-Section "Trying GNU mirror: $mirrorName"
        try {
            Write-Step "Downloading checksum from $checksumUri"
            Invoke-FileDownload -Uri $checksumUri -Destination $checksumPath
            $expectedHash = Get-ExpectedHash -ChecksumFile $checksumPath -ArchiveName $archiveName
            Write-Ok "Expected SHA-256: $expectedHash"

            $needsArchiveDownload = $true
            if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
                Write-Step 'Checking the existing local archive...'
                $existingHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
                if ($existingHash -eq $expectedHash) {
                    Write-Ok 'The existing local archive is valid and will be reused.'
                    $needsArchiveDownload = $false
                }
                else {
                    Write-Host '  Existing archive checksum mismatch. It will be replaced.' -ForegroundColor Yellow
                    Remove-Item -LiteralPath $archivePath -Force
                }
            }

            if ($needsArchiveDownload) {
                Write-Step "Downloading $archiveUri"
                Invoke-FileDownload -Uri $archiveUri -Destination $archivePath
            }

            Write-Step 'Verifying SHA-256...'
            $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($actualHash -ne $expectedHash) {
                throw "SHA-256 mismatch. Expected $expectedHash but received $actualHash."
            }

            Write-Ok "Verified $archiveName"
            $downloadSucceeded = $true
            break
        }
        catch {
            $lastError = $_.Exception.Message
            Write-Host "  Mirror failed: $lastError" -ForegroundColor Yellow
            Remove-Item -LiteralPath "$archivePath.partial" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$checksumPath.partial" -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $downloadSucceeded) {
        throw "All GNU mirrors failed. Last error: $lastError"
    }

    Write-Section 'Extracting verified archive'
    $stagingRoot = Join-Path $runtimeRoot ".staging-$Version-$PID"
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue

    try {
        Write-Step "Extracting to staging folder: $stagingRoot"
        Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingRoot -Force
        $stagedExecutable = Find-EdEmacsExecutable -Root $stagingRoot
        if (-not $stagedExecutable) {
            throw 'The verified archive did not contain runemacs.exe or emacs.exe.'
        }

        if (Test-Path -LiteralPath $versionRoot) {
            if (-not $Force) {
                throw "The destination already exists: $versionRoot. Use -Force to replace it."
            }
            Remove-Item -LiteralPath $versionRoot -Recurse -Force
        }

        Move-Item -LiteralPath $stagingRoot -Destination $versionRoot
        $installedExecutable = Find-EdEmacsExecutable -Root $versionRoot
        if (-not $installedExecutable) {
            throw 'Emacs could not be found after moving the staged installation.'
        }
        $binDir = Split-Path -Parent $installedExecutable.FullName
    }
    finally {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Ok "Installed Emacs $Version at $versionRoot"
    Write-Ok "Emacs bin directory: $binDir"
}

$relativeBin = $binDir.Substring($runtimeRoot.Length).TrimStart([char]92)
Set-Content -LiteralPath $currentBinFile -Value $relativeBin -Encoding ASCII

if (-not $SkipPathPrompt) {
    Write-Section 'Optional user PATH update'
    Write-Host '  The update preserves unexpanded registry references such as %USERPROFILE%.' -ForegroundColor Gray
    Write-Host "  Repository launcher path: $repoRoot" -ForegroundColor White
    Write-Host '  Only the stable launcher path is added; versioned runtime paths stay private.' -ForegroundColor Gray
    Write-Host ''

    if (Read-Confirmation -Question 'Add the ed launcher directory to your user PATH') {
        $pathResult = Add-EdUserPathEntriesPreservingExpansion -Entries @($repoRoot)
        if ($pathResult.Changed) {
            try {
                Send-EdEnvironmentChangedMessage
            }
            catch {
                Write-Host "  PATH was written, but the environment-change broadcast failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            Write-Ok 'User PATH updated and verified without expanding existing environment-variable references.'
        }
        else {
            Write-Ok 'The repository launcher directory is already present in the user PATH.'
        }
        Write-Host '  Open a new terminal before using ed, emacs, or runemacs.' -ForegroundColor Yellow
    }
    else {
        Write-Host '  PATH was not changed. You can run ed.cmd directly from this folder.' -ForegroundColor Yellow
    }
}

Write-Section 'Ready'
Write-Host '  Launch in the current directory:' -ForegroundColor Gray
Write-Host "    $repoRoot\ed.cmd" -ForegroundColor White
Write-Host ''
Write-Host '  After adding the repository to PATH:' -ForegroundColor Gray
Write-Host '    ed' -ForegroundColor White
Write-Host ''
