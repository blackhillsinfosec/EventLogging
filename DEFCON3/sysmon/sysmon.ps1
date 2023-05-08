# Configuration Variables
$sysmonshare = "<SysmonShareLoc>"
$sysmonshareexe = "$sysmonshare\Sysmon.exe" # x86_64
$sysmon64shareexe = "$sysmonshare\Sysmon64.exe" # x64
$sysmon64ashareexe = "$sysmonshare\Sysmon64a.exe" # x64 Arm
$sysmonshareconfig = "$sysmonshare\SysmonConfig.xml"
$localsysmonconfig = "$Env:Windir\SysmonConfig.xml"
$localsysmonexe = "$Env:Windir\Sysmon.exe" # x86_64
$localsysmon64exe = "$Env:Windir\Sysmon64.exe" # x64
$localsysmon64aexe = "$Env:Windir\Sysmon64a.exe" # x64 Arm
$sysmonlog = "$Env:Windir\Sysmon-Deploy.log"
$archivepath = "C:\Sysmon" # The defined archive in the sysmon config
$archivedays = "30" # Number of days to retain files in the Sysmon Archive

function Invoke-Logging([string]$logmessage){
    Write-Host "`t$logmessage"
    Add-Content $sysmonlog "$(Get-Date) ---- $logmessage"
}

function Invoke-Prep{
    # Check that the log file exists
    if (!(Test-Path $sysmonlog)){
        # Create a new log file if one doesn't exist
        Set-Content $sysmonlog "" -NoNewline
    }

    #Add exclusion for sysmonconfig in Windows Defender.
    Add-MpPreference -ExclusionPath $localsysmonconfig
    Add-MpPreference -ExclusionPath $sysmonshareconfig
}

function Get-Executables{
    # Determine which architecture of Sysmon should be installed.
    if ($Env:PROCESSOR_ARCHITECTURE -eq "AMD64"){
        return @{
            shareexecutable = $sysmon64shareexe
            localexecutable = $localsysmon64exe
            service = "Sysmon64"
        }
    } elseif ($Env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        return @{
            shareexecutable = $sysmon64ashareexe
            localexecutable = $localsysmon64aexe
            service = "Sysmon64a"
        }
    } else {
        return @{
            shareexecutable = $sysmonshareexe
            localexecutable = $localsysmonexe
            service = "Sysmon"
        }
    }
}

function Get-SysmonUpdates([hashtable] $executables){
    # Get Sysmon versions from share and local
    $sysmonsharever=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($($executables.shareexecutable)).FileVersion
    $localsysmonver=[System.Diagnostics.FileVersionInfo]::GetVersionInfo($($executables.localexecutable)).FileVersion

    # Convert strings to integers for comparison
    [double]$availablesysmonversion = [convert]::ToDouble($sysmonsharever)
    [double]$installedsysmonversion = [convert]::ToDouble($localsysmonver)

    # Checks if share version is greater than the installed version
    if($availablesysmonversion -gt $installedsysmonversion){
        # Copy sysmon locally, for install performance and incase network drops during install
        Copy-Item $sysmonshareconfig $localsysmonconfig
        Invoke-Logging("Uninstalling the installed Sysmon version.")
        cmd /c "$($executables.localexecutable) -u" | Out-Null
        Invoke-Logging("Installing a new Sysmon version.")
        cmd /c "$($executables.shareexecutable) -accepteula -i $sysmonshareconfig" | Out-Null
        # Make sure copies where successful
        if((Test-Path $($executables.localexecutable)) -and (Test-Path $localsysmonconfig)){
            Invoke-Logging("Updated Sysmon driver at $($executables.localexecutable).")
        }
        else {
            Invoke-Logging("Failed to update Sysmon files.")
            exit
        }
    }
}

function Get-ConfigUpdates([hashtable] $executables){
    # Obtain sysmonconfig.xml from share last write time
    $sysmonsharets = (Get-Item $sysmonshareconfig).LastWriteTime

    # Obtain sysmonconfig.xml from local last write time
    $localsysmonts = (Get-Item $localsysmonconfig).LastWriteTime

    # If the lastwrite for the share config is greater than the lastwrite for local - update config
    if($sysmonsharets -gt $localsysmonts)
    {
        # Copy config locally, for install performance and incase network drops during install
        Copy-Item $sysmonshareconfig $localsysmonconfig
        # Make sure network copy was successful
        if(Test-Path $localsysmonconfig)
        {
            cmd /c "$($executables.localexecutable) -c $localsysmonconfig"
            Invoke-Logging("Updated Sysmon configuration.")
        }
        else {
            Invoke-Logging("Failed to copy new Sysmon config or failed to start driver.")
            exit
        }                     
    }
}

function Get-Updates([hashtable]$executables){
    # No need to check for Sysmon executables, as this is checked in Invoke-ShareFetch.
    Invoke-Logging("Checking for updates.")
    Get-SysmonUpdates($executables)
    if ((Get-Item $sysmonshareconfig) -and (Get-Item $localsysmonconfig)) {
        Get-ConfigUpdates($executables)
    }
}

