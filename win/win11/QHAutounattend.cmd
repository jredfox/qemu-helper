@echo off
setlocal enableDelayedExpansion
set d=%~1
set oobe=%~2
IF /I "%oobe%" EQU "T" (
  reg import "%d%:\win11-oobe.reg"
) ELSE (
  reg import "%d%:\win11.reg" >NUL 2>&1
  ping 127.0.0.1 -n 2 >NUL 2>&1
)
endlocal
exit 0