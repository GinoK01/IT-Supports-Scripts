# ====================================================================
# QUICK SYSTEM DIAGNOSIS - SCRIPT FOR SUPPORT TECHNICIANS
# ====================================================================
# 
# PURPOSE:
# This script performs a quick evaluation (2-3 minutes) of the system status
# Perfect for a first review during technical visits or support calls
#
# WHAT IT DOES:
# - Checks CPU and memory usage
# - Verifies network connectivity
# - Detects basic system problems
# - Generates an easy-to-read HTML report
#
# WHEN TO USE IT:
# - First evaluation of a computer with problems
# - Before making important changes
# - To document the initial system status
# ====================================================================

# Initial script configuration
# Allow PowerShell script execution (necessary for it to work)
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch {
    # If it fails, continue - some systems don't allow changing the policy
}

# Configure support for special characters (accents, ñ, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Create the folder where reports are saved if it doesn't exist
$PSScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logsPath = Join-Path -Path $PSScriptRoot -ChildPath "logs_reports"
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

# Load support modules (additional functions for error handling and reports)
$errorHandlerPath = Join-Path -Path $PSScriptRoot -ChildPath "ErrorHandler.ps1"
if (Test-Path $errorHandlerPath) {
    . $errorHandlerPath
} else {
    Write-Warning "ErrorHandler.ps1 module not found. Continuing without advanced error handling."
    # Create basic functions so the script doesn't fail
    function Add-ITSupportError { param($Seccion, $Mensaje) }
    function Clear-ITSupportErrors { }
    function Get-ErrorSummaryHTML { param($IncludeCSS) return "" }
    function Export-ErrorLog { param($Path) }
    function Invoke-SafeExecution { param($Seccion, $ScriptBlock, $DefaultValue) try { & $ScriptBlock } catch { $DefaultValue } }
}

# Load template to generate professional HTML reports
$htmlTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath "HTMLTemplate.ps1"
if (Test-Path $htmlTemplatePath) {
    . $htmlTemplatePath
} else {
    Write-Warning "HTMLTemplate.ps1 not found. Using basic format."
    # Basic functions to generate HTML if template is not available
    function Get-UnifiedHTMLTemplate { 
        param($Title, $ShowSummary)
        return "<html><head><title>$Title</title></head><body><h1>$Title</h1>"
    }
    function Get-UnifiedHTMLFooter { 
        param($IncludeCountingScript, $ModuleName)
        return "</body></html>"
    }
}

# Clear errors from previous executions
Clear-ITSupportErrors

# ====================================================================
# START OF QUICK DIAGNOSIS
# ====================================================================

# Create unique name for report file (includes date and time)
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$summaryFile = Join-Path -Path $logsPath -ChildPath "diagnostico_rapido_$timestamp.html"

Write-Host "Starting quick system diagnosis..." -ForegroundColor Green
Write-Host "Report will be saved in: $summaryFile" -ForegroundColor Gray

# ====================================================================
# 1. CPU (PROCESSOR) USAGE VERIFICATION
# ====================================================================
# This tells us how hard the processor is working
# Normal values: 0-30% (good), 30-70% (acceptable), 70%+ (problem)

Write-Host "`n[1/4] Checking processor usage..." -ForegroundColor Yellow

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


