# Try to configure execution policy (silencing errors if it fails)
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch {
    # Continuar sin mostrar error
}

# Configurar soporte UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Asegurar que el directorio de logs y reportes exista
$PSScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logsPath = Join-Path -Path $PSScriptRoot -ChildPath "logs_reports"
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

# Importar módulo de manejo de errores
$errorHandlerPath = Join-Path -Path $PSScriptRoot -ChildPath "ErrorHandler.ps1"
if (Test-Path $errorHandlerPath) {
    . $errorHandlerPath
} else {
    Write-Warning "No se encontró el módulo ErrorHandler.ps1. Continuando sin manejo avanzado de errores."
    # Crear funciones dummy para que no falle
    function Add-ITSupportError { param($Seccion, $Mensaje) }
    function Clear-ITSupportErrors { }
    function Get-ErrorSummaryHTML { param($IncludeCSS) return "" }
    function Export-ErrorLog { param($Path) }
    function Invoke-SafeExecution { param($Seccion, $ScriptBlock, $DefaultValue) try { & $ScriptBlock } catch { $DefaultValue } }
}

# Importar plantilla HTML unificada
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

# Limpiar errores anteriores
Clear-ITSupportErrors

# Diagnóstico de Red
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$htmlFile = Join-Path -Path $logsPath -ChildPath "diagnostico_red_$timestamp.html"

$username = $env:USERNAME
$dateTimeFormatted = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Host "Iniciando diagnóstico de red..." -ForegroundColor Green

# Función auxiliar para realizar ping con manejo de errores
function Test-NetworkConnection {
    param(
        [string]$Target,
        [string]$Description,
        [int]$Count = 2
    )
    
    $result = Invoke-SafeExecution -Section "Red-$Description" -ScriptBlock {
        Test-Connection -ComputerName $Target -Count $Count -ErrorAction Stop
    }
    
    if ($result) {
        return $true
    } else {
        return $false
    }
}

# Función para obtener el gateway predeterminado dinámicamente
function Get-DefaultGateway {
    try {
        $gateway = Invoke-SafeExecution -Section "Red-Gateway-Discovery" -ScriptBlock {
            # Método 1: Intentar con Get-NetIPConfiguration (más moderno)
            try {
                $netConfig = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4DefaultGateway -ne $null }
                if ($netConfig -and $netConfig.IPv4DefaultGateway) {
                    $gatewayIP = $netConfig.IPv4DefaultGateway.NextHop
                    if ($gatewayIP -match '^\d+\.\d+\.\d+\.\d+$') {
                        return $gatewayIP
                    }
                }
            } catch {
                # Continuar con el siguiente método
            }
            
            # Método 2: Intentar obtener gateway desde adaptadores de red activos
            try {
                $activeAdapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop
                foreach ($adapter in $activeAdapters) {
                    if ($adapter.DefaultIPGateway -and $adapter.DefaultIPGateway[0]) {
                        return $adapter.DefaultIPGateway[0]
                    }
                }
            } catch {
                # Continuar con el siguiente método
            }
            
            # Método 3: Usar route print (más confiable)
            try {
                $routeOutput = cmd /c "route print 0.0.0.0" 2>$null | Select-String "0.0.0.0.*0.0.0.0"
                if ($routeOutput) {
                    $routeParts = $routeOutput.Line -split '\s+' | Where-Object { $_ -ne '' }
                    # El gateway está generalmente en la posición 2 después de filtrar espacios vacíos
                    for ($i = 0; $i -lt $routeParts.Length; $i++) {
                        if ($routeParts[$i] -match '^\d+\.\d+\.\d+\.\d+$' -and $routeParts[$i] -ne '0.0.0.0') {
                            return $routeParts[$i]
                        }
                    }
                }
            } catch {
                # Continuar al return null
            }
            
            return $null
        } -DefaultValue $null
        
        return $gateway
    } catch {
        Add-ITSupportError -Section "Red-Gateway-Discovery" -ErrorRecord $_
        return $null
    }
}

# Obtener gateway dinámicamente
$detectedGateway = Get-DefaultGateway

