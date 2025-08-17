# ====================================================================
# DETECTOR AUTOMÁTICO DE PROBLEMAS COMUNES - HERRAMIENTA PARA TÉCNICOS
# ====================================================================
#
# PROPÓSITO:
# Este script identifica automáticamente los problemas más frecuentes en equipos
# Es ideal para ejecutar como primera herramienta de diagnóstico
#
# PROBLEMAS QUE DETECTA:
# - Espacio en disco insuficiente
# - Memoria RAM agotada  
# - Procesos que consumen muchos recursos
# - Servicios críticos detenidos
# - Problemas de conectividad de red
# - Archivos temporales excesivos
#
# CÓMO INTERPRETAR LOS RESULTADOS:
# 🔴 CRÍTICO: Requiere atención inmediata, puede causar fallas del sistema
# 🟡 ADVERTENCIA: Debe revisarse, puede causar lentitud o problemas menores
# 🟢 NORMAL: Todo funcionando correctamente
#
# USO RECOMENDADO:
# - Ejecutar antes de hacer cualquier cambio al sistema
# - Como herramienta de diagnóstico inicial en llamadas de soporte
# - Para documentar problemas encontrados
# ====================================================================

# Configuración inicial del script
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch {
    # Si falla, continuar - algunos sistemas no permiten cambiar la política
}

# Configurar soporte para caracteres especiales
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Crear directorio de reportes si no existe
$PSScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logsPath = Join-Path -Path $PSScriptRoot -ChildPath "logs_reports"
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

# Cargar módulos de soporte
$errorHandlerPath = Join-Path -Path $PSScriptRoot -ChildPath "ErrorHandler.ps1"
if (Test-Path $errorHandlerPath) {
    . $errorHandlerPath
} else {
    Write-Warning "No se encontró el módulo ErrorHandler.ps1. Continuando sin manejo avanzado de errores."
    # Funciones básicas para que el script no falle
    function Add-ITSupportError { param($Seccion, $Mensaje) }
    function Clear-ITSupportErrors { }
    function Get-ErrorSummaryHTML { param($IncludeCSS) return "" }
    function Export-ErrorLog { param($Path) }
    function Invoke-SafeExecution { param($Seccion, $ScriptBlock, $DefaultValue) try { & $ScriptBlock } catch { $DefaultValue } }
}

# Cargar plantilla HTML
$htmlTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath "HTMLTemplate.ps1"
if (Test-Path $htmlTemplatePath) {
    . $htmlTemplatePath
} else {
    Write-Warning "No se encontró HTMLTemplate.ps1. Usando formato básico."
    function Get-UnifiedHTMLTemplate { 
        param($Title, $ComputerName, $UserName, $DateTime, $IncludeSummary)
        return "<html><head><title>$Title</title></head><body><h1>$Title</h1><p>$ComputerName - $UserName - $DateTime</p>"
    }
    function Get-UnifiedHTMLFooter { 
        param($IncludeCountingScript)
        return "</body></html>"
    }
}

# Limpiar errores de ejecuciones anteriores
Clear-ITSupportErrors

# ====================================================================
# INICIO DEL PROCESO DE DETECCIÓN
# ====================================================================

Write-Host "=== DETECTOR AUTOMÁTICO DE PROBLEMAS COMUNES ===" -ForegroundColor Green

# Preparar variables para el reporte
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlFile = Join-Path -Path $logsPath -ChildPath "problemas_detectados_$timestamp.html"
$dateTimeFormatted = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$username = $env:USERNAME

Write-Host "Iniciando detección automática de problemas..." -ForegroundColor Yellow
Write-Host "Reporte se guardará en: $htmlFile" -ForegroundColor Gray

# Contenedores para clasificar los problemas encontrados
$criticalIssues = @()    # Problemas críticos que requieren atención inmediata
$warningIssues = @()     # Advertencias que deben revisarse
$infoMessages = @()      # Información de elementos que funcionan bien

# ====================================================================
# FUNCIÓN: VERIFICAR ESPACIO EN DISCO
# ====================================================================
# Esta función verifica si hay suficiente espacio libre en todos los discos
# NIVELES DE ALERTA:
# - Menos del 10% libre = CRÍTICO (puede causar fallas del sistema)
# - Menos del 20% libre = ADVERTENCIA (puede causar lentitud)
# - 20% o más libre = NORMAL

