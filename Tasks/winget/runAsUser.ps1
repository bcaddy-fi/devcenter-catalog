$CustomizationScriptsDir = "C:\DevBoxCustomizations"
$LockFile = "lockfile"
$SetVariablesScript = "setVariables.ps1"
$RunAsUserScript = "runAsUser.ps1"
$CleanupScript = "cleanup.ps1"
$RunAsUserTask = "DevBoxCustomizations"
$CleanupTask = "DevBoxCustomizationsCleanup"

$UriVCLibs = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
$UriUIXaml = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
$UriWinGet = "https://aka.ms/getwinget"
$VCLibs = "Microsoft.VCLibs.x64.14.00.Desktop.appx"
$WinGet = "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
$UIXaml = "Microsoft.UI.Xaml.2.8.x64.appx"


Start-Transcript -Path $env:TEMP\scheduled-task-customization.log -Append -IncludeInvocationHeader

Write-Host "Microsoft Dev Box - Customizations"
Write-Host "----------------------------------"
Write-Host "Setting up scheduled tasks..."

Write-Host "Waiting on OneDrive initialization..."
Start-Sleep -Seconds 120
Remove-Item -Path "$($CustomizationScriptsDir)\$($LockFile)"

# install Microsoft.DesktopAppInstaller
try {
    Write-Host "Repairing WinGet Package Manager for user"
    Invoke-WebRequest -Uri $UriWinGet -OutFile $WinGet
    Invoke-WebRequest -Uri $UriVCLibs -OutFile $VCLibs
    Invoke-WebRequest -Uri $UriUIXaml -OutFile $UIXaml
    Add-AppxPackage $VCLibs
    Add-AppxPackage $UIXaml
    Add-AppxPackage $WinGet
    Start-Sleep -Seconds 60
    Write-Host "WinGet for user repaired"
} 
catch {
    Write-Error $_
}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
