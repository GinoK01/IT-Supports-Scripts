@echo off
chcp 65001 >nul
title IT Support Master Script - Launcher

echo ========================================
echo     IT Support Master Script 
echo ========================================
echo.

:: Detect if PowerShell Core is available
where pwsh >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ PowerShell Core detected - Using pwsh.exe
    echo Running with PowerShell Core...
    echo.
    pwsh.exe -ExecutionPolicy Bypass -File "%~dp0master_script.ps1"
) else (
    echo ⚠ PowerShell Core not found - Trying with Windows PowerShell
    echo.
    
    :: Try with Windows PowerShell
    echo Running with Windows PowerShell...
    echo If an execution policy error appears, check the instructions.
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0master_script.ps1"
)

if %errorlevel% neq 0 (
    echo.
    echo ========================================
    echo ERROR: Could not run the script
    echo ========================================
    echo.
    echo RECOMMENDED SOLUTIONS:
    echo.
    echo 1. INSTALL POWERSHELL CORE ^(RECOMMENDED^):
    echo    - Download from: https://github.com/PowerShell/PowerShell/releases
    echo    - It's more modern and compatible
    echo.
    echo 2. RUN AS ADMINISTRATOR:
    echo    - Right-click on this file ^(.bat^)
    echo    - Select "Run as administrator"
    echo.
    echo 3. CONFIGURE POLICY MANUALLY:
    echo    - Open PowerShell as Administrator
    echo    - Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    echo.
    echo 4. USE INTEGRATED TERMINAL:
    echo    - Open a terminal in this folder
    echo    - Run: pwsh .\master_script.ps1
    echo    - Or: powershell -ExecutionPolicy Bypass .\master_script.ps1
    echo.
    echo ========================================
)

echo.
echo Press any key to exit...
pause >nul
