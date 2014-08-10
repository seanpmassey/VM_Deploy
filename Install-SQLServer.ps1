Param([Parameter(Position=0)] $servername,[Parameter(Position=1)] $instancename, [Parameter(Position = 2)][Switch] $Dev)

Function Create-MSA
{
	Param($MSAName,$MSADescription,$Servername,$DC="Domain Controller",$Credential)
	
	New-ADServiceAccount -Name $MSAName -Description $MSADescription -RestricttoSingleComputer -Server $DC -Credential $Credential
	Add-ADComputerServiceAccount -Identity $servername -ServiceAccount $MSADefault -Server $DC -Credential $Credential

	Start-Sleep -seconds 10
	Install-ADServiceAccount $MSAName
}

Import-Module ActiveDirectory

$Domain = [Environment]::UserDomainName

#Configure AD Credentials
$ADUser = "Service Account UPN"
$PWHash = Get-Content Location of Password Hash file
$key = $key = Get-Content Location of Password Key File
$securestring = ConvertTo-SecureString -String $PWHash -Key $key
$ADCred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $ADUser, $securestring

#Configure vCenter Connection
#Create Default Managed Service Account and Per-Server SQL Service Accounts if not present - Required for other MSAs to function properly
If ($Dev -ne $true)
{
	$MSA = "svc" + $servername.substring(6)
}
Else
{
	$MSA = "svc" + $servername.substring(4)
}

$MSADefault = $MSA + "Default"
If($MSADefault.length -gt 15)
{
	$MSADefault = $MSA + "Def"
}
$MSAAG = $MSA+"AG"
$MSAIS = $MSA+"IS"
$DefaultSA = Get-ADServiceAccount -Filter { CN -eq $MSADefault} -server DomainController -Credential $ADCred
If($DefaultSA -eq $null)
{
Create-MSA -MSAName $MSADefault -MSADescription "Service Account for the default Managed Service Account on $Servername. This account is required otherwise Managed Service Accounts on $Servername will not function" -Servername $servername -Credential $ADCred
}

$ISSA = Get-ADServiceAccount -Filter { CN -eq $MSAIS} -server DomainController -Credential $ADCred
If($ISSA -eq $null)
{
Create-MSA -MSAName $MSAIS -MSADescription "Service Account for SQL Server Integration Services on $Servername" -Servername $Servername -Credential $ADCred
}

$AGSA = Get-ADServiceAccount -Filter { CN -eq $MSAAG} -server DomainController -Credential $ADCred
If($AGSA -eq $null)
{
Create-MSA -MSAName $MSAAG -MSADescription "Service Account for SQL Server Agent on $Servername." -Servername $Servername -Credential $ADCred
}


#Configure MSAs for Instance-Specific Services
$TempInstanceName = $InstanceName
If($TempInstanceName -eq "Default")
{
$TempInstanceName = "MSSQLServer"
}

$length = $TempInstanceName.length
If($length -gt 5)
{
$MSA = $MSA+$TempInstanceName.substring(0,5)
}
Else
{
$MSA = $MSA+$TempInstanceName
}

$MSADB = $MSA+"DB"
$MSARS = $MSA+"RS"
$MSAAS = $MSA+"AS"

$DBSA = Get-ADServiceAccount -Filter { CN -eq $MSADB } -server DomainController -Credential $ADCred
If ($DBSA -eq $null)
{
	Create-MSA -MSAName $MSADB -MSADescription "Service Account for $InstanceName Instance DB Engine on $Servername" -Servername $Servername -Credential $ADCred
}

$RSSA = Get-ADServiceAccount -Filter { CN -eq $MSARS } -server DomainController -Credential $ADCred
If ($RSSA -eq $null)
{
	Create-MSA -MSAName $MSARS -MSADescription "Service Account for $InstanceName Instance Reporting Services on $Servername" -Servername $Servername -Credential $ADCred
}

$ASSA = Get-ADServiceAccount -Filter { CN -eq $MSAAS } -server DomainController -Credential $ADCred
If ($ASSA -eq $null)
{
	Create-MSA -MSAName $MSAAS -MSADescription "Service Account for $InstanceName Instance Anaylsis Services on $Servername" -Servername $Servername -Credential $ADCred
}

