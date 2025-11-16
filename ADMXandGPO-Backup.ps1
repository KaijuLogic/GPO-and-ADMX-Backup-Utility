<#
	.DISCLAIMER:
	By using this content you agree to the following: This script may be used for legal purposes only. Users take full responsibility 
	for any actions performed using this script. The author accepts no liability for any damage caused by this script.  

	.DESCRIPTION
	It's a good idea to periodically backup ADMX files and/or Group Policy configurations. Especially before updating your DC or importing new ADMX files. 
	This script makes that a little simpler and can be used to automate the process via a scheduled task if so desired. THis script automatically grabs the domain name of the Domain Controller you run it on

	.PARAMETER BackupPath 
	Provide the path where you would like this backup to be sent. 
    
	.PARAMETER ADMX
	Enables backing up both the local PolicyDefinitions folder and the SysVol PolicyDefinitions folder. 

	.PARAMETER GPO
	Enables backing up all GroupPolicy Objects on the DC it is run on. Utilizes built-in Windows functions. 

	.EXAMPLE
	ADMXandGPO-Backup.ps1 -BackupPath "C:\DomainBackups" -GPO
	This command would backup Group Policy Objects to a folder created under C:\DomainBackups\  Based on the current date ex: C:\DomainBackups\GPOBackup-2024-02-25\
	A simple txt file will also be created called GPOBackupReport-2024-02-25.txt that contains a list of the GPOs backed up along with their GPO ID for reference

	.EXAMPLE
	ADMXandGPO-Backup.ps1 -BackupPath "C:\DomainBackups" -ADMX
	This command would only backup ADMX files to two different folders created under C:\DomainBackups\ based on the current date and what ADMX location it came from.
	EX: C:\DomainBackups\ADMX-2024-02-25\Local-ADMXBackup    and	  C:\DomainBackups\ADMX-2024-02-25\SYSVOL-ADMXBackup

	.EXAMPLE
	ADMXandGPO-Backup.ps1 -BackupPath "C:\DomainBackups" -GPO -ADMX
	This command would backup both Group Policy Objects and ADMX files to C:\DomainBackups\ 
	EX: C:\DomainBackups\GPOBackup-2024-02-25\ , C:\DomainBackups\ADMX-2024-02-25\Local-ADMXBackup  and  C:\DomainBackups\ADMX-2024-02-25\SYSVOL-ADMXBackup

	.NOTES
    Created by: KaijuLogic
    Created Date: 1.2024
    Last Modified Date: 15 Nov 2025
    Last Modified By: KaijuLogic
    Last Modification Notes: 
		* 16 Nov, 2025 - lots of small fixes.
			* Removing function that is never used. 
			* Simplifying parameter checks
			* Explicitly importing required modules
			* Explicitly require run as admin
			* Removing some variables that were just duplicates or were only used once or twice

		* 3.23.2024 - Added Logging, Examples, additional notes and Descriptions. Functionalized commands 

	.TODO
		Find a better way to do ADMX backup
		Done: Add logging
		More detailed feedback
		Add verification that all ADMX files were backed up

#>
#Requires -RunAsAdministrator
#################################### Parameters ###################################
[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)][String]$BackupPath,
	[Parameter()][Switch]$ADMX,
	[Parameter()][Switch]$GPO
)
################################## Import Modules #################################
try{
	Import-Module ActiveDirectory
	Import-Module GroupPolicy
}
catch{
	Write-Output "Failed to import required modules, are you sure AD and Group Policy tools are installed on this system?"
}

################################# SET COMMON VARIABLES ################################
$ErrorActionPreference = "Stop"
$CurrentDate = Get-Date
$DomainInfo = Get-ADDomain
$DomainName = $DomainInfo.DNSRoot
#Below variables used for creating logging
$CurrentPath = split-path -Parent $PSCommandPath
$Logfile = Join-Path -path  $CurrentPath -ChildPath "\Logs\$($CurrentDate.ToString("yyyy-MM"))\$Env:ComputerName-$($CurrentDate.ToString("yyyy-MM-dd_HH.mm")).txt"
#Used to track how long it takes updates to install
$sw = [Diagnostics.Stopwatch]::StartNew()

