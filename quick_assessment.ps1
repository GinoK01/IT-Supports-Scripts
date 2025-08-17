# ====================================================================
# DIAGNÓSTICO RÁPIDO DE SISTEMA - SCRIPT PARA TÉCNICOS DE SOPORTE
# ====================================================================
# 
# PROPÓSITO:
# Este script realiza una evaluación rápida (2-3 minutos) del estado del sistema
# Ideal para una primera revisión durante visitas técnicas o llamadas de soporte
#
# QUÉ HACE:
# - Verifica el uso de CPU y memoria
# - Comprueba la conectividad de red
# - Detecta problemas básicos del sistema
# - Genera un reporte HTML fácil de leer
#
# CUÁNDO USARLO:
# - Primera evaluación de un equipo con problemas
# - Antes de hacer cambios importantes
# - Para documentar el estado inicial del sistema
# ====================================================================

# Configuración inicial del script
# Permitir la ejecución de scripts PowerShell (necesario para que funcione)
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch {
    # Si falla, continuar - algunos sistemas no permiten cambiar la política
}

# Configurar soporte para caracteres especiales (acentos, ñ, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Crear la carpeta donde se guardan los reportes si no existe
$PSScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logsPath = Join-Path -Path $PSScriptRoot -ChildPath "logs_reports"
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

# Cargar módulos de soporte (funciones adicionales para manejo de errores y reportes)
$errorHandlerPath = Join-Path -Path $PSScriptRoot -ChildPath "ErrorHandler.ps1"
if (Test-Path $errorHandlerPath) {
    . $errorHandlerPath
} else {
    Write-Warning "No se encontró el módulo ErrorHandler.ps1. Continuando sin manejo avanzado de errores."
    # Crear funciones básicas para que el script no falle
    function Add-ITSupportError { param($Seccion, $Mensaje) }
    function Clear-ITSupportErrors { }
    function Get-ErrorSummaryHTML { param($IncludeCSS) return "" }
    function Export-ErrorLog { param($Path) }
    function Invoke-SafeExecution { param($Seccion, $ScriptBlock, $DefaultValue) try { & $ScriptBlock } catch { $DefaultValue } }
}

# Cargar plantilla para generar reportes HTML profesionales
$htmlTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath "HTMLTemplate.ps1"
if (Test-Path $htmlTemplatePath) {
    . $htmlTemplatePath
} else {
    Write-Warning "No se encontró HTMLTemplate.ps1. Usando formato básico."
    # Funciones básicas para generar HTML si no está disponible la plantilla
    function Get-UnifiedHTMLTemplate { 
        param($Title, $ShowSummary)
        return "<html><head><title>$Title</title></head><body><h1>$Title</h1>"
    }
    function Get-UnifiedHTMLFooter { 
        param($IncludeCountingScript, $ModuleName)
        return "</body></html>"
    }
}

# Limpiar errores de ejecuciones anteriores
Clear-ITSupportErrors

# ====================================================================
# INICIO DEL DIAGNÓSTICO RÁPIDO
# ====================================================================

# Crear nombre único para el archivo de reporte (incluye fecha y hora)
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$summaryFile = Join-Path -Path $logsPath -ChildPath "diagnostico_rapido_$timestamp.html"

Write-Host "Iniciando diagnóstico rápido del sistema..." -ForegroundColor Green
Write-Host "El reporte se guardará en: $summaryFile" -ForegroundColor Gray

# ====================================================================
# 1. VERIFICACIÓN DE USO DE CPU (PROCESADOR)
# ====================================================================
# Esto nos dice qué tanto está trabajando el procesador
# Valores normales: 0-30% (bueno), 30-70% (aceptable), 70%+ (problema)

Write-Host "`n[1/4] Verificando uso del procesador..." -ForegroundColor Yellow

$cpuLoad = 0
try {
    # MÉTODO 1: Usar contadores de rendimiento (más preciso)
    try {
        $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
        $cpuLoad = [int]($cpuCounter.CounterSamples.CookedValue)
        Write-Host "  → Método usado: Contadores de rendimiento" -ForegroundColor Gray
    } catch {
        # MÉTODO 2: Si el anterior falla, usar WMI (más compatible)
        Write-Host "  → Usando método alternativo para CPU..." -ForegroundColor Yellow
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
        $cpuLoad = [int]($cpu.LoadPercentage | Measure-Object -Average).Average
        if (-not $cpuLoad) { 
            # MÉTODO 3: Último recurso basado en procesos activos
            $processes = Get-Process | Where-Object { $_.CPU -gt 0 } | Sort-Object CPU -Descending | Select-Object -First 10
            $cpuLoad = if ($processes) { [math]::Min(50, ($processes | Measure-Object CPU -Sum).Sum / 100) } else { 25 }
            Write-Host "  → Usando estimación basada en procesos" -ForegroundColor Gray
        }
    }
    
    # Asegurar que el valor esté en rango válido (0-100%)
    if ($cpuLoad -lt 0) { $cpuLoad = 0 }
    if ($cpuLoad -gt 100) { $cpuLoad = 100 }
    
    # Mostrar resultado con código de colores
    $cpuStatus = if ($cpuLoad -gt 80) { "CRÍTICO"; "Red" } 
                elseif ($cpuLoad -gt 60) { "ALTO"; "Yellow" } 
                else { "NORMAL"; "Green" }
    Write-Host "  ✓ CPU Load: $cpuLoad% - Estado: $($cpuStatus[0])" -ForegroundColor $cpuStatus[1]
    
} catch {
    Add-ITSupportError -Seccion 'CPU' -Mensaje "Error al obtener información de CPU: $($_.Exception.Message)"
    $cpuLoad = 25  # Valor por defecto si no se puede obtener
    Write-Host "  ⚠ Error obteniendo CPU, usando valor estimado: $cpuLoad%" -ForegroundColor Yellow
}

