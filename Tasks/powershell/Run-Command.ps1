param(
    [Parameter()]
    [string]$Command,
    [Parameter()]
    [string]$WorkingDirectory,
    [Parameter()]
    [string]$PS7,
    [Parameter()]
    [string]$RunAsUser
 )

# Check if workingDirectory is set and not empty and if so, change to it.
if ($WorkingDirectory -and $WorkingDirectory -ne "") {
    # Check if the working directory exists.
    if (-not (Test-Path $WorkingDirectory)) {
        # Create the working directory if it does not exist.
        Write-Output "Creating working directory $WorkingDirectory"
        New-Item -ItemType Directory -Force -Path $WorkingDirectory
    }

    Write-Output "Changing to working directory $WorkingDirectory"
    Set-Location $WorkingDirectory
}

# Download Dev Box Customizations Support PowerShell module
# Download the DevBox Customization Support module and import it
if (!(Test-Path -PathType Leaf ".\DevBox.Customization.Support.psm1")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/francesco-sodano/devcenter-catalog/main/SupportTools/DevBox.Customization.Support.psm1" -OutFile "DevBox.Customization.Support.psm1"
    }
    Import-Module -Name ".\DevBox.Customization.Support.psm1"
    
# Set the Global Variables
Set-DevBoxCustomizationVariables
# Install PowerShell 7 (as it is required when running the command as user)
Install-DevBoxCustomizationPS7

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
        # Setup the scheduled tasks to run the script when the user login devbox
        New-DevBoxCustomizationScheduledTasks
    }

    Write-Host "Writing commands to user script"

    if ($PS7 -eq "true") {
        # Install PowerShell 7 for the user
        Merge-DevBoxCustomizationUserScript "Write-Host 'Installing Powershell 7'"
        Merge-DevBoxCustomizationUserScript "Install-DevBoxCustomizationPS7"
        Merge-DevBoxCustomizationUserScript "Write-Host 'Powershell 7 Installed'"
        # Run the command using PowerShell 7
        Merge-DevBoxCustomizationUserScript "pwsh.exe -Command 'Set-ExecutionPolicy Bypass -Scope Process -Force'"
        Merge-DevBoxCustomizationUserScript "pwsh.exe -Command $($Command)"
        # Update the PATH environment variable
        Merge-DevBoxCustomizationUserScript "Write-host 'Updating PATH'"
        Merge-DevBoxCustomizationUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
    }
    else {
        # Run the command using PowerShell installed in the system
        Merge-DevBoxCustomizationUserScript "powershell.exe -Command 'Set-ExecutionPolicy Bypass -Scope Process -Force'"
        Merge-DevBoxCustomizationUserScript "powershell.exe -Command $($Command)"
        # Update the PATH environment variable
        Merge-DevBoxCustomizationUserScript "Write-host 'Updating PATH'"
        Merge-DevBoxCustomizationUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
    }
}
# We're running in the provisioning context:
else {
    Write-Host "Running in the provisioning context"
    if ($PS7 -eq "true") {
        # Run the command using PowerShell 7
        pwsh.exe -Command "Set-ExecutionPolicy Bypass -Scope Process -Force"
        pwsh.exe -Command $($Command)
        # Update the PATH environment variable
        pwsh.exe -Command '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
    }
    else {
        # Run the command using PowerShell installed in the system
        powershell.exe -Command "Set-ExecutionPolicy Bypass -Scope Process -Force"
        powershell.exe -Command $($Command)
        # Update the PATH environment variable
        powershell.exe -Command '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
    }
}