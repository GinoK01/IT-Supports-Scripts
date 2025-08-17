@echo off
chcp 65001 >nul
title Script Maestro IT Support - Launcher

echo ========================================
echo     Script Maestro IT Support 
echo ========================================
echo.

:: Detectar si PowerShell Core está disponible
where pwsh >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ PowerShell Core detectado - Usando pwsh.exe
    echo Ejecutando con PowerShell Core...
    echo.
    pwsh.exe -ExecutionPolicy Bypass -File "%~dp0master_script.ps1"
) else (
    echo ⚠ PowerShell Core no encontrado - Intentando con Windows PowerShell
    echo.
    
    :: Intentar con Windows PowerShell
    echo Ejecutando con Windows PowerShell...
    echo Si aparece un error de política de ejecución, consulte las instrucciones.
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0master_script.ps1"
)

if %errorlevel% neq 0 (
    echo.
    echo ========================================
    echo ERROR: No se pudo ejecutar el script
    echo ========================================
    echo.
    echo SOLUCIONES RECOMENDADAS:
    echo.
    echo 1. INSTALAR POWERSHELL CORE ^(RECOMENDADO^):
    echo    - Descargar desde: https://github.com/PowerShell/PowerShell/releases
    echo    - Es más moderno y compatible
    echo.
    echo 2. EJECUTAR COMO ADMINISTRADOR:
    echo    - Clic derecho en este archivo ^(.bat^)
    echo    - Seleccionar "Ejecutar como administrador"
    echo.
    echo 3. CONFIGURAR POLITICA MANUALMENTE:
    echo    - Abrir PowerShell como Administrador
    echo    - Ejecutar: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    echo.
    echo 4. USAR TERMINAL INTEGRADA:
    echo    - Abrir una terminal en esta carpeta
    echo    - Ejecutar: pwsh .\master_script.ps1
    echo    - O: powershell -ExecutionPolicy Bypass .\master_script.ps1
    echo.
    echo ========================================
)

echo.
echo Presiona cualquier tecla para salir...
pause >nul
