. (Join-Path $PSScriptRoot "pc_monitor_common.ps1")

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PC Monitor - Task Installation" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-PcMonitorAdministrator)) {
    Write-Host "[ERROR] This script requires Administrator privileges." -ForegroundColor Red
    Write-Host ""
    Write-Host "Run PowerShell as Administrator, then execute:" -ForegroundColor Yellow
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File `"$PSScriptRoot\install_tasks.ps1`"" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

try {
    $installPath = Get-PcMonitorInstallPath -BasePath $PSScriptRoot -Persist
    $missingScripts = @(Test-PcMonitorRequiredScripts -InstallPath $installPath)
    if ($missingScripts.Count -gt 0) {
        throw "Missing required scripts: $($missingScripts -join ', ')"
    }

    $updatedFiles = Sync-PcMonitorTaskXml -BasePath $PSScriptRoot -InstallPath $installPath
    $installedTasks = Install-PcMonitorTasks -BasePath $PSScriptRoot
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Installation Path: $installPath" -ForegroundColor Green
Write-Host ""
Write-Host "Refreshed task XML files:" -ForegroundColor White
foreach ($file in $updatedFiles) {
    Write-Host "  [OK] $file" -ForegroundColor Green
}
Write-Host ""
Write-Host "Installed tasks:" -ForegroundColor White
foreach ($taskName in $installedTasks) {
    Write-Host "  [OK] $taskName" -ForegroundColor Green
}
Write-Host ""
Write-Host "Open Task Scheduler with: taskschd.msc" -ForegroundColor White
Write-Host ""
