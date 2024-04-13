Set-ExecutionPolicy Bypass -Scope Process -Force;

# This function updates the AzureRM module
function Update-WinGetModule {
    # Check if WinGet.Client module is installed
    if ((!Get-Module -ListAvailable -Name Microsoft.WinGet.Client) -or ((Get-Module -ListAvailable -Name Microsoft.WinGet.Client).Version.ToString().Replace(".","") -lt "1710861")){
        Write-Host "Installing Microsoft.Winget.Client"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope "AllUsers"
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Install-Module Microsoft.WinGet.Client -Scope "AllUsers"
        Import-Module -Name Microsoft.WinGet.Client
        Write-Host "Done Installing Microsoft.Winget.Client"
        # need to update the path post install
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Job -Name "Update-WinGetModule" -ScriptBlock {
            Repair-WinGetPackageManager -Latest -AllUsers -Force 
        }
        Wait-Job -Name "Update-WinGetModule" -Timeout 180
    }
    else {
        Write-Host "Microsoft.Winget.Client is already installed and updated"
    }
}

function InstallPS7 {
    if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "Installing PowerShell 7"
        $code = Invoke-RestMethod -Uri https://aka.ms/install-powershell.ps1
        $null = New-Item -Path function:Install-PowerShell -Value $code
        WithRetry -ScriptBlock {
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

# Update all prerequisites
InstallPS7
Update-WinGetModule