# ====================================================================
# 2. VERIFICACIÓN DE MEMORIA RAM
# ====================================================================
# Esto nos dice cuánta memoria está disponible en el sistema
# Es crítico porque poca memoria libre causa lentitud extrema

Write-Host "`n[2/4] Verificando memoria RAM disponible..." -ForegroundColor Yellow

$memoryPercentFree = 0
$memoryGB = 0
try {
    # Obtener información de memoria del sistema operativo
    $memory = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    if ($memory -and $memory.TotalVisibleMemorySize -and $memory.FreePhysicalMemory) {
        # Calcular porcentaje de memoria libre
        $memoryPercentFree = [math]::Round(($memory.FreePhysicalMemory / $memory.TotalVisibleMemorySize) * 100, 1)
        $memoryGB = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 1)
        
        # Mostrar resultado con código de colores
        $memStatus = if ($memoryPercentFree -lt 10) { "CRÍTICO"; "Red" } 
                    elseif ($memoryPercentFree -lt 25) { "BAJO"; "Yellow" } 
                    else { "NORMAL"; "Green" }
        Write-Host "  ✓ Memoria libre: $memoryPercentFree% ($memoryGB GB total) - Estado: $($memStatus[0])" -ForegroundColor $memStatus[1]
        
        # Información adicional útil para el técnico
        $freeGB = [math]::Round(($memory.FreePhysicalMemory / 1MB), 1)
        $usedGB = [math]::Round($memoryGB - $freeGB, 1)
        Write-Host "  → Memoria usada: $usedGB GB | Memoria libre: $freeGB GB" -ForegroundColor Gray
    } else {
        throw "No se pudo obtener información válida de memoria"
    }
} catch {
    Add-ITSupportError -Seccion 'Memoria' -Mensaje "Error al obtener información de memoria: $($_.Exception.Message)"
    Write-Host "  ⚠ Error obteniendo información de memoria" -ForegroundColor Yellow
}

# ====================================================================
# 3. VERIFICACIÓN DE CONECTIVIDAD DE RED
# ====================================================================
# Esto verifica si el equipo puede comunicarse con la red
# Es fundamental para diagnosticar problemas de internet/red corporativa

Write-Host "`n[3/4] Verificando adaptadores de red..." -ForegroundColor Yellow

$networkAdapters = @()
try {
    # Obtener solo los adaptadores de red que están activos (IPEnabled=True)
    $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop | 
    Select-Object Description, IPAddress, IPSubnet, DefaultIPGateway, MACAddress
    if (-not $networkAdapters) { $networkAdapters = @() }
    
    Write-Host "  ✓ Adaptadores de red activos encontrados: $($networkAdapters.Count)" -ForegroundColor Green
    
    # Mostrar información básica de cada adaptador
    foreach ($adapter in $networkAdapters) {
        $ip = if ($adapter.IPAddress) { $adapter.IPAddress[0] } else { 'Sin IP' }
        $desc = $adapter.Description
        if ($desc.Length -gt 40) { $desc = $desc.Substring(0, 37) + "..." }
        Write-Host "    → $desc : $ip" -ForegroundColor Gray
    }
} catch {
    Add-ITSupportError -Seccion 'Red' -Mensaje "Error al obtener adaptadores de red: $($_.Exception.Message)"
    $networkAdapters = @()
    Write-Host "  ⚠ Error obteniendo adaptadores de red" -ForegroundColor Yellow
}

# ====================================================================
# FUNCIÓN PARA DETECTAR EL GATEWAY (PUERTA DE ENLACE)
# ====================================================================
# El gateway es la "puerta" por donde sale el tráfico a internet
# Si no hay conectividad al gateway, no habrá internet

function Get-DefaultGateway {
    try {
        # Buscar en todos los adaptadores activos
        foreach ($adapter in $networkAdapters) {
            if ($adapter.DefaultIPGateway -and $adapter.DefaultIPGateway[0]) {
                return $adapter.DefaultIPGateway[0]
            }
        }
        return $null
    } catch {
        return $null
    }
}

