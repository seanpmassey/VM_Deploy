<#
	.SYNOPSIS
		This script will deploy a new VM from a template.  The template name and customization data is stored in a SQL database that is queried at run-time.  Prior to running this script, please read through the code and update the two credentials, the SQL server connection information, and the OUs for the AD Computer accounts.
		
		This script requires a SQL Server database to contain the customization data for the virtual machines.

	.DESCRIPTION
		This script will provision and customize a virtual machine based on values retrieved from a SQL database.

	.PARAMETER  Servername
		The name of the virtual machine in vCenter. This value will also be used as the computer's Active Directory name.

	.PARAMETER  Profile
		The information used to provision and customize the virtual machine.  This includes the template name, IP subnet information, cluster, and datastore. 

	.PARAMETER  IPAddress
		The IP Address that the VM will use after customization.

	.PARAMETER  CPUCount
		The number of CPUs that will be assigned to the VM during provisioning.

	.PARAMETER  RAMCount
		The amount of RAM assigned to the VM.

	.PARAMETER  Description
		A description or note to describe the VM in vCenter

	.PARAMETER  vCenter
		The vCenter Server that the script will connect to when performing provisioning operations

	.PARAMETER  CredentialPath
		The path the folder where the credential hashes are stored. The password hash can be created with the ....

	.PARAMETER  DomainController
		The domain controller that Active Directory operations will be performed against.

	.PARAMETER  SQLServer
		The SQL Server that the configuration information is stored in.  If you are not using a default instance, enter the SQL Server name as sql\instance.

	.PARAMETER  Owner
		The Active Directory User or Group that will be granted administrator rights on the server.

	.EXAMPLE
		PS C:\Scripts\VMProvisioning> .\Provision-VM.ps1 -Servername TestVM99 -profile 2008R2 -IPAddress 192.168.1.100 -CPUCount 1 -RAMCount 4 -Description "Test Server" -vCenter vcsa.contoso.com -DomainController dc1.contoso.com -Owner User1

	.NOTES
		Make sure you configure your authentication first.  This is first section at the top of the script.  The SQL Server connection details also need to be configured.  SQL Authentication is required because you cannot use alternative credentials when SQL is configured for Windows Authentication.  A basic SQL database will be required for storing profile data.
				

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

#>


Param($Servername,$profile,$IPAddress,$CPUCount=1,$RAMCount=4,$Description,$vCenter,$CredentialPath="Path",$DomainController,$SQLServer,$Owner)

add-pssnapin vmware.vimautomation.core
Import-Module ActiveDirectory
#Import-Module SQLPS

Set-Location C:\Scripts\VMProvisioning

#Configure AD Credentials
#Change ADUser to match your environment
$ADUser = "AD Service account @ UPN"
$PWHash = Get-Content $CredentialPath\$ADUser.txt
$key = Get-Content $CredentialPath\$ADUser.key
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$ADCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $ADUser,$securestring

#Configure vCenter Connection
#Change vCenter User to Match your environment
$vCenterUser = "vCenter Account @ UPN"
$PWHash = Get-Content $CredentialPath\$vCenterUser.txt
$key = Get-Content $CredentialPath\$vCenterUser.key
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$vCenterCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $vCenterUser,$securestring

Connect-VIServer $vCenter -Credential $vCenterCred

#Configure This Section Prior to running the script
$dataSource = $SQLServer
$user = "SQL User"
$pwd = "SQL Password"
$database = "OSCustomizationDB"
$databasetable = "OSCustomizationSettings"
$connectionString = "Server=$dataSource;uid=$user;pwd=$pwd;Database=$database;Integrated Security=False;"
 
$query = "Select * FROM $databasetable WHERE Profile_ID = '$Profile'"
 
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()
$command = $connection.CreateCommand()
$command.CommandText  = $query
 
$result = $command.ExecuteReader()

$ProfileDetails = new-object “System.Data.DataTable”
$ProfileDetails.Load($result)

$SubnetMask = ($ProfileDetails.Profile_NetMask).trim()
$DefaultGW = ($ProfileDetails.Profile_GW).trim()
$DataStore = $ProfileDetails.Profile_Datastore
$ESXiHost = $ProfileDetails.Profile_ResourcePool
$CustSpec = $ProfileDetails.Profile_CustSpec
$template = $ProfileDetails.Profile_Template
$DNS = $ProfileDetails.Profile_DNS
$DNS = $DNS.Split(",")
$OU = $ProfileDetails.Profile_OU
$OU = $OU.Replace("`"","")

Try{$TestAD = Get-ADComputer -Identity $Servername -Server $DomainController -ErrorAction SilentlyContinue}
Catch{Write-Output "Computer Account does not exist."}

Try
{
    $OSSpecName = "$Servername-NPSpec"
    $TestCustSpec = Get-OSCustomizationSpec -Name $OSSpecName -ErrorAction SilentlyContinue}
    Catch{Write-Output "Customization Spec already exists."
}

Try
{
	If($TestAD -ne $Null)
	{
		Write-Output "AD Account Already Exists."
	}
	Else
	{
		#Configure the AD OU paths prior to running the script
		New-ADComputer -Name $Servername -SAMAccountName $Servername -Path $OU -Server $DomainController -Credential $ADCred
	}
	

	If($TestCustSpec -ne $null)
	{
		Write-Output "Customization Spec Already Exists"
	}
	Else
	{
		Get-OSCustomizationSpec -Name $CustSpec | New-OSCustomizationSpec -Name $OSSpecName -Type NonPersistent

		Get-OSCustomizationSpec -Name $OSSpecName | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $IPAddress -SubnetMask $SubnetMask -DefaultGateway $DefaultGW -Dns $DNS
	}
	
	New-VM -Name $Servername -Template $Template -ResourcePool $ESXiHost -Datastore $Datastore -Notes $Description -OSCustomizationSpec $OSSpecName
	
	Set-VM -VM $Servername -NumCpu $CPUCount -MemoryGB $RAMCount -Confirm:$false
	
	If ($Dev -eq $true)
	{
		Move-VM -VM $Servername -Destination Test -Confirm:$false
	}
	
	Start-VM $Servername
	Write-Output "Starting Customization."
	
	Do
	{
	Start-Sleep -Seconds 60
	$events = Get-VM -Name $servername | Get-VIEvent -Types Info | Where-Object {($_ -is "VMware.Vim.CustomizationSucceeded") -or ($_ -is "VMware.Vim.CustomizationFailed")}
	Write-Output "Waiting for Customization to Complete."
	}
	While($events -eq $null)
	
	If($events -is "VMware.Vim.CustomizationSucceeded")
	{
		Write-Output "Customization Completed Successfully"
		
		#Add Server Owner to Local Administrators Group
		If($Owner -ne $null)
		{
		Wait-Tools -VM $Servername -HostCredential $ADCred -TimeoutSeconds 180

		$Domain = (Get-ADDomain -Current LocalComputer).forest
		$pass = $ADCred.getnetworkcredential().password
		$object = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$servername", $ADUser, $pass)
		$group = $object.Children.Find("Administrators", "group")
		$group.Add("WinNT://$domain/$Owner")
		$pass = $Null	
		}
	}
	ElseIF($events -is "VMware.Vim.CustomizationFailed")
	{
		Write-Output "Customization Did Not Complete Successfully"
	}
}
Finally
{
	Disconnect-VIServer -Confirm:$false
	
	If($connection -ne $null)
	{
		$connection.close()
	}
}