$MSADB = $MSADB + "`$"
$MSARS = $MSARS + "`$"
$MSAAS = $MSAAS + "`$"
$MSAAG = $MSAAG + "`$"
$MSAIS = $MSAIS + "`$"

#$Path = "E:\SQLInstall\$version"

If($InstanceName -eq "Default")
{
$Datapath = "R:\$InstanceName"
$LogPath = "T:\$InstanceName"
$BackupPath = "S:\SQL_Backup"
$InstanceName = "MSSQLServer"

E:\SQLInstall\2012\Setup.exe /ACTION="Install" /IAcceptSQLServerLicenseTerms /Q /FEATURES=SQL,AS,RS,BIDS,CONN,IS,BC,SDK,BOL,SSMS,ADV_SSMS,MDS /INSTALLSHAREDDIR="E:\Program Files\Microsoft SQL Server" /INSTANCEDIR="E:\Program Files\Microsoft SQL Server" /INSTALLSQLDATADIR="E:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="E:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME="$Instancename" /SQMREPORTING=0 /RSINSTALLMODE=FilesOnlyMode /ERRORREPORTING=0 /AGTSVCACCOUNT="\$MSAAG" /AGTSVCSTARTUPTYPE="Automatic" /ASSVCACCOUNT="$Domain\$MSAAS" /ISSVCACCOUNT="$Domain\$MSAIS" /ASDATADIR="$DataPath\OLAP\Data" /ASLOGDIR="$LogPath\OLAP\Log" /ASBACKUPDIR="$BackupPath\OLAP\Backup" /ASSYSADMINACCOUNTS="$Domain\Username" /SQLSVCSTARTUPTYPE="Automatic" /SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS" /SQLSVCACCOUNT="$Domain\$MSADB" /SQLSYSADMINACCOUNTS="$Domain\Faith SQL Server Admins" /SQLBACKUPDIR="$BackupPath" /SQLUSERDBDIR="$DataPath" /SQLUSERDBLOGDIR="$LogPath" /SQLTEMPDBDIR="R:\TempDB\$InstanceName" /SQLTEMPDBLOGDIR="T:\TempDB\$InstanceName" /TCPENABLED="1" /RSSVCACCOUNT="$Domain\$MSARS" 
}
Else
{
$Datapath = "R:\$InstanceName"
$LogPath = "T:\$InstanceName"
$BackupPath = "S:\SQL_Backup"

E:\SQLInstall\2012\Setup.exe /ACTION="Install" /IAcceptSQLServerLicenseTerms /Q /FEATURES=SQL,AS,RS /INSTALLSHAREDDIR="E:\Program Files\Microsoft SQL Server" /INSTANCEDIR="E:\Program Files\Microsoft SQL Server" /INSTALLSQLDATADIR="E:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="E:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME="$Instancename" /SQMREPORTING=0 /RSINSTALLMODE=FilesOnlyMode /ERRORREPORTING=0 /ASSVCACCOUNT="$Domain\$MSAAS" /ASDATADIR="$DataPath\OLAP\Data" /ASLOGDIR="$LogPath\OLAP\Log" /ASBACKUPDIR="$BackupPath\OLAP\Backup" /ASSYSADMINACCOUNTS="$Domain\Username" /SQLSVCSTARTUPTYPE="Automatic" /SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS" /SQLSVCACCOUNT="$Domain\$MSADB" /SQLSYSADMINACCOUNTS="$Domain\SQL Server Admins" "$Domain\$DBOwner" /SQLBACKUPDIR="$BackupPath" /SQLUSERDBDIR="$DataPath" /SQLUSERDBLOGDIR="$LogPath" /SQLTEMPDBDIR="R:\TempDB\$InstanceName" /SQLTEMPDBLOGDIR="T:\TempDB\$InstanceName" /TCPENABLED="1" /RSSVCACCOUNT="$Domain\$MSARS" 
}