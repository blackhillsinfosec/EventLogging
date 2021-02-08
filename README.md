![BHIS](https://www.blackhillsinfosec.com/wp-content/uploads/2018/12/BHIS-logo-L-1024x1024-400x400.png)

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

## Community Contributions
* palantir windows-event-forwarding | [GitHub](https://github.com/palantir/windows-event-forwarding)
* olafhartong sysmon-modular | [GitHub](https://github.com/olafhartong/sysmon-modular)

--- 

## License
GNUv3 - [License][1]

  [1]: LICENSE
