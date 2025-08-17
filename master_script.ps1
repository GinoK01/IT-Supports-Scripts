# ====================================================================
# SCRIPT MAESTRO MULTIFUNCIONAL - CENTRO DE CONTROL PARA TÉCNICOS IT
# ====================================================================
#
# PROPÓSITO:
# Este es el script principal que da acceso a todas las herramientas de diagnóstico
# Funciona como un "centro de control" para técnicos de soporte
#
# CARACTERÍSTICAS:
# - Menú interactivo con todas las herramientas disponibles
# - Verificación automática de archivos y dependencias
# - Manejo inteligente de políticas de ejecución de Windows
# - Organizadas por categorías para fácil navegación
#
# CÓMO USAR:
# 1. Ejecutar este script desde PowerShell o usando ejecutar_master.bat
# 2. Seleccionar la herramienta necesaria según el problema del cliente
# 3. Los reportes se guardan automáticamente en logs_reports\
#
# IDEAL PARA:
# - Técnicos que prefieren menús interactivos
# - Cuando no estás seguro qué herramienta usar
# - Acceso centralizado a todas las funciones
# ====================================================================

# === MANEJO ROBUSTO DE POLÍTICAS DE EJECUCIÓN ===
# Esta función maneja los problemas más comunes con políticas de PowerShell
# Intenta múltiples métodos para permitir la ejecución de scripts
function Initialize-ExecutionPolicy {
    Write-Host "Verificando políticas de ejecución..." -ForegroundColor Yellow
    
    # Intentar configurar la política de ejecución con diferentes métodos
    # Del más restrictivo al menos restrictivo
    $methods = @(
        { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop },
        { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop },
        { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force -ErrorAction Stop }
    )
    
    $success = $false
    foreach ($method in $methods) {
        try {
            & $method
            Write-Host "✓ Política de ejecución configurada correctamente" -ForegroundColor Green
            $success = $true
            break
        } catch {
            continue  # Intentar el siguiente método
        }
    }
    
    # Si ningún método funcionó, mostrar ayuda detallada
    if (-not $success) {
        Write-Host ""
        Write-Host "⚠️  ADVERTENCIA: No se pudo configurar la política de ejecución" -ForegroundColor Red
        Write-Host "Esto puede causar problemas al ejecutar los scripts." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "SOLUCIONES RECOMENDADAS:" -ForegroundColor Cyan
        Write-Host "1. Ejecutar como Administrador:" -ForegroundColor White
        Write-Host "   - Clic derecho en PowerShell → 'Ejecutar como administrador'" -ForegroundColor Gray
        Write-Host "   - Navegar a esta carpeta y ejecutar: .\master_script.ps1" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Usar PowerShell Core (recomendado):" -ForegroundColor White
        Write-Host "   - Descargar desde: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. Configurar política manualmente (como Admin):" -ForegroundColor White
        Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
        Write-Host ""
        Write-Host "4. Usar el archivo .bat incluido (método alternativo)" -ForegroundColor White
        Write-Host ""
        
        $continue = Read-Host "¿Desea continuar de todos modos? (s/n)"
        if ($continue -notmatch '^[sS].*') {
            Write-Host "Saliendo del script..." -ForegroundColor Yellow
            exit 1
        }
    }
}

# ====================================================================
# CONFIGURACIÓN INICIAL Y VERIFICACIÓN DEL ENTORNO
# ====================================================================

# Detectar versión de PowerShell para mostrar información útil al técnico
$psVersion = $PSVersionTable.PSVersion.Major
$psEdition = $PSVersionTable.PSEdition

