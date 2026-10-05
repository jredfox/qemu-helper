@echo off
setlocal enableDelayedExpansion
set d=%~1
set oobe=%~2
set BUILD=0
for /f "tokens=3" %%b in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') do set BUILD=%%b
IF %BUILD% GEQ 22000 IF /I "%oobe%" EQU "T" (
  reg import "%d%:\win11-oobe.reg"
  echo "imported win11-oobe.reg"
)
IF %BUILD% GEQ 22000 IF /I "%oobe%" NEQ "T" (
  reg import "%d%:\win11.reg"
  echo "imported win11.reg"
)
endlocal
exit 0