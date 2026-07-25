#Requires -Version 5.1

Set-StrictMode -Version Latest

function Find-EdEmacsExecutable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return $null
    }

    foreach ($name in @('runemacs.exe', 'emacs.exe')) {
        $candidate = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $name -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($candidate) {
            return $candidate
        }
    }
    return $null
}

function Resolve-EdEmacsExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RuntimeRoot,
        [Parameter(Mandatory)][string]$CurrentBinFile,
        [switch]$SkipSystemPath
    )

    if (Test-Path -LiteralPath $CurrentBinFile -PathType Leaf) {
        $relativeBin = (Get-Content -LiteralPath $CurrentBinFile -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($relativeBin) -and
            -not [IO.Path]::IsPathRooted($relativeBin)) {
            $recordedBin = Join-Path $RuntimeRoot $relativeBin
            foreach ($name in @('runemacs.exe', 'emacs.exe')) {
                $candidate = Join-Path $recordedBin $name
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    return $candidate
                }
            }
        }
    }

    $portable = Find-EdEmacsExecutable -Root $RuntimeRoot
    if ($portable) {
        return $portable.FullName
    }

    if (-not $SkipSystemPath) {
        foreach ($name in @('runemacs', 'emacs')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($command) {
                return $command.Source
            }
        }
    }
    return $null
}

function Get-EdComparablePath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $candidate = $Value.Trim().Trim('"').TrimEnd([char[]]@([char]92, [char]47))
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return ''
    }
    return [Environment]::ExpandEnvironmentVariables($candidate)
}

function Add-EdUserPathEntriesPreservingExpansion {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string[]]$Entries,
        [string]$RegistrySubKey = 'Environment'
    )

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($RegistrySubKey, $true)
    if (-not $key) {
        throw "Could not open HKCU\$RegistrySubKey for writing."
    }

    try {
        $options = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        $pathExists = $null -ne $key.GetValue('Path', $null, $options)
        $rawPath = [string]$key.GetValue('Path', '', $options)
        $valueKind = if ($pathExists) {
            $key.GetValueKind('Path')
        }
        else {
            [Microsoft.Win32.RegistryValueKind]::ExpandString
        }

        if ($valueKind -notin @(
                [Microsoft.Win32.RegistryValueKind]::String,
                [Microsoft.Win32.RegistryValueKind]::ExpandString)) {
            throw "HKCU\$RegistrySubKey\Path has unsupported registry type: $valueKind."
        }

        $existingParts = @()
        if (-not [string]::IsNullOrWhiteSpace($rawPath)) {
            $existingParts = @($rawPath -split ';' |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }

        $entriesToAppend = New-Object System.Collections.Generic.List[string]
        foreach ($entry in $Entries) {
            $literalEntry = $entry.Trim().TrimEnd([char[]]@([char]92, [char]47))
            if ([string]::IsNullOrWhiteSpace($literalEntry)) {
                throw 'A blank PATH entry was requested.'
            }

            $normalized = Get-EdComparablePath -Value $literalEntry
            $comparisonParts = @($existingParts) + @($entriesToAppend)
            $exists = $false
            foreach ($part in $comparisonParts) {
                if ((Get-EdComparablePath -Value $part).Equals(
                        $normalized, [StringComparison]::OrdinalIgnoreCase)) {
                    $exists = $true
                    break
                }
            }
            if (-not $exists) {
                [void]$entriesToAppend.Add($literalEntry)
            }
        }

        if ($entriesToAppend.Count -eq 0) {
            return [pscustomobject]@{
                Changed = $false
                Before = $rawPath
                After = $rawPath
                Kind = $valueKind
            }
        }

        $newPath = $rawPath
        if (-not [string]::IsNullOrEmpty($newPath) -and -not $newPath.EndsWith(';')) {
            $newPath += ';'
        }
        $newPath += ($entriesToAppend -join ';')
        if ($newPath.Length -gt 32767) {
            throw 'The requested user PATH would exceed the Windows environment-variable length limit.'
        }

        if (-not $PSCmdlet.ShouldProcess("HKCU\$RegistrySubKey\Path", 'Append PATH entries')) {
            return [pscustomobject]@{
                Changed = $false
                Before = $rawPath
                After = $rawPath
                Kind = $valueKind
            }
        }

        $key.SetValue('Path', $newPath, $valueKind)
        $writtenPath = [string]$key.GetValue('Path', '', $options)
        $writtenKind = $key.GetValueKind('Path')
        if ($writtenPath -cne $newPath -or $writtenKind -ne $valueKind) {
            if ($pathExists) {
                $key.SetValue('Path', $rawPath, $valueKind)
            }
            else {
                $key.DeleteValue('Path', $false)
            }
            throw 'PATH verification failed after writing; the original registry value was restored.'
        }

        return [pscustomobject]@{
            Changed = $true
            Before = $rawPath
            After = $newPath
            Kind = $valueKind
        }
    }
    finally {
        $key.Dispose()
    }
}

function Send-EdEnvironmentChangedMessage {
    [CmdletBinding()]
    param()

    if (-not ([System.Management.Automation.PSTypeName]'EdEnvironmentBroadcast').Type) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class EdEnvironmentBroadcast
{
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint flags, uint timeout, out UIntPtr result);
}
'@ | Out-Null
    }

    $result = [UIntPtr]::Zero
    [void][EdEnvironmentBroadcast]::SendMessageTimeout(
        [IntPtr]0xffff,
        0x001A,
        [UIntPtr]::Zero,
        'Environment',
        0x0002,
        5000,
        [ref]$result)
}
