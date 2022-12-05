#description: Checks Azure AD Hybrid Join status, attempts to join every 5 mins for 35 mins if host is not AAD Hybrid joined
#execution mode: IndividualWithRestart
#tags: SCC Hyperscale, Azure AD
<# 
Notes:
# It will check to see if the machine has successfully AAD Hybrid Joined.  If not, it is likely that the Computer Account hasn't yet synchronised from
# Windows Active Directory into Azure Active Directory.  The script waits for 2 minutes (hopefully for an AAD Connect delta sync to run) and then attempts
# to do the Azure AD Hybrid Join again.
#>


$LogPath = "C:\Logs\" 
$LogFile = "AADHybridJoin.log" 

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

Log-Write "**** Check AAD Hybrid Join script started ****" 

$hostname = hostname 

# Record start time so we can gracefully exit the script after maximum of 35 minutes
$startTimestamp = Get-Date
$maxRuntimeMins = 40

# Check the name of the machine.  If it contains "*image*" then stop the script as we don't want 
# the script to try Azure AD Hybrid joining an image/template machine 
# if ($hostname -like "*image*") { 
#    Log-Write "Hostname is '$($hostname)' which looks like an image machine so stopping the script." 
#    exit 
#} 

# Check the status of AAD Hybrid Join and extract the line containing the string "DomainJoin" which shows if the machine is Windows AD joined (i.e. "on-prem" AD).
$DSReg = Invoke-Expression "dsregcmd /status" 
$DJ = $DSReg | Select-String DomainJoin 
$DJ = ($DJ.tostring() -split ":")[1].trim() 

if ($DJ -ne "YES"){ 
    
    # If the machine isn't AD joined, maybe it doesn't need to be Azure AD Hybrid Joined either?
    Log-Write "FAILED: Computer is not joined to a local Active Directory domain.  Azure AD Hybrid Join will not work." 
    Log-Write "FAILED: Make sure machine is joined to the local Active Directory domain if you require Azure AD Hybrid Join." 

} else { 

    Log-Write "Computer is joined to a local Active Directory domain.  Checking Azure AD Hybrid join status..." 

    # Check if the device AzureAD 
    $AADJ = $DSReg | Select-String AzureAdJoined 
    $AADJ = ($AADJ.tostring() -split ":")[1].trim() 
        
    # Now enter a loop, checking the status of the AAD Hybrid join.
    # If the "dsregcmd /join" returned is a clienterror 0x801c03f2, it will wait two minutes (for AAD connect to sync the Comptuer Account) then try to join again and continue checking every 5 minutes.
    # If the script has run for the period defined in $maxRuntimeMins, then it will stop as it is assumed that there is a problem with AAD Hybrid Join or the Computer Account is not being synchronised for some reason.

    Do { 
        
        if ((Get-Date) -gt $startTimeStamp.AddMinutes($maxRuntimeMins)) {
  
            # Break out of the Do loop if we've been running this script for the time defined in $maxRuntimeMins
                    
            Log-Write "Azure AD Hybrid Join Script has been running for $($maxRuntimeMins) minutes.  Stopping.  Check that Azure AD Connect is configured to synchronise every 30 minutes and it working correctly."                
            throw "Azure AD Hybrid join reached the maximum runtime ($($maxRuntimeMins) minutes) and could not confirm AAD Hybrid Join status."

        } 
        else {

            $dsreg = Invoke-Expression "dsregcmd /status" 
            $AADJ = $DSReg | Select-String AzureAdJoined 
            $AADJ = ($AADJ.tostring() -split ":")[1].trim() 

            if ($AADJ -eq "Yes") {    

                Log-Write "This machine is Azure AD Hybrid joined."                                    
            } else {
   
                Log-Write "Attempting Azure AD Hybrid Join" 
                $DSReg = Invoke-Expression "dsregcmd /join" 
                Log-Write "Waiting 30 seconds before checking Azure AD Hybrid Join status" 
                Start-Sleep -Seconds 30
                $dsreg = Invoke-Expression "dsregcmd /status" 

                # Check status and look for any client errors in the output and capture any code that is found
                $clientErrorCode = $DSReg | Select-String "Client Errorcode" 
                if ($clientErrorCode) { 
                    $clientErrorCode = ($clientErrorCode.tostring() -split ":")[1].trim() 
                }

                if ($clientErrorCode -eq "0x801c03f3") { 

                    # If the Client error code 0x801c03f2 was found, it's likely that this is a new machine whose Computer Account hasn't been synchronised into Azure AD yet
                    # So we will wait 2 minutes and then try the join again
                    Log-Write "Client ErrorCode: 0x801c03f2 logged (device object is not found).  Waiting 2 minutes before proceeding (we need Azure AD Connect to synchronise the omputer Account into Azure AD)"                         
                    Start-Sleep -Seconds 120                         
                }
 
            }
                  
        }

    } while ($AADJ -ne "Yes")

       
} 

Log-Write "**** Check AAD Hybrid Join script finished ****" 
