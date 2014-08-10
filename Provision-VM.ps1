Param($Servername,$location = "FTDC1",$IPAddress,[switch]$Dev,$CPUCount=1,$RAMCount=4,$Description,$Version="2012")
Add-PSSnapin VMware.DeployAutomation


add-pssnapin vmware.vimautomation.core
Import-Module ActiveDirectory,SQLPS

#Configure AD Credentials
$ADUser = "Service Account UPN"
$PWHash = Get-Content Location of Password Hash file
$key = $key = Get-Content Location of Password Key File
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$ADCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $ADUser,$securestring

#Configure vCenter Connection
$vCenterUser = "Service Account UPN"
$PWHash = Get-Content Location of Password Hash file
$key = $key = Get-Content Location of Password Key File
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$vCenterCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $vCenterUser,$securestring

Connect-VIServer vCenterFQDN -Credential $vCenterCred

$LocationDetails = Invoke-Sqlcmd -query "Select * FROM OSCustomizationSettings WHERE Location_ID = '$Location'" -database OSCustomizationDB -serverinstance "SQLServer\Instance"

$SubnetMask = $LocationDetails.Location_NetMask
$DefaultGW = $LocationDetails.Location_GW
$DataStore = $LocationDetails.Location_Datastore
$ESXiHost = $LocationDetails.Location_Host
$DNS = $LocationDetails.Location_DNS
$DNS = $DNS.Split(",")

Try{$TestAD = Get-ADComputer -Identity $Servername -ErrorAction SilentlyContinue}
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
		If($Dev -ne $true)
		{
			New-ADComputer -Name $Servername -Path "OU Distinguished Name" -Server DCFQDN -Credential $ADCred
		}
		Else
		{
			New-ADComputer -Name $Servername -Path "OU Distinguished Name" -Server DCFQDN -Credential $ADCred
		}
	}
	

	If($TestCustSpec -ne $null)
	{
		Write-Output "Customization Spec Already Exists"
	}
	Else
	{
		Get-OSCustomizationSpec -Name AutomationSpec | New-OSCustomizationSpec -Name $OSSpecName -Type NonPersistent

		Get-OSCustomizationSpec -Name $OSSpecName | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $IPAddress -SubnetMask $SubnetMask -DefaultGateway $DefaultGW -Dns $DNS
	}
	
	Switch ($Version)
	{
		2012 { $template = "Windows Server 2012 R2" }
		2008 { $template = "Windows Server 2008 R2" }
		Default
		{
			Write-Error "Unknown Template. Exiting"
			Exit
		}
	}
	
	New-VM -Name $Servername -Template $Template -ResourcePool $ESXiHost -Datastore $Datastore -Notes $Description -OSCustomizationSpec $OSSpecName
	
	Set-VM -VM $Servername -NumCpu $CPUCount -MemoryGB $RAMCount -Confirm:$false
	
	If ($Dev -eq $true)
	{
		Move-VM -VM $Servername -Destination Dev-Servers-VM-Folder -Confirm:$false
	}
	
	Start-VM $Servername
	Write-Output "Waiting for Customization to Complete."
	
	Do
	{
	Start-Sleep -Seconds 60
	$events = Get-VM -Name $servername | Get-VIEvent -Types Info | Where-Object {($_ -is "VMware.Vim.CustomizationSucceeded") -or ($_ -is "VMware.Vim.CustomizationFailed")}
	Write-Output "Waiting for Customization to Complete."
	}
	While ($events -eq $null)
	
	Write-Output "Customization Complete."

}
Finally
{
	Disconnect-VIServer -Confirm:$false
}