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

# Escaneo de Seguridad Básico en Windows
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$htmlFile = Join-Path -Path $logsPath -ChildPath "escaneo_seguridad_$timestamp.html"

Write-Host "Iniciando escaneo de seguridad..."

# Usar el template unificado con resumen de errores
$htmlContent = Get-UnifiedHTMLTemplate -Title "Escaneo de Seguridad" -IncludeSummary $true

# Función para obtener estado de Windows Defender con múltiples métodos
function Get-DefenderStatus {
    Write-Host "Verificando estado de Windows Defender..." -ForegroundColor Yellow
    
    # Método 1: Get-MpComputerStatus (Windows 8+)
    $defenderStatus = Invoke-SafeExecution -Section "Windows Defender Primary" -ScriptBlock {
        Get-MpComputerStatus -ErrorAction Stop
    } -DefaultValue $null
    
    if ($defenderStatus) {
        return @{
            Method = "Get-MpComputerStatus"
            RealTimeProtectionEnabled = $defenderStatus.RealTimeProtectionEnabled
            AntivirusEnabled = $defenderStatus.AntivirusEnabled
            AntispywareEnabled = $defenderStatus.AntispywareEnabled
            FirewallEnabled = $defenderStatus.FirewallEnabled
            AntivirusSignatureAge = $defenderStatus.AntivirusSignatureAge
            AntispywareSignatureAge = $defenderStatus.AntispywareSignatureAge
            QuickScanAge = $defenderStatus.QuickScanAge
            FullScanAge = $defenderStatus.FullScanAge
            Available = $true
        }
    }
    
    # Método 2: Verificar servicio de Windows Defender
    $defenderService = Invoke-SafeExecution -Section "Windows Defender Service" -ScriptBlock {
        Get-Service -Name "WinDefend" -ErrorAction Stop
    } -DefaultValue $null
    
    if ($defenderService) {
        return @{
            Method = "Service Check"
            ServiceStatus = $defenderService.Status
            ServiceName = $defenderService.DisplayName
            Available = $true
            RealTimeProtectionEnabled = ($defenderService.Status -eq "Running")
        }
    }
    
    # Método 3: Verificar procesos de antivirus
    $antivirusProcesses = Invoke-SafeExecution -Section "Antivirus Processes" -ScriptBlock {
        $processes = Get-Process -ErrorAction Stop | Where-Object { 
            $_.ProcessName -match "(MsMpEng|NisSrv|avp|avgnt|avguard|avastsvc|mbamservice|mcshield)" 
        }
        return $processes
    } -DefaultValue @()
    
    if ($antivirusProcesses.Count -gt 0) {
        return @{
            Method = "Process Detection"
            AntivirusProcesses = $antivirusProcesses.ProcessName -join ", "
            Available = $true
            RealTimeProtectionEnabled = $true
        }
    }
    
    # Método 4: Verificar mediante registro
    $registryCheck = Invoke-SafeExecution -Section "Windows Defender Registry" -ScriptBlock {
        $defenderKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -ErrorAction Stop
        return $defenderKey
    } -DefaultValue $null
    
    if ($registryCheck) {
        return @{
            Method = "Registry Check"
            Available = $true
            DisableAntiSpyware = $registryCheck.DisableAntiSpyware
            RealTimeProtectionEnabled = -not $registryCheck.DisableAntiSpyware
        }
    }
    
    return @{
        Method = "None"
        Available = $false
        RealTimeProtectionEnabled = $false
        Error = "No se pudo detectar Windows Defender"
    }
}

