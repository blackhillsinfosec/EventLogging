# Configuration Variables
$sysmonshare = "<SysmonShareLoc>"
$service = "Sysmon"
$sysmonshareexe = "$sysmonshare\sysmon.exe"
$sysmonshareconfig = "$sysmonshare\sysmonconfig.xml"
$localsysmonconfig = "$Env:Windir\sysmonconfig.xml"
$localsysmonexe = "$Env:Windir\sysmon.exe"
$sysmonlog = "$Env:Windir\sysmon-deploy.log"
$archivepath = "C:\Sysmon" # The defined archive in the sysmon config
$archivedays = "30" # Number of days to retain files in the Sysmon Archive

function Invoke-Logging([string]$logmessage){
    Write-Host "`t$logmessage"
    Add-Content $sysmonlog "$(Get-Date) ---- $logmessage"
}

function Invoke-Prep{
    # Check that the log file exists
    if (!(Test-Path $sysmonlog)){
        # Create a new log file if one doesn't exist
        Set-Content $sysmonlog "" -NoNewline
    }

    #Add exclusion for sysmonconfig in Windows Defender.
    Add-MpPreference -ExclusionPath $localsysmonconfig
    Add-MpPreference -ExclusionPath $sysmonshareconfig
}

function Get-SysmonUpdates{
    # Get Sysmon versions from share and local
    $sysmonsharever=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($sysmonshareexe).FileVersion
    $localsysmonver=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($localsysmonexe).FileVersion

    # Convert strings to integers for comparison
    [double]$availablesysmonversion = [convert]::ToDouble($sysmonsharever)
    [double]$installedsysmonversion = [convert]::ToDouble($localsysmonver)

    # Checks if share version is greater than the installed version
    if($availablesysmonversion -gt $installedsysmonversion){
        # Copy sysmon locally, for install performance and incase network drops during install
        Copy-Item $sysmonshareconfig $localsysmonconfig
        Invoke-Logging("Uninstalling the installed Sysmon version.")
        cmd /c "$localsysmonexe -u" | Out-Null
        Invoke-Logging("Installing a new Sysmon version.")
        cmd /c "$sysmonshareexe -accepteula -i $sysmonshareconfig" | Out-Null
        # Make sure copies where successful
        if((Test-Path $localsysmonexe) -and (Test-Path $localsysmonconfig)){
            Invoke-Logging("Updated Sysmon driver.")
        }
        else {
            Invoke-Logging("Failed to update Sysmon files.")
            exit
        }
    }
}

function Get-ConfigUpdates{
    # Obtain sysmonconfig.xml from share last write time
    $sysmonsharets = (Get-Item $sysmonshareconfig).LastWriteTime

    # Obtain sysmonconfig.xml from local last write time
    $localsysmonts = (Get-Item $localsysmonconfig).LastWriteTime

    # If the lastwrite for the share config is greater than the lastwrite for local - update config
    if($sysmonsharets -gt $localsysmonts)
    {
        # Copy config locally, for install performance and incase network drops during install
        Copy-Item $sysmonshareconfig $localsysmonconfig
        # Make sure network copy was successful
        if(Test-Path $localsysmonconfig)
        {
            cmd /c "$localsysmonexe -c $localsysmonconfig"
            Invoke-Logging("Updated Sysmon configuration.")
        }
        else {
            Invoke-Logging("Failed to copy new Sysmon config or failed to start driver.")
            exit
        }                     
    }
}

function Get-Updates{
    # No need to check for Sysmon executables, as this is checked in Invoke-ShareFetch.
    Invoke-Logging("Checking for updates.")
    Get-SysmonUpdates
    if ((Get-Item $sysmonshareconfig) -and (Get-Item $localsysmonconfig)) {
        Get-ConfigUpdates
    }
}

