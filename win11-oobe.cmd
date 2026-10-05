@echo off
set drive="%~1"
set BUILD=0
for /f "tokens=3" %%b in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') do set BUILD=%%b
if %BUILD% GEQ 22000 (
  reg import "%drive%\win11-oobe.reg"
)