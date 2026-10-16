#Requires -Version 5.1
# Version pins (Windows x64): change a version AND its release archive SHA-256.
# Sources: github.com/iquiw/hunspell-binary and github.com/crate-ci/typos/releases.
# DictionaryCommit selects LibreOffice/dictionaries' en_US revision.
# URLs, archive names and install folders follow these pins; no other edits needed.
$script:EdHunspellVersion = '1.7.3'
$script:EdHunspellSha256 = 'b2bbdb6dc13a99b099b1efef966be6badca4d197e8ab0537e2f07a645aa9562f'
$script:EdTyposVersion = '1.47.0'
$script:EdTyposSha256 = '8773b1b3029b1e149b7bd676785b065b236173a7509bc9ab19fa64e638ae989a'
$script:EdDictionaryCommit = 'a4473e06b56bfe35187e302754f6baaa8d75e54f'

Set-StrictMode -Version Latest

$script:EdHunspellArchive = "hunspell-v$script:EdHunspellVersion.7z"
$script:EdTyposArchive = "typos-v$script:EdTyposVersion-x86_64-pc-windows-msvc.zip"
$script:EdHunspellBinary = 'Hunspell\bin\hunspell.exe'

function Get-EdSpellingPaths {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    $runtime = Join-Path $RepositoryRoot 'runtime'
    $hunspell = Join-Path $runtime "hunspell-v$script:EdHunspellVersion"
    $typos = Join-Path $runtime "typos-v$script:EdTyposVersion"
    return [pscustomobject]@{
        Runtime = $runtime
        Downloads = Join-Path $RepositoryRoot 'downloads'
        Hunspell = $hunspell
        HunspellExe = Join-Path $hunspell $script:EdHunspellBinary
        Dictionary = Join-Path $hunspell "dictionaries\$script:EdDictionaryCommit"
        Typos = $typos
        TyposExe = Join-Path $typos 'typos.exe'
    }
}

function Test-EdSpellingTool {
    param([Parameter(Mandatory)]$Paths, [Parameter(Mandatory)][ValidateSet('Hunspell','Typos')][string]$Tool)
    if ($Tool -eq 'Hunspell') {
        return [bool]((Test-Path -LiteralPath $Paths.HunspellExe -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $Paths.Dictionary 'en_US.aff') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $Paths.Dictionary 'en_US.dic') -PathType Leaf))
    }
    return (Test-Path -LiteralPath $Paths.TyposExe -PathType Leaf)
}

function Get-EdVerifiedArchive {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$ArchivePath,
        [Parameter(Mandatory)][string]$Sha256
    )
    if (Test-Path -LiteralPath $ArchivePath -PathType Leaf) {
        if ((Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash -ieq $Sha256) {
            Write-Host "ed: using cached $(Split-Path $ArchivePath -Leaf)"
            return
        }
        Remove-Item -LiteralPath $ArchivePath -Force
    }
    $partial = "$ArchivePath.partial"
    try {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
        Write-Host "ed: downloading $Url"
        Invoke-WebRequest -Uri $Url -OutFile $partial -UseBasicParsing -TimeoutSec 300
        $actual = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
        if ($actual -ine $Sha256) {
            throw "SHA-256 verification failed for $(Split-Path $ArchivePath -Leaf): $actual"
        }
        Move-Item -LiteralPath $partial -Destination $ArchivePath -Force
    }
    finally {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    }
}

function Save-EdDictionaryFile {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Folder)
    $url = "https://raw.githubusercontent.com/LibreOffice/dictionaries/$script:EdDictionaryCommit/en/$Name"
    $file = Join-Path $Folder $Name
    Write-Host "ed: downloading LibreOffice $Name ($script:EdDictionaryCommit)"
    Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing -TimeoutSec 120
    $size = (Get-Item -LiteralPath $file).Length
    $minimumSize = if ($Name -eq 'en_US.dic') { 100000 } else { 500 }
    if ($size -lt $minimumSize) { throw "Downloaded dictionary $Name is unexpectedly small ($size bytes)." }
}

