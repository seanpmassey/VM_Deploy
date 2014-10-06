Param($DataDriveLetter = "R",$LogDriveLetter = "T",$DataVolumeSize = "10", $LogVolumeSize = "5",$Servername,$DBOwner,$vCenter,$CredentialPath="\\PathTo\Credentials")

Function Add-vSCSI
{
    Param($servername)

    Shutdown-VMGuest -VM $Servername -Confirm:$false
	Do
    {$PowerState = (Get-VM -Name $Servername).PowerState}
	While($PowerState -ne "PoweredOff")

    $disk = Get-HardDisk -VM $servername | Select-Object -Last 1
    New-ScsiController -Type Paravirtual -HardDisk $disk -Confirm:$false

    Start-VM -VM $Servername | Wait-Tools
    Start-Sleep -Seconds 10
}

Function Create-VMDK
{
	#Create VMDK File on Server and Return VMDK File Name
	Param ($Servername,$VolumeSize)
	
    $disk = New-HardDisk -VM $servername -Persistence persistent -CapacityGB $VolumeSize -StorageFormat Thin -Confirm:$false

	
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

Function Create-Drive
{
	#Initialize volume, create partition, mount to drive letter, and format as NTFS Volume
	Param($Servername,$VolumeName,$VolumeSize,$Path,$DriveLetter,$CimSession)
	$VolumeSizeGB = [string]$VolumeSize + "GB"
	$DriveAccessLetter = $DriveLetter + ":"
	
	$partition = Get-Disk -CIMSession $CimSession | Where-Object {($_.partitionstyle -eq "raw") -and ($_.size -eq $VolumeSizeGB)} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -DriveLetter $DriveLetter
	
	$disknumber = $partition.DiskNumber
	$partitionnumber = $partition.partitionnumber

	Format-Volume -CIMSession $CimSession -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel $VolumeName -Confirm:$false
}


add-pssnapin vmware.vimautomation.core
Import-Module ActiveDirectory,ServerManager

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

$CimSession = New-CimSession -ComputerName $Servername -Credential $ADCred

Try
{
	#Set CPU and Memory Reservations
	$VMHost = (Get-VM -Name $servername).Host
	$HostNUMCPU = (Get-VMHost -Name $VMHost).NumCPU
	$HostCPUTotalMHZ = (Get-VMHost -Name $VMHost).CPUTotalMHz
	$HostCPUMHZ = $HostCPUTotalMHZ / $HostNUMCPU
	$VMNUMCPU = (Get-VM -Name $Servername).NumCPU
	$VMNUMRAM = (Get-VM -Name $Servername).MemoryGB
	$MHzReservation = $VMNUMCPU * $HostCPUMHZ
	Get-VMResourceConfiguration -VM $Servername | Set-VMResourceConfiguration -CpuReservationMhz $MHzReservation -MemReservationGB $VMNUMRAM
	
	Add-WindowsFeature -ComputerName $Servername -Name NET-Framework-Core -Credential $ADCred
	
	Set-StorageSetting –NewDiskPolicy OnlineAll -CimSession $CimSession

	#Create E Drive
	$Filename = Create-VMDK -Servername $Servername -Volumesize 50
	$VolumeName = "Data-"+$filename
    Write-Output $Filename
    Write-Output $VolumeName
	Create-Drive -Servername $Servername -VolumeName $VolumeName -VolumeSize 50 -DriveLetter "E" -CIMSession $CimSession

	$Drive = New-PSDrive -PSProvider FileSystem -Scope Script -Credential $ADCred -Name E -Root "\\$servername\e$"
	$DriveLetter = ($Drive.Name) + "`:"
	Copy-Item -Path "\\Fileshare\PathTo\SQLInstall\" -Destination "$DriveLetter" -Recurse -Verbose
	Write-Output "SQL Install Copy Complete"
	Remove-PSDrive -Name $Drive

	#Create R Drive
	$Filename = Create-VMDK -Servername $Servername -Volumesize 3
	$VolumeName = "SQLData-"+$Filename
	Create-Drive -Servername $Servername -VolumeName $VolumeName -VolumeSize 3 -DriveLetter "R" -CIMSession $CimSession

	#Create S Drive
	$Filename = Create-VMDK -Servername $Servername -Volumesize 200
	$VolumeName = "SQLBackup-"+$Filename
	Create-Drive -Servername $Servername -VolumeName $VolumeName -VolumeSize 200 -DriveLetter "S" -CIMSession $CimSession
	New-Item -ItemType Directory -Path "\\$Servername\S`$\SQL_Backups"

	#Create T Drive
	$Filename = Create-VMDK -Servername $Servername -Volumesize 3
	$VolumeName = "SQLLogs-"+$Filename
	Create-Drive -Servername $Servername -VolumeName $VolumeName -VolumeSize 3 -DriveLetter "T" -CIMSession $CimSession

	#Create TempDB Data Drive
	$Filename = Create-VMDK -Servername $Servername -Volumesize $DataVolumeSize
	$Path = $DataDriveLetter+":\TempDB"
	New-Item -ItemType Directory -Path "\\$Servername\$DataDriveLetter`$\TempDB"
    $VolumeName = "Data-TempDB-"+$Filename
    Create-Mountpoint -Servername $Servername -VolumeName $VolumeName -VolumeSize $DataVolumeSize -Path $Path -CIMSession $CimSession
    Add-vSCSI -Servername $Servername

	#Create TempDB Log Volume
	$Filename = Create-VMDK -Servername $Servername -Volumesize $LogVolumeSize
	$Path = $LogDriveLetter+":\TempDB"
	New-Item -ItemType Directory -Path "\\$Servername\$LogDriveLetter`$\TempDB"
    $VolumeName = "Logs-TempDB-"+$Filename
    Create-Mountpoint -Servername $Servername -VolumeName $VolumeName -VolumeSize $LogVolumeSize -Path $Path -CIMSession $CimSession
    Add-vSCSI -Servername $Servername
	
	#Add SQL Server Admins and Database owner to SQL Server Admins
	#Database Owner should only be used if this is a Dev Server or if an application owner/analyst needs direct DB Access
	#Developers should not get Admin rights on prod servers
		$Domain = (Get-ADDomain -Current LocalComputer).forest
		$pass = $ADCred.getnetworkcredential().password
		$object = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$servername", $ADUser, $pass)
		$group = $object.Children.Find("Administrators", "group")
		$group.Add("WinNT://$Domain/SQL Server Admins")
	
	If ($DBOwner -ne $null)
	{
		$group.Add("WinNT://$Domain/" + $DBOwner)
	}
	$pass = $Null
	
	#Invoke script on remote host to install SQL Server Management Studio and management tools
	$role = "Base"
	Invoke-Command -ComputerName $servername -Credential $ADCred -ScriptBlock {
			E:\SQLInstall\SSMS\Setup.exe /ACTION= "Install" /IAcceptSQLServerLicenseTerms /Q /FEATURES= SSMS, ADV_SSMS /INSTALLSHAREDDIR= "E:\Program Files\Microsoft SQL Server" /INSTANCEDIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSQLDATADIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR= "E:\Program Files (x86)\Microsoft SQL Server" /SQMREPORTING= 0 /ERRORREPORTING= 0
	}
}
Finally
{
	Remove-CIMSession $CimSession
	
	Disconnect-VIServer -Confirm:$false
}