# Common helpers for PC Monitor scripts.

Set-StrictMode -Version 3
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-PcMonitorConfigPath {
    [CmdletBinding()]
    param(
        [string]$BasePath = $PSScriptRoot
    )

    return Join-Path $BasePath "config.json"
}

function Get-PcMonitorConfig {
    [CmdletBinding()]
    param(
        [string]$BasePath = $PSScriptRoot
    )

    $configPath = Get-PcMonitorConfigPath -BasePath $BasePath
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    try {
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "Failed to read configuration: $($_.Exception.Message)"
    }

    foreach ($requiredProperty in @("botToken", "chatID")) {
        if (-not ($config.PSObject.Properties.Name -contains $requiredProperty) -or [string]::IsNullOrWhiteSpace($config.$requiredProperty)) {
            throw "Missing required configuration value: $requiredProperty"
        }
    }

    return $config
}

function Save-PcMonitorConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Config,
        [string]$BasePath = $PSScriptRoot
    )

    $configPath = Get-PcMonitorConfigPath -BasePath $BasePath
    $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
    return $configPath
}

function Get-PcMonitorInstallPath {
    [CmdletBinding()]
    param(
        [string]$BasePath = $PSScriptRoot,
        [switch]$Persist
    )

    $config = Get-PcMonitorConfig -BasePath $BasePath
    $installPath = $config.installPath

    if ([string]::IsNullOrWhiteSpace($installPath)) {
        $installPath = [System.IO.Path]::GetFullPath($BasePath)
        if ($Persist) {
            if ($config.PSObject.Properties.Name -contains "installPath") {
                $config.installPath = $installPath
            } else {
                $config | Add-Member -NotePropertyName "installPath" -NotePropertyValue $installPath
            }
            Save-PcMonitorConfig -Config $config -BasePath $BasePath | Out-Null
        }
    }

    return [System.IO.Path]::GetFullPath($installPath)
}

function Send-PcMonitorTelegramMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [psobject]$Config
    )

    $url = "https://api.telegram.org/bot$($Config.botToken)/sendMessage"
    $body = @{
        chat_id = "$($Config.chatID)"
        text    = $Message
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json; charset=utf-8" -ErrorAction Stop | Out-Null
}

function Send-PcMonitorTelegramPhoto {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PhotoPath,
        [Parameter(Mandatory = $true)]
        [psobject]$Config,
        [string]$Caption = ""
    )

    if (-not (Test-Path -LiteralPath $PhotoPath)) {
        throw "Photo file not found: $PhotoPath"
    }

    Add-Type -AssemblyName System.Net.Http

    $handler = New-Object System.Net.Http.HttpClientHandler
    $client = New-Object System.Net.Http.HttpClient($handler)

    try {
        $content = New-Object System.Net.Http.MultipartFormDataContent
        $content.Add((New-Object System.Net.Http.StringContent("$($Config.chatID)")), "chat_id")
        if (-not [string]::IsNullOrWhiteSpace($Caption)) {
            $content.Add((New-Object System.Net.Http.StringContent($Caption)), "caption")
        }

        $resolvedPhotoPath = (Resolve-Path -LiteralPath $PhotoPath).Path
        $bytes = [System.IO.File]::ReadAllBytes($resolvedPhotoPath)
        $fileContent = [System.Net.Http.ByteArrayContent]::new($bytes)
        $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
        $content.Add($fileContent, "photo", [System.IO.Path]::GetFileName($PhotoPath))

        $response = $client.PostAsync("https://api.telegram.org/bot$($Config.botToken)/sendPhoto", $content).GetAwaiter().GetResult()
        [void]$response.EnsureSuccessStatusCode()
    } finally {
        if ($response) {
            $response.Dispose()
        }
        if ($content) {
            $content.Dispose()
        }
        if ($client) {
            $client.Dispose()
        }
        if ($handler) {
            $handler.Dispose()
        }
    }
}

function Test-PcMonitorAdministrator {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PcMonitorTaskDefinitions {
    [CmdletBinding()]
    param()

    return @(
        @{
            Name = "EventMonitorTask.xml"
            TaskName = "PC Monitor\Event Monitor"
            Script = "event_monitor.ps1"
            Arguments = ""
        },
        @{
            Name = "PerformanceMonitorTask.xml"
            TaskName = "PC Monitor\Performance Monitor"
            Script = "performance_monitor.ps1"
            Arguments = ""
        },
        @{
            Name = "NetworkMonitorTask.xml"
            TaskName = "PC Monitor\Network Monitor"
            Script = "network_monitor.ps1"
            Arguments = ""
        },
        @{
            Name = "DailyReportTask.xml"
            TaskName = "PC Monitor\Daily Report"
            Script = "daily_report.ps1"
            Arguments = "-ReportType daily"
        },
        @{
            Name = "WeeklyReportTask.xml"
            TaskName = "PC Monitor\Weekly Report"
            Script = "daily_report.ps1"
            Arguments = "-ReportType weekly"
        },
        @{
            Name = "BotCommandsTask.xml"
            TaskName = "PC Monitor\Bot Commands"
            Script = "bot_commands.ps1"
            Arguments = "-WindowStyle Hidden"
        }
    )
}

function Test-PcMonitorRequiredScripts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallPath
    )

    $missingScripts = @()
    foreach ($task in Get-PcMonitorTaskDefinitions) {
        $scriptPath = Join-Path $InstallPath $task.Script
        if (-not (Test-Path -LiteralPath $scriptPath)) {
            $missingScripts += $task.Script
        }
    }

    return $missingScripts | Sort-Object -Unique
}

function Get-PcMonitorTaskCommandArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Task
    )

    $scriptPath = Join-Path $InstallPath $Task.Script
    $parts = @()

    if (-not [string]::IsNullOrWhiteSpace($Task.Arguments)) {
        $parts += $Task.Arguments.Trim()
    }

    $parts += "-ExecutionPolicy Bypass"
    $parts += "-File `"$scriptPath`""

    return ($parts -join " ").Trim()
}

function Sync-PcMonitorTaskXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        [Parameter(Mandatory = $true)]
        [string]$InstallPath
    )

    $tasksDir = Join-Path $BasePath "tasks"
    if (-not (Test-Path -LiteralPath $tasksDir)) {
        throw "Tasks directory not found: $tasksDir"
    }

    $updated = @()
    $namespaceUri = "http://schemas.microsoft.com/windows/2004/02/mit/task"

    foreach ($task in Get-PcMonitorTaskDefinitions) {
        $xmlPath = Join-Path $tasksDir $task.Name
        if (-not (Test-Path -LiteralPath $xmlPath)) {
            throw "Task XML file not found: $xmlPath"
        }

        $xmlDocument = Open-PcMonitorTaskXml -Path $xmlPath

        $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xmlDocument.NameTable)
        $namespaceManager.AddNamespace("task", $namespaceUri)

        $commandNode = $xmlDocument.SelectSingleNode("/task:Task/task:Actions/task:Exec/task:Command", $namespaceManager)
        $argumentsNode = $xmlDocument.SelectSingleNode("/task:Task/task:Actions/task:Exec/task:Arguments", $namespaceManager)

        if (-not $commandNode -or -not $argumentsNode) {
            throw "Task XML is missing Exec nodes: $xmlPath"
        }

        $commandNode.InnerText = "powershell.exe"
        $argumentsNode.InnerText = Get-PcMonitorTaskCommandArguments -InstallPath $InstallPath -Task $task

        $writerSettings = New-Object System.Xml.XmlWriterSettings
        $writerSettings.Encoding = [System.Text.UnicodeEncoding]::new($false, $true)
        $writerSettings.Indent = $true
        $writerSettings.NewLineChars = "`r`n"
        $writerSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

        $writer = [System.Xml.XmlWriter]::Create($xmlPath, $writerSettings)
        try {
            $xmlDocument.Save($writer)
        } finally {
            $writer.Dispose()
        }

        $updated += $task.Name
    }

    return $updated
}

function Open-PcMonitorTaskXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $xmlDocument = New-Object System.Xml.XmlDocument
    $xmlDocument.PreserveWhitespace = $true

    try {
        $xmlDocument.Load($Path)
        return $xmlDocument
    } catch {
        $encodings = @(
            [System.Text.Encoding]::Unicode,
            [System.Text.Encoding]::UTF8,
            [System.Text.Encoding]::Default
        )

        foreach ($encoding in $encodings) {
            try {
                $content = [System.IO.File]::ReadAllText($Path, $encoding)
                $xmlDocument = New-Object System.Xml.XmlDocument
                $xmlDocument.PreserveWhitespace = $true
                $xmlDocument.LoadXml($content)
                return $xmlDocument
            } catch {
            }
        }

        throw "Failed to open task XML: $Path"
    }
}

function Install-PcMonitorTasks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    $tasksDir = Join-Path $BasePath "tasks"
    $results = @()

    foreach ($task in Get-PcMonitorTaskDefinitions) {
        $xmlPath = Join-Path $tasksDir $task.Name
        if (-not (Test-Path -LiteralPath $xmlPath)) {
            throw "Task XML file not found: $xmlPath"
        }

        & schtasks /query /tn $task.TaskName 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            & schtasks /delete /tn $task.TaskName /f | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to remove existing task: $($task.TaskName)"
            }
        }

        $output = & schtasks /create /tn $task.TaskName /xml $xmlPath /ru SYSTEM 2>&1
        if ($LASTEXITCODE -ne 0) {
            $detail = ($output | Out-String).Trim()
            if ([string]::IsNullOrWhiteSpace($detail)) {
                $detail = "Unknown schtasks error"
            }
            throw "Failed to install $($task.TaskName): $detail"
        }

        $results += $task.TaskName
    }

    return $results
}