# Función para obtener estado del firewall con múltiples métodos
function Get-FirewallStatus {
    Write-Host "Checking firewall configuration..." -ForegroundColor Yellow
    
    # Método 1: Get-NetFirewallProfile (Windows 8+)
    $firewallProfiles = Invoke-SafeExecution -Section "Firewall Profiles" -ScriptBlock {
        Get-NetFirewallProfile -ErrorAction Stop
    } -DefaultValue $null
    
    if ($firewallProfiles) {
        return @{
            Method = "Get-NetFirewallProfile"
            Profiles = $firewallProfiles
            Available = $true
        }
    }
    
    # Método 2: netsh advfirewall (compatible con versiones anteriores)
    $netshResult = Invoke-SafeExecution -Section "Firewall Netsh" -ScriptBlock {
        Write-Host "    Ejecutando netsh advfirewall..." -ForegroundColor Gray
        $output = & netsh advfirewall show allprofiles state 2>$null
        Write-Host "    Código de salida netsh: $LASTEXITCODE" -ForegroundColor Gray
        if ($LASTEXITCODE -eq 0 -and $output) {
            Write-Host "    Salida netsh recibida: $($output.Count) líneas" -ForegroundColor Gray
            return $output
        }
        return $null
    } -DefaultValue $null
    
    if ($netshResult) {
        Write-Host "    Procesando salida de netsh..." -ForegroundColor Gray
        $profiles = @()
        $currentProfile = $null
        
        foreach ($line in $netshResult) {
            Write-Host "      Línea: $line" -ForegroundColor Gray
            if ($line -match "(Domain|Private|Public) Profile Settings:" -or $line -match "Configuración de Perfil de (dominio|privado|público):") {
                if ($matches[1]) {
                    $currentProfile = switch ($matches[1].ToLower()) {
                        "domain" { "Domain" }
                        "dominio" { "Domain" }
                        "private" { "Private" }
                        "privado" { "Private" }
                        "public" { "Public" }
                        "público" { "Public" }
                        default { $matches[1] }
                    }
                    Write-Host "      Perfil detectado: $currentProfile" -ForegroundColor Gray
                }
            } elseif ($line -match "State\s+(.+)" -or $line -match "Estado\s+(.+)") {
                $state = $matches[1].Trim()
                # Verificar estado en inglés y español
                $isEnabled = ($state -eq "ON" -or $state -eq "ACTIVAR" -or $state -eq "ACTIVADO" -or $state -match "^(ON|ACTIVAR|ACTIVADO|ENABLED)")
                Write-Host "      Estado para $currentProfile`: $state -> $(if($isEnabled){'Habilitado'}else{'Deshabilitado'})" -ForegroundColor Gray
                if ($currentProfile) {
                    $profiles += [PSCustomObject]@{
                        Name = $currentProfile
                        Enabled = $isEnabled
                    }
                }
            }
        }
        
        Write-Host "    Perfiles procesados: $($profiles.Count)" -ForegroundColor Gray
        if ($profiles.Count -gt 0) {
            return @{
                Method = "netsh advfirewall"
                Profiles = $profiles
                Available = $true
            }
        }
    }
    
    # Método 2b: netsh advfirewall alternativo (formato diferente)
    $netshResult2 = Invoke-SafeExecution -Section "Firewall Netsh Alternative" -ScriptBlock {
        Write-Host "    Probando netsh con formato alternativo..." -ForegroundColor Gray
        $profiles = @()
        
        # Probar cada perfil individualmente
        $profileNames = @("domainprofile", "privateprofile", "publicprofile")
        foreach ($profileName in $profileNames) {
            $output = & netsh advfirewall show $profileName state 2>$null
            if ($LASTEXITCODE -eq 0 -and $output) {
                $profileDisplayName = switch ($profileName) {
                    "domainprofile" { "Domain" }
                    "privateprofile" { "Private" }
                    "publicprofile" { "Public" }
                }
                
                $isEnabled = $false
                foreach ($line in $output) {
                    if ($line -match "State\s+(.+)" -or $line -match "Estado\s+(.+)") {
                        $state = $matches[1].Trim()
                        # Verificar estado en inglés y español
                        $isEnabled = ($state -eq "ON" -or $state -eq "ACTIVAR" -or $state -eq "ACTIVADO" -or $state -match "^(ON|ACTIVAR|ACTIVADO|ENABLED)")
                        break
                    }
                }
                
                $profiles += [PSCustomObject]@{
                    Name = $profileDisplayName
                    Enabled = $isEnabled
                }
                
                Write-Host "      $profileDisplayName`: $(if($isEnabled){'Habilitado'}else{'Deshabilitado'})" -ForegroundColor Gray
            }
        }
        
        return $profiles
    } -DefaultValue @()
    
    if ($netshResult2.Count -gt 0) {
        return @{
            Method = "netsh advfirewall (individual)"
            Profiles = $netshResult2
            Available = $true
        }
    }
    
    # Método 3: Verificar servicio de firewall
    $firewallService = Invoke-SafeExecution -Section "Firewall Service" -ScriptBlock {
        Get-Service -Name "MpsSvc" -ErrorAction Stop
    } -DefaultValue $null
    
    if ($firewallService) {
        return @{
            Method = "Service Check"
            ServiceStatus = $firewallService.Status
            Available = $true
            Enabled = ($firewallService.Status -eq "Running")
        }
    }
    
    return @{
        Method = "None"
        Available = $false
        Error = "Could not get firewall information"
    }
}

# Función para verificar actualizaciones de seguridad
function Get-SecurityUpdates {
    Write-Host "Verificando actualizaciones de seguridad..." -ForegroundColor Yellow
    
    $updates = Invoke-SafeExecution -Section "Security Updates" -ScriptBlock {
        # Verificar últimas actualizaciones instaladas
        $hotfixes = Get-HotFix -ErrorAction Stop | 
                   Where-Object { $_.Description -match "Security|Update" } |
                   Sort-Object InstalledOn -Descending |
                   Select-Object -First 10
        return $hotfixes
    } -DefaultValue @()
    
    $lastUpdate = if ($updates.Count -gt 0) {
        $updates[0].InstalledOn
    } else {
        $null
    }
    
    return @{
        RecentUpdates = $updates
        LastSecurityUpdate = $lastUpdate
        UpdateCount = $updates.Count
    }
}

