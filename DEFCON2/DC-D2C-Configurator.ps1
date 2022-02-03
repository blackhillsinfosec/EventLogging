# Set Windows Event Collector FQDN
$wechost = "<WECSERVER>"


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
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON4\Group-Policy-Objects\SOC-DC-Enhanced-Auditing\" -BackupGpoName "SOC-DC-Enhanced-Auditing" -CreateIfNeeded -TargetName "SOC-DC-Enhanced-Auditing" > $null
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON4\Group-Policy-Objects\SOC-Windows-Event-Forwarding\" -BackupGpoName "SOC-Windows Event Forwarding" -CreateIfNeeded -TargetName "SOC-Windows-Event-Forwarding" > $null
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-WS-Enhanced-Auditing\" -BackupGpoName "SOC-WS-Enhanced-Auditing" -CreateIfNeeded -TargetName "SOC-WS-Enhanced-Auditing" > $null
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-Enable-WinRM\" -BackupGpoName "SOC-Enable-WinRM" -CreateIfNeeded -TargetName "SOC-Enable-WinRM" > $null
Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON2\Group-Policy-Objects\SOC-CMD-PS-Logging\" -BackupGpoName "SOC-CMD-PS-Logging" -CreateIfNeeded -TargetName "SOC-CMD-PS-Logging" > $null

# Update Windowns Event Forwarding GPO
Set-GPRegistryValue -Name "SOC-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager -ValueName "1" -Type String -Value (-join("Server=http://", "$wechost", ":5985/wsman/SubscriptionManager/WEC,Refresh=60"))


# Confirm WEF GPO value is correct
Get-GPRegistryValue -Name "SOC-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager


# Destroy staging directory
cd $Env:WinDir
rm \tmp-eventlogging\ -R -Force


# write-host("New GPO SOC-Sysmon Deployment requires additional configuration and linking")
write-host("Group policies have been imported for SOC-DC-Enhanced-Auditing, SOC-Windows Event Forwarding, SOC-WS-Enhanced-Auditing, SOC-Enable-WinRM, and SOC-CMD-PS-Logging. These policies need to be linked before their settings are applied.")


# Return to directory of this script
cd $startdir