# Realizar pruebas de conectividad
if ($detectedGateway) {
    $gatewayResult = Test-NetworkConnection -Target $detectedGateway -Description "Gateway Local ($detectedGateway)"
} else {
    # Intentar detectar gateway usando método directo de route print como último recurso
    try {
        $routeOutput = cmd /c "route print 0.0.0.0" 2>$null | Select-String "0.0.0.0.*0.0.0.0"
        if ($routeOutput) {
            $routeParts = $routeOutput.Line -split '\s+' | Where-Object { $_ -ne '' }
            for ($i = 0; $i -lt $routeParts.Length; $i++) {
                if ($routeParts[$i] -match '^\d+\.\d+\.\d+\.\d+$' -and $routeParts[$i] -ne '0.0.0.0') {
                    $detectedGateway = $routeParts[$i]
                    break
                }
            }
        }
    } catch {
        # Si todo falla, usar un valor por defecto más común
        $detectedGateway = "192.168.1.1"
    }
    
    # Si aún no se detectó, usar fallback
    if (-not $detectedGateway) {
        $detectedGateway = "192.168.1.1"
    }
    
    $gatewayResult = Test-NetworkConnection -Target $detectedGateway -Description "Gateway Local (detectado: $detectedGateway)"
}

$dnsResult = Test-NetworkConnection -Target "8.8.8.8" -Description "DNS Público"
$internetResult = Test-NetworkConnection -Target "google.com" -Description "Sitio Web Externo"

