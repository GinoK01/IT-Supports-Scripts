# ====================================================================
# MULTIFUNCTIONAL MASTER SCRIPT - CONTROL CENTER FOR IT TECHNICIANS
# ====================================================================
#
# PURPOSE:
# This is the main script that gives access to all diagnostic tools.
# It works as a "control center" for support technicians
#
# FEATURES:
# - Interactive menu with all available tools
# - Automatic file and dependency checking
# - Smart handling of Windows execution policies
# - Organized by categories for easy navigation
#
# HOW TO USE:
# 1. Run this script from PowerShell or using ejecutar_master.bat
# 2. Select the needed tool according to the client's problem
# 3. Reports are automatically saved in logs_reports\
#
# GREAT FOR:
# - Technicians who prefer interactive menus
# - When you're not sure which tool to use
# - Centralized access to all functions
# ====================================================================

# === ROBUST EXECUTION POLICY HANDLING ===
# This function handles the most common problems with PowerShell policies
# It tries multiple methods to allow script execution
function Initialize-ExecutionPolicy {
    Write-Host "Checking execution policies..." -ForegroundColor Yellow
    
    # Try to configure execution policy with different methods
    # From most restrictive to least restrictive
    $methods = @(
        { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop },
        { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop },
        { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force -ErrorAction Stop }
    )
    
    $success = $false
    foreach ($method in $methods) {
        try {
            & $method
            Write-Host "Execution policy configured correctly" -ForegroundColor Green
            $success = $true
            break
        } catch {
            continue  # Try the next method
        }
    }
    
    # If no method worked, show detailed help
    if (-not $success) {
        Write-Host ""
        Write-Host "WARNING: Could not configure execution policy" -ForegroundColor Red
        Write-Host "This may cause problems when running scripts." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDED SOLUTIONS:" -ForegroundColor Cyan
        Write-Host "1. Run as Administrator:" -ForegroundColor White
        Write-Host "   - Right-click on PowerShell → 'Run as administrator'" -ForegroundColor Gray
        Write-Host "   - Navigate to this folder and run: .\master_script.ps1" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Use PowerShell Core (recommended):" -ForegroundColor White
        Write-Host "   - Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. Configure policy manually (as Admin):" -ForegroundColor White
        Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
        Write-Host ""
        Write-Host "4. Use the included .bat file (alternative method)" -ForegroundColor White
        Write-Host ""
        
        $continue = Read-Host "Do you want to continue anyway? (y/n)"
        if ($continue -notmatch '^[yY].*') {
            Write-Host "Exiting script..." -ForegroundColor Yellow
            exit 1
        }
    }
}

# ====================================================================
# INITIAL SETUP AND ENVIRONMENT VERIFICATION
# ====================================================================

# Detect PowerShell version to show useful information to the technician
$psVersion = $PSVersionTable.PSVersion.Major
$psEditionInfo = $PSVersionTable.PSEdition

