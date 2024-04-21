param(
    [Parameter()]
    [string]$Ditribution
 )

# Array of WSL2 supported distributions
$Distributions = @(
    "Ubuntu",
    "Debian",
    "kali-linux",
    "Ubuntu-18.04",
    "Ubuntu-20.04",
    "Ubuntu-22.04",
    "OracleLinux_7_9",
    "OracleLinux_8_7",
    "OracleLinux_9_1",
    "openSUSE-Leap-15.5",
    "SUSE-Linux-Enterprise-Server-15-SP4",
    "SUSE-Linux-Enterprise-15-SP5",
    "openSUSE-Tumbleweed"
)

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

# Install the operating system features required to run WSL2 - installed as SYSTEM
Write-Host "Installing WSL2 prerequirements"
Import-Module -Name "DISM"
Enable-WindowsOptionalFeature -online -FeatureName "Microsoft-Windows-Subsystem-Linux" -norestart
Enable-WindowsOptionalFeature -online -FeatureName "VirtualMachinePlatform" -norestart
wsl.exe --install --no-distribution
Write-Host "WSL2 prerequirements installed"

# if distribution not included in the supported distributions, exit

if ($Distributions -notcontains $Distribution) {
    Write-Host "The distribution $Distribution is not supported"
    exit 1
}

# Install the WSL2 distribution - Installed as User

# We're running as user via scheduled task:
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
# Install PowerShell 7 for the user
Merge-DevBoxCustomizationUserScript "Write-Host 'Installing Powershell 7'"
Merge-DevBoxCustomizationUserScript "Install-DevBoxCustomizationPS7"
Merge-DevBoxCustomizationUserScript "Write-Host 'Powershell 7 Installed'"
# Run the WSL2 installation command
Merge-DevBoxCustomizationUserScript "Write-Host 'Install WSL2'"
Merge-DevBoxCustomizationUserScript "pwsh.exe -Command 'Set-ExecutionPolicy Bypass -Scope Process -Force'"
Merge-DevBoxCustomizationUserScript "wsl --install -d $($Ditribution)"
Merge-DevBoxCustomizationUserScript "Write-Host 'WSL2 Installed'"
# Update the PATH environment variable
Merge-DevBoxCustomizationUserScript "Write-host 'Updating PATH'"
Merge-DevBoxCustomizationUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
exit 0