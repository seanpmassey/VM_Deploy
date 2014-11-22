Param ($instancename,$Role,$InstanceOwner,$SQLAdminGroup)

Import-Module NetSecurity

If ($InstanceName -eq "Default")
{
	$Datapath = "R:\MSSQL"
	$LogPath = "T:\MSSQL"
	$BackupPath = "S:\SQL_Backup"
	$InstanceName = "MSSQLServer"
	$Features = "SQL,RS"
}
Else
{
	$Datapath = "R:\$InstanceName"
	$LogPath = "T:\$InstanceName"
	$BackupPath = "S:\SQL_Backup"
	$Features = "SQL,RS"
}

$Domain = $env:USERDOMAIN
$AdminGroup = "$Domain\$SQLAdminGroup"

switch ($role)
{
	("DB"){
		If ($InstanceOwner -ne $null)
		{
			E:\SQLInstall\2012\Setup.exe /ACTION= "Install" /IAcceptSQLServerLicenseTerms /Q /FEATURES= $Features /INSTALLSHAREDDIR= "E:\Program Files\Microsoft SQL Server" /INSTANCEDIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSQLDATADIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR= "E:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME= "$Instancename" /INSTANCEID= $instancename /SQMREPORTING= 0 /RSINSTALLMODE= FilesOnlyMode /ERRORREPORTING= 0 /AGTSVCSTARTUPTYPE= "Automatic" /SQLSVCSTARTUPTYPE= "Automatic" /SQLCOLLATION= "SQL_Latin1_General_CP1_CI_AS" /SQLSYSADMINACCOUNTS= "$AdminGroup" "$Domain\$InstanceOwner" /SQLBACKUPDIR= "$BackupPath" /SQLUSERDBDIR= "$DataPath" /SQLUSERDBLOGDIR= "$LogPath" /SQLTEMPDBDIR= "R:\TempDB\$InstanceName" /SQLTEMPDBLOGDIR= "T:\TempDB\$InstanceName" /TCPENABLED= "1"           
		}
		Else
		{
			E:\SQLInstall\2012\Setup.exe /ACTION= "Install" /IAcceptSQLServerLicenseTerms /Q /FEATURES= $Features /INSTALLSHAREDDIR= "E:\Program Files\Microsoft SQL Server" /INSTANCEDIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSQLDATADIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR= "E:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME= "$Instancename" /INSTANCEID= $instancename /SQMREPORTING= 0 /RSINSTALLMODE= FilesOnlyMode /ERRORREPORTING= 0 /AGTSVCSTARTUPTYPE= "Automatic" /SQLSVCSTARTUPTYPE= "Automatic" /SQLCOLLATION= "SQL_Latin1_General_CP1_CI_AS" /SQLSYSADMINACCOUNTS= "$AdminGroup" /SQLBACKUPDIR= "$BackupPath" /SQLUSERDBDIR= "$DataPath" /SQLUSERDBLOGDIR= "$LogPath" /SQLTEMPDBDIR= "R:\TempDB\$InstanceName" /SQLTEMPDBLOGDIR= "T:\TempDB\$InstanceName" /TCPENABLED= "1"
        }
		
        Set-Location -Path C:\

		$ProgramPath = "E:\Program Files\Microsoft SQL Server\MSSQL11.$instanceName\MSSQL\Binn\sqlservr.exe"
		$pathexists = Test-Path -Path $ProgramPath
		If ($pathExists -eq $true)
		{
			New-NetFirewallRule -Program $ProgramPath -DisplayName "SQL Server - $instancename" -Direction Inbound -Action Allow -Profile Domain
		}
	}
	("Base") { E:\SQLInstall\2012\Setup.exe /ACTION= "Install" /IAcceptSQLServerLicenseTerms /Q /FEATURES= BIDS, CONN, SSMS, ADV_SSMS /INSTALLSHAREDDIR= "E:\Program Files\Microsoft SQL Server" /INSTANCEDIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSQLDATADIR= "E:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR= "E:\Program Files (x86)\Microsoft SQL Server" /SQMREPORTING= 0 /ERRORREPORTING= 0 }
}