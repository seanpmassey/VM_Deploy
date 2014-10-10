<#
	.SYNOPSIS
		A function to create SQL Server instance volumes

	.DESCRIPTION
		This script will create two disks on a SQL Server for the SQL instance data and log volumes.  These volumes will be configured as mount points and mounted under the Data/Log Volume in a folder named after the instance.  This script is intended to be run on servers that were configured using the Configure-BaseSQLServer.PS1 script.  This script requires Server 2012 R2 or newer.

	.PARAMETER  InstanceName
		The name of the SQL Server instance that is being installed.  If this will be the default instance, use Default or MSSQLServer as the Instance Name.

	.PARAMETER  Servername
		The name of the server that is being prepared.

	.PARAMETER  vCenter
		The name of the vCenter server that manages the VM.

	.PARAMETER CredentialPath
		Path to the network share where the encrypted passwords are stored.
	
	.PARAMETER  DBOwner
		Optional. The user or group that will owns the SQL Server.  They will be added to the local administrators group.

	.PARAMETER  DataDriveLetter
		This is the drive letter that SQL Server data volumes will be mounted under.  Defaults to R.
		
	.PARAMETER  LogDriveLetter
		This is the drive letter that SQL Server log volumes will be mounted under.  Defaults to T.

	.PARAMETER  DataVolumeSize
		The size, in GBs, of the TEMPDB data volume.  Defaults to 10.

	.PARAMETER  LogVolumeSize
		The size, in GBs, of the TEMPDB log volume.  Defaults to 5.
	
	.EXAMPLE
		PS C:\> Create-SQLInstanceDisks.ps1 -Servername ServerVM1 -InstanceName Test -vcenter vCenter1

#>


Param($InstanceName,$DataDriveLetter = "R",$LogDriveLetter = "T", $DataVolumeSize = "20", $LogVolumeSize = "10",$Servername,$vCenter,$CredentialPath="\\PathTo\Credentials")

Function Create-VMDK
{
	#Create VMDK File on Server and Return VMDK File Name
	Param ($Servername,$VolumeSize,$Controller)
	
    $disk = New-HardDisk -VM $servername -Persistence persistent -CapacityGB $VolumeSize -StorageFormat Thin -Confirm:$false -Controller $Controller

	$Filename = $disk.filename
	$pos = $Filename.IndexOf("/")
	$Filename = $Filename.Substring($pos+1)
	
	#$pos = $Filename.IndexOf(".")
	#$Filename = $Filename.Substring(0,$pos)
    
    #Write-Output $Filename
	
	Return $Filename
}

Function Create-MountPoint
{
	#Initialize volume, create partition, mount as NTFS Mount Point, and format as NTFS Volume
	Param($Servername,$VolumeName,$VolumeSize,$Path,$CimSession)
		$VolumeSizeGB = [string]$VolumeSize + "GB"
	
	$partition = Get-Disk -CIMSession $CimSession | Where-Object {($_.partitionstyle -eq "raw") -and ($_.size -eq $VolumeSizeGB)} | Initialize-Disk -PartitionStyle GPT -PassThru |  New-Partition -UseMaximumSize -AssignDriveLetter:$False 
	
	$disknumber = $partition.DiskNumber
	$partitionnumber = $partition.partitionnumber
	$diskID = $partition.diskID

	Get-Partition -DiskNumber $disknumber -PartitionNumber $partitionnumber -CimSession $CimSession | Format-Volume -AllocationUnitSize 64KB -FileSystem NTFS -NewFileSystemLabel $VolumeName -Confirm:$false 
	Add-PartitionAccessPath -CimSession $CimSession -DiskNumber $disknumber -PartitionNumber $partitionnumber -AssignDriveLetter:$False
	Add-PartitionAccessPath -CimSession $CimSession -DiskNumber $disknumber -PartitionNumber $partitionnumber -AccessPath $Path 
	Set-Partition -CimSession $CimSession -DiskNumber $disknumber -PartitionNumber $partitionnumber -NoDefaultDriveLetter:$true
}

add-pssnapin vmware.vimautomation.core
Import-Module ActiveDirectory

#Configure AD Credentials
#Change ADUser to match your environment
$ADUser = "ADServiceAccount@fqdn"
$PWHash = Get-Content $CredentialPath\$ADUser.txt
$key = Get-Content $CredentialPath\$ADUser.key
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$ADCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $ADUser,$securestring

#Configure vCenter Connection
#Change vCenter User to Match your environment
$vCenterUser = "vCenterServiceAccount@fqdn"
$PWHash = Get-Content $CredentialPath\$vCenterUser.txt
$key = Get-Content $CredentialPath\$vCenterUser.key
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$vCenterCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $vCenterUser,$securestring

Connect-VIServer $vCenter -Credential $vCenterCred

$CimSession = New-CimSession -ComputerName $Servername -Credential $ServerCred

Try
{
	$Random = Get-Random -Minimum 1 -Maximum 2

	Switch ($Random)
	{
		1
			{
			$DataController = "SCSI Controller 1"
			$LogController = "SCSI Controller 2"
			}
		2
			{
			$DataController = "SCSI Controller 2"
			$LogController = "SCSI Controller 1"
			}
	}

	If($InstanceName -eq "Default")
	{$InstanceName = "MSSQL"}

	#Create Data Drive
	$Filename = Create-VMDK -Servername $Servername -Volumesize $DataVolumeSize -Controller $DataController
	$Path = $DataDriveLetter+":\$Instancename"
	New-Item -ItemType Directory -Path "\\$Servername\$DataDriveLetter`$\$InstanceName"
	$VolumeName = "Data-"+$InstanceName+"-"+$Filename
	If($VolumeName.length -gt 32)
	{
		$Length = $Filename.Length
		$TempFileName = $Filename.Substring(6,$Length)
		$VolumeName = "Data-"+$TempInstanceName+"-"+$TempFilename
	}
	Create-Mountpoint -Servername $Servername -VolumeName $VolumeName -VolumeSize $DataVolumeSize -Path $Path -CIMSession $CimSession

	#Create Log Volume
	$Filename = Create-VMDK -Servername $Servername -Volumesize $LogVolumeSize -Controller $LogController
	$Path = $LogDriveLetter+":\$Instancename"
	New-Item -ItemType Directory -Path "\\$Servername\$LogDriveLetter`$\$InstanceName"
	$VolumeName = "Logs-"+$InstanceName+"-"+$Filename
	If($VolumeName.length -gt 32)
	{
		$Length = $Filename.Length
		$TempFileName = $Filename.Substring(6,$Length)
		$VolumeName = "Data-"+$TempInstanceName+"-"+$TempFilename
	}
	Create-Mountpoint -Servername $Servername -VolumeName $VolumeName -VolumeSize $LogVolumeSize -Path $Path -CIMSession $CimSession

}
Finally
{
	Remove-CIMSession $CimSession 
	
	Disconnect-VIServer -Confirm:$false
}