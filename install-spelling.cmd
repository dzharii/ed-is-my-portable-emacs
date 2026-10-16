@echo off
rem Version/hash pins: lib\Ed.Spelling.ps1. Optional: -Tool Hunspell or -Tool Typos.
setlocal
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-spelling.ps1" %*
) else (
  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-spelling.ps1" %*
)
exit /b %ERRORLEVEL%
