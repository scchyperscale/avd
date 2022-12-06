# Script to setup English (UK) System Locale and Language and set as default for all users
#description: Setup English (UK) Language for Windows 11
#execution mode: IndividualWithRestart
#tags: SCC Hyperscale, Language
<# 
Notes:
Sets up English (UK) Language
#>

# About 10 minutes to run this to install
Install-Language -Language en-gb -CopyToSettings

# Set Display Language
Set-SystemPreferredUILAnguage -Language en-gb

# Set Input Language and Format to en-gb
$newLanguageList = New-WinUserLanguageList -Language "en-GB"
$newLanguageList[0].Handwriting = 1
Set-WinUserLanguageList -LanguageList $newLanguageList -Force

# Sets the home local for the current user to "United Kingdom"
Set-WinHomeLocation -GeoId 242

# Copy the current user settings to the defaults
Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUSer $True

# Set the System Locale
Set-WinSystemLocale -SystemLocale en-GB
