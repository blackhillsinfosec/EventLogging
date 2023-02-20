# Configuration Variables
$sysmonshare = "<SysmonShareLoc>"
$sysmonshareexe = "$sysmonshare\Sysmon.exe" # x86_64
$sysmon64shareexe = "$sysmonshare\Sysmon64.exe" # x64
$sysmon64ashareexe = "$sysmonshare\Sysmon64a.exe" # x64 Arm
$sysmonshareconfig = "$sysmonshare\SysmonConfig.xml"
$localsysmonconfig = "$Env:Windir\SysmonConfig.xml"
$localsysmonexe = "$Env:Windir\Sysmon.exe" # x86_64
$localsysmon64exe = "$Env:Windir\Sysmon64.exe" # x64
$localsysmon64aexe = "$Env:Windir\Sysmon64a.exe" # x64 Arm
$sysmonlog = "$Env:Windir\Sysmon-Deploy.log"
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

function Get-Executables{
    # Determine which architecture of Sysmon should be installed.
    if ($Env:PROCESSOR_ARCHITECTURE -eq "AMD64"){
        return @{
            shareexecutable = $sysmon64shareexe
            localexecutable = $localsysmon64exe
            service = "Sysmon64"
        }
    } elseif ($Env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        return @{
            shareexecutable = $sysmon64ashareexe
            localexecutable = $localsysmon64aexe
            service = "Sysmon64a"
        }
    } else {
        return @{
            shareexecutable = $sysmonshareexe
            localexecutable = $localsysmonexe
            service = "Sysmon"
        }
    }
}

function Get-SysmonUpdates([hashtable] $executables){
    # Get Sysmon versions from share and local
    $sysmonsharever=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($($executables.shareexecutable)).FileVersion
    $localsysmonver=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($($executables.localexecutable)).FileVersion

    # Convert strings to integers for comparison
    [double]$availablesysmonversion = [convert]::ToDouble($sysmonsharever)
    [double]$installedsysmonversion = [convert]::ToDouble($localsysmonver)

    # Checks if share version is greater than the installed version
    if($availablesysmonversion -gt $installedsysmonversion){
        # Copy sysmon locally, for install performance and incase network drops during install
        Copy-Item $sysmonshareconfig $localsysmonconfig
        Invoke-Logging("Uninstalling the installed Sysmon version.")
        cmd /c "$($executables.localexecutable) -u" | Out-Null
        Invoke-Logging("Installing a new Sysmon version.")
        cmd /c "$($executables.shareexecutable) -accepteula -i $sysmonshareconfig" | Out-Null
        # Make sure copies where successful
        if((Test-Path $($executables.localexecutable)) -and (Test-Path $localsysmonconfig)){
            Invoke-Logging("Updated Sysmon driver at $($executables.localexecutable).")
        }
        else {
            Invoke-Logging("Failed to update Sysmon files.")
            exit
        }
    }
}

function Get-ConfigUpdates([hashtable] $executables){
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
            cmd /c "$($executables.localexecutable) -c $localsysmonconfig"
            Invoke-Logging("Updated Sysmon configuration.")
        }
        else {
            Invoke-Logging("Failed to copy new Sysmon config or failed to start driver.")
            exit
        }                     
    }
}

function Get-Updates([hashtable]$executables){
    # No need to check for Sysmon executables, as this is checked in Invoke-ShareFetch.
    Invoke-Logging("Checking for updates.")
    Get-SysmonUpdates($executables)
    if ((Get-Item $sysmonshareconfig) -and (Get-Item $localsysmonconfig)) {
        Get-ConfigUpdates($executables)
    }
}

function Invoke-ShareFetch([hashtable]$executables){
    # Verify exe and config are accessible in sysmon share location
    if(Test-Path $sysmonshare){
        if((Test-Path "$($executables.shareexecutable)") -and (Test-Path "$sysmonshareconfig")){
            # If local config has been removed, copy it back down.
            if(!(Test-Path $localsysmonconfig)){
                Copy-Item $sysmonshareconfig $localsysmonconfig
                Invoke-Logging("Local Config not found at $localsysmonconfig. Copying to local system.")
            }
    
            # Check for Sysmon.exe on the local host
            if(Test-Path $($executables.localexecutable)){
                # If the binary exists but the service doesn't, log the event and move to installation
                try{
                    $sysmonstatus = Get-Service -Name $($executables.Service) -ErrorAction SilentlyContinue 
                    if($sysmonstatus){
                        Invoke-Logging("The Sysmon service is installed.")
                        Get-Updates($executables)
                    }
                    else{
                        Invoke-Logging("The Sysmon Service is not running, but the binary exists.")
                        Invoke-SysmonInstallation($executables)
                    }
                }
                # If the binary and service are running, check for updates
                catch{
                    Invoke-Logging("The Sysmon service is not running, but the binary exists.")
                    Invoke-SysmonInstallation($executables)
                }
            }
            # Sysmon doesn't exist locally
            else{
                Invoke-SysmonInstallation($executables)
            }
        }
        # If one of the share files is not reachable, log and exit
        else{
            if (!(Test-Path $($executables.shareexecutable))){
                Invoke-Logging("Cannot find a file at $($executables.shareexecutable)")
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

function Invoke-SysmonInstallation([hashtable]$executables){
    # Sysmon isn't installed, install it from the share location
    cmd /c "$($executables.shareexecutable) -accepteula -i $sysmonshareconfig" | Out-Null
    Invoke-Logging("Sysmon driver installed.")
    # Make sure copies where successful
    if((Test-Path $($executables.localexecutable)) -and (Test-Path $localsysmonconfig)){
        Invoke-Logging("Files found: $($executables.localexecutable) and $localsysmonconfig")
    }
    else {
        if(!(Test-Path $($executables.localexecutable))){
            Invoke-Logging("Something went wrong and could not find $($executables.localexecutable) after installation.")
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
        $sysmonstatus = Get-Service -Name $($executables.Service) -ErrorAction SilentlyContinue
        if($sysmonstatus){
            try{
                Start-Service -name $($executables.Service) -ErrorAction SilentlyContinue
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
            Start-Service -name $($executables.Service) -ErrorAction SilentlyContinue
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
    $executables = Get-Executables
    Invoke-ShareFetch($executables)
    Get-SysmonStatus
    Invoke-ArchiveCleanup
    Invoke-LogCleanup
}

Invoke-Main