function Invoke-ShareFetch([hashtable]$executables){
    # Verify exe and config are accessible in sysmon share location
    if(Test-Path $sysmonshare){
        if((Test-Path "$($executables.shareexecutable)") -and (Test-Path "$sysmonshareconfig")){
            # If local config has been removed, copy it back down.
            if(!(Test-Path $localsysmonconfig)){
                Copy-Item $sysmonshareconfig $localsysmonconfig
                Invoke-Logging("Local Config not found at $localsysmonconfig. Copying to local system.")
            }
    
            # Check for Sysmon.exe on the local host
            if(Test-Path $($executables.localexecutable)){
                # If the binary exists but the service doesn't, log the event and move to installation
                try{
                    $sysmonstatus = Get-Service -Name $($executables.Service) -ErrorAction SilentlyContinue 
                    if($sysmonstatus){
                        Invoke-Logging("The Sysmon service is installed.")
                        Get-Updates($executables)
                    }
                    else{
                        Invoke-Logging("The Sysmon Service is not running, but the binary exists.")
                        Invoke-SysmonInstallation($executables)
                    }
                }
                # If the binary and service are running, check for updates
                catch{
                    Invoke-Logging("The Sysmon service is not running, but the binary exists.")
                    Invoke-SysmonInstallation($executables)
                }
            }
            # Sysmon doesn't exist locally
            else{
                Invoke-SysmonInstallation($executables)
            }
        }
        # If one of the share files is not reachable, log and exit
        else{
            if (!(Test-Path $($executables.shareexecutable))){
                Invoke-Logging("Cannot find a file at $($executables.shareexecutable)")
            }
            if (!(Test-Path $sysmonshareconfig)){
                Invoke-Logging("Cannot find a file at $sysmonshareconfig")
            }
            exit
        }
    }
    # If the Sysmon share cannot be reached, log and exit.
    else{
        Invoke-Logging("Could not connect to $sysmonshare")
        exit
    }
}

function Invoke-SysmonInstallation([hashtable]$executables){
    # Sysmon isn't installed, install it from the share location
    cmd /c "$($executables.shareexecutable) -accepteula -i $sysmonshareconfig" | Out-Null
    Invoke-Logging("Sysmon driver installed.")
    # Make sure copies where successful
    if((Test-Path $($executables.localexecutable)) -and (Test-Path $localsysmonconfig)){
        Invoke-Logging("Files found: $($executables.localexecutable) and $localsysmonconfig")
    }
    else {
        if(!(Test-Path $($executables.localexecutable))){
            Invoke-Logging("Something went wrong and could not find $($executables.localexecutable) after installation.")
        }
        if(!(Test-Path $localsysmonconfig)){
            Invoke-Logging("Something went wrong and could not find $localsysmonconfig after installation.")
        }
        exit
    }
}

function Get-SysmonStatus{
    # Ensure sysmon services are running
    try{
        $sysmonstatus = Get-Service -Name $($executables.Service) -ErrorAction SilentlyContinue
        if($sysmonstatus){
            try{
                Start-Service -name $($executables.Service) -ErrorAction SilentlyContinue
            }
            catch{
                Invoke-Logging("Failed restarting and or getting the status of Sysmon.")
                exit
            }
        }
    }
    catch{
        Invoke-Logging("Service was stopped, attempting to start Sysmon.")
        try{
            Start-Service -name $($executables.Service) -ErrorAction SilentlyContinue
        }
        catch{
            Invoke-Logging("Failed restarting or getting the status of Sysmon.")
            exit
        }
    }
}

function Invoke-ArchiveCleanup{
    if((Test-Path $archivepath) -and ($Env:USERNAME -match '\$$')){
        #Manages the archive used to store files seen in EID 23 logs.   
        $CurrentDate = Get-Date
        $DatetoDelete = $CurrentDate.AddDays($(0 - $archivedays))
        if($(Get-ChildItem $archivepath | Where-Object { $_.LastWriteTime -lt $DatetoDelete })){
            Get-ChildItem $archivepath | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
            Invoke-Logging("Archive Cleaned")
        }
    }
}

function Invoke-LogCleanup{
    if((Get-Content $sysmonlog).Length -gt 1000){
        $logcontent = Get-Content $sysmonlog -Tail 500
        Set-Content -Path $sysmonlog -Value $logcontent
        Invoke-Logging("Logs Cleaned")
    }
}

function Invoke-Main{
    Invoke-Prep
    $executables = Get-Executables
    Invoke-ShareFetch($executables)
    Get-SysmonStatus
    Invoke-ArchiveCleanup
    Invoke-LogCleanup
}

