# Start the transcript log
Start-Transcript -Path $env:TEMP\scheduled-task-customization.log -Append -IncludeInvocationHeader

# Download Dev Box Customizations Support PowerShell module
# Download the DevBox Customization Support module and import it
if (!(Test-Path -PathType Leaf ".\DevBox.Customization.Support.psm1")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/microsoft/PowerShell/master/src/Microsoft.PowerShell.SDK/SupportTools/DevBox.Customization.Support.psm1" -OutFile "DevBox.Customization.Support.psm1"
    }
Import-Module -Name ".\DevBox.Customization.Support.psm1"

# Set the Global Variables
DevBoxCustomizations-SetVariables

Write-Host "Microsoft Dev Box - Customizations"
Write-Host "----------------------------------"
White-Host "Script provided by Support Tools"
Write-Host "----------------------------------"
Write-Host "Setting up scheduled tasks..."

# Wait for the OneDrive initialization to complete
Write-Host "Waiting on OneDrive initialization..."
Start-Sleep -Seconds 120
Remove-Item -Path "$($CustomizationScriptsDir)\$($LockFile)"

# Update PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
