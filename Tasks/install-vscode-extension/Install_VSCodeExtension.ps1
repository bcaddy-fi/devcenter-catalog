Param(
    [Parameter()]    
    [string]$MarketplaceItemName,
    [Parameter()]
    [string]$RunAsUser
)

####################################################################################################
# Support functions for runasuser script
####################################################################################################

$CustomizationScriptsDir = "C:\DevBoxCustomizations"
$LockFile = "lockfile"
$RunAsUserScript = "runAsUser.ps1"
$CleanupScript = "cleanup.ps1"
$RunAsUserTask = "DevBoxCustomizations"
$CleanupTask = "DevBoxCustomizationsCleanup"

function AppendToUserScript {
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Content
    )

    Add-Content -Path "$($CustomizationScriptsDir)\$($RunAsUserScript)" -Value $Content
}

function SetupScheduledTasks {
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

####################################################################################################
# Task Code
####################################################################################################

# Check if the Visual Studio Code command-line utility is available
if (Get-Command code -ErrorAction SilentlyContinue) {
    if ($RunAsUser) {
        # Append the installation command to the user script
        AppendToUserScript '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
        AppendToUserScript -Content "code --install-extension '$MarketplaceItemName'"
        # Install completed successfully
        Write-Host "Extension '$MarketplaceItemName' added to the task script"
    }
    else {
        # Install the extension using the Visual Studio Code command-line utility
        code --install-extension $MarketplaceItemName
        # Install completed successfully
        Write-Host "Extension '$MarketplaceItemName' has been installed."
    }
}
else {
    # Visual Studio Code command-line utility is not available
    Write-Error "Visual Studio Code command-line utility (code) is not available in PATH."
}