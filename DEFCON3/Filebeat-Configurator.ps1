$ProgressPreference = 'SilentlyContinue' #Disable status bar

# Get working directory of this script to return to
$startdir = ($pwd).path

 	
# Change to WinDir directory, script will perform work using this drive (Usually C:\)
cd $Env:WinDir


# Stage Downloads
mkdir \tmp-eventlogging\ > $null
cd \tmp-eventlogging\


# Download Filebeat and config
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -URI https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.11.1-windows-x86_64.zip -OutFile "Filebeat.zip"
Invoke-WebRequest -URI "<FilebeatConf>" -OutFile "WEC.zip"
Invoke-WebRequest -URI "<certurl>" -OutFile "ca.crt"


# Expand Archive
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") > $null
[System.IO.Compression.ZipFile]::ExtractToDirectory("\tmp-eventlogging\Filebeat.zip", "\Program Files\")

# Rename Filebeat Program Files directory
Rename-Item '\Program Files\filebeat-7.11.1-windows-x86_64' Filebeat


# Install Filebeat as service
cp \tmp-eventlogging\ca.crt '\program files\Filebeat\ca.crt'
cd '\Program Files\Filebeat\'
powershell -Exec bypass -File .\install-service-filebeat.ps1 > $null
Set-Service -name "filebeat" -StartupType automatic
cp '\program files\Filebeat\filebeat.yml' '\program files\Filebeat\filebeat.yml.old'
$null > '\program files\Filebeat\filebeat.yml'
Get-Content \tmp-eventlogging\filebeat.yml > '\program files\Filebeat\filebeat.yml'
Start-Service -name "filebeat"
Get-Service -name "filebeat"


# Destroy staging directory
cd $Env:WinDir
rm \tmp-eventlogging\ -R


# Return to directory of this script
cd $startdir