#################################### FUNCTIONS #######################################
Function Write-Log{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info","WARN","ERROR","FATAL","DEBUG")]
        [string]
        $level = "INFO",

        [Parameter(Mandatory=$true)]
        [string]
        $Message,

        [Parameter(Mandatory=$true)]
        [string]
        $logfile
    )
    $Stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $Line = "$Stamp | $Level | $Message"
    Add-content $logfile -Value $Line
}

Function Set-LogFolders {
	$LogFolder = Split-Path $logfile -Parent
	if (!(Test-Path $LogFolder)) {
		New-Item -Path $LogFolder -ItemType "directory" | out-null
		if (Test-Path $LogFolder) {
			Write-Output "$LogFolder created successfully"
		}
		else {
			Write-Output "Error creating path: $LogPath maybe try manual creation?"
		}
	}
}

function Backup-ADMX {
	$admxBackupPath = "$BackupPath\ADMX-$($CurrentDate.ToString("yyyy-MM-dd_HHmm"))"
	if (!(Test-Path $admxBackupPath)) {
		Write-Log -level INFO -message "Backup path folder $admxBackupPath doesn't exist, creating now" -logfile $logfile
		New-Item -Path $admxBackupPath -ItemType "directory" | out-null
	}
	#Backup ADMX files from DC store
	$Message = "Backing up ADMX files from: C:\Windows\SYSVOL\sysvol\$DomainName\Policies\PolicyDefinitions"
	Write-Output $Message
	Write-Log -level INFO -message $Message -logfile $logfile
	robocopy /E /R:2 /W:10 /V /NDL /NFL  "C:\Windows\SYSVOL\sysvol\$DomainName\Policies\PolicyDefinitions"* "$admxBackupPath\SYSVOL-ADMXBackup" | Out-Null
	
	#Backup ADMX files from local 
	$Message = "Backing up ADMX files from: C:\Windows\PolicyDefinitions"
	Write-Output $Message
	Write-Log -level INFO -message $Message -logfile $logfile
	robocopy /E /R:2 /W:10 /V /NDL /NFL  "C:\Windows\PolicyDefinitions"* "$admxBackupPath\Local-ADMXBackup" | Out-Null
	
	Write-Output "ADMX Backup completed"
	Write-Log -level INFO -message "ADMX Backup completed" -logfile $logfile
}

#################################### EXECUTION #####################################
Set-LogFolders

Write-Log -level INFO -message "GPO/ADMX BACKUP SCRIPT, RUN BY $Env:UserName ON $Env:ComputerName" -logfile $logfile
If (!$ADMX -and !$GPO){
	$Message = "No options chosen please use -ADMX and/or -GPO"
	Write-Warning $Message
	Write-Log -level WARN -message $Message -logfile $logfile
	Exit
}
If ($ADMX) {
	$Message = "ADMX Backup was enabled"
	Write-Verbose $Message
	Write-Log -level INFO -message $Message -logfile $logfile
	Backup-ADMX
}
If ($GPO) {
	$gpoBackupPath = "$BackupPath\GPOBackup-$($CurrentDate.ToString("yyyy-MM-dd_HHmm"))\"
	$Message = "GPO Backup was enabled"
	Write-Verbose $Message 
	Write-Log -level INFO -message $Message -logfile $logfile

	if (!(Test-Path $gpoBackupPath)) {
		Write-Verbose "Backup path folder $gpoBackupPath doesn't exist, creating now"
		Write-Log -level INFO -message "Backup path folder $gpoBackupPath doesn't exist, creating now" -logfile $logfile
		New-Item -Path $gpoBackupPath -ItemType "directory" | out-null
	}
	Write-Output "Backing up Group Policy Objects..."
	Write-Log -level INFO -message "Backing up Group Policy Objects" -logfile $logfile
	Backup-gpo -path $gpoBackupPath -ALL
	Write-Output "GPO Backup completed"
	Write-Log -level INFO -message "GPO Backup completed. Sent to $gpoBackupPath" -logfile $logfile
}

$sw.stop()
$Message = "ADMX and GPO backup script ran for: $($sw.elapsed)"
Write-Output $Message 
Write-Log -level INFO -message $Message -logfile $logfile
