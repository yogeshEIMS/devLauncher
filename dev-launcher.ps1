# Dev Environment Launcher
# Parses apps.txt and launches selected applications in separate PowerShell tabs

function Parse-AppsFile {
    param([string]$FilePath)
    
    $apps = @()
    $currentApp = $null
    
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comment lines
        if ($line -eq "" -or $line.StartsWith("//")) {
            return
        }
        
        # Check if line starts with a number (new app)
        if ($line -match "^(\d+)\.\s*(.+)$") {
            # Save previous app if exists
            if ($currentApp) {
                $apps += $currentApp
            }
            
            # Start new app
            $currentApp = @{
                Number = $matches[1]
                Name = $matches[2]
                Commands = @()
            }
        }
        elseif ($line.StartsWith("-----")) {
            # Skip separator lines
            return
        }
        elseif ($line -match "^[a-z]\.\s*(.+)$") {
            # Command line (a., b., c., etc.)
            if ($currentApp) {
                $currentApp.Commands += $matches[1]
            }
        }
    }
    
    # Add the last app
    if ($currentApp) {
        $apps += $currentApp
    }
    
    return $apps
}

function Show-AppMenu {
    param([array]$Apps)
    
    Write-Host "`n=== Dev Environment Launcher ===" -ForegroundColor Cyan
    Write-Host "Available Applications:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($app in $Apps) {
        $letter = [char](96 + [int]$app.Number)  # Convert number to letter (1=a, 2=b, etc.)
        Write-Host "$letter) $($app.Name)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Instructions:" -ForegroundColor Yellow
    Write-Host "- Select single app: a" -ForegroundColor White
    Write-Host "- Select multiple apps: a,b,c" -ForegroundColor White
    Write-Host "- Type 'q' to quit" -ForegroundColor White
    Write-Host ""
}

function Launch-App {
    param(
        [hashtable]$App,
        [string]$WindowsTerminalPath
    )
    
    # Build a proper PowerShell script that executes commands sequentially
    $scriptCommands = @()
    
    foreach ($cmd in $App.Commands) {
        # Handle different types of commands
        if ($cmd.StartsWith("cd ")) {
            # Change directory command
            $scriptCommands += "Set-Location '$($cmd.Substring(3).Trim())'"
        }        elseif ($cmd -match "\.\\venv\\Scripts\\activate" -or $cmd -match "venv\\Scripts\\activate") {
            # Virtual environment activation - try PowerShell first, then batch file
            $scriptCommands += @"
if (Test-Path '.\venv\Scripts\Activate.ps1') {
    & '.\venv\Scripts\Activate.ps1'
    Write-Host 'Virtual environment activated (PowerShell)' -ForegroundColor Green
} elseif (Test-Path '.\venv\Scripts\activate.bat') {
    cmd /c '.\venv\Scripts\activate.bat && powershell'
    Write-Host 'Virtual environment activated (Batch)' -ForegroundColor Green
} else {
    Write-Host 'Warning: Virtual environment activation script not found' -ForegroundColor Yellow
}
"@
        }
        elseif ($cmd.StartsWith(".\celery_worker.bat") -or $cmd.StartsWith(".\celery_beat.bat")) {
            # Batch file execution
            $scriptCommands += "& '$cmd'"
        }
        else {
            # Regular command
            $scriptCommands += $cmd
        }
    }
    
    # Create the full command sequence with proper error handling
    $fullScript = @"
try {
    `$Host.UI.RawUI.WindowTitle = '$($App.Name)'
    Write-Host 'Starting $($App.Name)...' -ForegroundColor Green
    Write-Host '===========================================' -ForegroundColor Cyan
    
$($scriptCommands -join "`n    ")
    
    Write-Host '===========================================' -ForegroundColor Cyan
    Write-Host '$($App.Name) commands completed.' -ForegroundColor Green
} catch {
    Write-Host 'Error occurred: ' -ForegroundColor Red -NoNewline
    Write-Host `$_.Exception.Message -ForegroundColor Yellow
}
"@
    
    # Create a temporary script file to avoid command line length issues
    $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
    $fullScript | Out-File -FilePath $tempScript -Encoding UTF8
    
    # Launch new PowerShell tab with the script
    $tabTitle = $App.Name
    
    if ($WindowsTerminalPath -and (Test-Path $WindowsTerminalPath)) {
        # Use Windows Terminal if available
        $wtArgs = @(
            "new-tab"
            "--title"
            "`"$tabTitle`""
            "powershell.exe"
            "-NoExit"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$tempScript`""
        )
        Start-Process -FilePath $WindowsTerminalPath -ArgumentList $wtArgs
    } else {
        # Fallback to regular PowerShell window
        $psArgs = @(
            "-NoExit"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$tempScript`""
        )
        Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs
    }
    
    Write-Host "Launched: $tabTitle" -ForegroundColor Green
    
    # Clean up temp script after a delay (in background)
    Start-Job -ScriptBlock {
        param($scriptPath)
        Start-Sleep -Seconds 10
        if (Test-Path $scriptPath) {
            Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        }
    } -ArgumentList $tempScript | Out-Null
}

function Get-WindowsTerminalPath {
    # Try to find Windows Terminal
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.WindowsTerminal*\wt.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Check if wt.exe is in PATH
    try {
        $wtPath = Get-Command wt.exe -ErrorAction Stop
        return $wtPath.Source
    } catch {
        return $null
    }
}

function Main {
    # Get the script directory - handle different execution contexts
    if ($PSScriptRoot) {
        $scriptDir = $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $scriptDir = Get-Location
    }
    
    $appsFile = Join-Path $scriptDir "apps.txt"
    
    if (-not (Test-Path $appsFile)) {
        Write-Error "apps.txt file not found in $scriptDir"
        return
    }
    
    # Parse the apps file
    $apps = Parse-AppsFile -FilePath $appsFile
    
    if ($apps.Count -eq 0) {
        Write-Error "No apps found in apps.txt"
        return
    }
    
    # Get Windows Terminal path
    $wtPath = Get-WindowsTerminalPath
    if ($wtPath) {
        Write-Host "Windows Terminal found: $wtPath" -ForegroundColor Green
    } else {
        Write-Host "Windows Terminal not found, will use regular PowerShell windows" -ForegroundColor Yellow
    }
    
    while ($true) {
        Show-AppMenu -Apps $apps
        
        $selection = Read-Host "Select app(s) to launch"
        
        if ($selection -eq "q" -or $selection -eq "quit") {
            Write-Host "Goodbye!" -ForegroundColor Cyan
            break
        }
        
        if ($selection -eq "") {
            continue
        }
        
        # Parse selection (can be single letter or comma-separated)
        $selectedLetters = $selection -split "," | ForEach-Object { $_.Trim().ToLower() }
        
        $launchedCount = 0
        foreach ($letter in $selectedLetters) {
            # Convert letter back to number
            $appNumber = [int][char]$letter - 96
            
            # Find the app
            $selectedApp = $apps | Where-Object { [int]$_.Number -eq $appNumber }
            
            if ($selectedApp) {
                Launch-App -App $selectedApp -WindowsTerminalPath $wtPath
                $launchedCount++
                Start-Sleep -Milliseconds 500  # Small delay between launches
            } else {
                Write-Host "Invalid selection: $letter" -ForegroundColor Red
            }
        }
        
        if ($launchedCount -gt 0) {
            Write-Host "`nLaunched $launchedCount app(s). Press Enter to continue or 'q' to quit..." -ForegroundColor Yellow
        }
    }
}

# Run the main function
Main
