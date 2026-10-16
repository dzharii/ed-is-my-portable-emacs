#Requires -Version 5.1
# Configuration: edit version/hash pins at the top of lib\Ed.Spelling.ps1.
# Usage: install-spelling.cmd [-Tool All|Hunspell|Typos]. No admin or PATH edits.
[CmdletBinding()]
param([ValidateSet('All','Hunspell','Typos')][string]$Tool = 'All')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Ed.Spelling.ps1')
try {
    Install-EdSpelling -RepositoryRoot $PSScriptRoot -Tool $Tool
    Set-EdSpellingEnvironment -RepositoryRoot $PSScriptRoot
    Write-Host 'ed: spelling tools are ready.' -ForegroundColor Green
}
catch {
    Write-Error "Spelling installation failed: $($_.Exception.Message)"
    exit 1
}
