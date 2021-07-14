# Get working directory of this script to return to
$startdir = ($pwd).path


# Change to WinDir directory, script will perform work using this drive (Usually C:\)
cd $Env:WinDir


# Stage Downloads
mkdir \tmp-eventlogging\ > $null
cd \tmp-eventlogging\


# Download Tools
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -URI https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-7.13.2-windows-x86_64.zip -OutFile "WinLogBeat.zip"


Stop-Service Winlogbeat
Move-item '\Program Files\Winlogbeat\' '\Program Files\Winlogbeat-old'


Expand-Archive .\WinLogBeat.zip '\Program Files\'
Rename-Item '\Program Files\winlogbeat-7.13.2-windows-x86_64' WinLogBeat


cd '\Program Files\WinLogBeat\'
powershell -Exec bypass -File .\install-service-winlogbeat.ps1 > $null
Set-Service -name "winlogbeat" -StartupType automatic
cp '\program files\Winlogbeat\winlogbeat.yml' '\program files\winlogbeat\winlogbeat.yml.old'
cp '\program files\Winlogbeat-old\winlogbeat.yml' '\program files\winlogbeat\winlogbeat.yml'
Start-Service -name "winlogbeat"
Get-Service -name "winlogbeat"


# Destroy staging directory
cd $Env:WinDir
rm '\Program Files\Winlogbeat-old' -R
rm \tmp-eventlogging\ -R


# Return to directory of this script
cd $startdir

