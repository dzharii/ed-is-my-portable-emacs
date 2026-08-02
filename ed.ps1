#Requires -Version 5.1
<#
.SYNOPSIS
Launches the repository's portable Emacs configuration.

.DESCRIPTION
Opens Emacs in the current directory or in the directory represented by the
optional path. The launcher prefers the repository's portable runtime. On a
first run it clearly offers to download and install Emacs; no download starts
until the user approves it.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This launcher currently supports Windows only.'
}

. (Join-Path $PSScriptRoot 'lib\Ed.Common.ps1')

function Stop-WithError {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Details
    )

    Write-Host ''
    Write-Host "ERROR: $Title" -ForegroundColor Red
    foreach ($detail in $Details) {
        Write-Host "  $detail" -ForegroundColor Red
    }
    Write-Host ''
    exit 1
}

function ConvertTo-ElispString {
    param([Parameter(Mandatory)][string]$Value)
    $escaped = $Value.Replace('\', '/').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function ConvertTo-WindowsCommandLineArgument {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0

    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) {
            $backslashes++
            continue
        }

        if ($character -eq [char]34) {
            if ($backslashes -gt 0) {
                [void]$builder.Append((-join (([string][char]92) * ($backslashes * 2))))
            }
            [void]$builder.Append('\"')
            $backslashes = 0
            continue
        }

        if ($backslashes -gt 0) {
            [void]$builder.Append((-join (([string][char]92) * $backslashes)))
            $backslashes = 0
        }
        [void]$builder.Append($character)
    }

    if ($backslashes -gt 0) {
        [void]$builder.Append((-join (([string][char]92) * ($backslashes * 2))))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    $repoRoot = (Get-Location).Path
}
$initRoot = Join-Path $repoRoot 'emacs-init'
$runtimeRoot = Join-Path $repoRoot 'runtime'
$currentBinFile = Join-Path $runtimeRoot 'current-bin.txt'

if (-not (Test-Path -LiteralPath (Join-Path $initRoot 'init.el') -PathType Leaf)) {
    Stop-WithError -Title 'The emacs-init configuration folder is missing.' -Details @(
        "Expected: $initRoot\init.el",
        'Keep ed.cmd and ed.ps1 in the repository root.'
    )
}

$startDir = (Get-Location).Path
$openFile = $null

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Stop-WithError -Title 'The requested path does not exist.' -Details @("Path: $Path")
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) {
        $startDir = $item.FullName
    }
    else {
        $startDir = $item.DirectoryName
        $openFile = $item.FullName
    }
}

$emacs = Resolve-EdEmacsExecutable -RuntimeRoot $runtimeRoot -CurrentBinFile $currentBinFile
if (-not $emacs) {
    Write-Host ''
    Write-Host 'ed: portable Emacs is not installed yet.' -ForegroundColor Yellow
    Write-Host '    The installer will download the official GNU Emacs 30.2 ZIP' -ForegroundColor White
    Write-Host "    into $repoRoot\downloads and extract it under runtime." -ForegroundColor White
    Write-Host '    The installer will ask for approval before any download.' -ForegroundColor White
    Write-Host ''

    $engine = (Get-Process -Id $PID).Path
    & $engine -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'install.ps1') -SkipPathPrompt
    $installExitCode = $LASTEXITCODE
    if ($installExitCode -ne 0) {
        if ($installExitCode -eq 2) {
            Write-Host 'ed: installation was declined; nothing was launched.' -ForegroundColor Yellow
            exit 2
        }
        Stop-WithError -Title 'Portable Emacs installation did not complete.' -Details @(
            "Installer exit code: $installExitCode",
            "You can retry with $repoRoot\install.cmd."
        )
    }

    $emacs = Resolve-EdEmacsExecutable -RuntimeRoot $runtimeRoot -CurrentBinFile $currentBinFile -SkipSystemPath
    if (-not $emacs) {
        Stop-WithError -Title 'The installer completed but portable Emacs was not found.' -Details @(
            "Expected a runtime below: $runtimeRoot"
        )
    }
}

$startDirForElisp = $startDir.TrimEnd([char[]]@([char]92, [char]47)) + '/'
$openedFileValue = if ($openFile) { 't' } else { 'nil' }
$startupExpression = "(setq ed-start-dir $(ConvertTo-ElispString $startDirForElisp) ed-launch-opened-file $openedFileValue)"

$arguments = @(
    '--no-site-file',
    '--init-directory',
    $initRoot,
    '--eval',
    $startupExpression
)
if ($openFile) {
    $arguments += $openFile
}

$argumentString = ($arguments | ForEach-Object { ConvertTo-WindowsCommandLineArgument $_ }) -join ' '
$emacsBinPath = Split-Path  $emacs -Parent

if ($emacsBinPath -and $env:PATH -and -not($env:PATH.Contains(";$($emacsBinPath)"))) {
     $env:PATH += ";$($emacsBinPath)";
}

Write-Host 'ed: launching Emacs' -ForegroundColor Cyan
Write-Host "    executable : $emacs"
Write-Host "    init       : $initRoot"
Write-Host "    directory  : $startDir"
if ($openFile) {
    Write-Host "    file       : $openFile"
}

Start-Process -FilePath $emacs -ArgumentList $argumentString -WorkingDirectory $startDir | Out-Null
