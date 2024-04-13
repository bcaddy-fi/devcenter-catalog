$CustomizationScriptsDir = "C:\DevBoxCustomizations"
$LockFile = "lockfile"

Write-Host "Starting the script as user"

Remove-Item -Path "$($CustomizationScriptsDir)\$($LockFile)" -Force