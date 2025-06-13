# Dev Environment Launcher

Launch multiple development applications in separate tabs with a simple menu.

## How to Run

Double-click `launch.bat` or run in PowerShell:
```powershell
.\dev-launcher.ps1
```

Use the interactive menu:
- Launch single app: `a`
- Launch multiple apps: `a,b,c`
- Open in VS Code: `vs a` or `vs a,b,c`
- Quit: `q`

## How to Add a New App

Edit `apps.txt` and add your app using this format:

```
5. Your App Name
-------------------------------------
a. cd C:\path\to\your\project
b. npm start
```

**Format Rules:**
- Start with number and app name: `5. Your App Name`
- Add separator line: `-------------------------------------`
- List commands with letters: `a.`, `b.`, `c.`, etc.
- Commands run in sequence in the same terminal

**Example commands:**
- `cd path` - Change directory
- `npm start` - Run npm command
- `python manage.py runserver` - Run Python
- `.\venv\Scripts\activate` - Activate virtual environment
