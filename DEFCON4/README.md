# DEFCON4
DEFCON4 contains guidance for Increased Security Measures. This guidance is intended to setup foundational logging principals which will be built upon in DEFCON3

## Resources

### Scripts and Configuration Files

| Resource                    | Description                                  |
|-----------------------------|----------------------------------------------|
| DC-Configurator.ps1         | PowerShell script to import WEF GPO w/ DC Audit GPOs |
| DC-Configurator-NoAudit.ps1 | PowerShell script to import Sysmon Deployment GPO w/o DC Audit GPOs |
| WEC-Configurator.ps1        | PowerShell script to configure WEC services  |
| winlogbeat.yml              | WinlogBeat configuration file                |


### Group Policy Objects

| Resource                     | Description                              |
|------------------------------|------------------------------------------|
| SOC-DC-Enhanced-Auditing     | Configure Enhanced Domain Controller Auditing |
| SOC-Windows Event Forwarding | Configure Windows Event Forwarding       |


### WEF Subscriptions

| Resource                          | Windows EventID                                      |
|-----------------------------------|------------------------------------------------------|
| Account-Lockout.xml               | 4740                                                 |
| Account-Management.xml            | 4627, 4703-4705, 4720, 4722-4735, 4737-4739, 4741-4767, 4780, 4782, 4793, 4794, 4798, 4799, 5376, 5377 |
| Active-Directory.xml              | 4662, 4706,4707, 4713, 4716-4718, 4739, 4864-4867, 5136, 5137, 5139, 5141, 5178 |
| ADFS.xml                          |                                                      |
| Application-Crashes.xml           | 1000, 1001, 1002                                     |
| Applocker.xml                     |                                                      |
| Authentication.xml                | 4624-4626, 4634, 4647, 4649, 4672, 4675, 4774-4779, 4800-4803, 4964, 5378 |
| Autoruns.xml                      |                                                      |
| Bits-Client.xml                   |                                                      |
| Certificate-Authority.xml         | 4886-4888                                            |
| Code-Integrity.xml                | 3001-3004, 3010, 3023, 5038, 6281, 6410              |
| Device-Guard.xml                  |                                                      |
| DNS.xml                           | 150, 541, 770, 3008                                  |
| Drivers.xml                       | 219, 2004                                            |
| Duo-Security.xml                  |                                                      |
| EMET.xml                          | 0, 1, 2                                              |
| Event-Log-Diagnostics.xml         | 1100, 1104, 1105, 1108                               |
| Explicit-Credentials.xml          | 4648                                                 |
| Exploit-Guard-ASR.xml             | 1121, 1122, 5007                                     |
| Exploit-Guard-CFA.xml             | 1123, 1124, 5007                                     |
| Exploit-Guard-EP.xml              | 260                                                  |
| Exploit-Guard-NP.xml              | 1125, 1126, 5007                                     |
| External-Devices.xml              | 43, 400, 410, 6416, 6419-6424                        |
| Firewall.xml                      | 4944-4954, 4956-4958, 5024, 5025, 5037, 5027-5030, 5032-5035 |
| Group-Policy-Errors.xml           | 1085, 1125, 1127, 1129, 6144, 6145                   |
| Kerberos.xml                      | 4768-4773                                            |
| Log-Deletion-Security.xml         | 1102                                                 |
| Log-Deletion-System.xml           | 104                                                  |
| Microsoft-Office.xml              |                                                      |
| MSI-Packages.xml                  | 2, 800, 903-908, 1022, 1033                          |
| NTLM.xml                          |                                                      |
| Object-Manipulation.xml           | 4656, 4658, 4660, 4663, 4670, 4715, 4817             |
| Operating-System.xml              | 12, 13, 41, 1001, 1074, 3000, 4608, 4610, 4611, 4614, 4621, 4622, 4697, 4719, 4817, 4826, 4902, 4904-4906, 4908, 4912, 6008, 16962, 16965, 16968, 16969 |
| Powershell.xml                    |                                                      |
| Print.xml                         | 307                                                  |
| Privilege-Use.xml                 | 4673, 4674,4985                                      |
| Process-Execution.xml             | 4688, 4689                                           |
| Registry.xml                      | 4657                                                 |
| Services.xml                      | 7022-7024, 7026, 7031, 7032, 7034, 7040, 7045        |
| Shares.xml                        | 5140, 5142, 5144, 5145, 5168, 30622, 30624           |
| Smart-Card.xml                    |                                                      |
| Software-Restriction-Policies.xml | 865-868, 882                                         |
| Sysmon.xml                        |                                                      |
| System-Time-Change.xml            | 4616                                                 |
| Task-Scheduler.xml                | 106, 129, 141, 142, 200, 201, 4698-4702              |
| Terminal-Services.xml             |                                                      |
| Windows-Defender.xml              | 1006-1009, 1116-1119                                 |
| Windows-Diagnostics.xml           |                                                      |
| Windows-Updates.xml               | 19, 20, 24, 25, 31, 34, 35, 1009                     |
| Wireless.xml                      | 5632, 5633                                           |
| WMI.xml                           |                                                      |

