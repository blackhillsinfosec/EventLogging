# Get working directory of this script to return to
$invocation = $MyInvocation.MyCommand.Path
$startdir = Split-Path -Parent $MyInvocation.MyCommand.Path

 	
# Change to WinDir directory, script will perform work using this drive (Usually C:\)
cd $Env:WinDir


# Stage Downloads
mkdir \tmp-eventlogging\ > $null
cd \tmp-eventlogging\


# Download GPOs
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -URI https://github.com/blackhillsinfosec/EventLogging/archive/master.zip -OutFile "EventLogging.zip"


# Expand Archive
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") > $null
[System.IO.Compression.ZipFile]::ExtractToDirectory("\tmp-eventlogging\EventLogging.zip", "\tmp-eventlogging\EventLogging")


# Import and Create GPOs
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-WS-Enhanced-Auditing\" -BackupGpoName "SOC-WS-Enhanced-Auditing" -CreateIfNeeded -TargetName "SOC-WS-Enhanced-Auditing" > $null
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-Enable-WinRM\" -BackupGpoName "SOC-Enable-WinRM" -CreateIfNeeded -TargetName "SOC-Enable-WinRM" > $null

# Destroy staging directory
cd $Env:WinDir
rm \tmp-eventlogging\ -R -Force


# write-host("New GPO SOC-Sysmon Deployment requires additional configuration and linking")
write-host("Group policies have been imported for SOC-WS-Enhanced-Auditing and SOC-Enable-WinRM. These policies need to be linked before their settings are applied.")
# Return to directory of this script
cd $startdir
