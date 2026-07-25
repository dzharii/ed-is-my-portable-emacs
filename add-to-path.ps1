#Requires -Version 5.1
<#
.SYNOPSIS
Safely adds the ed launcher directory to the current user's PATH.

.DESCRIPTION
Reads HKCU\Environment\Path without expanding references such as %JAVA_HOME%,
asks before changing it, preserves its registry type, writes only the repository
root, and verifies the exact raw value after writing.
#>
[CmdletBinding()]
param(
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This PATH helper currently supports Windows only.'
}

. (Join-Path $PSScriptRoot 'lib\Ed.Common.ps1')

function Read-EdConfirmation {
    param([Parameter(Mandatory)][string]$Question)
    $answer = Read-Host "$Question [y/N]"
    return -not [string]::IsNullOrWhiteSpace($answer) -and
        $answer.Trim().ToLowerInvariant() -in @('y', 'yes')
}

$repoRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd([char]92)
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'ed.cmd') -PathType Leaf)) {
    throw "ed.cmd was not found in the repository root: $repoRoot"
}

Write-Host ''
Write-Host 'ed user PATH setup' -ForegroundColor Cyan
Write-Host "  Add: $repoRoot" -ForegroundColor White
Write-Host '  Scope: current user only (HKCU\Environment\Path)' -ForegroundColor Gray
Write-Host '  Existing %VARIABLE% references will remain unexpanded.' -ForegroundColor Gray
Write-Host ''

if (-not $Yes -and -not (Read-EdConfirmation -Question 'Add this launcher directory to your user PATH')) {
    Write-Host 'PATH was not changed.' -ForegroundColor Yellow
    exit 2
}

$result = Add-EdUserPathEntriesPreservingExpansion -Entries @($repoRoot)
if ($result.Changed) {
    try {
        Send-EdEnvironmentChangedMessage
    }
    catch {
        Write-Host "PATH was written and verified, but the environment-change broadcast failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Write-Host 'User PATH updated and verified.' -ForegroundColor Green
}
else {
    Write-Host 'The launcher directory is already present in the user PATH.' -ForegroundColor Green
}
Write-Host 'Open a new terminal, then run: ed' -ForegroundColor Yellow