Write-Host "System detected:" -ForegroundColor Cyan
Write-Host "- PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "- Edition: $psEditionInfo" -ForegroundColor White
Write-Host "- OS: $($PSVersionTable.OS -split "`n" | Select-Object -First 1)" -ForegroundColor White

# Initialize execution policies
Initialize-ExecutionPolicy

# Configure support for special characters (accents, ñ, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Define working paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath = Join-Path -Path $scriptPath -ChildPath "logs_reports"

# Create reports folder if it doesn't exist
if (-not (Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

# ====================================================================
# FUNCTION: CHECK THAT ALL SCRIPTS ARE AVAILABLE
# ====================================================================
# This function verifies that all tools are present
# before showing the menu to the technician

function Test-ScriptExists {
    param($scriptName)
    
    $fullPath = Join-Path -Path $scriptPath -ChildPath $scriptName
    if (Test-Path -Path $fullPath) {
        return $true
    } else {
        Write-Host "ERROR: Script '$scriptName' not found" -ForegroundColor Red
        Write-Host "Path searched: $fullPath" -ForegroundColor Yellow
        return $false
    }
}

# Function to show the menu
function Show-Menu {
    Clear-Host
    Write-Host "========================================"
    Write-Host "       Multifunctional Master Script    " -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host "System: $env:COMPUTERNAME | User: $env:USERNAME"
    Write-Host "Current directory: $scriptPath"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "PART 1 - BASIC DIAGNOSTICS AND MAINTENANCE" -ForegroundColor Green
    Write-Host "1) Simple Diagnosis (quick evaluation)" -ForegroundColor White
    Write-Host "2) Complete Diagnosis (exhaustive analysis)" -ForegroundColor White
    Write-Host "3) Critical Folders Backup" -ForegroundColor White
    Write-Host "4) Deleted Files Recovery" -ForegroundColor White
    Write-Host "5) System Cleanup and Maintenance" -ForegroundColor White
    Write-Host ""
    Write-Host "PART 2 - SPECIFIC DIAGNOSTICS" -ForegroundColor Yellow
    Write-Host "6) Hardware and Software Inventory" -ForegroundColor White
    Write-Host "7) User Configuration Validation" -ForegroundColor White
    Write-Host "8) Basic Security Scan" -ForegroundColor White
    Write-Host "9) Network Diagnosis" -ForegroundColor White
    Write-Host "10) Performance Diagnosis" -ForegroundColor White
    Write-Host ""
    Write-Host "0) Exit" -ForegroundColor Red
    Write-Host "========================================"
}

# Function to execute tasks
function Execute-Task($choice) {
    # Import ErrorHandler before executing any script
    $errorHandlerPath = Join-Path -Path $scriptPath -ChildPath "ErrorHandler.ps1"
    if (Test-Path $errorHandlerPath) {
        . $errorHandlerPath
        Write-Host "ErrorHandler loaded correctly" -ForegroundColor Green
    } else {
        Write-Host "Warning: ErrorHandler.ps1 not found" -ForegroundColor Yellow
    }

    switch ($choice) {
        1 { 
            # Simple Diagnosis
            $script = "quick_assessment.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Simple Diagnosis..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        2 { 
            # Complete Diagnosis
            $script = "diagnostico_completo.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Complete Diagnosis..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        3 { 
            # Backups
            $script = "backups.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Critical Folders Backup..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        4 { 
            # File Recovery
            $script = "recuperacion_archivos.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running File Recovery..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        5 { 
            # Cleanup and Maintenance
            $script = "limpieza_mantenimiento.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Cleanup and Maintenance..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        6 { 
            # Inventory
            $script = "inventario_hw_sw.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Hardware and Software Inventory..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        7 { 
            # User Validation
            $script = "validacion_usuario.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running User Validation..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        8 { 
            # Security Scan
            $script = "escaneo_seguridad.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Security Scan..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        9 { 
            # Network Diagnosis
            $script = "diagnostico_red.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Network Diagnosis..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        10 { 
            # Performance Diagnosis
            $script = "diagnostico_rendimiento.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Running Performance Diagnosis..." -ForegroundColor Green
                try {
                    $scriptFullPath = Join-Path -Path $scriptPath -ChildPath $script
                    Write-Host "Executing: $scriptFullPath" -ForegroundColor Cyan
                    & "$scriptFullPath"
                } catch {
                    Write-Host ("Error running " + $script + ": " + $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        0 { 
            Write-Host "Exiting master script..." -ForegroundColor Green
            exit 
        }
        default { 
            Write-Host "Invalid option. Please try again." -ForegroundColor Red 
            Start-Sleep -Seconds 2
        }
    }
}

# Function to show message when a script is missing
function Show-ScriptMissing($scriptName) {
    Write-Host ""
    Write-Host "===================== ATTENTION =====================" -ForegroundColor Red
    Write-Host "The script '$scriptName' is not found in the current folder." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To solve this problem:" -ForegroundColor White
    Write-Host "1. Make sure all scripts are in the same folder:"
    Write-Host "   $scriptPath"
    Write-Host "2. Check that the file name is exactly: $scriptName"
    Write-Host "3. If you need to download the scripts, visit:"
    Write-Host "   https://github.com/GinoK01/IT-Support-Scripts"
    Write-Host "=====================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main loop
while ($true) {
    Show-Menu
    Write-Host "Please select an option [0-10]: " -ForegroundColor Cyan -NoNewline
    $choice = Read-Host
    
    # Validate input
    if ($choice -match '^(0|[1-9]|10)$') {
        Execute-Task $choice
        
        # Pause to see results before returning to menu (except when exiting)
        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "Press any key to return to main menu..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } else {
        Write-Host "Invalid input. Please enter a number from 0 to 10." -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}