# Get network adapter information using multiple methods
$networkAdapters = Invoke-SafeExecution -Section "Red-Adaptadores" -DefaultValue @() -ScriptBlock {
    Write-Host "  Detectando adaptadores de red..." -ForegroundColor Gray
    $allAdapters = @()
    
    # Método 1: Get-NetAdapter (más moderno y confiable)
    try {
        Write-Host "    Método 1: Get-NetAdapter..." -ForegroundColor Gray
        $netAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" }
        
        foreach ($adapter in $netAdapters) {
            # Get IP configuration for this adapter
            $ipConfig = try {
                Get-NetIPConfiguration -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
            } catch {
                $null
            }
            
            $adapterInfo = [PSCustomObject]@{
                Description = $adapter.InterfaceDescription
                Name = $adapter.Name
                IPAddress = if ($ipConfig -and $ipConfig.IPv4Address) { $ipConfig.IPv4Address.IPAddress } else { "Sin IP" }
                SubnetMask = if ($ipConfig -and $ipConfig.IPv4Address) { "/$($ipConfig.IPv4Address.PrefixLength)" } else { "N/A" }
                DefaultGateway = if ($ipConfig -and $ipConfig.IPv4DefaultGateway) { $ipConfig.IPv4DefaultGateway.NextHop } else { "N/A" }
                MACAddress = $adapter.MacAddress
                DHCPEnabled = if ($ipConfig -and $ipConfig.NetAdapter.DhcpEnabled -ne $null) { if ($ipConfig.NetAdapter.DhcpEnabled) { "Sí" } else { "No" } } else { "N/A" }
                DNSServers = if ($ipConfig -and $ipConfig.DNSServer) { ($ipConfig.DNSServer.ServerAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }) -join ", " } else { "N/A" }
                ConnectionStatus = "Conectado"
                Speed = if ($adapter.LinkSpeed) { 
                    if ($adapter.LinkSpeed -ge 1000000000) {
                        "$([math]::Round($adapter.LinkSpeed / 1000000000, 1)) Gbps"
                    } else {
                        "$([math]::Round($adapter.LinkSpeed / 1000000, 0)) Mbps"
                    }
                } else { "N/A" }
                InterfaceType = $adapter.MediaType
                Method = "Get-NetAdapter"
            }
            $allAdapters += $adapterInfo
        }
        
        Write-Host "    Encontrados $($netAdapters.Count) adaptadores con Get-NetAdapter" -ForegroundColor Gray
    } catch {
        Write-Host "    Error con Get-NetAdapter: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Método 2: Win32_NetworkAdapterConfiguration (fallback)
    if ($allAdapters.Count -eq 0) {
        try {
            Write-Host "    Método 2: Win32_NetworkAdapterConfiguration..." -ForegroundColor Gray
            $adaptersConfig = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop
            
            foreach ($config in $adaptersConfig) {
                $physical = try {
                    Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "Index=$($config.Index)" -ErrorAction SilentlyContinue
                } catch {
                    $null
                }
                
                $adapterInfo = [PSCustomObject]@{
                    Description = if ($config.Description) { $config.Description } else { "Adaptador desconocido" }
                    Name = if ($physical) { $physical.NetConnectionID } else { "N/A" }
                    IPAddress = if ($config.IPAddress) { $config.IPAddress[0] } else { "N/A" }
                    SubnetMask = if ($config.IPSubnet) { $config.IPSubnet[0] } else { "N/A" }
                    DefaultGateway = if ($config.DefaultIPGateway) { $config.DefaultIPGateway[0] } else { "N/A" }
                    MACAddress = if ($config.MACAddress) { $config.MACAddress } else { "N/A" }
                    DHCPEnabled = if ($config.DHCPEnabled -ne $null) { if ($config.DHCPEnabled) { "Sí" } else { "No" } } else { "N/A" }
                    DNSServers = if ($config.DNSServerSearchOrder) { $config.DNSServerSearchOrder -join ", " } else { "N/A" }
                    ConnectionStatus = if ($physical -and $physical.NetConnectionStatus -eq 2) { "Conectado" } else { "Desconocido" }
                    Speed = if ($physical -and $physical.Speed) { 
                        $speedMbps = [math]::Round($physical.Speed / 1MB, 0)
                        "$speedMbps Mbps"
                    } else { "N/A" }
                    InterfaceType = if ($physical) { $physical.AdapterType } else { "N/A" }
                    Method = "Win32_NetworkAdapterConfiguration"
                }
                $allAdapters += $adapterInfo
            }
            
            Write-Host "    Encontrados $($adaptersConfig.Count) adaptadores con WMI" -ForegroundColor Gray
        } catch {
            Write-Host "    Error con WMI: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Método 3: netsh (último recurso)
    if ($allAdapters.Count -eq 0) {
        try {
            Write-Host "    Método 3: netsh interface..." -ForegroundColor Gray
            $netshOutput = & netsh interface show interface 2>$null
            
            if ($LASTEXITCODE -eq 0 -and $netshOutput) {
                $interfaces = $netshOutput | Where-Object { $_ -match 'Enabled.*Connected' } | ForEach-Object {
                    if ($_ -match '\s+(\w+)\s+Connected\s+Dedicated\s+(.+)$') {
                        [PSCustomObject]@{
                            Description = $matches[2].Trim()
                            Name = $matches[2].Trim()
                            IPAddress = "N/A"
                            SubnetMask = "N/A"
                            DefaultGateway = "N/A"
                            MACAddress = "N/A"
                            DHCPEnabled = "N/A"
                            DNSServers = "N/A"
                            ConnectionStatus = "Conectado"
                            Speed = "N/A"
                            InterfaceType = "N/A"
                            Method = "netsh"
                        }
                    }
                }
                
                if ($interfaces) {
                    $allAdapters += $interfaces
                    Write-Host "    Encontrados $($interfaces.Count) adaptadores con netsh" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "    Error con netsh: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "    Total de adaptadores detectados: $($allAdapters.Count)" -ForegroundColor Gray
    return $allAdapters
}

# Si aún no tenemos adaptadores, mostrar un mensaje de advertencia
if ($networkAdapters.Count -eq 0) {
    Add-ITSupportError -Section "Red-Adaptadores" -Message "No se pudieron detectar adaptadores de red activos" -Severity "Warning"
    Write-Host "Advertencia: No se detectaron adaptadores de red activos" -ForegroundColor Yellow
}

# Generar reporte HTML usando plantilla unificada con módulo específico
$moduleName = "NetworkDiagnostic"
$htmlContent = Get-UnifiedHTMLTemplate -Title "Diagnóstico de Red" -IncludeSummary $true

$gatewayClass = if($gatewayResult){'good'}else{'critical'}
$dnsClass = if($dnsResult){'good'}else{'critical'}
$internetClass = if($internetResult){'good'}else{'critical'}

# Registrar errores críticos de conectividad
if (-not $gatewayResult) {
    Add-ITSupportError -Section "Conectividad Red" -Message "No se pudo conectar al gateway predeterminado ($detectedGateway)" -Severity "Critical"
}
if (-not $dnsResult) {
    Add-ITSupportError -Section "Conectividad Red" -Message "No se pudo conectar a DNS público (8.8.8.8)" -Severity "Critical"
}
if (-not $internetResult) {
    Add-ITSupportError -Section "Conectividad Red" -Message "No se pudo conectar a Internet (google.com)" -Severity "Critical"
}

$htmlContent += @"
        <div class="diagnostic-section $(Get-ModuleStatusClass -ModuleName $moduleName -Status $gatewayClass)">
            <h2>Conectividad al Gateway</h2>
            <div class="metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $gatewayClass)">
                <h4>Estado: $(if($gatewayResult){'Exitoso'}else{'Fallido'})</h4>
                <p>Prueba de conectividad con el gateway predeterminado: <strong>$detectedGateway</strong></p>
            </div>
        </div>
        
        <div class="diagnostic-section $(Get-ModuleStatusClass -ModuleName $moduleName -Status $dnsClass)">
            <h2>Conectividad a DNS Público</h2>
            <div class="metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $dnsClass)">
                <h4>Estado: $(if($dnsResult){'Exitoso'}else{'Fallido'})</h4>
                <p>Prueba de conectividad a DNS público (8.8.8.8)</p>
            </div>
        </div>
        
        <div class="diagnostic-section $(Get-ModuleStatusClass -ModuleName $moduleName -Status $internetClass)">
            <h2>Conectividad a Internet</h2>
            <div class="metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $internetClass)">
                <h4>Estado: $(if($internetResult){'Exitoso'}else{'Fallido'})</h4>
                <p>Prueba de conectividad a sitio web externo (google.com)</p>
            </div>
        </div>
        
        <div class="diagnostic-section">
            <h2>Adaptadores de Red</h2>
            <div class="metric">
                <p><strong>Adaptadores detectados:</strong> $($networkAdapters.Count)</p>
            </div>
            <div class="table-container">
                <table>
                    <tr>
                        <th>Nombre</th>
                        <th>Descripción</th>
                        <th>IP</th>
                        <th>Máscara/Prefijo</th>
                        <th>Gateway</th>
                        <th>MAC</th>
                        <th>DHCP</th>
                        <th>Velocidad</th>
                        <th>Estado</th>
                        <th>Método</th>
                    </tr>
"@

foreach($adapter in $networkAdapters) {
    $statusClass = if($adapter.ConnectionStatus -eq "Conectado") { "good" } else { "warning" }
    $htmlContent += "<tr class='$statusClass'>"
    $htmlContent += "<td>$($adapter.Name)</td>"
    $htmlContent += "<td>$($adapter.Description)</td>"
    $htmlContent += "<td>$($adapter.IPAddress)</td>"
    $htmlContent += "<td>$($adapter.SubnetMask)</td>"
    $htmlContent += "<td>$($adapter.DefaultGateway)</td>"
    $htmlContent += "<td>$($adapter.MACAddress)</td>"
    $htmlContent += "<td>$($adapter.DHCPEnabled)</td>"
    $htmlContent += "<td>$($adapter.Speed)</td>"
    $htmlContent += "<td>$($adapter.ConnectionStatus)</td>"
    $htmlContent += "<td><small>$($adapter.Method)</small></td>"
    $htmlContent += "</tr>"
}

$htmlContent += "</table></div>"

# Add DNS information if available
if ($networkAdapters | Where-Object { $_.DNSServers -ne "N/A" }) {
    $htmlContent += "<div class='metric'>"
    $htmlContent += "<h3>Servidores DNS Configurados</h3>"
    foreach($adapter in $networkAdapters) {
        if ($adapter.DNSServers -ne "N/A") {
            $htmlContent += "<p><strong>$($adapter.Description):</strong> $($adapter.DNSServers)</p>"
        }
    }
    $htmlContent += "</div>"
}

$htmlContent += "</div>"

# Agregar resumen de errores
$htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false

# Finalizar HTML con conteo específico del módulo
$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true -ModuleName $moduleName

# Guardar archivos
[System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "Diagnóstico de red completado." -ForegroundColor Green
Write-Host "Reporte HTML: $htmlFile" -ForegroundColor Cyan
if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores/advertencias. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
