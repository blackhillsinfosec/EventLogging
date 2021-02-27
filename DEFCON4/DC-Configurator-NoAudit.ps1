# Set Windows Event Collector FQDN
$wechost = "<WECSERVER>"


# Get working directory of this script to return to
$startdir = ($pwd).path

 	
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
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON4\Group-Policy-Objects\SOC-Windows-Event-Forwarding\" -BackupGpoName "SOC-Windows Event Forwarding" -CreateIfNeeded -TargetName "SOC-Windows-Event-Forwarding" > $null


# Update Windowns Event Forwarding GPO
Set-GPRegistryValue -Name "SOC-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager -ValueName "1" -Type String -Value (-join("Server=http://", "$wechost", ":5985/wsman/SubscriptionManager/WEC,Refresh=60"))


# Confirm WEF GPO value is correct
Get-GPRegistryValue -Name "SOC-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager


# Destroy staging directory
cd $Env:WinDir
rm \tmp-eventlogging\ -R -Force


# write-host("New GPO SOC-Sysmon Deployment requires additional configuration and linking")
write-host("Group policies have been imported for SOC-Windows-Event-Forwarding. This policy need to be linked before its settings are applied.")


# Return to directory of this script
cd $startdir
