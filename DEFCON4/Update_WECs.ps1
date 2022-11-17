$FolderName = "c:\temp"
if (Test-Path $FolderName) {

    Write-Host "Folder Exists"
    # Perform Delete file from folder operation
}
else
{

    #PowerShell Create directory if not exists
    New-Item $FolderName -ItemType Directory
    Write-Host "Folder Created successfully"
}
cd "c:\temp"
wecutil es > c:\temp\subscriptions.txt
foreach($line in Get-Content C:\temp\subscriptions.txt) {wecutil ss /e:false $line}
foreach($line in Get-Content C:\temp\subscriptions.txt) {wecutil ds $line}
Invoke-WebRequest -URI https://github.com/blackhillsinfosec/EventLogging/archive/master.zip -OutFile "C:\temp\EventLogging.zip"
Expand-Archive C:\temp\EventLogging.zip
wecutil cs "C:\temp\EventLogging\EventLogging-master\DEFCON4\WEF-Subscriptions\WEC1_AD_AUTH.xml"
wecutil cs "C:\temp\EventLogging\EventLogging-master\DEFCON4\WEF-Subscriptions\WEC2_os_app_events.xml"
wecutil cs "C:\temp\EventLogging\EventLogging-master\DEFCON4\WEF-Subscriptions\WEC3_sec_events.xml"
wecutil cs "C:\temp\EventLogging\EventLogging-master\DEFCON4\WEF-Subscriptions\WEC4_os_app_events.xml"
remove-item "C:\temp\subscriptions.txt"
remove-item "c:\temp\EventLogging.zip"
remove-item -path "c:\temp\EventLogging\" -recurse 