function Install-EdHunspell {
    param([Parameter(Mandatory)]$Paths)
    if (Test-EdSpellingTool -Paths $Paths -Tool Hunspell) { return }
    $archive = Join-Path $Paths.Downloads $script:EdHunspellArchive
    Get-EdVerifiedArchive -Url "https://github.com/iquiw/hunspell-binary/releases/download/v$script:EdHunspellVersion/$script:EdHunspellArchive" -ArchivePath $archive -Sha256 $script:EdHunspellSha256
    $stage = Join-Path $Paths.Runtime ('.staging-hunspell-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $stage -Force | Out-Null
        $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
        if (-not $tar) { throw 'Windows tar.exe (7z extraction support) is required to unpack Hunspell.' }
        & $tar.Source -xf $archive -C $stage
        if ($LASTEXITCODE -ne 0) { throw "Hunspell archive extraction failed (tar exit code $LASTEXITCODE)." }
        if (-not (Test-Path -LiteralPath (Join-Path $stage $script:EdHunspellBinary) -PathType Leaf)) {
            throw "Hunspell archive did not contain $script:EdHunspellBinary."
        }
        $dictFolder = Join-Path $stage "dictionaries\$script:EdDictionaryCommit"
        New-Item -ItemType Directory -Path $dictFolder -Force | Out-Null
        Save-EdDictionaryFile -Name 'en_US.aff' -Folder $dictFolder
        Save-EdDictionaryFile -Name 'en_US.dic' -Folder $dictFolder
        if (Test-Path -LiteralPath $Paths.Hunspell) {
            Remove-Item -LiteralPath $Paths.Hunspell -Recurse -Force
        }
        Move-Item -LiteralPath $stage -Destination $Paths.Hunspell
        Write-Host "ed: Hunspell $script:EdHunspellVersion and en_US installed"
    }
    finally { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
}

function Install-EdTypos {
    param([Parameter(Mandatory)]$Paths)
    if (Test-EdSpellingTool -Paths $Paths -Tool Typos) { return }
    $archive = Join-Path $Paths.Downloads $script:EdTyposArchive
    Get-EdVerifiedArchive -Url "https://github.com/crate-ci/typos/releases/download/v$script:EdTyposVersion/$script:EdTyposArchive" -ArchivePath $archive -Sha256 $script:EdTyposSha256
    $stage = Join-Path $Paths.Runtime ('.staging-typos-' + [guid]::NewGuid().ToString('N'))
    try {
        Expand-Archive -LiteralPath $archive -DestinationPath $stage -Force
        $binary = Get-ChildItem -LiteralPath $stage -Recurse -File -Filter typos.exe |
            Select-Object -First 1
        if (-not $binary) { throw 'typos archive did not contain typos.exe.' }
        # Normalize the archive layout so the caller always knows the executable location.
        if ($binary.DirectoryName -ne $stage) {
            Copy-Item -LiteralPath $binary.FullName -Destination (Join-Path $stage 'typos.exe') -Force
        }
        if (Test-Path -LiteralPath $Paths.Typos) {
            Remove-Item -LiteralPath $Paths.Typos -Recurse -Force
        }
        Move-Item -LiteralPath $stage -Destination $Paths.Typos
        Write-Host "ed: typos $script:EdTyposVersion installed"
    }
    finally { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
}

function Install-EdSpelling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [ValidateSet('All','Hunspell','Typos')][string]$Tool = 'All'
    )
    if ($env:OS -ne 'Windows_NT') { throw 'Portable spelling installation supports Windows only.' }
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Portable spelling installation requires Windows x64.' }
    $paths = Get-EdSpellingPaths -RepositoryRoot $RepositoryRoot
    $tools = if ($Tool -eq 'All') { @('Hunspell', 'Typos') } else { @($Tool) }
    $missing = @($tools | Where-Object { -not (Test-EdSpellingTool -Paths $paths -Tool $_) })
    if ($missing.Count -eq 0) { return }

    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    New-Item -ItemType Directory -Path $paths.Runtime -Force | Out-Null
    New-Item -ItemType Directory -Path $paths.Downloads -Force | Out-Null
    # Serialize simultaneous launcher starts against the same repository directory.
    $bytes = [Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($RepositoryRoot).ToLowerInvariant())
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').Substring(0, 24) }
    finally { $hasher.Dispose() }
    $mutex = [System.Threading.Mutex]::new($false, "Local\ed-spelling-$key")
    $acquired = $false
    try {
        try { $acquired = $mutex.WaitOne(300000) }
        catch [System.Threading.AbandonedMutexException] { $acquired = $true }
        if (-not $acquired) { throw 'Timed out waiting for another ed spelling installer.' }
        $failures = New-Object 'System.Collections.Generic.List[string]'
        foreach ($name in $missing) {
            try {
                if ($name -eq 'Hunspell') { Install-EdHunspell -Paths $paths }
                else { Install-EdTypos -Paths $paths }
            }
            catch { $failures.Add("${name}: $($_.Exception.Message)") }
        }
        if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
    }
    finally {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Set-EdSpellingEnvironment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    $paths = Get-EdSpellingPaths -RepositoryRoot $RepositoryRoot
    $prepend = @()
    if (Test-EdSpellingTool -Paths $paths -Tool Hunspell) {
        $prepend += (Split-Path -Parent $paths.HunspellExe)
        $env:DICPATH = $paths.Dictionary
        # Emacs probes hunspell -D before selecting a dictionary; Windows may lack LANG.
        $env:DICTIONARY = 'en_US'
    }
    if (Test-EdSpellingTool -Paths $paths -Tool Typos) {
        $prepend += $paths.Typos
    }
    if ($prepend.Count -gt 0) {
        $env:PATH = (($prepend + @($env:PATH)) -join ';')
    }
}
