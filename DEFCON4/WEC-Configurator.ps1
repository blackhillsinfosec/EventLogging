# Get working directory of this script to return to
$startdir = ($pwd).path


# Change to WinDir directory, script will perform work using this drive (Usually C:\)
cd $Env:WinDir


# Stage Downloads
mkdir \tmp-eventlogging\ > $null
cd \tmp-eventlogging\


# Download Tools
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -URI https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-7.10.1-windows-x86_64.zip -OutFile "WinLogBeat.zip"
Invoke-WebRequest -URI https://github.com/blackhillsinfosec/EventLogging/archive/master.zip -OutFile "EventLogging.zip"
Invoke-WebRequest -URI "<WinLogBeatConf>" -OutFile "WEC.zip"


# Expand Tools
Expand-Archive .\WinLogBeat.zip '\Program Files\'
Rename-Item '\Program Files\winlogbeat-7.10.1-windows-x86_64' WinLogBeat
Expand-Archive .\EventLogging.zip
Expand-Archive .\WEC.zip


# Install WinLogBeat as service
cd '\Program Files\WinLogBeat\'
powershell -Exec bypass -File .\install-service-winlogbeat.ps1 > $null
Set-Service -name "winlogbeat" -StartupType automatic
cp '\program files\WinLogBeat\winlogbeat.yml' '\program files\winlogbeat\winlogbeat.yml.old'
$null > '\program files\winlogbeat\winlogbeat.yml'
Get-Content \tmp-eventlogging\WEC\WEC\winlogbeat.yml > '\program files\winlogbeat\winlogbeat.yml'
Start-Service -name "winlogbeat"
Get-Service -name "winlogbeat"


# Create Event Subscriptions
wecutil qc /q
cd \tmp-eventlogging\EventLogging\EventLogging-master\DEFCON4\WEF-Subscriptions
foreach ($file in (Get-ChildItem *.xml)) {wecutil cs $file}
wevtutil sl ForwardedEvents /ms:41943040


# Fix WecSvc and WinRM ACLs
netsh http delete urlacl url=http://+:5985/wsman/
netsh http add urlacl url=http://+:5985/wsman/ sddl=D:(A;;GX;;;S-1-5-80-569256582-2953403351-2909559716-1301513147-412116970)(A;;GX;;;S-1-5-80-4059739203-877974739-1245631912-527174227-2996563517)


# Destroy staging directory
cd $Env:WinDir
rm \tmp-eventlogging\ -R


# Return to directory of this script
cd $startdir


# Inform of required reboot
write-host "Restart the computer to complete the installation"
