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
cd "c:\temp\EventLogging\EventLogging-master\DEFCON4\WEF-Subscriptions"
foreach ($file in (Get-ChildItem *.xml)) {wecutil cs $file}
remove-item "C:\temp\subscriptions.txt"
remove-item "c:\temp\EventLogging.zip"
remove-item -path "c:\temp\EventLogging\" -recurse 
wecutil es
