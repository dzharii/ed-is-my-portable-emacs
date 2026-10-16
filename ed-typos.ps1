#Requires -Version 5.1
# Standalone typos runner. Version/hash pins: lib\Ed.Spelling.ps1.
# Avoid parameter binding: -w and -v belong to typos, not PowerShell.
$typosArguments = $args

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Ed.Spelling.ps1')

Install-EdSpelling -RepositoryRoot $PSScriptRoot -Tool Typos
$paths = Get-EdSpellingPaths -RepositoryRoot $PSScriptRoot
& $paths.TyposExe @typosArguments
exit $LASTEXITCODE
