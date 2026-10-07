REM @echo off
setlocal enableDelayedExpansion
set d=%~1
set oobe=%~2
set "dirOEM=%SYSTEMDRIVE%\sources\$OEM$\$$"
IF /I "%oobe%" EQU "T" (
  reg import "%d%:\win11-oobe.reg"
) ELSE (
  reg import "%d%:\win11.reg" >NUL 2>&1
  mkdir "%dirOEM%\Panther"
  copy /B /V /Y "%d%:\Autounattend.xml" "%dirOEM%\Panther\Autounattend.xml"
  copy /B /V /Y "%d%:\Autounattend.xml" "%dirOEM%\Autounattend.xml"
  copy /B /V /Y "%d%:\QHAutounattend.cmd" "%dirOEM%\QHAutounattend.cmd"
  copy /B /V /Y "%d%:\win11-oobe.reg" "%dirOEM%\win11-oobe.reg"
  REM ping 127.0.0.1 -n 2 >NUL 2>&1
)
endlocal
exit 0