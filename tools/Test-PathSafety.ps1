#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\Ed.Common.ps1')

function Assert-Ed {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
    Write-Host "  [ OK ] $Message" -ForegroundColor Green
}

$testRoot = 'Software\ed-is-my-portable-emacs\Tests'
$testName = [Guid]::NewGuid().ToString('N')
$testSubKey = "$testRoot\$testName"
$base = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($testSubKey)
$options = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames

try {
    Write-Host 'PATH safety tests (isolated temporary HKCU key)' -ForegroundColor Cyan

    $raw = 'C:\Tools;%JAVA_HOME%\bin;%USERPROFILE%\bin;'
    $base.SetValue('Path', $raw, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    $result = Add-EdUserPathEntriesPreservingExpansion -Entries @('D:\portable ed') -RegistrySubKey $testSubKey
    $actual = [string]$base.GetValue('Path', '', $options)
    Assert-Ed ($result.Changed) 'a missing entry is appended'
    Assert-Ed ($actual -ceq "$raw" + 'D:\portable ed') 'raw %VARIABLE% references are byte-for-byte preserved'
    Assert-Ed ($base.GetValueKind('Path') -eq [Microsoft.Win32.RegistryValueKind]::ExpandString) 'REG_EXPAND_SZ type is preserved'

    $beforeSecondAdd = $actual
    $second = Add-EdUserPathEntriesPreservingExpansion -Entries @('d:\PORTABLE ED\') -RegistrySubKey $testSubKey
    $afterSecondAdd = [string]$base.GetValue('Path', '', $options)
    Assert-Ed (-not $second.Changed) 'duplicate detection is case-insensitive and slash-insensitive'
    Assert-Ed ($afterSecondAdd -ceq $beforeSecondAdd) 'an idempotent call does not rewrite PATH'

    $env:ED_PATH_TEST_HOME = 'C:\VariableRoot'
    $variableRaw = '%ED_PATH_TEST_HOME%\bin'
    $base.SetValue('Path', $variableRaw, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    $expandedDuplicate = Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\VariableRoot\bin') -RegistrySubKey $testSubKey
    Assert-Ed (-not $expandedDuplicate.Changed) 'an expanded equivalent of an existing %VARIABLE% entry is not duplicated'
    Assert-Ed ([string]$base.GetValue('Path', '', $options) -ceq $variableRaw) 'expanded-equivalent detection leaves raw text untouched'

    $plainRaw = 'C:\Plain'
    $base.SetValue('Path', $plainRaw, [Microsoft.Win32.RegistryValueKind]::String)
    [void](Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\Added') -RegistrySubKey $testSubKey)
    Assert-Ed ($base.GetValueKind('Path') -eq [Microsoft.Win32.RegistryValueKind]::String) 'REG_SZ type is preserved'

    $base.SetValue('Path', $raw, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    [void](Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\WhatIf') -RegistrySubKey $testSubKey -WhatIf)
    Assert-Ed ([string]$base.GetValue('Path', '', $options) -ceq $raw) '-WhatIf makes no registry change'

    $base.SetValue('Path', [byte[]](1, 2, 3), [Microsoft.Win32.RegistryValueKind]::Binary)
    $unsupportedRejected = $false
    try {
        [void](Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\Never') -RegistrySubKey $testSubKey)
    }
    catch {
        $unsupportedRejected = $_.Exception.Message -like '*unsupported registry type*'
    }
    Assert-Ed $unsupportedRejected 'an unsupported PATH registry type is rejected'
    Assert-Ed ($base.GetValueKind('Path') -eq [Microsoft.Win32.RegistryValueKind]::Binary) 'rejection does not rewrite the unsupported value'

    Write-Host 'All PATH safety tests passed.' -ForegroundColor Cyan
}
finally {
    Remove-Item Env:\ED_PATH_TEST_HOME -ErrorAction SilentlyContinue
    $base.Dispose()
    $testsKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\ed-is-my-portable-emacs', $true)
    if ($testsKey) {
        try {
            $testsKey.DeleteSubKeyTree("Tests\$testName", $false)
        }
        finally {
            $testsKey.Dispose()
        }
    }
}
