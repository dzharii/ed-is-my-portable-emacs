Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ([System.Management.Automation.PSTypeName]'EdWindowNative').Type) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class EdWindowNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
'@ | Out-Null
}

function Get-EdWindow {
    [CmdletBinding()]
    param(
        [int]$ProcessId,
        [string]$TitlePattern = '*',
        [int]$TimeoutSeconds = 15
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $processes = if ($ProcessId) {
            @(Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
        }
        else {
            @(Get-Process | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
        }

        $match = $processes |
            Where-Object {
                $_.MainWindowHandle -ne [IntPtr]::Zero -and
                $_.MainWindowTitle -like $TitlePattern
            } |
            Select-Object -First 1
        if ($match) {
            return $match
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "No visible window matched process '$ProcessId' and title '$TitlePattern' within $TimeoutSeconds seconds."
}

function Get-EdWindowRectangle {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][Diagnostics.Process]$Process)

    process {
        $rect = New-Object EdWindowNative+RECT
        if (-not [EdWindowNative]::GetWindowRect($Process.MainWindowHandle, [ref]$rect)) {
            throw "Could not read the window rectangle for PID $($Process.Id)."
        }
        [pscustomobject]@{
            Left = $rect.Left
            Top = $rect.Top
            Width = $rect.Right - $rect.Left
            Height = $rect.Bottom - $rect.Top
            Right = $rect.Right
            Bottom = $rect.Bottom
        }
    }
}

function Set-EdWindowState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [ValidateSet('Restore', 'Minimize', 'Maximize')]
        [string]$State
    )

    $command = switch ($State) {
        Restore { 9 }
        Minimize { 6 }
        Maximize { 3 }
    }
    if (-not [EdWindowNative]::ShowWindow($Process.MainWindowHandle, $command)) {
        # ShowWindow returns the prior visibility state, not success. Refreshing
        # and validating the handle is the meaningful check.
        $Process.Refresh()
        if ($Process.MainWindowHandle -eq [IntPtr]::Zero) {
            throw "The window for PID $($Process.Id) is no longer available."
        }
    }
}

function Set-EdWindowForeground {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Diagnostics.Process]$Process)

    if ([EdWindowNative]::IsIconic($Process.MainWindowHandle)) {
        [void][EdWindowNative]::ShowWindow($Process.MainWindowHandle, 9)
    }
    [void][EdWindowNative]::SetForegroundWindow($Process.MainWindowHandle)

    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    do {
        if ([EdWindowNative]::GetForegroundWindow() -eq $Process.MainWindowHandle) {
            return
        }
        Start-Sleep -Milliseconds 100
        [void][EdWindowNative]::SetForegroundWindow($Process.MainWindowHandle)
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Refusing input: PID $($Process.Id) did not become the foreground window."
}

function Invoke-EdWindowClick {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [ValidateRange(0.05, 0.95)][double]$HorizontalRatio = 0.5,
        [ValidateRange(0.05, 0.95)][double]$VerticalRatio = 0.5
    )

    Set-EdWindowForeground -Process $Process
    $rect = Get-EdWindowRectangle -Process $Process
    $x = [int]($rect.Left + ($rect.Width * $HorizontalRatio))
    $y = [int]($rect.Top + ($rect.Height * $VerticalRatio))
    if (-not [EdWindowNative]::SetCursorPos($x, $y)) {
        throw "Could not move the pointer to ($x, $y)."
    }
    [EdWindowNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [EdWindowNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Send-EdWindowKeys {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [Parameter(Mandatory)][string]$Keys
    )

    Set-EdWindowForeground -Process $Process
    if ([EdWindowNative]::GetForegroundWindow() -ne $Process.MainWindowHandle) {
        throw "Refusing input: PID $($Process.Id) is not the foreground window."
    }
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

function Save-EdWindowScreenshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [Parameter(Mandatory)][string]$Path
    )

    $rect = Get-EdWindowRectangle -Process $Process
    if ($rect.Width -le 0 -or $rect.Height -le 0) {
        throw "The window for PID $($Process.Id) has no visible area."
    }

    $absolutePath = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $absolutePath
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $bitmap = New-Object Drawing.Bitmap $rect.Width, $rect.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen(
            $rect.Left,
            $rect.Top,
            0,
            0,
            [Drawing.Size]::new($rect.Width, $rect.Height))
        $bitmap.Save($absolutePath, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    return Get-Item -LiteralPath $absolutePath
}

Export-ModuleMember -Function @(
    'Get-EdWindow',
    'Get-EdWindowRectangle',
    'Set-EdWindowState',
    'Set-EdWindowForeground',
    'Invoke-EdWindowClick',
    'Send-EdWindowKeys',
    'Save-EdWindowScreenshot'
)
