$ProgressPreference = 'SilentlyContinue' #Disable status bar

function invoke-main {
    #Collect path to site dictionary file from user.
    Write-host "An Explorer window will open shortly please select the site definition csv file"
    Start-sleep -seconds 3
    $WECSites = Import-csv $(Get-CSVFilePath)

        
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
    Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON3\Group-Policy-Objects\SOC-Enable-WinRM\" -BackupGpoName "SOC-Enable-WinRM" -CreateIfNeeded -TargetName "SOC-Enable-WinRM" > $null
    Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON2\Group-Policy-Objects\SOC-CMD-PS-Logging\" -BackupGpoName "SOC-CMD-PS-Logging" -CreateIfNeeded -TargetName "SOC-CMD-PS-Logging" > $null

    foreach ($site in $WECSites)
        {
            Import-GPO -Path "\tmp-eventlogging\EventLogging\EventLogging-master\DEFCON4\Group-Policy-Objects\SOC-Windows-Event-Forwarding\" -BackupGpoName "SOC-Windows Event Forwarding" -CreateIfNeeded -TargetName "SOC-$($site.location)-Windows-Event-Forwarding" > $null
            # Update Windowns Event Forwarding GPO
            Set-GPRegistryValue -Name "SOC-$($Site.location)-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager -ValueName "1" -Type String -Value (-join("Server=http://", "$($site.wec)", ":5985/wsman/SubscriptionManager/WEC,Refresh=60"))
            # Confirm WEF GPO value is correct by writing to stdout
            Write-host "GPO value for $($site.location) is set to $($(Get-GPRegistryValue -Name "SOC-$($site.location)-Windows-Event-Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager).value)"
        }

    # Add exclusions to the Windows Event Forwarding to prevent WECs from doubling logs
    foreach ($site in $WECSites)
    {
        # Select each GPO
        $GPOADObject = [ADSI]"LDAP://$($(Get-GPO "SOC-$($Site.location)-Windows-Event-Forwarding").path)"
        # Apply each WEC to each GPO
        foreach ($wec in $WECSites) {
            # Set Apply group policy to deny for each WEC
            $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $($(Get-ADComputer $($wec.wec.Split("."))[0]).sid),"ExtendedRight","Deny",$([system.guid]"edacfd8f-ffb3-11d1-b41d-00a0c968f939"),"All"
            $GPOADObject.ObjectSecurity.AddAccessRule($ace)
            $GPOADObject.CommitChanges()
        }
    }

    # Destroy staging directory
    cd $Env:WinDir
    rm \tmp-eventlogging\ -R -Force


    # write-host("New GPO SOC-Sysmon Deployment requires additional configuration and linking")
    write-host("Group policies have been imported for SOC-Windows-Event-Forwarding, SOC-Enable-WinRM, and SOC-CMD-PS-Logging. This policy need to be linked before its settings are applied.")

}

Function Get-CSVFilePath
{
# wrap windows.forms in try-catch to prevent failure on Server Core
    try {
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.initialDirectory = "C:\"
        $OpenFileDialog.filter = "CSV (*.csv) | *.csv"
        $OpenFileDialog.ShowDialog() | Out-Null
        $output = $OpenFileDialog.FileName
    } catch {
    # do-while to ensure that path provided actually points to a file
        do {
            $output = Read-Host -Prompt "Which sites.csv file:"
        } while (-not (Test-Path -Path $output -PathType Leaf))
    } 

    return $output

}

# Get working directory of this script to return to
$startdir = Split-Path -Parent $MyInvocation.MyCommand.Path

invoke-main

# Return to directory of this script
cd $startdir
