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
DevBoxCustomizations-Set-Variables


# ---------------------------------------------- #
# Main Script----------------------------------- #
# ---------------------------------------------- #

# We're running as user via scheduled task:
if ($RunAsUser -eq "true") {
    Write-Host "Running as user via scheduled task"
    # Download the runAsUser script
    if (!(Test-Path -PathType Leaf ".\runAsUser.ps1")) {
        # Download the runAsUser script
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/francesco-sodano/devcenter-catalog/main/SupportTools/runAsUser.ps1" -OutFile "runAsUser.ps1"
    }

    # Download the cleanup script
    if (!(Test-Path -PathType Leaf ".\cleanup.ps1")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/francesco-sodano/devcenter-catalog/main/SupportTools/cleanup.ps1" -OutFile "cleanup.ps1"
    }

    if (!(Test-Path -PathType Leaf "$($CustomizationScriptsDir)\$($LockFile)")) {
        DevBoxCustomizations-SetupScheduledTasks
    }

    Write-Host "Writing commands to user script"

    if ($Package) {
        # Get the name of the package from the ID
        Write-Host "Appending package install: $($Package)"
        DevBoxCustomizations-AppendToUserScript "Write-Host 'Installing Powershell 7'"
        DevBoxCustomizations-AppendToUserScript "DevBoxCustomizations-InstallPS7"
        DevBoxCustomizations-AppendToUserScript "Write-Host 'Powershell 7 Installed'"
        DevBoxCustomizations-AppendToUserScript "Write-Host 'Installing WinGet Package Manager'"        
        DevBoxCustomizations-AppendToUserScript "DevBoxCustomizations-InstallWinGet"
        DevBoxCustomizations-AppendToUserScript "Write-Host 'WinGet Package Manager Installed'"
        DevBoxCustomizations-AppendToUserScript "Write-Host 'Installing WinGet Powershell Module'"
        DevBoxCustomizations-AppendToUserScript "DevBoxCustomizations-InstallWinGetModule"
        DevBoxCustomizations-AppendToUserScript "Write-Host 'WinGet Powershell Module Installed'"
        DevBoxCustomizations-AppendToUserScript "`$PackageName = (Get-WinGetPackage -id $($Package)).Name"
        DevBoxCustomizations-AppendToUserScript "Write-host 'Installing WinGet Package: ' `$PackageName"
        # Install the package from the MS Store if specified, otherwise install from the default source
        if ($FromMSStore -eq "true") {
            DevBoxCustomizations-AppendToUserScript "Install-WinGetPackage -Id $($Package) -Source msstore"
        }
        else {
            DevBoxCustomizations-AppendToUserScript "Install-WinGetPackage -Id $($Package)"
        }
        # Update the PATH environment variable
        DevBoxCustomizations-AppendToUserScript "Write-host 'Updating PATH'"
        DevBoxCustomizations-AppendToUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
    }
    else {
        Write-Error "No package or configuration file specified"
        exit 1
    }
}

# We're running in the provisioning context:
else {
    Write-Host "Running in the provisioning context"
    # Install PowerShell 7, WinGet, and the WinGet PowerShell module
    Write-Host "Installing PowerShell 7"
    DevBoxCustomizations-InstallPS7
    Write-Host "Installing WinGet Package Manager"
    DevBoxCustomizations-InstallWinGet
    Write-Host "Installing WinGet PowerShell Module"
    DevBoxCustomizations-InstallWinGetModule

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
    }
    else {
        Write-Error "No package or configuration file specified"
        exit 1
    }
}
exit 0