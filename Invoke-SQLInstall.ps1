<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2014 v4.1.63
	 Created on:   	8/14/2014 7:52 AM
	 Created by:   	SMassey
	 Organization: 	
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		A description of the file.
#>
<#
	.SYNOPSIS
		Description of the function.

	.DESCRIPTION
		A detailed description of the function.

	.PARAMETER  ParameterA
		The description of the ParameterA parameter.

	.PARAMETER  ParameterB
		The description of the ParameterB parameter.

	.EXAMPLE
		Get-Something -ParameterA 'One value' -ParameterB 32

	.EXAMPLE
		Get-Something 'One value' 32

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

	.NOTES
		Additional information about the function go here.

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

#>

Param ($servername, $instancename, $InstanceOwner)

#Configure Remote Server Connection
$ServerUser = "faithadmin1@faith1.net"
$PWHash = Get-Content C:\Scripts\Other\$ServerUser.txt
$key = $key = Get-Content C:\Scripts\Other\$ServerUser.key
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$ServerCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $Serveruser, $securestring

$role = "DB"

$FQDN = "$servername.faith1.net"
Enable-WsManCredSSP -Role Client -DelegateComputer $FQDN -Force

connect-wsman $servername -Credential $ServerCred
set-item wsman:\$servername\service\auth\credSSP -value $true


If ($InstanceOwner -ne $null)
{
    $command = {
    param ($role,$instanceName,$instanceOwner)
    & E:\SQLInstall\Scripts\Install-SQLServer.ps1 -InstanceName $instancename -Role $role -InstanceOwner $InstanceOwner
    }	
	Invoke-Command -ComputerName $FQDN -Credential $ServerCred -ScriptBlock $command -ArgumentList ($role,$instancename,$InstanceOwner) -Authentication Credssp

}
Else
{
    $command = {
    param ($role,$instanceName)
    & E:\SQLInstall\Scripts\Install-SQLServer.ps1 -InstanceName $instancename -Role $role
    }	

	Invoke-Command -ComputerName $FQDN -Credential $ServerCred -ScriptBlock $command -ArgumentList ($role,$instancename) -Authentication Credssp
}


set-item wsman:\$servername\service\auth\credSSP -value $false
Disable-WSManCredSSP -Role Client