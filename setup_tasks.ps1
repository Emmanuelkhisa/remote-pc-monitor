. (Join-Path $PSScriptRoot "pc_monitor_common.ps1")

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PC Monitor - Task Setup Wizard" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try {
    $installPath = Get-PcMonitorInstallPath -BasePath $PSScriptRoot -Persist
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Create config.json from config.example.json and fill in your bot details." -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Installation Path: $installPath" -ForegroundColor Green
Write-Host ""

$missingScripts = @(Test-PcMonitorRequiredScripts -InstallPath $installPath)
if ($missingScripts.Count -gt 0) {
    Write-Host "[ERROR] The following scripts are missing:" -ForegroundColor Red
    foreach ($script in $missingScripts) {
        Write-Host "  - $script" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Please ensure all required scripts exist in: $installPath" -ForegroundColor Yellow
    exit 1
}

try {
    $updatedFiles = Sync-PcMonitorTaskXml -BasePath $PSScriptRoot -InstallPath $installPath
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Task XML files refreshed:" -ForegroundColor Cyan
foreach ($file in $updatedFiles) {
    Write-Host "  [OK] $file" -ForegroundColor Green
}
Write-Host ""

if (-not (Test-PcMonitorAdministrator)) {
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "  NEXT STEP: Install Tasks" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Run PowerShell as Administrator, then execute:" -ForegroundColor White
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File `"$PSScriptRoot\install_tasks.ps1`"" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host "[INFO] Administrator session detected. Installing tasks now..." -ForegroundColor Cyan
Write-Host ""

try {
    $installedTasks = Install-PcMonitorTasks -BasePath $PSScriptRoot
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Installation Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed tasks:" -ForegroundColor White
foreach ($taskName in $installedTasks) {
    Write-Host "  [OK] $taskName" -ForegroundColor Green
}
Write-Host ""
Write-Host "Open Task Scheduler with: taskschd.msc" -ForegroundColor White
Write-Host ""
