# Dev Environment Launcher

A PowerShell script that parses your `apps.txt` file and launches selected development applications in separate tabs.

## Features

- Parse `apps.txt` to extract application information
- Display interactive menu of available apps
- Select single or multiple apps to launch
- Open each app in a separate PowerShell tab with custom title
- Works with Windows Terminal (preferred) or regular PowerShell windows

## Usage

### Method 1: Run the batch file
Double-click `launch.bat` or run it from command prompt:
```cmd
launch.bat
```

### Method 2: Run PowerShell script directly
```powershell
.\dev-launcher.ps1
```

### Method 3: From PowerShell with execution policy
```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\dev-launcher.ps1"
```

## How to Use

1. Run the launcher using one of the methods above
2. You'll see a menu with lettered options (a, b, c, etc.) corresponding to your apps
3. Select apps to launch:
   - Single app: Type `a` and press Enter
   - Multiple apps: Type `a,b,c` and press Enter
   - Quit: Type `q` and press Enter

## App Selection Examples

- Launch only "Infraon API": `a`
- Launch "Infraon API" and "Infraon UI": `a,c`
- Launch first 3 apps: `a,b,c`
- Launch all apps: `a,b,c,d,e,f,g,h`

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Windows Terminal (optional but recommended for better tab management)

## Notes

- Each app runs in its own tab with the app name as the title
- The script automatically detects if Windows Terminal is available
- If Windows Terminal is not found, it falls back to regular PowerShell windows
- There's a small delay between launching multiple apps to avoid conflicts

## Troubleshooting

If you get execution policy errors, run this command in PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