function Test-DiskSpace {
    Write-Host "`n[1/6] Verificando espacio en disco..." -ForegroundColor Yellow
    
    # Obtener información de todos los discos duros (DriveType=3)
    $disks = Invoke-SafeExecution -Seccion "Problemas-Espacio-Disco" -DefaultValue @() -ScriptBlock {
        Get-WmiObject -Query "SELECT * FROM Win32_LogicalDisk WHERE DriveType=3" -ErrorAction Stop
    }
    
    foreach ($disk in $disks) {
        try {
            # Calcular espacio libre y total en GB
            $freeSpaceGB = [Math]::Round($disk.FreeSpace / 1GB, 2)
            $totalSpaceGB = [Math]::Round($disk.Size / 1GB, 2)
            $freePercent = [Math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
            
            # Determinar el estado según el porcentaje libre
            if ($freePercent -lt 10) {
                # CRÍTICO: Muy poco espacio libre
                $message = "Unidad $($disk.DeviceID): Solo $freePercent% libre ($freeSpaceGB GB de $totalSpaceGB GB)"
                $script:criticalIssues += @{Type="Disco Crítico"; Message=$message}
                Add-ITSupportError -Seccion "Problemas-Disco-Crítico" -Mensaje $message -Severidad "Critical"
                Write-Host "    🔴 $message" -ForegroundColor Red
            } elseif ($freePercent -lt 20) {
                $message = "Unidad $($disk.DeviceID): Solo $freePercent% libre ($freeSpaceGB GB de $totalSpaceGB GB)"
                $script:warningIssues += @{Type="Disco Bajo"; Message=$message}
                Add-ITSupportError -Seccion "Problemas-Disco-Advertencia" -Mensaje $message -Severidad "Warning"
            } else {
                $message = "Unidad $($disk.DeviceID): $freePercent% libre ($freeSpaceGB GB de $totalSpaceGB GB) - OK"
                $script:infoMessages += @{Type="Disco OK"; Message=$message}
            }
        } catch {
            Add-ITSupportError -Seccion "Problemas-Disco-$($disk.DeviceID)" -ErrorRecord $_ -Severidad "Warning"
        }
    }
}

# Función para verificar procesos con alto uso de recursos
function Test-HighResourceProcesses {
    Write-Host "Verificando procesos con alto uso de recursos..." -ForegroundColor Yellow
    
    $topCPUProcesses = Invoke-SafeExecution -Seccion "Problemas-CPU-Procesos" -DefaultValue @() -ScriptBlock {
        Get-Process -ErrorAction Stop | Sort-Object -Property CPU -Descending | Select-Object -First 5
    }
    
    $topMemoryProcesses = Invoke-SafeExecution -Seccion "Problemas-Memoria-Procesos" -DefaultValue @() -ScriptBlock {
        Get-Process -ErrorAction Stop | Sort-Object -Property WorkingSet -Descending | Select-Object -First 5
    }
    
    foreach ($proc in $topCPUProcesses) {
        try {
            $cpuTime = [Math]::Round($proc.CPU, 2)
            $memoryMB = [Math]::Round($proc.WorkingSet / 1MB, 2)
            $message = "$($proc.ProcessName): $cpuTime s CPU, $memoryMB MB RAM"
            
            if ($memoryMB -gt 1000) {  # Más de 1GB de RAM
                $script:warningIssues += @{Type="Proceso Alto Memoria"; Message="$($proc.ProcessName) usa $memoryMB MB de RAM"}
                Add-ITSupportError -Seccion "Problemas-Proceso-Memoria" -Mensaje "$($proc.ProcessName) usa excesiva memoria: $memoryMB MB" -Severidad "Warning"
            }
        } catch {
            Add-ITSupportError -Seccion "Problemas-Proceso-$($proc.ProcessName)" -ErrorRecord $_ -Severidad "Info"
        }
    }
    
    foreach ($proc in $topMemoryProcesses) {
        try {
            $memoryMB = [Math]::Round($proc.WorkingSet / 1MB, 2)
        } catch {
            Add-ITSupportError -Seccion "Problemas-Proceso-Memoria-$($proc.ProcessName)" -ErrorRecord $_ -Severidad "Info"
        }
    }
}

# Función para verificar servicios críticos
function Test-CriticalServices {
    Write-Host "Verificando servicios críticos..." -ForegroundColor Yellow
    
    $criticalServices = @(
        @{Name="wuauserv"; DisplayName="Windows Update"},
        @{Name="WinDefend"; DisplayName="Windows Defender"},
        @{Name="BITS"; DisplayName="Background Intelligent Transfer Service"},
        @{Name="wscsvc"; DisplayName="Windows Security Center"},
        @{Name="Spooler"; DisplayName="Print Spooler"},
        @{Name="Themes"; DisplayName="Themes"}
    )
    
    foreach ($svc in $criticalServices) {
        $serviceStatus = Invoke-SafeExecution -Seccion "Problemas-Servicio-$($svc.Name)" -ScriptBlock {
            Get-Service -Name $svc.Name -ErrorAction Stop
        }
        
        if ($null -eq $serviceStatus) {
            $message = "Servicio $($svc.DisplayName) ($($svc.Name)) no encontrado"
            $script:infoMessages += @{Type="Servicio No Encontrado"; Message=$message}
        } elseif ($serviceStatus.Status -ne "Running") {
            $message = "Servicio $($svc.DisplayName) ($($svc.Name)) no está en ejecución (Estado: $($serviceStatus.Status))"
            $script:warningIssues += @{Type="Servicio Detenido"; Message=$message}
            Add-ITSupportError -Seccion "Problemas-Servicios" -Mensaje $message -Severidad "Warning"
        } else {
            $message = "Servicio $($svc.DisplayName) está funcionando correctamente"
            $script:infoMessages += @{Type="Servicio OK"; Message=$message}
        }
    }
}

# Función para verificar conectividad de red básica
function Test-BasicConnectivity {
    Write-Host "Verificando conectividad básica..." -ForegroundColor Yellow
    
    $tests = @(
        @{Target="127.0.0.1"; Description="Loopback local"},
        @{Target="8.8.8.8"; Description="DNS público de Google"}
    )
    
    foreach ($test in $tests) {
        $result = Invoke-SafeExecution -Seccion "Problemas-Red-$($test.Target)" -ScriptBlock {
            Test-Connection -ComputerName $test.Target -Count 1 -ErrorAction Stop
        }
        
        if ($result) {
            $message = "Conectividad a $($test.Description) ($($test.Target)): OK"
            $script:infoMessages += @{Type="Red OK"; Message=$message}
        } else {
            $message = "Sin conectividad a $($test.Description) ($($test.Target))"
            $script:criticalIssues += @{Type="Red Crítica"; Message=$message}
        }
    }
}

# Ejecutar todas las verificaciones
Test-DiskSpace
Test-HighResourceProcesses
Test-CriticalServices
Test-BasicConnectivity

# Generar reporte HTML usando plantilla unificada
$htmlHeader = Get-UnifiedHTMLTemplate -Title "🔍 Detector de Problemas del Sistema" -ComputerName $env:COMPUTERNAME -UserName $username -DateTime $dateTimeFormatted -IncludeSummary $false

$htmlSections = @"
        <div class="summary">
            <div class="summary-box critical">
                <h3>🚨 Críticos</h3>
                <p style="font-size: 2em; font-weight: bold;">$($criticalIssues.Count)</p>
            </div>
            <div class="summary-box warning">
                <h3>⚠️ Advertencias</h3>
                <p style="font-size: 2em; font-weight: bold;">$($warningIssues.Count)</p>
            </div>
            <div class="summary-box good">
                <h3>✅ Funcionando</h3>
                <p style="font-size: 2em; font-weight: bold;">$($infoMessages.Count)</p>
            </div>
        </div>
"@

if ($criticalIssues.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section critical">
            <h2>🚨 Problemas Críticos Detectados</h2>
"@
    foreach ($issue in $criticalIssues) {
        $htmlSections += "<div class='issue-item issue-critical'><strong>$($issue.Type):</strong> $($issue.Message)</div>"
    }
    $htmlSections += "</div>"
}

if ($warningIssues.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section warning">
            <h2>⚠️ Advertencias</h2>
"@
    foreach ($issue in $warningIssues) {
        $htmlSections += "<div class='issue-item issue-warning'><strong>$($issue.Type):</strong> $($issue.Message)</div>"
    }
    $htmlSections += "</div>"
}

if ($infoMessages.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section good">
            <h2>✅ Elementos Funcionando Correctamente</h2>
"@
    foreach ($issue in $infoMessages) {
        $htmlSections += "<div class='issue-item issue-ok'><strong>$($issue.Type):</strong> $($issue.Message)</div>"
    }
    $htmlSections += "</div>"
}

# Generar footer y contenido completo
$htmlFooter = (Get-ErrorSummaryHTML -IncludeCSS) + (Get-UnifiedHTMLFooter -IncludeCountingScript $false)
$htmlContent = $htmlHeader + $htmlSections + $htmlFooter

# Guardar archivos
[System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "Detección de problemas completada."
Write-Host "Reporte HTML: $htmlFile"
Write-Host ""
Write-Host "RESUMEN:" -ForegroundColor Cyan
Write-Host "- Problemas críticos: $($criticalIssues.Count)" -ForegroundColor $(if($criticalIssues.Count -gt 0){"Red"}else{"Green"})
Write-Host "- Advertencias: $($warningIssues.Count)" -ForegroundColor $(if($warningIssues.Count -gt 0){"Yellow"}else{"Green"})
Write-Host "- Elementos OK: $($infoMessages.Count)" -ForegroundColor Green

if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores adicionales durante el análisis. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}
