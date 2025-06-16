# Infraon DevLaunchPad
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
                Number   = $matches[1]
                Name     = $matches[2]
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
    
    Write-Host "`n=== Infraon DevLaunchPad ===" -ForegroundColor Cyan
    Write-Host "Available Applications:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($app in $Apps) {
        $letter = [char](96 + [int]$app.Number)  # Convert number to letter (1=a, 2=b, etc.)
        Write-Host "$letter) $($app.Name)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Instructions:" -ForegroundColor Yellow
    Write-Host "- Launch app(s): a" -ForegroundColor White
    Write-Host "- Launch multiple: a,b,c" -ForegroundColor White
    Write-Host "- Open in VS Code: vs a" -ForegroundColor White
    Write-Host "- Open multiple in VS Code: vs a,b,c" -ForegroundColor White
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
        }
        elseif ($cmd -match "\.\\venv\\Scripts\\activate" -or $cmd -match "venv\\Scripts\\activate") {
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
        # Define tab colors for different apps (cycling through colors)
        $tabColors = @("#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FECA57", "#FF9FF3", "#54A0FF", "#5F27CD")
        $colorIndex = ([int]$App.Number - 1) % $tabColors.Length
        $tabColor = $tabColors[$colorIndex]
        
        # Use Windows Terminal if available - create new tab in current window with custom color
        $wtArgs = @(
            "-w"
            "0"
            "new-tab"
            "--title"
            "`"$tabTitle`""
            "--tabColor"
            $tabColor
            "powershell.exe"
            "-NoExit"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$tempScript`""
        )
        Start-Process -FilePath $WindowsTerminalPath -ArgumentList $wtArgs
    }
    else {
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
        } } -ArgumentList $tempScript | Out-Null
}

function Open-InVSCode {
    param(
        [hashtable]$App
    )
    
    # Extract the first directory path from the app commands
    $projectPath = $null
    foreach ($cmd in $App.Commands) {
        if ($cmd.StartsWith("cd ")) {
            $projectPath = $cmd.Substring(3).Trim()
            break
        }
    }
    
    if (-not $projectPath) {
        Write-Host "No project directory found for $($App.Name)" -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path $projectPath)) {
        Write-Host "Project directory does not exist: $projectPath" -ForegroundColor Red
        return
    }
    
    # Open the project in VS Code using simple approach
    Write-Host "Opening $($App.Name) in VS Code..." -ForegroundColor Green
    Set-Location $projectPath
    & code .
}

function Get-VSCodePath {
    # Check if code command is available
    try {
        Get-Command code -ErrorAction Stop | Out-Null
        return "code"
    }
    catch {
        return $null
    }
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
    }
    catch {
        return $null
    }
}

function Main {
    # Get the script directory - handle different execution contexts
    if ($PSScriptRoot) {
        $scriptDir = $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    else {
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
    }
    else {
        Write-Host "Windows Terminal not found, will use regular PowerShell windows" -ForegroundColor Yellow
    }
    
    # Check VS Code availability
    $vsCodePath = Get-VSCodePath
    if ($vsCodePath) {
        Write-Host "VS Code found: $vsCodePath" -ForegroundColor Green
    }
    else {
        Write-Host "VS Code not found, VS Code features will be disabled" -ForegroundColor Yellow
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
        
        # Check if this is a VS Code command
        $isVSCodeCommand = $false
        $appSelection = $selection
        
        if ($selection.ToLower().StartsWith("vs ")) {
            if (-not $vsCodePath) {
                Write-Host "VS Code is not available. Please install VS Code first." -ForegroundColor Red
                continue
            }
            $isVSCodeCommand = $true
            $appSelection = $selection.Substring(3).Trim()
        }
        
        # Parse selection (can be single letter or comma-separated)
        $selectedLetters = $appSelection -split "," | ForEach-Object { $_.Trim().ToLower() }
        
        $processedCount = 0
        foreach ($letter in $selectedLetters) {
            # Convert letter back to number
            $appNumber = [int][char]$letter - 96
            
            # Find the app
            $selectedApp = $apps | Where-Object { [int]$_.Number -eq $appNumber }
            
            if ($selectedApp) {
                if ($isVSCodeCommand) {
                    Open-InVSCode -App $selectedApp
                }
                else {
                    Launch-App -App $selectedApp -WindowsTerminalPath $wtPath
                }
                $processedCount++
                Start-Sleep -Milliseconds 500  # Small delay between operations
            }
            else {
                Write-Host "Invalid selection: $letter" -ForegroundColor Red
            }
        }
        
        if ($processedCount -gt 0) {
            $action = if ($isVSCodeCommand) { "opened in VS Code" } else { "launched" }
            Write-Host "`n$processedCount app(s) $action. Press Enter to continue or 'q' to quit..." -ForegroundColor Yellow
        }
    }
}

# Run the main function
Main
