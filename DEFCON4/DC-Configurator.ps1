function invoke-main {
    #Collect path to site dictionary file from user.
    Write-host "An Exploer window will open shortly please select the site definition csv file"
    Start-sleep -seconds 3
    $WECSites = Import-csv $(Get-CSVFilePath)

    # Get working directory of this script to return to
    $invocation = $MyInvocation.MyCommand.Path
    $startdir = Split-Path -Parent $MyInvocation.MyCommand.Path

        
    # Change to WinDir directory, script will perform work using this drive (Usually C:\)
    Set-Location $Env:WinDir


    # Stage Downloads
    mkdir \tmp-eventlogging\ > $null
    Set-Location \tmp-eventlogging\


    # Download GPOs
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -URI https://github.com/blackhillsinfosec/EventLogging/archive/master.zip -OutFile "EventLogging.zip"


    # Expand Archive
    [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") > $null
    [System.IO.Compression.ZipFile]::ExtractToDirectory("\tmp-eventlogging\EventLogging.zip", "\tmp-eventlogging\EventLogging")


    # Import and Create GPOs
    Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON4\Group-Policy-Objects\SOC-DC-Enhanced-Auditing\" -BackupGpoName "SOC-DC-Enhanced-Auditing" -CreateIfNeeded -TargetName "SOC-DC-Enhanced-Auditing" > $null

    foreach ($site in $WECSites)
        {
            Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON4\Group-Policy-Objects\SOC-Windows-Event-Forwarding\" -BackupGpoName "SOC-Windows Event Forwarding" -CreateIfNeeded -TargetName "SOC-$($site.location)-Windows-Event-Forwarding" > $null
            # Update Windowns Event Forwarding GPO
            Set-GPRegistryValue -Name "SOC-$($Site.location)-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager -ValueName "1" -Type String -Value (-join("Server=http://", "$($site.wec)", ":5985/wsman/SubscriptionManager/WEC,Refresh=60"))
            # Confirm WEF GPO value is correct by writing to stdout
            Write-host "GPO value for $($site.location) is set to $($(Get-GPRegistryValue -Name "SOC-$($site.location)-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager).value)"
        }



    # Update Windowns Event Forwarding GPO
    Set-GPRegistryValue -Name "SOC-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager -ValueName "1" -Type String -Value (-join("Server=http://", "$wechost", ":5985/wsman/SubscriptionManager/WEC,Refresh=60"))


    # Confirm WEF GPO value is correct
    Get-GPRegistryValue -Name "SOC-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager


    # Destroy staging directory
    Set-Location $Env:WinDir
    Remove-Item \tmp-eventlogging\ -R -Force


    # write-host("New GPO SOC-Sysmon Deployment requires additional configuration and linking")
    write-host("Group policies have been imported for SOC-DC-Enhanced-Auditing and SOC-Windows Event Forwarding. These policies need to be linked before their settings are applied.")


    # Return to directory of this script
    Set-Location $startdir
}

Function Get-CSVFilePath
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = "C:\"
  $OpenFileDialog.filter = "CSV (*.csv) | *.csv"
  $OpenFileDialog.ShowDialog() | Out-Null
  return $OpenFileDialog.FileName
}

invoke-main