Write-Host "Sistema detectado:" -ForegroundColor Cyan
Write-Host "- PowerShell versión: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "- Edición: $psEdition" -ForegroundColor White
Write-Host "- SO: $($PSVersionTable.OS -split "`n" | Select-Object -First 1)" -ForegroundColor White

# Inicializar políticas de ejecución
Initialize-ExecutionPolicy

# Configurar soporte para caracteres especiales (acentos, ñ, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Definir rutas de trabajo
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath = Join-Path -Path $scriptPath -ChildPath "logs_reports"

# Crear carpeta de reportes si no existe
if (-not (Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

# ====================================================================
# FUNCIÓN: VERIFICAR QUE TODOS LOS SCRIPTS ESTÉN DISPONIBLES
# ====================================================================
# Esta función verifica que todas las herramientas estén presentes
# antes de mostrar el menú al técnico

function Test-ScriptExists {
    param($scriptName)
    
    $fullPath = Join-Path -Path $scriptPath -ChildPath $scriptName
    if (Test-Path -Path $fullPath) {
        return $true
    } else {
        Write-Host "ERROR: No se encuentra el script '$scriptName'" -ForegroundColor Red
        Write-Host "Ruta buscada: $fullPath" -ForegroundColor Yellow
        return $false
    }
}

# Función para mostrar el menú
function Show-Menu {
    Clear-Host
    Write-Host "========================================"
    Write-Host "       Script Maestro Multifuncional    " -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host "Sistema: $env:COMPUTERNAME | Usuario: $env:USERNAME"
    Write-Host "Directorio actual: $scriptPath"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "PARTE 1 - DIAGNÓSTICOS Y MANTENIMIENTO BÁSICO" -ForegroundColor Green
    Write-Host "1) Diagnóstico Simple (evaluación rápida)" -ForegroundColor White
    Write-Host "2) Diagnóstico Completo (análisis exhaustivo)" -ForegroundColor White
    Write-Host "3) Backups de Carpetas Críticas" -ForegroundColor White
    Write-Host "4) Recuperación de Archivos Eliminados" -ForegroundColor White
    Write-Host "5) Limpieza y Mantenimiento del Sistema" -ForegroundColor White
    Write-Host ""
    Write-Host "PARTE 2 - DIAGNÓSTICOS ESPECÍFICOS" -ForegroundColor Yellow
    Write-Host "6) Inventario de Hardware y Software" -ForegroundColor White
    Write-Host "7) Validación de Configuración de Usuario" -ForegroundColor White
    Write-Host "8) Escaneo de Seguridad Básico" -ForegroundColor White
    Write-Host "9) Diagnóstico de Red" -ForegroundColor White
    Write-Host "10) Diagnóstico de Rendimiento" -ForegroundColor White
    Write-Host ""
    Write-Host "0) Salir" -ForegroundColor Red
    Write-Host "========================================"
}

# Función para ejecutar tareas
function Execute-Task($choice) {
    # Importar ErrorHandler antes de ejecutar cualquier script
    $errorHandlerPath = Join-Path -Path $scriptPath -ChildPath "ErrorHandler.ps1"
    if (Test-Path $errorHandlerPath) {
        . $errorHandlerPath
        Write-Host "✓ ErrorHandler cargado correctamente" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Advertencia: ErrorHandler.ps1 no encontrado" -ForegroundColor Yellow
    }

    switch ($choice) {
        1 { 
            # Diagnóstico Simple
            $script = "quick_assessment.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Diagnóstico Simple..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        2 { 
            # Diagnóstico Completo
            $script = "diagnostico_completo.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Diagnóstico Completo..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        3 { 
            # Backups
            $script = "backups.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Backup de Carpetas Críticas..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        4 { 
            # Recuperación de Archivos
            $script = "recuperacion_archivos.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Recuperación de Archivos..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        5 { 
            # Limpieza y Mantenimiento
            $script = "limpieza_mantenimiento.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Limpieza y Mantenimiento..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        6 { 
            # Inventario
            $script = "inventario_hw_sw.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Inventario de Hardware y Software..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        7 { 
            # Validación de Usuario
            $script = "validacion_usuario.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Validación de Usuario..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        8 { 
            # Escaneo de Seguridad
            $script = "escaneo_seguridad.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Escaneo de Seguridad..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        9 { 
            # Diagnóstico de Red
            $script = "diagnostico_red.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Diagnóstico de Red..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        10 { 
            # Diagnóstico de Rendimiento
            $script = "diagnostico_rendimiento.ps1"
            if (Test-ScriptExists $script) {
                Write-Host "Ejecutando Diagnóstico de Rendimiento..." -ForegroundColor Green
                try {
                    . "$scriptPath\$script"
                } catch {
                    Write-Host "Error ejecutando $script`: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Show-ScriptMissing $script
            }
        }
        0 { 
            Write-Host "Saliendo del script maestro..." -ForegroundColor Green
            exit 
        }
        default { 
            Write-Host "Opción inválida. Por favor intenta nuevamente." -ForegroundColor Red 
            Start-Sleep -Seconds 2
        }
    }
}

# Función para mostrar mensaje cuando falta un script
function Show-ScriptMissing($scriptName) {
    Write-Host ""
    Write-Host "===================== ATENCIÓN =====================" -ForegroundColor Red
    Write-Host "El script '$scriptName' no se encuentra en la carpeta actual." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Para resolver este problema:" -ForegroundColor White
    Write-Host "1. Asegúrate de que todos los scripts están en la misma carpeta:"
    Write-Host "   $scriptPath"
    Write-Host "2. Verifica que el nombre del archivo sea exactamente: $scriptName"
    Write-Host "3. Si necesitas descargar los scripts, visita:"
    Write-Host "   https://github.com/GinoK01/IT-Support-Scripts"
    Write-Host "=====================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Presiona cualquier tecla para continuar..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main loop
while ($true) {
    Show-Menu
    Write-Host "Por favor selecciona una opción [0-10]: " -ForegroundColor Cyan -NoNewline
    $choice = Read-Host
    
    # Validar entrada
    if ($choice -match '^(0|[1-9]|10)$') {
        Execute-Task $choice
        
        # Pausa para ver los resultados antes de volver al menú (excepto al salir)
        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "Presiona cualquier tecla para volver al menú principal..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } else {
        Write-Host "Entrada inválida. Por favor introduce un número del 0 al 10." -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}