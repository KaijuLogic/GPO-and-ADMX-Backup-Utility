# ADMX & GPO Backup
This is a script to support simple backups of ADMX and GPO files.

# DESCRIPTION
It's a good idea to periodically backup ADMX files and/or Group Policy configurations. Especially before updating your DC or importing new ADMX files. 
This script makes that a little simpler and can be used to automate the process via a scheduled task if so desired. 

## FEATURES
- By default this script will automatically fill in the domain name for the system you run it on so it can find sysvol\domain.name and backup ADMX files from there.
- Supports -whatif for testing
- Functions with "Get-Help"

## PRE-REQUISITS
Not much, this either needs to be run on a server with Active Directory/Group Policy installed, or a system with RSAT tools. 
RSAT: https://www.microsoft.com/en-us/download/details.aspx?id=45520 

Note that the script assumes this is being run on a system hosting ADMX files in sysvol

### EXAMPLE
```PowerShell
ADMXandGPO-Backup.ps1 -BackupPath "C:\DomainBackups" -GPO
```
This command would backup Group Policy Objects to a folder created under C:\DomainBackups\  Based on the current date ex: C:\DomainBackups\GPOBackup-2024-02-25\
A simple txt file will also be created called GPOBackupReport-2024-02-25.txt that contains a list of the GPOs backed up along with their GPO ID for reference

### EXAMPLE
```PowerShell
ADMXandGPO-Backup.ps1 -BackupPath "C:\DomainBackups" -ADMX
```
This command would only backup ADMX files to two different folders created under C:\DomainBackups\ based on the current date and what ADMX location it came from.
EX: C:\DomainBackups\ADMX-2024-02-25\Local-ADMXBackup  &  C:\DomainBackups\ADMX-2024-02-25\SYSVOL-ADMXBackup

### EXAMPLE
```PowerShell
ADMXandGPO-Backup.ps1 -BackupPath "C:\DomainBackups" -GPO -ADMX
```
This command would backup both Group Policy Objects and ADMX files to C:\DomainBackups\ 
EX: C:\DomainBackups\GPOBackup-2024-02-25\ , C:\DomainBackups\ADMX-2024-02-25\Local-ADMXBackup  and  C:\DomainBackups\ADMX-2024-02-25\SYSVOL-ADMXBackup
