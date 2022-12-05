# Script to run on an AVD host before it is removed/deleted to make sure it is removed from Azure AD Hybrid Join
 
#description: Disjoined from Azure AD Hybrid Join
#execution mode: IndividualWithRestart
#tags: SCC Hyperscale, Azure AD
<# 
Notes:
Disjoin the host from Azure AD
#>

$LogPath = "C:\Logs\" 
$LogFile = "AADHybridLeave.log" 

Function Log-Write 
{ 
   Param ([string]$logstring) 

   if (-Not (Test-Path $logPath)) { 
        New-Item -Path $logPath -ItemType Directory 
   }  
   if (-Not (Test-Path ($logPath + $logFile))) { 
        New-Item -Path ($logPath + $logFile) -ItemType File 
   }  

   $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss") 
   $line = $stamp + " " + $logString 
   Add-content ($logPath + $logFile) -value $line 
} 

Log-Write "**** Check AAD Hybrid Leave script started ****" 

$hostname = hostname 

$DSReg = Invoke-Expression "dsregcmd /leave" 

<#
# Record start time so we can gracefully exit the script after maximum of 35 minutes
$startTimestamp = Get-Date
$maxRuntimeMins = 10

# Check the name of the machine.  If it contains "*image*" then stop the script as we don't want 
# the script to try Azure AD Hybrid joining an image/template machine 
# if ($hostname -like "*image*") { 
#    Log-Write "Hostname is '$($hostname)' which looks like an image machine so stopping the script." 
#    exit 
#} 

try { 
    # Check the status of AAD Hybrid Join and extract the line containing the string "DomainJoin" which shows if the machine is Windows AD joined (i.e. "on-prem" AD).
    $DSReg = Invoke-Expression "dsregcmd /status" 
    $DJ = $DSReg | Select-String DomainJoin 
    $DJ = ($DJ.tostring() -split ":")[1].trim()

    # Check if the device AzureAD 
    $AADJ = $DSReg | Select-String AzureAdJoined 
    $AADJ = ($AADJ.tostring() -split ":")[1].trim()     

    if ($AADJ -eq "Yes") {
        
        Log-Write "This machine is Azure AD Hybrid joined.  Running dsregcmd /leave"  

        Do { 

            # Break out of the Do loop if we've been running this script for the time defined in $maxRuntimeMins
            If ((Get-Date) -gt $now.AddMinutes($maxRuntimeMins)) {

                Log-Write "Azure AD Hybrid Leave Script has been running for $($maxRuntimeMins).  Stopping."                
                break

            # Otherwise we carry on waiting a bit longer for AAD Hybrid Join to complete
            } else {

                Log-Write "Waiting 10 seconds..." 
                Start-Sleep -Seconds 10
                Log-Write "Checking Azure AD Hybrid Join Status." 
                # Check the machines AAD Hybrid Join status and get the value for AzureADJoined in the output
                $DSReg = Invoke-Expression "dsregcmd /status" 
                $AADJ = $DSReg | Select-String AzureAdJoined 
                $AADJ = ($AADJ.tostring() -split ":")[1].trim() 
                
                if ($AADJ -ne "Yes") {                    
                    Log-Write "This machine is now disjoined from Azure AD."                
                }
            }

        } While ($AADJ -eq "Yes")                           
    
    } else {

        Log-Write "This machine is not Azure AD Hybrid joined.  Nothing for me to do, exiting..."                 
    
        # Now loop every 5 seconds, checking the status of the AAD Hybrid join.
        # If the "dsregcmd /join" returned is a clienterror 0x801c03f2, it will wait two minutes (for AAD connect to sync the Comptuer Account) then try to join again and continue checking every 5 minutes.
        # If the script has run for the period defined in $maxRuntimeMins, then it will stop as it is assumed that there is a problem with AAD Hybrid Join or the Computer Account is not being synchronised for some reason.
    }
       

} 

catch [Exception] { 
    Log-Write "ERROR:  $($_.Exception.Message)" 
    exit 
} 
#>

Log-Write "**** Check AAD Hybrid Leave script finished ****" 
