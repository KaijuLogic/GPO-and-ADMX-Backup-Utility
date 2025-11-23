<#
	.SYNOPSIS
	Simple script to backup Group Policy and ADMX files.

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
    Last Modified Date: 16 Nov 2025
    Last Modified By: KaijuLogic
    Last Modification Notes: 
		24.11.2025
				Updating folder creation function
				Updating write-log function to reduce repetative lines
				Added a couple of try-catches
				Enabled -whatif capability
				Added timer for fun and seeing how long the script takes

		16.11.2025
				lots of small fixes.
				Removing function that is never used. 
				Simplifying parameter checks
				Explicitly importing required modules
				Explicitly require run as admin
				Removing some variables that were just duplicates or were only used once or twice
		3.23.2024 
				Added Logging, Examples, additional notes and Descriptions. Functionalized commands 

	.TODO
		Find a better way to do ADMX backup
		Done: Add logging
		More detailed feedback
		Add verification that all ADMX files were backed up

	.DISCLAIMER:
	By using this content you agree to the following: This script may be used for legal purposes only. Users take full responsibility 
	for any actions performed using this script. The author accepts no liability for any damage caused by this script.  


#>
#Requires -RunAsAdministrator
#################################### Parameters ###################################
[CmdletBinding(SupportsShouldProcess)]
param (
	[Parameter(Mandatory = $true)]
	[ValidateScript({
        if (Test-Path $_ -PathType Container) {
            return $True
        } else {
            Throw "$_ not found, please verify your path is correct."
        }
    })]
	[String]$BackupPath,

	[Parameter()]
	[Switch]$ADMX,

	[Parameter()]
	[Switch]$GPO
)
################################## Import Modules #################################
try{
	Import-Module ActiveDirectory
	Import-Module GroupPolicy
}
catch{
	Throw "Failed to import required modules, please make sure Group Policy tools are installed on this system."
}

################################# SET COMMON VARIABLES ################################
$CurrentDate = Get-Date
$DomainInfo = Get-ADDomain
$DomainName = $DomainInfo.DNSRoot

#Below variables used for creating logging
$CurrentPath = split-path -Parent $PSCommandPath
$LogFolder = Join-Path -Path $CurrentPath -ChildPath "\ADMX-GPO-BU-Logs\$($CurrentDate.ToString("yyyy-MM"))"
$Logfile = Join-Path -path  $LogFolder -ChildPath "$Env:ComputerName-$($CurrentDate.ToString("yyyy-MM-dd_HH.mm")).txt"

#Backup paths naming
$gpoBackupPath = Join-Path -path $BackupPath -ChildPath "GPOBackup-$($CurrentDate.ToString("yyyy-MM-dd_HHmm"))\"
$admxBackupPath = Join-Path -path $BackupPath -ChildPath "ADMX-$($CurrentDate.ToString("yyyy-MM-dd_HHmm"))\"

#Used to trasck how long the script took to process
$sw = [Diagnostics.Stopwatch]::StartNew()

#################################### FUNCTIONS #######################################
Function Write-Log{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info","WARN","ERROR","FATAL","DEBUG")]
        [string]$level = "INFO",

        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$true)]
        [string]$logfile
    )

    $Stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $Line = "$Stamp | $Level | $Message"
    
    #To make our cli output look ~pretty~
    $ColorDitcionary = @{"INFO" = "Cyan"; "WARN" = "Yellow"; "ERROR" = "Red"}
    Write-Host $Line -ForegroundColor $ColorDitcionary[$Level]

    Add-content $logfile -Value $Line -Force
}

Function Set-NewFolders {
    param(
        [Parameter(Mandatory=$true)]
        [string[]] $FolderPaths
    )
    ##Tests for and creates necessary folders and files for the script to run and log appropriatel
	foreach ($Path in $FolderPaths){
	    if (!(Test-Path $Path)){
	        Write-Verbose "$Path does not exist, creating path"
	        Try{
	            New-Item -Path $Path -ItemType "directory" | out-null
	        }
	        Catch{
	            Throw "Error creating path: $Path. Error provided: $($_.ErrorDetails.Message)"
	        }
        }
	}
}

function Backup-ADMX {
	#Backup ADMX files from DC store
	Write-Log -level INFO -message "Backing up ADMX files from: C:\Windows\SYSVOL\sysvol\$DomainName\Policies\PolicyDefinitions" -logfile $logfile
	Try{
		robocopy /E /R:2 /W:10 /V /NDL /NFL  "C:\Windows\SYSVOL\sysvol\$DomainName\Policies\PolicyDefinitions"* "$admxBackupPath\SYSVOL-ADMXBackup" | Out-Null
	}
	Catch{
		Write-Log -level ERROR -message "Ran into an issue backing up sysvol ADMX files. ERROR: $($_.ErrorDetails.Message)" -logfile $logfile
	}
	
	#Backup ADMX files from local 
	Write-Log -level INFO -message "Backing up ADMX files from: C:\Windows\PolicyDefinitions" -logfile $logfile
	try{
		robocopy /E /R:2 /W:10 /V /NDL /NFL  "C:\Windows\PolicyDefinitions"* "$admxBackupPath\Local-ADMXBackup" | Out-Null
	}
	Catch{
		Write-Log -level ERROR -message "Ran into an issue backing up local ADMX files. ERROR: $($_.ErrorDetails.Message)" -logfile $logfile
	}
	
	Write-Log -level INFO -message "ADMX Backup completed" -logfile $logfile
}

#################################### EXECUTION #####################################
Set-NewFolders -FolderPaths $LogFolder

Write-Log -level INFO -message "GPO/ADMX BACKUP SCRIPT, RUN BY $Env:UserName ON $Env:ComputerName" -logfile $logfile
If ($ADMX) {
	Write-Log -level INFO -message "ADMX Backup was enabled" -logfile $logfile
	Set-NewFolders -FolderPaths $admxBackupPath
	Backup-ADMX
}
If ($GPO) {
	Write-Log -level INFO -message "GPO Backup was enabled" -logfile $logfile
	Set-NewFolders -FolderPaths $gpoBackupPath
	Write-Log -level INFO -message "Backing up Group Policy Objects" -logfile $logfile
	Backup-gpo -path $gpoBackupPath -ALL | Out-Null
	Write-Log -level INFO -message "GPO Backup completed. Sent to $gpoBackupPath" -logfile $logfile
}
else{
	Throw "No options chosen please use -ADMX and/or -GPO"
}

$sw.stop()

Write-Log -level INFO -message  "ADMX and GPO backup script ran for: $($sw.elapsed)" -logfile $logfile