# Ejecutar verificaciones de seguridad
$defenderStatus = Get-DefenderStatus
$firewallStatus = Get-FirewallStatus
$securityUpdates = Get-SecurityUpdates

$htmlContent += "<div class=`"diagnostic-section`">`n"

# Estado de Windows Defender
$htmlContent += "<h2>Protección Antivirus</h2>`n"

if ($defenderStatus.Available) {
    $realtimeStatus = if ($defenderStatus.RealTimeProtectionEnabled) { "Activa" } else { "Inactiva" }
    $realtimeClass = if ($defenderStatus.RealTimeProtectionEnabled) { "good" } else { "critical" }
    
    # Registrar problema crítico si la protección está inactiva
    if (-not $defenderStatus.RealTimeProtectionEnabled) {
        Add-ITSupportError -Section "Windows Defender" -Message "La protección en tiempo real está desactivada" -Severity "Critical"
    }
    
    $htmlContent += "<div class=`"metric $realtimeClass`">`n"
    $htmlContent += "<h3>Protección en Tiempo Real</h3>`n"
    $htmlContent += "<p>Estado: <strong>$realtimeStatus</strong></p>`n"
    $htmlContent += "<p>Método de detección: <strong>$($defenderStatus.Method)</strong></p>`n"
    $htmlContent += "</div>`n"
    
    if ($defenderStatus.AntivirusSignatureAge -ne $null) {
        $definitionsAge = "$($defenderStatus.AntivirusSignatureAge) días"
        $definitionsClass = if ($defenderStatus.AntivirusSignatureAge -le 7) { "good" } elseif ($defenderStatus.AntivirusSignatureAge -le 14) { "warning" } else { "critical" }
        
        # Registrar problemas con definiciones antiguas
        if ($defenderStatus.AntivirusSignatureAge -gt 14) {
            Add-ITSupportError -Section "Windows Defender" -Message "Las definiciones de antivirus tienen más de 14 días de antigüedad ($($defenderStatus.AntivirusSignatureAge) días)" -Severity "Critical"
        } elseif ($defenderStatus.AntivirusSignatureAge -gt 7) {
            Add-ITSupportError -Section "Windows Defender" -Message "Las definiciones de antivirus tienen más de 7 días de antigüedad ($($defenderStatus.AntivirusSignatureAge) días)" -Severity "Warning"
        }
        
        $htmlContent += "<div class=`"metric $definitionsClass`">`n"
        $htmlContent += "<h3>Definiciones de Antivirus</h3>`n"
        $htmlContent += "<p>Antigüedad: <strong>$definitionsAge</strong></p>`n"
        $htmlContent += "</div>`n"
    }
    
    if ($defenderStatus.AntivirusProcesses) {
        $htmlContent += "<div class=`"metric good`">`n"
        $htmlContent += "<h3>Procesos de Antivirus Detectados</h3>`n"
        $htmlContent += "<p><strong>$($defenderStatus.AntivirusProcesses)</strong></p>`n"
        $htmlContent += "</div>`n"
    }
} else {
    # Registrar que no se pudo detectar antivirus
    Add-ITSupportError -Section "Windows Defender" -Message "Could not get antivirus protection information" -Severity "Critical"
    
    $htmlContent += "<div class=`"metric critical`">`n"
    $htmlContent += "<h3>Windows Defender / Antivirus</h3>`n"
    $htmlContent += "<p>Could not get antivirus protection information</p>`n"
    if ($defenderStatus.Error) {
        $htmlContent += "<p>Error: $($defenderStatus.Error)</p>`n"
    }
    $htmlContent += "</div>`n"
}

$htmlContent += "</div>`n" # Cerrar sección Defender

# Configuración de Firewall
$htmlContent += "<div class=`"diagnostic-section`">`n"
$htmlContent += "<h2>Configuración del Firewall</h2>`n"

