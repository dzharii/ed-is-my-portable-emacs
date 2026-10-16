#Requires -Version 5.1
# Offline regression tests; use isolated fixtures, not the installed runtime.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\Ed.Spelling.ps1')

function Assert-Ed {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
    Write-Host "  [ OK ] $Message" -ForegroundColor Green
}

function Write-EdFixtureFile {
    param([string]$Path)
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, 'fixture')
}

$script:installCounts = @{ Hunspell = 0; Typos = 0 }
function Install-EdHunspell {
    param($Paths)
    if (Test-EdSpellingTool -Paths $Paths -Tool Hunspell) { return }
    $script:installCounts.Hunspell++
    Write-EdFixtureFile $Paths.HunspellExe
    Write-EdFixtureFile (Join-Path $Paths.Dictionary 'en_US.aff')
    Write-EdFixtureFile (Join-Path $Paths.Dictionary 'en_US.dic')
}
function Install-EdTypos {
    param($Paths)
    if (Test-EdSpellingTool -Paths $Paths -Tool Typos) { return }
    $script:installCounts.Typos++
    Write-EdFixtureFile $Paths.TyposExe
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ed-spelling-test-' + [guid]::NewGuid().ToString('N'))
$originalPath = $env:PATH
$originalDictionary = $env:DICPATH
$originalDefaultDictionary = $env:DICTIONARY
$originalTyposVersion = $script:EdTyposVersion
$originalDictionaryCommit = $script:EdDictionaryCommit
try {
    Write-Host 'Portable spelling tests (offline fixtures)' -ForegroundColor Cyan
    Install-EdSpelling -RepositoryRoot $testRoot
    $paths = Get-EdSpellingPaths -RepositoryRoot $testRoot
    Assert-Ed ((Test-EdSpellingTool $paths Hunspell) -and (Test-EdSpellingTool $paths Typos)) 'first launch installs both tools and the dictionary'
    Assert-Ed ($script:installCounts.Hunspell -eq 1 -and $script:installCounts.Typos -eq 1) 'each missing tool is installed once'
    Assert-Ed ($script:EdTyposArchive -eq "typos-v$script:EdTyposVersion-x86_64-pc-windows-msvc.zip") 'typos archive follows the central version pin'
    Assert-Ed ($script:EdHunspellArchive -eq "hunspell-v$script:EdHunspellVersion.7z") 'Hunspell archive follows the central version pin'

    & {
        function New-Item { throw 'Warm launch must not create directories or enter installer setup.' }
        function Get-ChildItem { throw 'Warm launch must not scan directories.' }
        function Get-FileHash { throw 'Warm launch must not hash archives.' }
        function Invoke-WebRequest { throw 'Warm launch must not access the network.' }
        function Install-EdHunspell { throw 'Warm launch must not run the Hunspell installer.' }
        function Install-EdTypos { throw 'Warm launch must not run the typos installer.' }
        Install-EdSpelling -RepositoryRoot $testRoot
        Set-EdSpellingEnvironment -RepositoryRoot $testRoot
        $samples = @(1..25 | ForEach-Object {
            (Measure-Command {
                Install-EdSpelling -RepositoryRoot $testRoot
                Set-EdSpellingEnvironment -RepositoryRoot $testRoot
            }).TotalMilliseconds
        } | Sort-Object)
        Write-Host ('  Warm spelling check + environment: median {0:N2} ms' -f $samples[12])
    }
    Assert-Ed ($env:DICPATH -eq $paths.Dictionary) 'Emacs receives the pinned dictionary through DICPATH'
    Assert-Ed ($env:DICTIONARY -eq 'en_US') 'Hunspell discovery has a default dictionary even without LANG'
    $expectedPrefix = "$(Split-Path -Parent $paths.HunspellExe);$($paths.Typos);"
    Assert-Ed ($env:PATH.StartsWith($expectedPrefix)) 'Emacs receives both tool directories through its process PATH'
    Assert-Ed ($script:installCounts.Hunspell -eq 1 -and $script:installCounts.Typos -eq 1) 'cached launch bypasses all installer work'

    Remove-Item -LiteralPath (Join-Path $paths.Dictionary 'en_US.dic')
    Install-EdSpelling -RepositoryRoot $testRoot
    Assert-Ed ($script:installCounts.Hunspell -eq 2 -and $script:installCounts.Typos -eq 1) 'an incomplete dictionary repairs only Hunspell'

    Remove-Item -LiteralPath $paths.TyposExe
    Install-EdSpelling -RepositoryRoot $testRoot -Tool Typos
    Assert-Ed ($script:installCounts.Hunspell -eq 2 -and $script:installCounts.Typos -eq 2) 'standalone typos provisioning installs only typos'

    $script:EdTyposVersion = 'test-next'
    Install-EdSpelling -RepositoryRoot $testRoot -Tool Typos
    $upgradedPaths = Get-EdSpellingPaths -RepositoryRoot $testRoot
    Assert-Ed ($upgradedPaths.TyposExe -ne $paths.TyposExe -and (Test-EdSpellingTool $upgradedPaths Typos)) 'a version change selects and installs the new runtime'
    $script:EdTyposVersion = $originalTyposVersion

    $script:EdDictionaryCommit = 'test-next'
    Install-EdSpelling -RepositoryRoot $testRoot -Tool Hunspell
    $upgradedPaths = Get-EdSpellingPaths -RepositoryRoot $testRoot
    Assert-Ed ($upgradedPaths.Dictionary -ne $paths.Dictionary -and (Test-EdSpellingTool $upgradedPaths Hunspell)) 'a dictionary revision change triggers provisioning'
    $script:EdDictionaryCommit = $originalDictionaryCommit

    & {
        function Install-EdHunspell { throw 'simulated Hunspell download failure' }
        $failureRoot = Join-Path $testRoot 'failed-install'
        $failed = $false
        try { Install-EdSpelling -RepositoryRoot $failureRoot }
        catch { $failed = $_.Exception.Message -like '*Hunspell: simulated Hunspell download failure*' }
        $failurePaths = Get-EdSpellingPaths -RepositoryRoot $failureRoot
        Assert-Ed $failed 'installation failures retain the tool name and cause'
        Assert-Ed (Test-EdSpellingTool $failurePaths Typos) 'Hunspell failure does not prevent typos installation'
    }
    & {
        function Install-EdTypos { throw 'simulated typos download failure' }
        $failureRoot = Join-Path $testRoot 'failed-typos'
        $failed = $false
        try { Install-EdSpelling -RepositoryRoot $failureRoot -Tool Typos }
        catch { $failed = $_.Exception.Message -like '*Typos: simulated typos download failure*' }
        Assert-Ed $failed 'standalone typos installation failures are not reported as success'
    }
    Write-Host 'All spelling tests passed.' -ForegroundColor Cyan
}
finally {
    $env:PATH = $originalPath
    $env:DICPATH = $originalDictionary
    $env:DICTIONARY = $originalDefaultDictionary
    $script:EdTyposVersion = $originalTyposVersion
    $script:EdDictionaryCommit = $originalDictionaryCommit
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
