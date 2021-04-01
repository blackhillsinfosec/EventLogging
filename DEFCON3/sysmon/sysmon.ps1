# Set Sysmon related locations
$sysmonshare = "<SysmonShareLoc>"
$hostname = "$env:COMPUTERNAME"
$service = "Sysmon"
$sysmonshareexe = "$sysmonshare\sysmon.exe"
$sysmonshareconfig = "$sysmonshare\sysmonconfig.xml"
$localsysmonconfig = "$Env:Windir\sysmonconfig.xml"
$localsysmonexe = "$Env:Windir\sysmon.exe"
$sysmonsharelog = "$sysmonshare\sysmon-deploy.log"

# Time code will be reused throughout the script for accurate timestamping of log events
$exectime = Get-Date


# Check that the log file exists
$checksharelog = Test-Path $sysmonsharelog


# Create a new log file is one doesn't exist
if ($checksharelog -eq $false)
{
    Set-Content $sysmonsharelog "" -NoNewline
}


# Change to WinDir directory, script will perform work using this drive (Usually C:\)
cd $Env:WinDir


Function main{

# Verify exe and config are accessible in sysmon share location
$checkshareexe = Test-Path "$sysmonshareexe"
$checkshareconf = Test-Path "$sysmonshareconfig"

if(($checkshareexe -eq $true) -and ($checkshareconf -eq $true))
{

    # Checks for existing sysmon.exe in C:\windows\
    $checklocalexe = Test-Path $localsysmonexe
    
    # Checks for existance of Sysmon service
    $checkservice = get-service -Name $service -ErrorAction SilentlyContinue

    # If the binary exists but the service doesn't, log the event and move to installation
    if (-Not $checkservice)
    {
        $exectime = Get-Date
        Add-Content $sysmonsharelog "$exectime ---- $hostname ---- No Sysmon service but binary exists"
    }

    if (($checklocalexe -eq $true) -and ($checkservice)) {

        # Get Sysmon versions from share and local
        $sysmonsharever=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($sysmonshareexe).FileVersion
        $localsysmonver=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($localsysmonexe).FileVersion

        # Convert strings to integers for comparison
        [double]$availablesysmonversion = [convert]::ToDouble($sysmonsharever)
        [double]$installedsysmonversion = [convert]::ToDouble($localsysmonver)

        # Checks if share version is greater than the installed version
        if($availablesysmonversion -gt $installedsysmonversion)
        {
            # Copy sysmon locally, for install performance and incase network drops during install
            cp $sysmonshareconfig $localsysmonconfig
            cmd /c "$localsysmonexe -u"
            cmd /c "$sysmonshareexe -accepteula -i $sysmonshareconfig"
            # Make sure copies where successful
            if((Test-Path $localsysmonexe) -and (Test-Path $localsysmonconfig))
            {
                $exectime = Get-Date
                Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Updated Sysmon driver."
            }

            else {
                $exectime = Get-Date
                Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Failed updating while copying Sysmon files or starting driver."
                exit
            }
        }
        # Obtain sysmonconfig.xml from share last write time
        $sysmonsharets = (get-item $sysmonshareconfig).LastWriteTime

        # Obtain sysmonconfig.xml from local last write time
        $localsysmonts = (get-item $localsysmonconfig).LastWriteTime

        # If the lastwrite for the share config is greater than the lastwrite for local - update config
        if($sysmonsharets -gt $localsysmonts)
        {
            # Copy config locally, for install performance and incase network drops during install
            cmd /c "copy $sysmonshareconfig $localsysmonconfig"
            # Make sure network copy was successful
            if(Test-Path $localsysmonconfig)
            {
                cmd /c "$localsysmonexe -c $localsysmonconfig"
                $exectime = Get-Date
                Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Updated Sysmon configuration."
            }
            else {
                $exectime = Get-Date
                Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Failed to copy new Sysmon config or failed to start driver."
                exit
            }                     
        }
    }
    # Sysmon isn't installed, install it from the share location
    else
    {
        # Running install from share has much better success rate than installing locally
        cmd /c "$sysmonshareexe -accepteula -i $sysmonshareconfig"
        $exectime = Get-Date
        Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Sysmon driver installed."
        # Make sure copies where successful
        if((Test-Path $localsysmonexe) -and (Test-Path $localsysmonconfig))
        {
            $exectime = Get-Date
            Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Sysmon files exist"
        }
        else {
            $exectime = Get-Date
            Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Something went wrong"
            exit
        }
    }    
}
else{
    $exectime = Get-Date
    Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Failed to find Sysmon files in $sysmonshare."
}
# Ensure sysmon services are running
try{
    $sysmonservice = get-service -Name $service -ErrorAction STOP
    $exectime = Get-Date
    if($sysmonservice.Status -ne "running"){Add-Content $LogFileForScript "$exectime ---- $hostname ---- Service was stopped, attempting start of Sysmon."; start-service -name $service -ErrorAction Stop}
}
catch{
    $exectime = Get-Date
    Add-Content $sysmonsharelog "$exectime ---- $hostname ---- Failed restarting and or getting status of Sysmon"
    exit
}

}

main
