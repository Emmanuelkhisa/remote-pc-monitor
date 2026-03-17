# Remote PC Monitor

Windows PowerShell monitoring scripts that send alerts and reports through Telegram.

## Features

- Login and failed-login alerts
- Event log tamper alerts
- Process launch and file access monitoring
- CPU, memory, disk, and network health checks
- Network adapter, IP, and VPN change detection
- Telegram bot commands for status, screenshot, processes, lock, shutdown, and restart
- Daily and weekly summary reports

## Quick Start

### 1. Create a Telegram bot

1. Open Telegram and search for `BotFather`.
2. Send `/newbot`.
3. Save the bot token.

### 2. Get your chat ID

1. Open Telegram and search for `userinfobot`.
2. Press Start.
3. Save the chat ID it returns.

### 3. Create `config.json`

```powershell
Copy-Item config.example.json config.json
notepad config.json
```

Use values like:

```json
{
  "botToken": "YOUR_BOT_TOKEN_HERE",
  "chatID": "YOUR_CHAT_ID_HERE",
  "cpuThreshold": 90,
  "memoryThreshold": 90,
  "diskThreshold": 90,
  "installPath": "C:\\path\\to\\Remote PC Monitor"
}
```

Users should not edit the task XML files manually. `installPath` is the single path source, and `setup_tasks.ps1` rewrites the XML files locally for each machine.

### 4. Enable Windows auditing

Run PowerShell as Administrator:

```powershell
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Process Creation" /success:enable
auditpol /set /subcategory:"Other Logon/Logoff Events" /success:enable /failure:enable
```

Optional:

```powershell
auditpol /set /subcategory:"File System" /success:enable
```

### 5. Set up and install tasks

Run PowerShell as Administrator in the project folder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\setup_tasks.ps1"
```

This will:

- Detect and persist `installPath`
- Refresh all task XML files with the current script path
- Install all six scheduled tasks under `SYSTEM`

The committed XML files in `tasks/` are templates. They intentionally ship with placeholder paths so forks and downloaded copies stay portable.

## Manual Test

Start the bot listener manually:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\bot_commands.ps1"
```

Then send these commands in Telegram:

- `/start`
- `/status`
- `/screenshot`
- `/processes`

## File Structure

```text
Remote PC Monitor/
|-- bot_commands.ps1
|-- daily_report.ps1
|-- event_monitor.ps1
|-- install_tasks.ps1
|-- network_monitor.ps1
|-- pc_monitor_common.ps1
|-- performance_monitor.ps1
|-- setup_tasks.ps1
|-- config.example.json
|-- config.json
|-- tasks/
|   |-- BotCommandsTask.xml
|   |-- DailyReportTask.xml
|   |-- EventMonitorTask.xml
|   |-- NetworkMonitorTask.xml
|   |-- PerformanceMonitorTask.xml
|   `-- WeeklyReportTask.xml
|-- README.md
`-- LICENSE
```

## Scripts

- `event_monitor.ps1`: Handles monitored Windows events and sends alerts.
- `performance_monitor.ps1`: Checks CPU, memory, disk, and connectivity thresholds.
- `network_monitor.ps1`: Detects adapter, IP, and VPN changes.
- `daily_report.ps1`: Sends daily or weekly summary reports.
- `bot_commands.ps1`: Polls Telegram for remote commands.
- `pc_monitor_common.ps1`: Shared config, Telegram, task, and installer helpers.

## Scheduled Tasks

- `Event Monitor`
- `Performance Monitor`
- `Network Monitor`
- `Daily Report`
- `Weekly Report`
- `Bot Commands`

## Setup Model

For GitHub users and forks, the supported setup flow is:

1. Clone or download the repository
2. Copy `config.example.json` to `config.json`
3. Fill in `botToken` and `chatID`
4. Leave `installPath` as the placeholder or set it explicitly
5. Run `setup_tasks.ps1` as Administrator

Do not manually edit the XML files in `tasks/`. `setup_tasks.ps1` localizes them automatically for the current machine.

## Troubleshooting

### No alerts

1. Verify `config.json` has the right bot token and chat ID.
2. Run `taskschd.msc` and confirm the `PC Monitor` tasks exist.
3. Confirm the `Logon` and `Other Logon/Logoff Events` audit subcategories are enabled.
4. Run a script manually with `powershell.exe -ExecutionPolicy Bypass -File ".\script_name.ps1"`.

### Bot commands do not respond

1. Start `bot_commands.ps1` manually.
2. Send `/start`.
3. Confirm the machine can reach `api.telegram.org`.

### Tasks do not install

1. Run PowerShell as Administrator.
2. Re-run `setup_tasks.ps1`.
3. Review the terminal output for the failing task name.

## Security Notes

- Protect `config.json`.
- Rotate the Telegram bot token if it is exposed.
- Review remote commands before using shutdown or restart actions.

## Changelog

### Version 2.0 - 2026-03-17

- Added multi-event monitoring
- Added Telegram bot commands
- Added performance monitoring
- Added network monitoring
- Added daily and weekly reports
- Removed legacy and duplicate installer scripts
- Consolidated shared logic into `pc_monitor_common.ps1`

### Version 1.0

- Basic login monitoring
