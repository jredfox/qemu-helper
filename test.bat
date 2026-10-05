@echo off
set BUILD=0
for /f "tokens=3" %%b in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') do set BUILD=%%b
if %BUILD% GEQ 22000 (
  reg add HKLM\System\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 0x00000001 /f
  reg add HKLM\System\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 0x00000001 /f
  reg add HKLM\System\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 0x00000001 /f
  reg add HKLM\System\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 0x00000001 /f
)