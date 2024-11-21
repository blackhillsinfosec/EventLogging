# Notice
This repo is no longer maintined as of April 2024

![BHIS](https://www.blackhillsinfosec.com/wp-content/uploads/2018/12/BHIS-logo-L-1024x1024-400x400.png)

# Notice
This repo is no longer maintined as of April 2024

# EventLogging
This repo contains guidance on setting up event logging. This guidance is broken up into sections, Defensive Readiness Condition (DEFCON), and intended to be applied from 5 (lowest) to 1 (highest).


| Readiness State       | Description                     | Readiness Condition Features                     |
|-----------------------|---------------------------------|--------------------------------------------------|
| DEFCON 1              | Breach imminent or occurred     | Forensic imaging; Blocking techinques/tools (Server, Workstation, and Network)     |
| DEFCON 2              | Enhanced Measures               | Event Forwarding (Workstation); Threat Hunting     |
| DEFCON 3              | Heightened Measures             | Event Forwarding (Member Servers/apps); Network Device logging; Sysmon/EDR     | 
| DEFCON 4              | Increased Security Measures     | Audit policies; Event Forwarding (Domain Controllers); Network Monitoring; Centralized logs     |
| DEFCON 5              | Default Configurations          | Vanilla OS/App/Device logging; No centralized logs     |


Initial work on this project will be focused on Windows.

<!-- Start Document Outline -->

* [Assumptions](#Assumptions)
	* [Active Directory](#active-directory)
	* [PowerShell](#powershell)
	* [Windows Event Collector](#windows-event-collector)
* [Deployment](#Deployment)
* [Community Contributions](#community-contributions)

* [License](#license)

<!-- End Document Outline -->
 
--- 
 
## Assumptions:
### Active Directory
* Microsoft Active Directory is being used

### PowerShell
* PowerShell 5 is being used

### Windows Event Collector
* A Windows Server running Windows Event Collector (WEC) services can be reached by all logged Windows endpoints.
--- 

## Deployment:
The scripts are designed to be run DEFCON 4 first followed by DEFCON 3 and then DEFCON 2. Each DEFCON has a script for making changes on a DC these scripts add extra functionality and increase visibility in your deployment. You should review these scripts carefully before running them as some of the changes are difficult to revert once made. DEFCON 3 also contains a script for installing Sysmon for Windows. This script should be run from the DC as it will import a GPO used for deployment.

Before deployment, you will need to determine how many WECs you will require and their FQDN Hostname. These hosts should be configured as base Windows Server machines with all of the current updates Windows Server 2016 or higher is recommended. You will then convert the server into a WEC via the WEC-Configurator.ps1 script found in DEFCON4.

Change the following files before running the scripts.
* [/DEFCON4/sites.csv](https://github.com/blackhillsinfosec/EventLogging/blob/master/DEFCON4/sites.csv) - Populate site prefix and WEC FQDN.
* [/DEFCON4/winlogbeat.yml](https://github.com/blackhillsinfosec/EventLogging/blob/master/DEFCON4/winlogbeat.yml) - Only required if you plan to ship to an ELK stack. Replace the tags \<LogstashIP>, \<LogstashPort>, and \<CompanyInit>

Once the files have been edited you can run the scripts on the respective host. The DC scripts will import GPOs. These GPOs must still be linked to the correct OU for the system to work. Suggested GPO links are below.

* [SOC-$(SiteName)-Windows-Event-Forwarding](https://github.com/blackhillsinfosec/EventLogging/tree/master/DEFCON4/Group-Policy-Objects/SOC-Windows-Event-Forwarding) : Link to OU for each site hosts in that OU will ship to respective WEC defined in /DEFCON4/sites.csv. This will be replicated for each row in the CSV.
* [SOC-DC-Enhanced-Auditing](https://github.com/blackhillsinfosec/EventLogging/tree/master/DEFCON4/Group-Policy-Objects/SOC-DC-Enhanced-Auditing) : Link to OU Containing DC’s
* [SOC-WS-Enhanced-Auditing](https://github.com/blackhillsinfosec/EventLogging/tree/master/DEFCON3/Group-Policy-Objects/SOC-WS-Enhanced-Auditing) : Link to the highest level with workstations
* [SOC-Sysmon-Deployment](https://github.com/blackhillsinfosec/EventLogging/tree/master/DEFCON3/Group-Policy-Objects/SOC-Sysmon-Deployment) : Link to the entire domain
* [SOC-CMD-PS-Logging](https://github.com/blackhillsinfosec/EventLogging/tree/master/DEFCON2/Group-Policy-Objects/SOC-CMD-PS-Logging) : Link to the entire domain
* [SOC-Enable-WinRM](https://github.com/blackhillsinfosec/EventLogging/tree/master/DEFCON3/Group-Policy-Objects/SOC-Enable-WinRM) : Link to the entire domain

---

## Video Webcast
* BHIS Webcasts | [Youtube](https://www.youtube.com/watch?v=Eix5BPta56E&t=2s)

--- 

## Community Contributions
* palantir windows-event-forwarding | [GitHub](https://github.com/palantir/windows-event-forwarding)
* olafhartong sysmon-modular | [GitHub](https://github.com/olafhartong/sysmon-modular)

--- 

## License
GNUv3 - [License][1]

  [1]: LICENSE

# Notice
This repo is no longer maintined as of April 2024