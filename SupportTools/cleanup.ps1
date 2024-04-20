# Download Dev Box Customizations Support PowerShell module
# Download the DevBox Customization Support module and import it
if (!(Test-Path -PathType Leaf ".\DevBox.Customization.Support.psm1")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/francesco-sodano/devcenter-catalog/main/SupportTools/DevBox.Customization.Support.psm1" -OutFile "DevBox.Customization.Support.psm1"
    }
Import-Module -Name ".\DevBox.Customization.Support.psm1"

# Set the Global Variables
DevBoxCustomizations-SetVariables

if (!(Test-Path "$($CustomizationScriptsDir)\$($LockFile)")) {
    Unregister-ScheduledTask -TaskName $RunAsUserTask -Confirm:$false
    Unregister-ScheduledTask -TaskName $CleanupTask -Confirm:$false
    Remove-Item $CustomizationScriptsDir -Force -Recurse
}