#Gets latest Box Drive installer and deploys it

$filename = "googlechromestandaloneenterprise64.msi"

$ChromeDownloader = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"

invoke-webrequest $ChromeDownloader -Outfile C:\Temp\$filename

msiexec.exe /i $filename /passive

https://www.youtube.com/redirect?event=video_description&v=M0qX46M3mnE&q=http%3A%2F%2Fdl.google.com%2Fchrome%2Finstall%2F375.126%2Fchrome_installer.exe&redir_token=9YhAn5VfIWlANeKTuf-corP-7458MTU0NjQwMzgwNEAxNTQ2MzE3NDA0