#Input SysmonShare
$sysmonshare = Read-Host("Enter Sysmon UNC path: ")


# Get working directory of this script to return to
$startdir = ($pwd).path

 	
# Change to WinDir directory, script will perform work using this drive (Usually C:\)
cd $Env:WinDir


# Stage Downloads
mkdir \tmp-eventlogging\ > $null
cd \tmp-eventlogging\


# Download Files
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

#Archive the old files to be safe
if (!(Test-Path $sysmonshare\Archive)){New-Item -ItemType Directory -Name "Archive" -Path $sysmonshare | out-null}
else{Remove-Item -Path $sysmonshare\Archive\* -Force}
Get-ChildItem $sysmonshare -Exclude Archive | Copy-Item -Destination $sysmonshare\Archive
 

# Copy to DC or share accessible by everyone
cp \tmp-eventlogging\sysmon\* $sysmonshare
cp \tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\sysmon\sysmonconfig.xml $sysmonshare
cp \tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\sysmon\sysmon.ps1 $sysmonshare
$null > $sysmonshare\sysmon-deploy.log


# Destroy staging directory
cd $Env:WinDir
rm \tmp-eventlogging\ -R -Force


# Return to directory of this script
cd $startdir
