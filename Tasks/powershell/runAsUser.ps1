$CustomizationScriptsDir = "C:\DevBoxCustomizations"
$LockFile = "lockfile"

Write-Host "Staring the script as user"
Start-Sleep -Seconds 5

Remove-Item -Path "$($CustomizationScriptsDir)\$($LockFile)" -Force