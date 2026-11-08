# Test tools

`Test-PathSafety.ps1` exercises the shared PATH implementation against a temporary key below `HKCU\Software\ed-is-my-portable-emacs\Tests`. It never targets the real user PATH.

```powershell
.\tools\Test-PathSafety.ps1
```

`Test-Spelling.ps1` checks first-launch provisioning, offline fast paths, upgrades,
and failure handling using temporary fixtures; it never downloads or replaces tools.

```powershell
.\tools\Test-Spelling.ps1
```

`Test-RustDiagnostics.el` checks Cargo detection, automatic Eglot selection,
standalone files, opt-out behavior, and coexistence with spelling diagnostics.
It does not download packages or start language servers.

```powershell
.\runtime\emacs-30.2\bin\emacs.exe -Q --batch -l .\tools\Test-RustDiagnostics.el
```

`window-tool.ps1` targets one explicit process ID. Keyboard input first verifies that the same window is foreground; otherwise it refuses to type.

```powershell
.\tools\window-tool.ps1 -ProcessId 1234 -Screenshot .\work\emacs.png
.\tools\window-tool.ps1 -ProcessId 1234 -Click
.\tools\window-tool.ps1 -ProcessId 1234 -Keys '^x'
.\tools\window-tool.ps1 -ProcessId 1234 -State Maximize
```

`WindowAutomation.psm1` exposes the underlying commands for test scripts:

- `Get-EdWindow`
- `Get-EdWindowRectangle`
- `Set-EdWindowBounds`
- `Set-EdWindowState`
- `Set-EdWindowForeground`
- `Invoke-EdWindowClick`
- `Send-EdWindowKeys`
- `Save-EdWindowScreenshot`

Resolve the target PID from its executable path below this repository's `runtime` directory. Never select a process only by the generic name `emacs`.
