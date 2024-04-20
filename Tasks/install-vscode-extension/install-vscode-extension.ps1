param(
    [Parameter()]
    [string]$Extension,
    [Parameter()]
    [string]$RunAsUser
 )

# Download Dev Box Customizations Support PowerShell module
# Download the DevBox Customization Support module and import it
 if (!(Test-Path -PathType Leaf ".\DevBox.Customization.Support.psm1")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/francesco-sodano/devcenter-catalog/main/SupportTools/DevBox.Customization.Support.psm1" -OutFile "DevBox.Customization.Support.psm1"
    }
Import-Module -Name ".\DevBox.Customization.Support.psm1"

# Set the Global Variables
Set-DevBoxCustomizationVariables

# ---------------------------------------------- #
# Main Script----------------------------------- #
# ---------------------------------------------- #

# We're running as user via scheduled task:
if ($RunAsUser -eq "true") {
    Write-Host "Running as user via scheduled task"
    # Download the runAsUser script
    if (!(Test-Path -PathType Leaf ".\runAsUser.ps1")) {
        # Download the runAsUser script
        Invoke-WebRequest -Uri $UriRunAsUser -OutFile "runAsUser.ps1"
    }

    # Download the cleanup script
    if (!(Test-Path -PathType Leaf ".\cleanup.ps1")) {
    Invoke-WebRequest -Uri $UriCleanup -OutFile "cleanup.ps1"
    }

    # Check if the Scheduler tasks are already set up
    if (!(Test-Path -PathType Leaf "$($CustomizationScriptsDir)\$($LockFile)")) {
        New-DevBoxCustomizationScheduledTasks
    }

    Write-Host "Writing commands to user script"

    if ($Extension) {
        # Get the name of the package from the ID
        Write-Host "Appending package install: $($Extension)"
        Merge-DevBoxCustomizationUserScript "Write-Host 'Installing Powershell 7'"
        Merge-DevBoxCustomizationUserScript "Install-DevBoxCustomizationPS7"
        Merge-DevBoxCustomizationUserScript "Write-Host 'Powershell 7 Installed'"
        # Install the VS Code Extension
        Merge-DevBoxCustomizationUserScript "Write-Host 'Installing Visual Studio Code Extension: ' $($Extension)"
        # Check if Visual Studio Code or Visual Studio Code insiders is installed
        Merge-DevBoxCustomizationUserScript "if (Get-Command -Name 'code' -ErrorAction SilentlyContinue) {"
        Merge-DevBoxCustomizationUserScript "   Write-Output 'Visual Studio Code detected.'"
        # Install the VS Code Extension with VS Code
        Merge-DevBoxCustomizationUserScript "   code --install-extension $($Extension)"
        Merge-DevBoxCustomizationUserScript "}" 
        Merge-DevBoxCustomizationUserScript "elseif (Get-Command -Name 'code-insiders' -ErrorAction SilentlyContinue) {"
        Merge-DevBoxCustomizationUserScript "   Write-Output 'Visual Studio Code Insiders detected.'"
        # Install the VS Code Extension with VS Code Insiders
        Merge-DevBoxCustomizationUserScript "   code-insiders --install-extension $($Extension)"
        Merge-DevBoxCustomizationUserScript "}"
        Merge-DevBoxCustomizationUserScript "else {"
        # Write a message if VS Code or VS Code Insiders is not detected
        Merge-DevBoxCustomizationUserScript "   Write-Output 'VS Code or VS Code Insiders NOT detected.'"
        Merge-DevBoxCustomizationUserScript "}"
        # Update the PATH environment variable
        Merge-DevBoxCustomizationUserScript "Write-host 'Updating PATH'"
        Merge-DevBoxCustomizationUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
    }
    else {
        Write-Error "No package or configuration file specified"
        exit 1
    }
}

# We're running in the provisioning context:
else {
    Write-Host "Install VS Code Extension is not intended to run in the provisioning context."
    exit 1
}
exit 0