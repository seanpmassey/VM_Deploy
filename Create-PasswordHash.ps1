<#
	.SYNOPSIS
		This script creates a password hash and key file to encode a password so it can be stored securely.

	.DESCRIPTION
		In order to overcome the limitations of Kerberos authentication when using vCenter Orchestrator and PowerShell, the password needs to be hashed and stored on the file system.  To enable this to be portable and used by multiple service accounts, a key file will also be created to enable the hash to be decoded at run time.  The hash and key files should be stored on a secured network share.

	.PARAMETER  filepath
		The location where the hash and key files should be stored.

	.EXAMPLE
		PS C:\> Create-PasswordHash -Output \\file\secured$\folder

#>
Param($filepath="\\fileserver\share\folder")

Try
{
$username = Read-Host -prompt "Enter the Account Username"
$secureString = Read-Host -Prompt "Enter the Account Password" -AsSecureString

$key = New-Object byte[](32)
$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
$rng.GetBytes($key)
$encryptedString = ConvertFrom-SecureString -SecureString $secureString -Key $key

$encryptedString | Out-File -FilePath $filepath\$username.txt
$key | Out-File -FilePath $filepath\$username.key

}
finally
{
    if ($null -ne $key) { [array]::Clear($key, 0, $key.Length) }
}