Invoke-Main
# SIG # Begin signature block
# MIIm2AYJKoZIhvcNAQcCoIImyTCCJsUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA5Fg55Jep/5BAz
# l+s2uHpbzDA7drB+phAkd5i8pMBGkqCCDYgwggZyMIIEWqADAgECAghkM1HTxzif
# CDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzEOMAwGA1UECAwFVGV4YXMx
# EDAOBgNVBAcMB0hvdXN0b24xGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlvbjExMC8G
# A1UEAwwoU1NMLmNvbSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IFJTQTAe
# Fw0xNjA2MjQyMDQ0MzBaFw0zMTA2MjQyMDQ0MzBaMHgxCzAJBgNVBAYTAlVTMQ4w
# DAYDVQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3RvbjERMA8GA1UECgwIU1NMIENv
# cnAxNDAyBgNVBAMMK1NTTC5jb20gQ29kZSBTaWduaW5nIEludGVybWVkaWF0ZSBD
# QSBSU0EgUjEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCfgxNzqrDG
# bSHL24t6h3TQcdyOl3Ka5LuINLTdgAPGL0WkdJq/Hg9Q6p5tePOf+lEmqT2d0bKU
# Vz77OYkbkStW72fL5gvjDjmMxjX0jD3dJekBrBdCfVgWQNz51ShEHZVkMGE6ZPKX
# 13NMfXsjAm3zdetVPW+qLcSvvnSsXf5qtvzqXHnpD0OctVIFD+8+sbGP0EmtpuNC
# GVQ/8y8Ooct8/hP5IznaJRy4PgBKOm8yMDdkHseudQfYVdIYyQ6KvKNc8HwKp4WB
# wg6vj5lc02AlvINaaRwlE81y9eucgJvcLGfE3ckJmNVz68Qho+Uyjj4vUpjGYDdk
# jLJvSlRyGMwnh/rNdaJjIUy1PWT9K6abVa8mTGC0uVz+q0O9rdATZlAfC9KJpv/X
# gAbxwxECMzNhF/dWH44vO2jnFfF3VkopngPawismYTJboFblSSmNNqf1x1KiVgMg
# Lzh4gL32Bq5BNMuURb2bx4kYHwu6/6muakCZE93vUN8BuvIE1tAx3zQ4XldbyDge
# VtSsSKbt//m4wTvtwiS+RGCnd83VPZhZtEPqqmB9zcLlL/Hr9dQg1Zc0bl0EawUR
# 0tOSjAknRO1PNTFGfnQZBWLsiePqI3CY5NEv1IoTGEaTZeVYc9NMPSd6Ij/D+KNV
# t/nmh4LsRR7Fbjp8sU65q2j3m2PVkUG8qQIDAQABo4H7MIH4MA8GA1UdEwEB/wQF
# MAMBAf8wHwYDVR0jBBgwFoAU3QQJB6L1en1SUxKSle44gCUNplkwMAYIKwYBBQUH
# AQEEJDAiMCAGCCsGAQUFBzABhhRodHRwOi8vb2NzcHMuc3NsLmNvbTARBgNVHSAE
# CjAIMAYGBFUdIAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwOwYDVR0fBDQwMjAwoC6g
# LIYqaHR0cDovL2NybHMuc3NsLmNvbS9zc2wuY29tLXJzYS1Sb290Q0EuY3JsMB0G
# A1UdDgQWBBRUwv4QlQCTzWr158DX2bJLuI8M4zAOBgNVHQ8BAf8EBAMCAYYwDQYJ
# KoZIhvcNAQELBQADggIBAPUPJodwr5miyvXWyfCNZj05gtOII9iCv49UhCe204MH
# 154niU2EjlTRIO5gQ9tXQjzHsJX2vszqoz2OTwbGK1mGf+tzG8rlQCbgPW/M9r1x
# xs19DiBAOdYF0q+UCL9/wlG3K7V7gyHwY9rlnOFpLnUdTsthHvWlM98CnRXZ7WmT
# V7pGRS6AvGW+5xI+3kf/kJwQrfZWsqTU+tb8LryXIbN2g9KR+gZQ0bGAKID+260P
# Z+34fdzZcFt6umi1s0pmF4/n8OdX3Wn+vF7h1YyfE7uVmhX7eSuF1W0+Z0duGwdc
# +1RFDxYRLhHDsLy1bhwzV5Qe/kI0Ro4xUE7bM1eV+jjk5hLbq1guRbfZIsr0WkdJ
# LCjoT4xCPGRo6eZDrBmRqccTgl/8cQo3t51Qezxd96JSgjXktefTCm9r/o35pNfV
# HUvnfWII+NnXrJlJ27WEQRQu9i5gl1NLmv7xiHp0up516eDap8nMLDt7TAp4z5T3
# NmC2gzyKVMtODWgqlBF1JhTqIDfM63kXdlV4cW3iSTgzN9vkbFnHI2LmvM4uVEv9
# XgMqyN0eS3FE0HU+MWJliymm7STheh2ENH+kF3y0rH0/NVjLw78a3Z9UVm1F5VPz
# iIorMaPKPlDRADTsJwjDZ8Zc6Gi/zy4WZbg8Zv87spWrmo2dzJTw7XhQf+xkR6Od
# MIIHDjCCBPagAwIBAgIQNyK1kw5a57c71ANTsnzLAzANBgkqhkiG9w0BAQsFADB4
# MQswCQYDVQQGEwJVUzEOMAwGA1UECAwFVGV4YXMxEDAOBgNVBAcMB0hvdXN0b24x
# ETAPBgNVBAoMCFNTTCBDb3JwMTQwMgYDVQQDDCtTU0wuY29tIENvZGUgU2lnbmlu
# ZyBJbnRlcm1lZGlhdGUgQ0EgUlNBIFIxMB4XDTIzMDQyMDE5NDQ1NloXDTI0MDQx
# MDE5NDQ1NlowgZYxCzAJBgNVBAYTAlVTMRUwEwYDVQQIDAxTb3V0aCBEYWtvdGEx
# EjAQBgNVBAcMCVNwZWFyZmlzaDEtMCsGA1UECgwkQmxhY2sgSGlsbHMgSW5mb3Jt
# YXRpb24gU2VjdXJpdHkgTExDMS0wKwYDVQQDDCRCbGFjayBIaWxscyBJbmZvcm1h
# dGlvbiBTZWN1cml0eSBMTEMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDo54aCUBZveaURwaE3ebwfO7X7KMmGf36XSaVPWcgCdDdEDkxhsIynKrcK1o+r
# ueG3N6fcXSfZg9Blr/dxu8HxlNv7vQ1GCNegsVkS5lJQo7gNzKpF+Hdzw5zzmuxW
# FkCgk7FMZAsvxKN2uuTJBeKDspEmq/0jqu2VAXQQzUvHv9EiLhnRbipbmVqxQqVv
# M/cQME7HvFg3vfNZDjU82QlUqJUHDEVfh1m5RPX5n69IEVUIIxkDPkF/U/ckhakC
# NjaNJmSMGKbyjTHryw4qbxdtbl2+pOQg41g9iprVArAT/8ZJd2dobMLfJt9iK07k
# oGesHPriqktQarLDk1nsAyvOb7oVUSqjd6evcaqeol2zMN9hYvBBCP6vitYD9PDw
# EK+iaR4BurGI0nY8h0tKzVvaACLNX8Prk9/IUFQMdwoLLmDXCQRhDlAKOI3RBO8V
# CDzqFbCWjEjQjFIKhJVFVMc84puYh2nMWojhBn8+B4ZgYHHigjsCEC7INReu8MPB
# juL1Nvo6XYJdDW9aFPP6m5oU+8KL6Y7myK3jpVX6lb0BPJVFR4N9lr2Fcu8sibSq
# 0Zla80DqUZAl3NCR5K+BKcVqsexCw8XXw2uOJ1D01NQaMerKLgCGeoOJ/wWA6YF9
# XxeVRtajxw1287uJ7/WS+yoNdqQv0b8yI8eAiUK7PLogaQIDAQABo4IBczCCAW8w
# DAYDVR0TAQH/BAIwADAfBgNVHSMEGDAWgBRUwv4QlQCTzWr158DX2bJLuI8M4zBY
# BggrBgEFBQcBAQRMMEowSAYIKwYBBQUHMAKGPGh0dHA6Ly9jZXJ0LnNzbC5jb20v
# U1NMY29tLVN1YkNBLUNvZGVTaWduaW5nLVJTQS00MDk2LVIxLmNlcjBRBgNVHSAE
# SjBIMAgGBmeBDAEEATA8BgwrBgEEAYKpMAEDAwEwLDAqBggrBgEFBQcCARYeaHR0
# cHM6Ly93d3cuc3NsLmNvbS9yZXBvc2l0b3J5MBMGA1UdJQQMMAoGCCsGAQUFBwMD
# ME0GA1UdHwRGMEQwQqBAoD6GPGh0dHA6Ly9jcmxzLnNzbC5jb20vU1NMY29tLVN1
# YkNBLUNvZGVTaWduaW5nLVJTQS00MDk2LVIxLmNybDAdBgNVHQ4EFgQU1cIxaQkm
# cvG0weDCHTumgjG7jZUwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQBmqILyfzrhfEb+Tk4/qOt8kzt/w5+q3Uz3kvz1gtLEAAyzWkFTGOG/zw/uWCK+
# pLZyrxmG+zC+9fs5GcqS4BqGCpOXoLVMRdWrTg9d3E5t1OW/KGmbf+fE4zuDRf+6
# ZiXOAFEtuQkn1cdQikZUHoQhcZOqmwAu8AyAjl+b1WwRho1Bfcr726Z0wMsXJKI+
# QP0huyO4ANW6gwmbsEl23iVEGLDut2xcxrSMTwz3Xd0aDnMkM3AbSOibWPDF3xus
# JNe1RcrayDcK1/muB/gsEzHlSsXKp02MmZyuDhOgfYng1IIFeAFI58f8ZN/stnQJ
# hPHWRZiO0Zy8DE2NDH+uA6hPNQPvHU4W4YXSAfk9EohXnDrcZuWc1bN1SruBf7fY
# 6b4T7VqmxC8HgTMqYaWCIwQDco+gOZFB3UWBqyoi9EUid/F2eisGMi84Mn4MUD0/
# YUCtnez8qKJeFajECzoaPEIitYr+zLipzOqjwPzdv9eZqNgDorYPMz8JCwau2ifv
# zPsmB3u3a/LhNAa8XHa428mrqwZAH7GA0Jwo6v8Md8ktyelXi/4JkSAN+l/HWAKl
# 0rikrv5dZ2JA/LWimQ9Idi+bIPZuM94tF861NnPiEDXvd6fnbWovc4psjoqffEmI
# 1yTywIeyPBTvFsKfr8P6oJBQF91XjyFep4eipqIuI/kZlTGCGKYwghiiAgEBMIGM
# MHgxCzAJBgNVBAYTAlVTMQ4wDAYDVQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3Rv
# bjERMA8GA1UECgwIU1NMIENvcnAxNDAyBgNVBAMMK1NTTC5jb20gQ29kZSBTaWdu
# aW5nIEludGVybWVkaWF0ZSBDQSBSU0EgUjECEDcitZMOWue3O9QDU7J8ywMwDQYJ
# YIZIAWUDBAIBBQCggfcwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIH9We2i3Qfo6
# YbY/Ce8kwI2QALn5kXZVt0J4Qc8TqsMKMIGKBgorBgEEAYI3AgEMMXwweqAcgBoA
# UwB5AHMAbQBvAG4AIABSAHUAbgBuAGUAcqFagFhodHRwczovL2dpdGh1Yi5jb20v
# YmxhY2toaWxsc2luZm9zZWMvRXZlbnRMb2dnaW5nL2Jsb2IvbWFzdGVyL0RFRkNP
# TjMvc3lzbW9uL3N5c21vbi5wczEgMA0GCSqGSIb3DQEBAQUABIICANwhOMNhJOgs
# GApCKjlMfZn9YM22g2X1q5ShK/pcHWrsYxUgUEcpa3ZvRncyNTFIolq0BlfMhuPp
# 6XyspEmoMEEUxYBkI20M0bUbdo+1KDHPHOoGU7PlEWRCA72ryUfn60a1P7Vc+tFj
# StuP5BZr/bC5UK/zc5FDnt0lg/5ZtZZUoeFS9djj0cdDwMRnrAZSWRYMH3N2p1MM
# 6wHnIAsHCcW6x/d9R/2N3s3WCgGM+xKNO8kf0vlg1T3+CXNZPmlF9i7alnnEzcO9
# MzNDU210ItyIlewj5KVJTHCSBhy4qiHJ1Xz03ry4whHFuFybx+VHBQjTQlXszV97
# 3Kqj3aqPgseXmwruAxtecqAWvY4P40e3L3NQcaSllg6UtOK9NtDMLzJ+VafloCyX
# Y/jOscZxn31UPE3jg3CU1fsBfh0RC44Psx02+heMisDe3Tc4g7ehnjtE4exhbIOQ
# 6+GaaOZuc62bQLHDlUb/g0d5gR1iwicyeCHoqLPpFJVeteKAYXiTDap15lqkfikm
# 9CNYsjd4xkRTPTzkTEX2EzFq1C0Da5s6CZmFRg8eX0Y+uKCx4XeIIuoxMBsIPEB9
# AqrTHw3OddjtIRVgkgw8a3i0pU+VH+3abiVKH1Yk1mR6YwH8NhfFzven970ZZRrt
# JPQugeoPUg2+3EhowOkkxhtcCqpXoxTmoYIU8DCCFOwGCisGAQQBgjcDAwExghTc
# MIIU2AYJKoZIhvcNAQcCoIIUyTCCFMUCAQMxDTALBglghkgBZQMEAgEwdwYLKoZI
# hvcNAQkQAQSgaARmMGQCAQEGDCsGAQQBgqkwAQMGATAxMA0GCWCGSAFlAwQCAQUA
# BCA5SHB+ZYbe56nr1SSGjjDYVmroUW0m12cRcc4pjEwtvQIIfXh76AGIS2oYDzIw
# MjMwNTA4MjA1ODM4WjADAgEBoIIR2TCCBPkwggLhoAMCAQICEBrWCKfWNLXN3pfL
# o8zw0EswDQYJKoZIhvcNAQELBQAwczELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRl
# eGFzMRAwDgYDVQQHDAdIb3VzdG9uMREwDwYDVQQKDAhTU0wgQ29ycDEvMC0GA1UE
# AwwmU1NMLmNvbSBUaW1lc3RhbXBpbmcgSXNzdWluZyBSU0EgQ0EgUjEwHhcNMjIx
# MjA5MTgzMDUxWhcNMzIxMjA2MTgzMDUwWjBrMQswCQYDVQQGEwJVUzEOMAwGA1UE
# CAwFVGV4YXMxEDAOBgNVBAcMB0hvdXN0b24xETAPBgNVBAoMCFNTTCBDb3JwMScw
# JQYDVQQDDB5TU0wuY29tIFRpbWVzdGFtcGluZyBVbml0IDIwMjIwWTATBgcqhkjO
# PQIBBggqhkjOPQMBBwNCAATefPqSJZSy2TTZyF4GhypEr9YCY44KQr+4/R2+4QOH
# yAxCLyYMIolVLQzaqOySeI6nI4j/+L1aB3Jv9HeBPTu4o4IBWjCCAVYwHwYDVR0j
# BBgwFoAUDJ0QJY6apxuZh0PPCH7hvYGQ9M8wUQYIKwYBBQUHAQEERTBDMEEGCCsG
# AQUFBzAChjVodHRwOi8vY2VydC5zc2wuY29tL1NTTC5jb20tdGltZVN0YW1waW5n
# LUktUlNBLVIxLmNlcjBRBgNVHSAESjBIMDwGDCsGAQQBgqkwAQMGATAsMCoGCCsG
# AQUFBwIBFh5odHRwczovL3d3dy5zc2wuY29tL3JlcG9zaXRvcnkwCAYGZ4EMAQQC
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEYGA1UdHwQ/MD0wO6A5oDeGNWh0dHA6
# Ly9jcmxzLnNzbC5jb20vU1NMLmNvbS10aW1lU3RhbXBpbmctSS1SU0EtUjEuY3Js
# MB0GA1UdDgQWBBQFupPR3+IUrCAqhlkxfyhyDq2sXzAOBgNVHQ8BAf8EBAMCB4Aw
# DQYJKoZIhvcNAQELBQADggIBAFqotJYQYw1EaMzHk5NlJLaJzxDf3njeZNS3iMrO
# vZPAMnJxzPeIWGqneI6rxGdOwewqS3gYcCPZKEag2WVTjrhBpFtN5oCdbnaCQuWc
# JHvf3H104NBhYsqkCrMwWoo3E2Udaw49PBeZoZFMykPraTG/I3W76FoP1BuzI9xh
# SG56DzRn3lIwIg80JgimsRASJEwcw4K2Uk0a1aO3hJ8/RHhZ7EZ2bSEQfyym66kU
# buGsksxzbgtCSZpk76XLfT+rSOIL5SY+WCIiVd+FrUPfLhFMSzxjwbVuRA5FLdcL
# 7+p9kuSggpUI+m2fzwropdX6GHpp5EfYdpWGZDdB9R+fbKiLC54gbzd2ubArEn1Q
# HOwe5K1qXqjYrelatIbNlA5NUS7BJmmcjlLtiGMfqw/fmSfGOvo1le1HFnRFj1QJ
# YX9rYku2iTtjGS6jiUAmP6Q2yiunn8nNVtgUYCorD5NsgbmVEqzccIIkKImW9IxW
# HOSFGu41ZswpSGKDABcdq+NcUVTwjg6QlvGi3rQtAVZKaXWzbbZSiR7hM0CDtcPw
# XPKdhbtdGkJmvCvBfX357q7+dmkB3XHYLteoxEfClzMRMJ9AKF0qSh6hf4PTg9Wb
# LwFNCClWQeM9CXtpi5EWD3wu5DlfIDpInNwUZDPOrVO0DGu9+msd72naMPXZTl+c
# vrv9MIIF2DCCBMCgAwIBAgIRAOQnBJX2jJHW0Ox7SU6k3xwwDQYJKoZIhvcNAQEL
# BQAwfjELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVz
# IFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEi
# MCAGA1UEAxMZQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQTAeFw0xODA5MTEwOTI2
# NDdaFw0yMzA5MTEwOTI2NDdaMHwxCzAJBgNVBAYTAlVTMQ4wDAYDVQQIDAVUZXhh
# czEQMA4GA1UEBwwHSG91c3RvbjEYMBYGA1UECgwPU1NMIENvcnBvcmF0aW9uMTEw
# LwYDVQQDDChTU0wuY29tIFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgUlNB
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA+Q/doyt9y9Aq/uxnhabn
# Lhu6d+Hj9a+k7PpKXZHEV0drGHdrdvL9k+Q9D8IWngtmw1aUnheDhc5W7/IW/QBi
# 9SIJVOhlF05BueBPRpeqG8i4bmJeabFf2yoCfvxsyvNB2O3Q6Pw/YUjtsAMUHRAO
# Sxngu07shmX/NvNeZwILnYZVYf16OO3+4hkAt2+hUGJ1dDyg+sglkrRueiLH+B6h
# 47LdkTGrKx0E/6VKBDfphaQzK/3i1lU0fBmkSmjHsqjTt8qhk4jrwZe8jPkd2SKE
# JHTHBD1qqSmTzOu4W+H+XyWqNFjIwSNUnRuYEcM4nH49hmylD0CGfAL0XAJPKMuu
# cZ8POsgz/hElNer8usVgPdl8GNWyqdN1eANyIso6wx/vLOUuqfqeLLZRRv2vA9bq
# YGjqhRY2a4XpHsCz3cQk3IAqgUFtlD7I4MmBQQCeXr9/xQiYohgsQkCz+W84J0tO
# gPQ9gUfgiHzqHM61dVxRLhwrfxpyKOcAtdF0xtfkn60Hk7ZTNTX8N+TD9l0WviFz
# 3pIK+KBjaryWkmo++LxlVZve9Q2JJgT8JRqmJWnLwm3KfOJZX5es6+8uyLzXG1k8
# K8zyGciTaydjGc/86Sb4ynGbf5P+NGeETpnr/LN4CTNwumamdu0bc+sapQ3EIhMg
# lFYKTixsTrH9z5wJuqIz7YcCAwEAAaOCAVEwggFNMBIGA1UdEwEB/wQIMAYBAf8C
# AQIwHQYDVR0OBBYEFN0ECQei9Xp9UlMSkpXuOIAlDaZZMB8GA1UdIwQYMBaAFAh2
# zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1UdDwEB/wQEAwIBBjA2BgNVHR8ELzAtMCug
# KaAnhiVodHRwOi8vc3NsY29tLmNybC5jZXJ0dW0ucGwvY3RuY2EuY3JsMHMGCCsG
# AQUFBwEBBGcwZTApBggrBgEFBQcwAYYdaHR0cDovL3NzbGNvbS5vY3NwLWNlcnR1
# bS5jb20wOAYIKwYBBQUHMAKGLGh0dHA6Ly9zc2xjb20ucmVwb3NpdG9yeS5jZXJ0
# dW0ucGwvY3RuY2EuY2VyMDoGA1UdIAQzMDEwLwYEVR0gADAnMCUGCCsGAQUFBwIB
# FhlodHRwczovL3d3dy5jZXJ0dW0ucGwvQ1BTMA0GCSqGSIb3DQEBCwUAA4IBAQAf
# lZojVO6FwvPUb7npBI9Gfyz3MsCnQ6wHAO3gqUUt/Rfh7QBAyK+YrPXAGa0boJcw
# QGzsW/ujk06MiWIbfPA6X6dCz1jKdWWcIky/dnuYk5wVgzOxDtxROId8lZwSaZQe
# AHh0ftzABne6cC2HLNdoneO6ha1J849ktBUGg5LGl6RAk4ut8WeUtLlaZ1Q8qBvZ
# Bc/kpPmIEgAGiCWF1F7u85NX1oH4LK739VFIq7ZiOnnb7C7yPxRWOsjZy6SiTyWo
# 0ZurLTAgUAcab/HxlB05g2PoH/1J0OgdRrJGgia9nJ3homhBSFFuevw1lvRU0rwr
# ROVH13eCpUqrX5czqyQRMIIG/DCCBOSgAwIBAgIQbVIYcIfoI02FYADQgI+TVjAN
# BgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzEOMAwGA1UECAwFVGV4YXMxEDAO
# BgNVBAcMB0hvdXN0b24xGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlvbjExMC8GA1UE
# AwwoU1NMLmNvbSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IFJTQTAeFw0x
# OTExMTMxODUwMDVaFw0zNDExMTIxODUwMDVaMHMxCzAJBgNVBAYTAlVTMQ4wDAYD
# VQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3RvbjERMA8GA1UECgwIU1NMIENvcnAx
# LzAtBgNVBAMMJlNTTC5jb20gVGltZXN0YW1waW5nIElzc3VpbmcgUlNBIENBIFIx
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEArlEQE9L5PCCgIIXeyVAc
# ZMnh/cXpNP8KfzFI6HJaxV6oYf3xh/dRXPu35tDBwhOwPsJjoqgY/Tg6yQGBqt65
# t94wpx0rAgTVgEGMqGri6vCI6rEtSZVy9vagzTDHcGfFDc0Eu71mTAyeNCUhjaYT
# BkyANqp9m6IRrYEXOKdd/eREsqVDmhryd7dBTS9wbipm+mHLTHEFBdrKqKDM3fPY
# dBOro3bwQ6OmcDZ1qMY+2Jn1o0l4N9wORrmPcpuEGTOThFYKPHm8/wfoMocgizTY
# YeDG/+MbwkwjFZjWKwb4hoHT2WK8pvGW/OE0Apkrl9CZSy2ulitWjuqpcCEm2/W1
# RofOunpCm5Qv10T9tIALtQo73GHIlIDU6xhYPH/ACYEDzgnNfwgnWiUmMISaUnYX
# ijp0IBEoDZmGT4RTguiCmjAFF5OVNbY03BQoBb7wK17SuGswFlDjtWN33ZXSAS+i
# 45My1AmCTZBV6obAVXDzLgdJ1A1ryyXz4prLYyfJReEuhAsVp5VouzhJVcE57dRr
# UanmPcnb7xi57VPhXnCuw26hw1Hd+ulK3jJEgbc3rwHPWqqGT541TI7xaldaWDo8
# 5k4lR2bQHPNGwHxXuSy3yczyOg57TcqqG6cE3r0KR6jwzfaqjTvN695GsPAPY/h2
# YksNgF+XBnUD9JBtL4c34AcCAwEAAaOCAYEwggF9MBIGA1UdEwEB/wQIMAYBAf8C
# AQAwHwYDVR0jBBgwFoAU3QQJB6L1en1SUxKSle44gCUNplkwgYMGCCsGAQUFBwEB
# BHcwdTBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5zc2wuY29tL3JlcG9zaXRvcnkv
# U1NMY29tUm9vdENlcnRpZmljYXRpb25BdXRob3JpdHlSU0EuY3J0MCAGCCsGAQUF
# BzABhhRodHRwOi8vb2NzcHMuc3NsLmNvbTA/BgNVHSAEODA2MDQGBFUdIAAwLDAq
# BggrBgEFBQcCARYeaHR0cHM6Ly93d3cuc3NsLmNvbS9yZXBvc2l0b3J5MBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMDsGA1UdHwQ0MDIwMKAuoCyGKmh0dHA6Ly9jcmxzLnNz
# bC5jb20vc3NsLmNvbS1yc2EtUm9vdENBLmNybDAdBgNVHQ4EFgQUDJ0QJY6apxuZ
# h0PPCH7hvYGQ9M8wDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEBCwUAA4ICAQCS
# GXUNplpCzxkH2fL8lPrAm/AV6USWWi9xM91Q5RN7mZN3D8T7cm1Xy7qmnItFukgd
# tiUzLbQokDJyFTrF1pyLgGw/2hU3FJEywSN8crPsBGo812lyWFgAg0uOwUYw7WJQ
# 1teICycX/Fug0KB94xwxhsvJBiRTpQyhu/2Kyu1Bnx7QQBA1XupcmfhbQrK5O3Q/
# yIi//kN0OkhQEiS0NlyPPYoRboHWC++wogzV6yNjBbKUBrMFxABqR7mkA0x1Kfy3
# Ud08qyLC5Z86C7JFBrMBfyhfPpKVlIiiTQuKz1rTa8ZW12ERoHRHcfEjI1EwwpZX
# XK5J5RcW6h7FZq/cZE9kLRZhvnRKtb+X7CCtLx2h61ozDJmifYvuKhiUg9LLWH0O
# r9D3XU+xKRsRnfOuwHWuhWch8G7kEmnTG9CtD9Dgtq+68KgVHtAWjKk2ui1s1iLY
# AYxnDm13jMZm0KpRM9mLQHBK5Gb4dFgAQwxOFPBslf99hXWgLyYE33vTIi9p0gYq
# GHv4OZh1ElgGsvyKdUUJkAr5hfbDX6pYScJI8v9VNYm1JEyFAV9x4MpskL6kE2Sy
# 8rOqS9rQnVnIyPWLi8N9K4GZvPit/Oy+8nFL6q5kN2SZbox5d69YYFe+rN1sDD4C
# pNWwBBTI/q0V4pkgvhL99IV2XasjHZf4peSrHdL4RjGCAlkwggJVAgEBMIGHMHMx
# CzAJBgNVBAYTAlVTMQ4wDAYDVQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3RvbjER
# MA8GA1UECgwIU1NMIENvcnAxLzAtBgNVBAMMJlNTTC5jb20gVGltZXN0YW1waW5n
# IElzc3VpbmcgUlNBIENBIFIxAhAa1gin1jS1zd6Xy6PM8NBLMAsGCWCGSAFlAwQC
# AaCCAWEwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEP
# Fw0yMzA1MDgyMDU4MzhaMCgGCSqGSIb3DQEJNDEbMBkwCwYJYIZIAWUDBAIBoQoG
# CCqGSM49BAMCMC8GCSqGSIb3DQEJBDEiBCD8ZRnolim/7PaaQ0oIAPdNKtAxjf0p
# Gqd5U6eMhSdDazCByQYLKoZIhvcNAQkQAi8xgbkwgbYwgbMwgbAEII3FxCVC0k8V
# z/XIGW7UWoNo1MrWvcvkIaneI1Cdi9MiMIGLMHekdTBzMQswCQYDVQQGEwJVUzEO
# MAwGA1UECAwFVGV4YXMxEDAOBgNVBAcMB0hvdXN0b24xETAPBgNVBAoMCFNTTCBD
# b3JwMS8wLQYDVQQDDCZTU0wuY29tIFRpbWVzdGFtcGluZyBJc3N1aW5nIFJTQSBD
# QSBSMQIQGtYIp9Y0tc3el8ujzPDQSzAKBggqhkjOPQQDAgRIMEYCIQDJG1eFnj60
# i5lnk/OamvEzj9X1AdeVHzPAyj450fXweAIhAJbtzSfDov6o68kP66Bk996cxLXA
# ezrRJNQ1CjRyrO26
# SIG # End signature block
