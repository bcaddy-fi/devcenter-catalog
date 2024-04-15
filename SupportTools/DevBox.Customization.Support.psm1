# PowerShell Module for DevBox Customization #
# This module contains functions to customize the DevBox environment.
function Set-DevBoxCustomizationVariables {
    $global:CustomizationScriptsDir = "C:\DevBoxCustomizations"
    $global:LockFile = "lockfile"
    $global:SetVariablesScript = "setVariables.ps1"
    $global:RunAsUserScript = "runAsUser.ps1"
    $global:CleanupScript = "cleanup.ps1"
    $global:RunAsUserTask = "DevBoxCustomizations"
    $global:CleanupTask = "DevBoxCustomizationsCleanup"
    
    # Latest version of the WinGet Package Manager and its dependencies
    $global:UriVCLibs = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
    $global:UriUIXaml = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
    $global:UriWinGet = "https://aka.ms/getwinget"
    $global:VCLibs = "Microsoft.VCLibs.x64.14.00.Desktop.appx"
    $global:WinGet = "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $global:UIXaml = "Microsoft.UI.Xaml.2.8.x64.appx"
}

function New-DevBoxCustomizationScheduledTasks {
    Write-Host "Setting up scheduled tasks"
    if (!(Test-Path -PathType Container $CustomizationScriptsDir)) {
        New-Item -Path $CustomizationScriptsDir -ItemType Directory
    }

    if (!(Test-Path -PathType Leaf "$($CustomizationScriptsDir)\$($LockFile)")) {
        New-Item -Path "$($CustomizationScriptsDir)\$($LockFile)" -ItemType File
    }

    if (!(Test-Path -PathType Leaf "$($CustomizationScriptsDir)\$($RunAsUserScript)")) {
        Copy-Item "./$($RunAsUserScript)" -Destination $CustomizationScriptsDir
    }

    if (!(Test-Path -PathType Leaf "$($CustomizationScriptsDir)\$($CleanupScript)")) {
        Copy-Item "./$($CleanupScript)" -Destination $CustomizationScriptsDir
    }

    # Reference: https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-objects
    $ShedService = New-Object -comobject "Schedule.Service"
    $ShedService.Connect()

    # Schedule the cleanup script to run every minute as SYSTEM
    $Task = $ShedService.NewTask(0)
    $Task.RegistrationInfo.Description = "Dev Box Customizations Cleanup"
    $Task.Settings.Enabled = $true
    $Task.Settings.AllowDemandStart = $false

    $Trigger = $Task.Triggers.Create(9)
    $Trigger.Enabled = $true
    $Trigger.Repetition.Interval="PT1M"

    $Action = $Task.Actions.Create(0)
    $Action.Path = "PowerShell.exe"
    $Action.Arguments = "Set-ExecutionPolicy Bypass -Scope Process -Force; $($CustomizationScriptsDir)\$($CleanupScript)"

    $TaskFolder = $ShedService.GetFolder("\")
    $TaskFolder.RegisterTaskDefinition("$($CleanupTask)", $Task , 6, "NT AUTHORITY\SYSTEM", $null, 5)

    # Schedule the script to be run in the user context on login
    $Task = $ShedService.NewTask(0)
    $Task.RegistrationInfo.Description = "Dev Box Customizations"
    $Task.Settings.Enabled = $true
    $Task.Settings.AllowDemandStart = $false
    $Task.Principal.RunLevel = 1

    $Trigger = $Task.Triggers.Create(9)
    $Trigger.Enabled = $true

    $Action = $Task.Actions.Create(0)
    $Action.Path = "C:\Program Files\PowerShell\7\pwsh.exe"
    $Action.Arguments = "-MTA -Command $($CustomizationScriptsDir)\$($RunAsUserScript)"

    $TaskFolder = $ShedService.GetFolder("\")
    $TaskFolder.RegisterTaskDefinition("$($RunAsUserTask)", $Task , 6, "Users", $null, 4)
    Write-Host "Done setting up scheduled tasks"
}

function Set-DevBoxCustomizationWithRetry {
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position=1, Mandatory=$false)]
        [int]$Maximum = 5,

        [Parameter(Position=2, Mandatory=$false)]
        [int]$Delay = 100
    )

    $iterationCount = 0
    $lastException = $null
    do {
        $iterationCount++
        try {
            Invoke-Command -Command $ScriptBlock
            return
        } catch {
            $lastException = $_
            Write-Error $_

            # Sleep for a random amount of time with exponential backoff
            $randomDouble = Get-Random -Minimum 0.0 -Maximum 1.0
            $k = $randomDouble * ([Math]::Pow(2.0, $iterationCount) - 1.0)
            Start-Sleep -Milliseconds ($k * $Delay)
        }
    } while ($iterationCount -lt $Maximum)

    throw $lastException
}

function Merge-DevBoxCustomizationUserScript {
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Content
    )

    Add-Content -Path "$($CustomizationScriptsDir)\$($RunAsUserScript)" -Value $Content
}
function Install-DevBoxCustomizationPS7 {
    if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "Installing PowerShell 7"
        $code = Invoke-RestMethod -Uri https://aka.ms/install-powershell.ps1
        $null = New-Item -Path function:Install-PowerShell -Value $code
        Set-DevBoxCustomizationWithRetry -ScriptBlock {
            Install-PowerShell -UseMSI -Quiet
        } -Maximum 5 -Delay 100
        # Need to update the path post install
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Done Installing PowerShell 7"
    }
    else {
        Write-Host "PowerShell 7 is already installed"
    }
}

function Install-DevBoxCustomizationWinGet {
    # Install the WinGet Package Manager
    if ((!(Get-AppxPackage Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue) -or (Get-AppxPackage Microsoft.DesktopAppInstaller).Version.ToString().Replace(".","") -lt "122108610")) {
        try {
            Write-Host "Installing WinGet Package Manager for user"
            Invoke-WebRequest -Uri $UriWinGet -OutFile $WinGet
            Invoke-WebRequest -Uri $UriVCLibs -OutFile $VCLibs
            Invoke-WebRequest -Uri $UriUIXaml -OutFile $UIXaml
            Add-AppxPackage $VCLibs
            Add-AppxPackage $UIXaml
            Add-AppxPackage $WinGet
            Start-Sleep -Seconds 10
            Write-Host "WinGet for user Installed"
            # Update PATH after install
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        } 
        catch {
            Write-Error $_
        }
    }
    else {
        Write-Host "WinGet Package Manager is already installed"
    }
}

function Install-DevBoxCustomizationWinGetModule {
    # Check in the current user is SYSTEM
    $psInstallScope = "CurrentUser"
    $whoami = whoami.exe
    if ($whoami -eq "nt authority\system") {
        $psInstallScope = "AllUsers"
    }

    Write-Host "Installing WinGet Powershell Module in scope: $psInstallScope"

    # check if the Microsoft.Winget.Client module is installed
    if (!(Get-Module -ListAvailable -Name Microsoft.Winget.Client)) {
        Write-Host "Installing Microsoft.Winget.Client"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope $psInstallScope
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Install-Module Microsoft.WinGet.Client -Scope $psInstallScope
        Write-Host "Done Installing Microsoft.Winget.Client"
        # Update PATH after install
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    else {
        Write-Host "Microsoft.Winget.Client is already installed"
    }
    return 0
}
