#description: Installs/Updates OneDrive Per-Machine installer and sets config via registry
#execution mode: Individual
#tags: SCC Hyperscale, Apps install

<# 
Notes:  This script downloads the OneDrive installer, removes any other version of OneDrive
installed, installs using a per-machine installer and sets some configuration via registry keys
#>

# Configure powershell logging
$SaveVerbosePreference = $VerbosePreference
$VerbosePreference = 'continue'
$VMTime = Get-Date
$LogTime = $VMTime.ToUniversalTime()
mkdir "$env:windir\Temp\NMWLogs\ScriptedActions\onedrive_sa" -Force
Start-Transcript -Path "$env:windir\Temp\NMWLogs\ScriptedActions\onedrive_sa\ps_log.txt" -Append -IncludeInvocationHeader
Write-Host "################# New Script Run #################"
Write-host "Current time (UTC-0): $LogTime"

# Create directory to store ODT and setup files
mkdir "$env:windir\Temp\onedrive_sa\raw" -Force

Write-Host "INFO: Downloading OneDriveSetup.exe" -ForegroundColor Gray
$OnedriveInstallerUri = "https://go.microsoft.com/fwlink/?linkid=844652"
Invoke-WebRequest -Uri $OnedriveInstallerUri -OutFile "$env:windir\Temp\onedrive_sa\raw\OneDriveSetup.exe"

Write-Host "INFO: Removing any existing OneDrive installations" -ForegroundColor Gray
Start-Process -filepath "$env:windir\Temp\onedrive_sa\raw\OneDriveSetup.exe" -ArgumentList " /uninstall" -Wait

Write-Host "INFO: Setting registry for Per-Machine install (HKLM\Software\Microsoft\OneDrive = AllUsersInstall" -ForegroundColor Gray
REG ADD "HKLM\Software\Microsoft\OneDrive" /v "AllUsersInstall" /t REG_DWORD /d 1 /reg:64

Write-Host "INFO: Installing OneDrive in per-machine mode (OneDriveSetup.exe /allusers)" -ForegroundColor Gray
Start-Process -filepath "$env:windir\Temp\onedrive_sa\raw\OneDriveSetup.exe" -ArgumentList " /allusers" -Wait

Write-Host "INFO: Configuring OneDrive to start at sign in for all users" -ForegroundColor Gray
REG ADD "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /t REG_SZ /d "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe /background" /f

Write-Host "INFO: Configuring OneDrive to enable silent user account configuration" -ForegroundColor Gray
REG ADD "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" /v "SilentAccountConfig" /t REG_DWORD /d 1 /f

Write-Host "INFO: Configuring OneDrive to move Windows known folders to OneDrive" -ForegroundColor Gray
REG ADD "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" /v "KFMSilentOptIn" /t REG_SZ /d "$($SecureVars.tenantid)" /f

# End Logging
Stop-Transcript
$VerbosePreference=$SaveVerbosePreference
