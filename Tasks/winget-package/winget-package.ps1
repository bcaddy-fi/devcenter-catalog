param (
    [string]$Package,
    [Parameter()]
    [string]$FromMSStore,
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

    if ($Package) {
        Write-Host "Appending package install: $($Package)"
        # Install PowerShell 7
        Merge-DevBoxCustomizationUserScript "Write-Host 'Installing Powershell 7'"
        Merge-DevBoxCustomizationUserScript "Install-DevBoxCustomizationPS7"
        Merge-DevBoxCustomizationUserScript "Write-Host 'Powershell 7 Installed'"
        # Install WinGet Package Manager
        Merge-DevBoxCustomizationUserScript "Write-Host 'Installing WinGet Package Manager'"        
        Merge-DevBoxCustomizationUserScript "Install-DevBoxCustomizationWinGet"
        Merge-DevBoxCustomizationUserScript "Write-Host 'WinGet Package Manager Installed'"
        # Install WinGet PowerShell Module
        Merge-DevBoxCustomizationUserScript "Write-Host 'Installing WinGet Powershell Module'"
        Merge-DevBoxCustomizationUserScript "Install-DevBoxCustomizationWinGetModule"
        Merge-DevBoxCustomizationUserScript "Write-Host 'WinGet Powershell Module Installed'"
        # Update the PATH environment variable
        Merge-DevBoxCustomizationUserScript "Write-host 'Updating PATH'"
        Merge-DevBoxCustomizationUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
        # Get the name of the package from the ID
        Merge-DevBoxCustomizationUserScript '$PackageName = (Get-WinGetPackage -id ' + "$($Package)).Name"
        Merge-DevBoxCustomizationUserScript 'Write-host "Installing WinGet Package: " $PackageName'
        # Install the package from the MS Store if specified, otherwise install from the default source
        if ($FromMSStore -eq "true") {
            Merge-DevBoxCustomizationUserScript "Install-WinGetPackage -Id $($Package) -Source msstore"
        }
        else {
            Merge-DevBoxCustomizationUserScript "Install-WinGetPackage -Id $($Package)"
        }
        # Update the PATH environment variable
        Merge-DevBoxCustomizationUserScript "Write-host 'Updating PATH'"
        Merge-DevBoxCustomizationUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
    }
    else {
        Write-Error "No package specified"
        exit 1
    }
}

# We're running in the provisioning context:
else {
    Write-Host "Running in the provisioning context"
    # Install PowerShell 7, WinGet, and the WinGet PowerShell module
    Write-Host "Installing PowerShell 7"
    Install-DevBoxCustomizationPS7
    Write-Host "Installing WinGet Package Manager"
    Install-DevBoxCustomizationWinGet
    Write-Host "Installing WinGet PowerShell Module"
    Install-DevBoxCustomizationWinGetModule

    # We're running in package mode:
    if ($Package) {
        Write-Host "Running package install: $($Package)"
        if ($FromMSStore -eq "true") {
            $processCreation = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine="C:\Program Files\PowerShell\7\pwsh.exe -MTA -Command `"Install-WinGetPackage -Id $($Package) -Source msstore`""}
        }
        else {
            $processCreation = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine="C:\Program Files\PowerShell\7\pwsh.exe -MTA -Command `"Install-WinGetPackage -Id $($Package)`""}
        }
        $process = Get-Process -Id $processCreation.ProcessId
        $handle = $process.Handle # cache process.Handle so ExitCode isn't null when we need it below
        $process.WaitForExit()
        $installExitCode = $process.ExitCode
        if ($installExitCode -ne 0) {
            Write-Error "Failed to install package. Exit code: $installExitCode"
            exit 1
        }
        Clear-Variable $handle
    }
    else {
        Write-Error "No package specified"
        exit 1
    }
}
exit 0