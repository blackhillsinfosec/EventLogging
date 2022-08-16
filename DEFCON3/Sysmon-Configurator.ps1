param (
    [string]$SysmonConfig
)

$ProgressPreference = 'SilentlyContinue' #Disable status bar

#Input SysmonShare
$sysmonshare = Read-Host("Enter Sysmon UNC path: ")


# Get working directory of this script to return to
$invocation = $MyInvocation.MyCommand.Path
$startdir = Split-Path -Parent $MyInvocation.MyCommand.Path

 	
# Change to WinDir directory, script will perform work using this drive (Usually C:\)
cd $Env:WinDir


# Stage Downloads
mkdir \tmp-eventlogging\ > $null
cd \tmp-eventlogging\

#Import Sysmon Config
function SysmonConfig {
    if($SysmonConfig){
        #Test that current user can access specified config file
        if (Test-Path $SysmonConfig){
            #Copy config file to UNC path
            Copy-Item $SysmonConfig $sysmonshare\sysmonconfig.xml
        }
        else {
            #File not accessable to current user. Prompt for path again.
            write-host "Unable to access Sysmon config at path specified"
            $SysmonConfig = Read-Host -Prompt "Please specify path to Sysmon config file"
            SysmonConfig
        }
    
    }
    else {
        #Download and install Sysmon-Modular
        Invoke-WebRequest -URI https://github.com/olafhartong/sysmon-modular/archive/refs/heads/master.zip -OutFile "sysmon-modular.zip"
        [System.IO.Compression.ZipFile]::ExtractToDirectory("\tmp-eventlogging\sysmon-modular.zip", "\tmp-eventlogging\sysmon-modular")
        copy-item \tmp-eventlogging\sysmon-modular\sysmon-modular-master\sysmonconfig.xml $sysmonshare\sysmonconfig.xml
    }
}

SysmonConfig

# Download GPOs
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -URI https://github.com/blackhillsinfosec/EventLogging/archive/master.zip -OutFile "EventLogging.zip"
Invoke-WebRequest -URI https://download.sysinternals.com/files/Sysmon.zip -OutFile "Sysmon.zip"

# Expand Archive
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") > $null
[System.IO.Compression.ZipFile]::ExtractToDirectory("\tmp-eventlogging\EventLogging.zip", "\tmp-eventlogging\EventLogging")
[System.IO.Compression.ZipFile]::ExtractToDirectory("\tmp-eventlogging\sysmon.zip", "\tmp-eventlogging\sysmon")


#Update sysmon.ps1 with Sysmon Share Location
$SysmonPS1 = '\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\sysmon\sysmon.ps1'
(Get-Content $SysmonPS1).replace('<SysmonShareLoc>', "$sysmonshare") | Set-Content $SysmonPS1


# Copy to DC or share accessible by everyone
cp \tmp-eventlogging\sysmon\* $sysmonshare
cp \tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\sysmon\sysmon.ps1 $sysmonshare
$null > $sysmonshare\sysmon-deploy.log


# Update SOC-Sysmon-Deployment GPO with location of sysmon share
$SysmonGPOgpr = '\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-Sysmon-Deployment\{D61B8B97-2753-494C-AFC5-860A65B5B76C}\gpreport.xml'
(Get-Content $SysmonGPOgpr).replace('\\dc01\apps\Sysmon\sysmon.ps1', "$sysmonshare\sysmon.ps1") | Set-Content $SysmonGPOgpr
$SysmonGPOschedTask = '\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-Sysmon-Deployment\{D61B8B97-2753-494C-AFC5-860A65B5B76C}\DomainSysvol\GPO\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml'
(Get-Content $SysmonGPOschedTask).replace('\\dc01\apps\Sysmon\sysmon.ps1', "$sysmonshare\sysmon.ps1") | Set-Content $SysmonGPOschedTask


# Import and Create GPOs
Import-GPO -path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-Sysmon-Deployment\" -BackupGpoName "SOC-Sysmon Deployment" -CreateIfNeeded -TargetName "SOC-Sysmon-Deployment" > $null


# Destroy staging directory
cd $Env:WinDir
rm \tmp-eventlogging\ -R -Force


# Return to directory of this script
cd $startdirg