# Quick Setup Guide

This guide gets the project running with the supported install flow.

## Prerequisites

- Windows 10 or Windows 11
- Administrator access
- Telegram account
- Internet access

## 1. Create a Telegram bot

1. Open Telegram and search for `@BotFather`.
2. Send `/newbot`.
3. Save the bot token.

## 2. Get your chat ID

1. Search for `@userinfobot`.
2. Press Start.
3. Save the returned chat ID.

## 3. Configure the project

```powershell
Copy-Item config.example.json config.json
notepad config.json
```

Replace the placeholder values with your bot token and chat ID.
You can leave `installPath` as the placeholder value. The setup script will replace it with the current project folder automatically.

## 4. Enable auditing

Run PowerShell as Administrator:

```powershell
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Process Creation" /success:enable
auditpol /set /subcategory:"Other Logon/Logoff Events" /success:enable /failure:enable
```

## 5. Install the monitoring tasks

Run PowerShell as Administrator in the project directory:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\setup_tasks.ps1"
```

The script will:

- Detect and save the install path
- Refresh all task XML files
- Install the six supported scheduled tasks

Do not edit the XML files in `tasks/` manually. They are committed as templates and localized by `setup_tasks.ps1`.

## 6. Test the bot manually

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\bot_commands.ps1"
```

Then send:

1. `/start`
2. `/status`
3. `/screenshot`

## 7. Verify Task Scheduler

1. Press `Win + R`
2. Run `taskschd.msc`
3. Open `Task Scheduler Library > PC Monitor`
4. Confirm all six tasks exist and are enabled

## Troubleshooting

### Setup failed

1. Confirm `config.json` exists.
2. Confirm all `.ps1` files are still in the project directory.
3. Confirm `installPath` in `config.json` is correct or still a placeholder.
4. Re-run `setup_tasks.ps1` from an Administrator PowerShell window.

### Bot does not respond

1. Check `config.json`.
2. Start `bot_commands.ps1` manually.
3. Send `/start`.
4. Confirm network access to Telegram.

### Tasks do not run

1. Open `taskschd.msc`.
2. Run one task manually from the `PC Monitor` folder.
3. Check the task history and terminal output.