if ($firewallStatus.Available) {
    $htmlContent += "<p>Método de detección: <strong>$($firewallStatus.Method)</strong></p>`n"
    
    if ($firewallStatus.Profiles) {
        foreach ($profile in $firewallStatus.Profiles) {
            $status = if ($profile.Enabled) { "Habilitado" } else { "Deshabilitado" }
            $statusClass = if ($profile.Enabled) { "good" } else { "critical" }
            
            # Registrar perfil de firewall deshabilitado
            if (-not $profile.Enabled) {
                Add-ITSupportError -Section "Firewall" -Message "El perfil de firewall '$($profile.Name)' está deshabilitado" -Severity "Critical"
            }
            
            $htmlContent += "<div class=`"metric $statusClass`">`n"
            $htmlContent += "<h3>Perfil $($profile.Name)</h3>`n"
            $htmlContent += "<p>Estado: <strong>$status</strong></p>`n"
            $htmlContent += "</div>`n"
        }
    } elseif ($firewallStatus.ServiceStatus) {
        $status = $firewallStatus.ServiceStatus
        $statusClass = if ($firewallStatus.Enabled) { "good" } else { "critical" }
        
        # Registrar servicio de firewall deshabilitado
        if (-not $firewallStatus.Enabled) {
            Add-ITSupportError -Section "Firewall" -Message "El servicio de firewall está deshabilitado" -Severity "Critical"
        }
        
        $htmlContent += "<div class=`"metric $statusClass`">`n"
        $htmlContent += "<h3>Servicio de Firewall</h3>`n"
        $htmlContent += "<p>Estado: <strong>$status</strong></p>`n"
        $htmlContent += "</div>`n"
    }
} else {
    # Registrar que no se pudo obtener información del firewall
    Add-ITSupportError -Section "Firewall" -Message "Could not get firewall information" -Severity "Warning"
    
    $htmlContent += "<div class=`"metric warning`">`n"
    $htmlContent += "<p>Could not get firewall information</p>`n"
    if ($firewallStatus.Error) {
        $htmlContent += "<p>Error: $($firewallStatus.Error)</p>`n"
    }
    $htmlContent += "</div>`n"
}

$htmlContent += "</div>`n" # Cerrar sección Firewall

# Actualizaciones de seguridad
$htmlContent += "<div class=`"diagnostic-section`">`n"
$htmlContent += "<h2>Actualizaciones de Seguridad</h2>`n"

if ($securityUpdates.UpdateCount -gt 0) {
    $updateClass = if ($securityUpdates.LastSecurityUpdate -and ((Get-Date) - $securityUpdates.LastSecurityUpdate).Days -le 30) { "good" } else { "warning" }
    
    # Registrar advertencia si las actualizaciones son muy antiguas
    if ($securityUpdates.LastSecurityUpdate -and ((Get-Date) - $securityUpdates.LastSecurityUpdate).Days -gt 30) {
        $daysSince = ((Get-Date) - $securityUpdates.LastSecurityUpdate).Days
        Add-ITSupportError -Section "Actualizaciones de Seguridad" -Message "La última actualización de seguridad es de hace $daysSince días" -Severity "Warning"
    }
    
    $htmlContent += "<div class=`"metric $updateClass`">`n"
    $htmlContent += "<h3>Estado de Actualizaciones</h3>`n"
    $htmlContent += "<p>Actualizaciones de seguridad encontradas: <strong>$($securityUpdates.UpdateCount)</strong></p>`n"
    
    if ($securityUpdates.LastSecurityUpdate) {
        $daysSince = ((Get-Date) - $securityUpdates.LastSecurityUpdate).Days
        $htmlContent += "<p>Última actualización de seguridad: <strong>$($securityUpdates.LastSecurityUpdate.ToString('yyyy-MM-dd'))</strong> (hace $daysSince días)</p>`n"
    }
    
    $htmlContent += "<h4>Últimas 5 actualizaciones:</h4>`n"
    $htmlContent += "<ul>`n"
    foreach ($update in ($securityUpdates.RecentUpdates | Select-Object -First 5)) {
        $htmlContent += "<li>$($update.HotFixID) - $($update.Description) - $($update.InstalledOn)</li>`n"
    }
    $htmlContent += "</ul>`n"
    $htmlContent += "</div>`n"
} else {
    # Registrar que no se pudieron obtener actualizaciones
    Add-ITSupportError -Section "Actualizaciones de Seguridad" -Message "No se pudieron obtener actualizaciones de seguridad" -Severity "Warning"
    
    $htmlContent += "<div class=`"metric warning`">`n"
    $htmlContent += "<p>No se pudieron obtener actualizaciones de seguridad</p>`n"
    $htmlContent += "</div>`n"
}

$htmlContent += "</div>`n" # Cerrar sección Updates

# Definir nombre del módulo para conteo específico
$moduleName = "SecurityScan"

# Agregar resumen de errores
$htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false

# Finalizar HTML con conteo específico del módulo
$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true -ModuleName $moduleName

# Guardar HTML
[System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "Escaneo de seguridad completado." -ForegroundColor Green
Write-Host "Reporte HTML: $htmlFile" -ForegroundColor Cyan
if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores/advertencias. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")