# ====================================================================
# PRUEBA DE CONECTIVIDAD AL GATEWAY
# ====================================================================
# Esta prueba nos dice si el equipo puede comunicarse con el router/gateway

Write-Host "`n[4/4] Probando conectividad de red..." -ForegroundColor Yellow

$detectedGateway = Get-DefaultGateway
$gatewayConnectivity = $false

if ($detectedGateway) {
    try {
        Write-Host "  → Gateway detectado: $detectedGateway" -ForegroundColor Gray
        Write-Host "  → Enviando ping al gateway..." -ForegroundColor Gray
        
        # Enviar un ping al gateway para verificar conectividad
        $pingResult = Test-Connection -ComputerName $detectedGateway -Count 1 -Quiet -ErrorAction Stop
        $gatewayConnectivity = $pingResult
        
        $connStatus = if ($gatewayConnectivity) { "EXITOSA"; "Green" } else { "FALLIDA"; "Red" }
        Write-Host "  ✓ Conectividad al gateway: $($connStatus[0])" -ForegroundColor $connStatus[1]
        
    } catch {
        Add-ITSupportError -Seccion 'Red-Gateway' -Mensaje "Error al conectar al gateway $detectedGateway`: $($_.Exception.Message)"
        $gatewayConnectivity = $false
        Write-Host "Error probando conectividad al gateway" -ForegroundColor Yellow
    }
} else {
    Write-Host "No se detectó gateway predeterminado" -ForegroundColor Yellow
}

# Determinar estados
$cpuClass = if($cpuLoad -gt 80){"critical"}elseif($cpuLoad -gt 60){"warning"}else{"good"}
$memoryClass = if($memoryPercentFree -lt 10){"critical"}elseif($memoryPercentFree -lt 25){"warning"}else{"good"}

# Generar HTML con conteo específico del módulo
$moduleName = "QuickAssessment"
$htmlContent = Get-UnifiedHTMLTemplate -Title "Diagnóstico Rápido de Sistema" -IncludeSummary $true

$htmlContent += @"
        <div class="diagnostic-section">
            <h2>Estado del Sistema</h2>
            <div class="metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $cpuClass)">
                <h3>Procesador (CPU)</h3>
                <p>Uso actual: <strong>$cpuLoad%</strong></p>
            </div>
            
            <div class="metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $memoryClass)">
                <h3>Memoria RAM</h3>
                <p>Memoria libre: <strong>$memoryPercentFree%</strong> ($memoryGB GB total)</p>
            </div>
        </div>
        
        <div class="diagnostic-section">
            <h2>Red</h2>
            <table>
                <tr>
                    <th>Adaptador</th>
                    <th>IP</th>
                    <th>Gateway</th>
                    <th>MAC</th>
                </tr>
"@

foreach($adapter in $networkAdapters) {
    $ip = if($adapter.IPAddress) { $adapter.IPAddress[0] } else { 'N/D' }
    $gateway = if($adapter.DefaultIPGateway) { $adapter.DefaultIPGateway[0] } else { 'N/D' }
    $htmlContent += "<tr><td>$($adapter.Description)</td><td>$ip</td><td>$gateway</td><td>$($adapter.MACAddress)</td></tr>"
}

$htmlContent += "</table>"

if($detectedGateway) {
    $connectivityClass = if($gatewayConnectivity) { "good" } else { "critical" }
    $connectivityStatus = if($gatewayConnectivity) { "Exitoso" } else { "Fallido" }
    $htmlContent += @"
            <div class='metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $connectivityClass)'>
                <h3>Conectividad al Gateway</h3>
                <p>Gateway detectado: <strong>$detectedGateway</strong></p>
                <p>Estado de conexión: <strong>$connectivityStatus</strong></p>
            </div>
"@
} else {
    $htmlContent += @"
            <div class='metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status "warning")'>
                <h3>Conectividad al Gateway</h3>
                <p>No se pudo detectar un gateway predeterminado</p>
            </div>
"@
}

$htmlContent += "</div>"

# Finalizar HTML con conteo específico del módulo
# Agregar resumen de errores
$htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false

$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true -ModuleName $moduleName

# Guardar archivo
try {
    [System.IO.File]::WriteAllText($summaryFile, $htmlContent, [System.Text.Encoding]::UTF8)
    Write-Host "✓ Archivo HTML generado: $summaryFile" -ForegroundColor Green
} catch {
    Write-Host "❌ Error al guardar archivo HTML: $($_.Exception.Message)" -ForegroundColor Red
}

if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "⚠️  Se detectaron $($Global:ITSupportErrors.Count) errores/advertencias. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}

Write-Host "Diagnóstico completado. Revisa el archivo: $summaryFile" -ForegroundColor Green

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


