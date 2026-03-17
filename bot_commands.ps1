. (Join-Path $PSScriptRoot "pc_monitor_common.ps1")

try {
    $config = Get-PcMonitorConfig -BasePath $PSScriptRoot
} catch {
    Write-Error $_
    exit 1
}

function Get-SystemStatus {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $uptime = (Get-Date) - $os.LastBootUpTime

    $memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $memFree = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $memUsed = [math]::Round($memTotal - $memFree, 2)
    $memPercent = [math]::Round(($memUsed / $memTotal) * 100, 1)

    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskTotal = [math]::Round($disk.Size / 1GB, 2)
    $diskFree = [math]::Round($disk.FreeSpace / 1GB, 2)
    $diskUsed = [math]::Round($diskTotal - $diskFree, 2)
    $diskPercent = [math]::Round(($diskUsed / $diskTotal) * 100, 1)

    return @"
[SYSTEM STATUS]

PC: $env:COMPUTERNAME
User: $env:USERNAME
OS: $($os.Caption)
Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m

CPU: $($cpu.Name)
Load: $([math]::Round((Get-CimInstance Win32_Processor).LoadPercentage, 1))%

Memory: $memUsed GB / $memTotal GB ($memPercent%)
Disk C: $diskUsed GB / $diskTotal GB ($diskPercent%)
"@
}

function Get-TopProcesses {
    $processes = Get-Process |
        Sort-Object @{ Expression = {
            if ($null -eq $_.CPU) {
                return 0
            }
            if ($_.CPU -is [TimeSpan]) {
                return $_.CPU.TotalSeconds
            }
            return [double]$_.CPU
        } } -Descending |
        Select-Object -First 10
    $output = "[TOP 10 PROCESSES BY CPU]`n`n"

    foreach ($proc in $processes) {
        if ($proc.CPU -is [TimeSpan]) {
            $cpu = [math]::Round($proc.CPU.TotalSeconds, 2)
        } elseif ($null -ne $proc.CPU) {
            $cpu = [math]::Round([double]$proc.CPU, 2)
        } else {
            $cpu = 0
        }
        $mem = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        $output += "$($proc.Name) - CPU: $cpu s, RAM: $mem MB`n"
    }

    return $output
}

function Get-Screenshot {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
        $screenshotPath = Join-Path $env:TEMP "screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
        $bitmap.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        return $screenshotPath
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Send-BotMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Send-PcMonitorTelegramMessage -Message $Message -Config $config
}

function Lock-PC {
    rundll32.exe user32.dll,LockWorkStation
}

function Shutdown-PC {
    Stop-Computer -Force
}

function Restart-PC {
    Restart-Computer -Force
}

$lastUpdateId = 0

Write-Host "[INFO] Bot command listener started. Press Ctrl+C to stop."
Write-Host "[INFO] Waiting for commands from Telegram..."

while ($true) {
    try {
        $url = "https://api.telegram.org/bot$($config.botToken)/getUpdates?offset=$($lastUpdateId + 1)&timeout=30"
        $updates = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop

        foreach ($update in $updates.result) {
            $lastUpdateId = $update.update_id

            if (-not $update.message -or "$($update.message.chat.id)" -ne "$($config.chatID)") {
                continue
            }

            $command = [string]$update.message.text
            if ([string]::IsNullOrWhiteSpace($command)) {
                continue
            }

            Write-Host "[CMD] Received: $command"

            switch -Regex ($command) {
                "^/start$" {
                    Send-BotMessage -Message "PC Monitor Bot Active`n`nAvailable commands:`n/status - System status`n/screenshot - Take screenshot`n/processes - Top processes`n/lock - Lock PC`n/shutdown - Shutdown PC`n/restart - Restart PC"
                }
                "^/status$" {
                    Send-BotMessage -Message (Get-SystemStatus)
                }
                "^/screenshot$" {
                    Send-BotMessage -Message "[INFO] Taking screenshot..."
                    $screenshotPath = $null
                    try {
                        $screenshotPath = Get-Screenshot
                        Send-PcMonitorTelegramPhoto -PhotoPath $screenshotPath -Config $config
                    } finally {
                        if ($screenshotPath -and (Test-Path -LiteralPath $screenshotPath)) {
                            Remove-Item -LiteralPath $screenshotPath -Force
                        }
                    }
                }
                "^/processes$" {
                    Send-BotMessage -Message (Get-TopProcesses)
                }
                "^/lock$" {
                    Send-BotMessage -Message "[EXECUTED] PC locked"
                    Lock-PC
                }
                "^/shutdown$" {
                    Send-BotMessage -Message "[EXECUTED] PC shutting down..."
                    Start-Sleep -Seconds 2
                    Shutdown-PC
                }
                "^/restart$" {
                    Send-BotMessage -Message "[EXECUTED] PC restarting..."
                    Start-Sleep -Seconds 2
                    Restart-PC
                }
                default {
                    if ($command -match "^/") {
                        Send-BotMessage -Message "[ERROR] Unknown command. Type /start for help."
                    }
                }
            }
        }
    } catch {
        Write-Error "Error in main loop: $($_.Exception.Message)"
        Start-Sleep -Seconds 5
    }
}