function Invoke-ShareFetch{
    # Verify exe and config are accessible in sysmon share location
    if(Test-Path $sysmonshare){
        if((Test-Path "$sysmonshareexe") -and (Test-Path "$sysmonshareconfig")){
            # If local config has been removed, copy it back down.
            if(!(Test-Path $localsysmonconfig)){
                Copy-Item $sysmonshareconfig $localsysmonconfig
                Invoke-Logging("Local Config not found at $localsysmonconfig. Copying to local system.")
            }
    
            # Check for Sysmon.exe on the local host
            if(Test-Path $localsysmonexe){
                # If the binary exists but the service doesn't, log the event and move to installation
                try{
                    $sysmonstatus = Get-Service -Name $service -ErrorAction SilentlyContinue 
                    if($sysmonstatus){
                        Invoke-Logging("The Sysmon service is installed.")
                        Get-Updates
                    }
                    else{
                        Invoke-Logging("The Sysmon Service is not running, but the binary exists.")
                        Invoke-SysmonInstallation
                    }
                }
                # If the binary and service are running, check for updates
                catch{
                    Invoke-Logging("The Sysmon service is not running, but the binary exists.")
                    Invoke-SysmonInstallation
                }
            }
            # Sysmon doesn't exist locally
            else{
                Invoke-SysmonInstallation
            }
        }
        # If one of the share files is not reachable, log and exit
        else{
            if (!(Test-Path $sysmonshareexe)){
                Invoke-Logging("Cannot find a file at $sysmonshareexe")
            }
            if (!(Test-Path $sysmonshareconfig)){
                Invoke-Logging("Cannot find a file at $sysmonshareconfig")
            }
            exit
        }
    }
    # If the Sysmon share cannot be reached, log and exit.
    else{
        Invoke-Logging("Could not connect to $sysmonshare")
        exit
    }
}

function Invoke-SysmonInstallation{
    # Sysmon isn't installed, install it from the share location
    cmd /c "$sysmonshareexe -accepteula -i $sysmonshareconfig" | Out-Null
    Invoke-Logging("Sysmon driver installed.")
    # Make sure copies where successful
    if((Test-Path $localsysmonexe) -and (Test-Path $localsysmonconfig)){
        Invoke-Logging("Files found: $localsysmonexe and $localsysmonconfig")
    }
    else {
        if(!(Test-Path $localsysmonexe)){
            Invoke-Logging("Something went wrong and could not find $localsysmonexe after installation.")
        }
        if(!(Test-Path $localsysmonconfig)){
            Invoke-Logging("Something went wrong and could not find $localsysmonconfig after installation.")
        }
        exit
    }
}

function Get-SysmonStatus{
    # Ensure sysmon services are running
    try{
        $sysmonstatus = Get-Service -Name $service -ErrorAction SilentlyContinue
        if($sysmonstatus){
            try{
                Start-Service -name $service -ErrorAction SilentlyContinue
            }
            catch{
                Invoke-Logging("Failed restarting and or getting the status of Sysmon.")
                exit
            }
        }
    }
    catch{
        Invoke-Logging("Service was stopped, attempting to start Sysmon.")
        try{
            Start-Service -name $service -ErrorAction SilentlyContinue
        }
        catch{
            Invoke-Logging("Failed restarting or getting the status of Sysmon.")
            exit
        }
    }
}

function Invoke-ArchiveCleanup{
    if((Test-Path $archivepath) -and ($Env:USERNAME -match '\$$')){
        #Manages the archive used to store files seen in EID 23 logs.   
        $CurrentDate = Get-Date
        $DatetoDelete = $CurrentDate.AddDays($(0 - $archivedays))
        if($(Get-ChildItem $archivepath | Where-Object { $_.LastWriteTime -lt $DatetoDelete })){
            Get-ChildItem $archivepath | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
            Invoke-Logging("Archive Cleaned")
        }
    }
}

function Invoke-LogCleanup{
    if((Get-Content $sysmonlog).Length -gt 1000){
        $logcontent = Get-Content $sysmonlog -Tail 500
        Set-Content -Path $sysmonlog -Value $logcontent
        Invoke-Logging("Logs Cleaned")
    }
}

function Invoke-Main{
    Invoke-Prep
    Invoke-ShareFetch
    Get-SysmonStatus
    Invoke-ArchiveCleanup
    Invoke-LogCleanup
}

Invoke-Main