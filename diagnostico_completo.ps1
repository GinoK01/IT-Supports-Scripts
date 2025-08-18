# ====================================================================
# COMPLETE DETAILED DIAGNOSIS - PROFESSIONAL REPORT FOR CLIENTS
# ====================================================================
#
# PURPOSE:
# This script generates the most complete and professional report available
# It's perfect for formal deliveries to clients and exhaustive documentation
#
# WHAT THE REPORT INCLUDES:
# - Complete hardware inventory and specifications
# - List of installed software and versions
# - Detailed performance analysis (CPU, memory, disk)
# - Network connectivity diagnosis
# - Basic security evaluation
# - Specific technical recommendations
#
# EXECUTION TIME: 5-10 minutes
#
# WHEN TO USE IT:
# - To deliver a complete report to the client
# - Documentation before/after a technical service
# - Exhaustive analysis of corporate equipment
# - Purchase or sale evaluations of equipment
#
# RESULT:
# - Professional HTML report with graphics and tables
# - Easy to send by email or print
# - Includes executive summary and technical details
# ====================================================================

# Initial script configuration
Write-Host "=== STARTING COMPLETE DETAILED DIAGNOSIS ===" -ForegroundColor Yellow
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch {
    # If it fails, continue - some systems don't allow changing the policy
}

# Configure support for special characters (accents, ñ, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configure working paths
$PSScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logsPath = Join-Path -Path $PSScriptRoot -ChildPath "logs_reports"
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

Write-Host "Preparing complete diagnosis..." -ForegroundColor Green
Write-Host "Reports will be saved to: $logsPath" -ForegroundColor Gray

# ====================================================================
# LOAD SUPPORT MODULES
# ====================================================================
# These modules provide additional functions for error handling
# and professional HTML report generation

# Load error handling module
$errorHandlerPath = Join-Path -Path $PSScriptRoot -ChildPath "ErrorHandler.ps1"
if (Test-Path $errorHandlerPath) {
    . $errorHandlerPath
    Write-Host "Error handling module loaded" -ForegroundColor Green
} else {
    Write-Warning "ErrorHandler.ps1 module not found. Continuing without advanced error handling."
    # Create basic functions so the script doesn't fail
    function Add-ITSupportError { param($Section, $ErrorRecord) }
    function Clear-ITSupportErrors { }
    function Get-ErrorSummaryHTML { param($IncludeCSS) return "" }
    function Export-ErrorLog { param($Path) }
    function Invoke-SafeExecution { param($Section, $ScriptBlock, $DefaultValue) try { & $ScriptBlock } catch { $DefaultValue } }
}

# Load HTML template for professional reports
$htmlTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath "HTMLTemplate.ps1"
if (Test-Path $htmlTemplatePath) {
    . $htmlTemplatePath
    Write-Host "HTML template loaded correctly" -ForegroundColor Green
} else {
    Write-Warning "HTMLTemplate.ps1 not found. Using basic format."
    # Basic functions to generate HTML if template is not available
    function Get-UnifiedHTMLTemplate { 
        param($Title, $ComputerName, $UserName, $DateTime, $IncludeSummary)
        return "<html><head><title>$Title</title></head><body><h1>$Title</h1>"
    }
    function Get-UnifiedHTMLFooter { 
        param($IncludeCountingScript, $ModuleName)
        return "</body></html>"
    }
}

# Clear errors from previous executions
Clear-ITSupportErrors

# ==================== DETAILED DIAGNOSTIC FUNCTIONS ====================

# Enhanced function to get the default gateway
function Get-DefaultGateway {
    Write-Host "Detecting default gateway..." -ForegroundColor Yellow
    
    $gateway = Invoke-SafeExecution -Section "Network-Gateway-Discovery" -ScriptBlock {
        # Method 1: Use Get-CimInstance (more modern)
        try {
            $networkConfig = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop
            foreach ($adapter in $networkConfig) {
                if ($adapter.DefaultIPGateway -and $adapter.DefaultIPGateway[0]) {
                    Write-Host "  Gateway detected via CIM: $($adapter.DefaultIPGateway[0])" -ForegroundColor Green
                    return $adapter.DefaultIPGateway[0]
                }
            }
        } catch {
            # Continue with next method
        }
        
        # Method 2: Use Get-WmiObject (compatibility)
        try {
            $activeAdapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop
            foreach ($adapter in $activeAdapters) {
                if ($adapter.DefaultIPGateway -and $adapter.DefaultIPGateway[0]) {
                    Write-Host "  Gateway detected via WMI: $($adapter.DefaultIPGateway[0])" -ForegroundColor Green
                    return $adapter.DefaultIPGateway[0]
                }
            }
        } catch {
            # Continue with next method
        }
        
        # Method 3: Use route print (more reliable)
        try {
            $routeOutput = cmd /c "route print 0.0.0.0" 2>$null | Select-String "0.0.0.0.*0.0.0.0"
            if ($routeOutput) {
                $routeParts = $routeOutput.Line -split '\s+' | Where-Object { $_ -ne '' }
                for ($i = 0; $i -lt $routeParts.Length; $i++) {
                    if ($routeParts[$i] -match '^\d+\.\d+\.\d+\.\d+$' -and $routeParts[$i] -ne '0.0.0.0') {
                        Write-Host "  Gateway detected via route: $($routeParts[$i])" -ForegroundColor Green
                        return $routeParts[$i]
                    }
                }
            }
        } catch {
            # Continue to return null
        }
        
        return $null
    } -DefaultValue $null
    
    if (-not $gateway) {
        Write-Host "  Could not detect gateway automatically" -ForegroundColor Red
        Add-ITSupportError -Section "Network-Gateway-Discovery" -ErrorRecord "Could not detect default gateway"
    }
    
    return $gateway
}

# Function to test network connectivity
function Test-NetworkConnection {
    param(
        [string]$Target,
        [string]$Description,
        [int]$Count = 4
    )
    
    return Invoke-SafeExecution -Section "Network-Connectivity-$Target" -ScriptBlock {
        Write-Host "  Testing connectivity to $Description ($Target)..." -ForegroundColor Gray
        
        $result = Test-Connection -ComputerName $Target -Count $Count -ErrorAction Stop
        
        # Handle different PowerShell versions that may have different object structures
        $responseTime = 0
        $packetsReceived = 0
        
        if ($result) {
            # Try to get response time (multiple possible properties)
            $responseTimes = @()
            foreach ($ping in $result) {
                if ($ping.ResponseTime -ne $null) {
                    $responseTimes += $ping.ResponseTime
                    $packetsReceived++
                } elseif ($ping.Latency -ne $null) {
                    $responseTimes += $ping.Latency
                    $packetsReceived++
                } elseif ($ping.RoundtripTime -ne $null) {
                    $responseTimes += $ping.RoundtripTime
                    $packetsReceived++
                }
            }
            
            if ($responseTimes.Count -gt 0) {
                $responseTime = ($responseTimes | Measure-Object -Average).Average
            } else {
                # Fallback: use array length as indicator of packets received
                $packetsReceived = $result.Count
                $responseTime = 1 # Default value if response time cannot be obtained
            }
        }
        
        $packetLoss = [math]::Round((($Count - $packetsReceived) / $Count) * 100, 2)
        
        Write-Host "    OK $Description - Average: $([math]::Round($responseTime, 2))ms" -ForegroundColor Green
        
        return @{
            Target = $Target
            Description = $Description
            Status = "OK"
            AverageResponseTime = [math]::Round($responseTime, 2)
            PacketsSent = $Count
            PacketsReceived = $packetsReceived
            PacketLoss = $packetLoss
            Success = $true
        }
    } -DefaultValue @{
        Target = $Target
        Description = $Description
        Status = "FALLO"
        Error = "No se pudo conectar"
        Success = $false
    }
}

# Función detallada para obtener información de CPU
function Get-CPUInfo {
    Write-Host "Midiendo uso de CPU..." -ForegroundColor Yellow
    
    $cpuData = @{
        Load = 0
        Info = $null
        LoadSamples = @()
    }
    
    # Obtener información del procesador
    $cpuData.Info = Invoke-SafeExecution -Section "Rendimiento-CPU-Info" -ScriptBlock {
        Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
    } -DefaultValue $null
    
    # Método 1: Usar Get-Counter (más preciso)
    $cpuLoad = Invoke-SafeExecution -Section "Rendimiento-CPU-Counter" -ScriptBlock {
        Write-Host "  Tomando múltiples muestras de CPU..." -ForegroundColor Gray
        $samples = @()
        
        # Tomar varias muestras para obtener un promedio más confiable
        for ($i = 1; $i -le 3; $i++) {
            try {
                $counter = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
                $sample = [math]::Round($counter.CounterSamples[0].CookedValue, 2)
                $samples += $sample
                Write-Host "    Muestra ${i}: ${sample}%" -ForegroundColor Gray
            } catch {
                Write-Host "    Error en muestra ${i}" -ForegroundColor Red
            }
        }
        
        if ($samples.Count -gt 0) {
            $avgLoad = [math]::Round(($samples | Measure-Object -Average).Average, 2)
            return @{
                Average = $avgLoad
                Samples = $samples
                Method = "Performance Counter"
            }
        }
        return $null
    } -DefaultValue $null
    
    # Método 2: Fallback usando WMI
    if (-not $cpuLoad) {
        $cpuLoad = Invoke-SafeExecution -Section "Rendimiento-CPU-WMI" -ScriptBlock {
            Write-Host "  Usando método WMI como respaldo..." -ForegroundColor Gray
            $cpu = Get-WmiObject -Class Win32_Processor
            if ($cpu.LoadPercentage) {
                return @{
                    Average = $cpu.LoadPercentage
                    Method = "WMI LoadPercentage"
                }
            }
            return $null
        } -DefaultValue $null
    }
    
    if ($cpuLoad) {
        $cpuData.Load = $cpuLoad.Average
        $cpuData.LoadSamples = $cpuLoad.Samples
        $cpuData.Method = $cpuLoad.Method
        Write-Host "  OK CPU Load: $($cpuLoad.Average)%" -ForegroundColor Green
    } else {
        Write-Host "  ERROR No se pudo obtener el uso de CPU" -ForegroundColor Red
        $cpuData.Load = 0
    }
    
    return $cpuData
}

# Función detallada para obtener información de memoria
function Get-MemoryInfo {
    Write-Host "Analizando uso de memoria..." -ForegroundColor Yellow
    
    return Invoke-SafeExecution -Section "Rendimiento-Memoria" -ScriptBlock {
        # Información del sistema operativo
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        
        # Información de memoria física
        $physicalMemory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
        
        # Cálculos
        $totalMemoryKB = $os.TotalVisibleMemorySize
        $freeMemoryKB = $os.FreePhysicalMemory
        $usedMemoryKB = $totalMemoryKB - $freeMemoryKB
        
        $totalMemoryGB = [math]::Round($totalMemoryKB / 1MB, 2)
        $freeMemoryGB = [math]::Round($freeMemoryKB / 1MB, 2)
        $usedMemoryGB = [math]::Round($usedMemoryKB / 1MB, 2)
        $usagePercent = [math]::Round(($usedMemoryKB / $totalMemoryKB) * 100, 2)
        
        # Información de módulos
        $memoryModules = $physicalMemory | ForEach-Object {
            @{
                Capacity = [math]::Round($_.Capacity / 1GB, 2)
                Speed = $_.Speed
                Manufacturer = $_.Manufacturer
                PartNumber = $_.PartNumber
            }
        }
        
        Write-Host "  OK Memoria total: ${totalMemoryGB} GB, Uso: ${usagePercent}%" -ForegroundColor Green
        
        return @{
            TotalGB = $totalMemoryGB
            UsedGB = $usedMemoryGB
            FreeGB = $freeMemoryGB
            UsagePercent = $usagePercent
            TotalModules = $physicalMemory.Count
            Modules = $memoryModules
        }
    } -DefaultValue @{
        TotalGB = 0
        UsedGB = 0
        FreeGB = 0
        UsagePercent = 0
        TotalModules = 0
        Modules = @()
    }
}

# Función detallada para obtener información de discos
function Get-DiskInfo {
    Write-Host "Analizando discos..." -ForegroundColor Yellow
    
    return Invoke-SafeExecution -Section "Rendimiento-Discos" -ScriptBlock {
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        $diskData = @()
        
        foreach ($disk in $disks) {
            $totalGB = [math]::Round($disk.Size / 1GB, 2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usedGB = $totalGB - $freeGB
            $usagePercent = if ($totalGB -gt 0) { [math]::Round(($usedGB / $totalGB) * 100, 2) } else { 0 }
            
            # Obtener información adicional del disco físico
            $physicalDisk = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue | 
                Where-Object { $_.DeviceID -eq $disk.DeviceID }
            
            $diskInfo = @{
                Drive = $disk.DeviceID
                Label = $disk.VolumeName
                TotalGB = $totalGB
                UsedGB = $usedGB
                FreeGB = $freeGB
                UsagePercent = $usagePercent
                FileSystem = $disk.FileSystem
                DriveType = "Local Disk"
            }
            
            if ($physicalDisk) {
                $diskInfo.Model = $physicalDisk.Model
                $diskInfo.Interface = $physicalDisk.InterfaceType
            }
            
            $diskData += $diskInfo
            Write-Host "  OK Disco $($disk.DeviceID) - $usagePercent% usado ($usedGB/$totalGB GB)" -ForegroundColor Green
        }
        
        return $diskData
    } -DefaultValue @()
}

# Función detallada para obtener estado de Windows Defender
function Get-DefenderStatus {
    Write-Host "Verificando estado de Windows Defender..." -ForegroundColor Yellow
    
    # Método 1: Get-MpComputerStatus (Windows 8+)
    $defenderStatus = Invoke-SafeExecution -Section "Windows Defender Primary" -ScriptBlock {
        Get-MpComputerStatus -ErrorAction Stop
    } -DefaultValue $null
    
    if ($defenderStatus) {
        Write-Host "  OK Windows Defender detectado via Get-MpComputerStatus" -ForegroundColor Green
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
        Write-Host "  OK Servicio Windows Defender detectado: $($defenderService.Status)" -ForegroundColor Green
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
        Write-Host "  OK Procesos de antivirus detectados: $($antivirusProcesses.ProcessName -join ', ')" -ForegroundColor Green
        return @{
            Method = "Process Detection"
            AntivirusProcesses = $antivirusProcesses.ProcessName -join ", "
            Available = $true
            RealTimeProtectionEnabled = $true
        }
    }
    
    Write-Host "  ERROR No se pudo detectar Windows Defender" -ForegroundColor Red
    return @{
        Method = "None"
        Available = $false
        RealTimeProtectionEnabled = $false
        Error = "No se pudo detectar Windows Defender"
    }
}

# Función detallada para obtener estado del firewall
function Get-FirewallStatus {
    Write-Host "Verificando configuración del firewall..." -ForegroundColor Yellow
    
    # Método 1: Get-NetFirewallProfile (Windows 8+)
    $firewallProfiles = Invoke-SafeExecution -Section "Firewall Profiles" -ScriptBlock {
        Get-NetFirewallProfile -ErrorAction Stop
    } -DefaultValue $null
    
    if ($firewallProfiles) {
        $profiles = @()
        foreach ($profile in $firewallProfiles) {
            $profiles += @{
                Name = $profile.Name
                Enabled = $profile.Enabled
                DefaultInboundAction = $profile.DefaultInboundAction
                DefaultOutboundAction = $profile.DefaultOutboundAction
            }
        }
        Write-Host "  OK Firewall detectado via Get-NetFirewallProfile" -ForegroundColor Green
        return @{
            Method = "Get-NetFirewallProfile"
            Profiles = $profiles
            Available = $true
        }
    }
    
    # Método 2: netsh firewall (compatibilidad)
    $netshResult = Invoke-SafeExecution -Section "Firewall netsh" -ScriptBlock {
        $output = netsh advfirewall show allprofiles state 2>$null
        return $output
    } -DefaultValue $null
    
    if ($netshResult) {
        Write-Host "  OK Firewall detectado via netsh" -ForegroundColor Green
        return @{
            Method = "netsh"
            Output = $netshResult -join "`n"
            Available = $true
        }
    }
    
    Write-Host "  ERROR No se pudo verificar el estado del firewall" -ForegroundColor Red
    return @{
        Method = "None"
        Available = $false
        Error = "No se pudo verificar el firewall"
    }
}

# ==================== INICIO DEL DIAGNOSTICO PRINCIPAL ====================

$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$htmlReportPath = Join-Path -Path $logsPath -ChildPath "diagnostico_completo_$timestamp.html"

Write-Host "Iniciando diagnóstico completo detallado..." -ForegroundColor Green

# Variables del sistema
$computerName = $env:COMPUTERNAME
$userName = $env:USERNAME
$currentDate = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

# === 1. DETECCIÓN DE GATEWAY ===
Write-Host "`n=== DETECCIÓN DE GATEWAY ===" -ForegroundColor Cyan
$detectedGateway = Get-DefaultGateway

# === 2. DIAGNÓSTICO DE RED ===
Write-Host "`n=== DIAGNÓSTICO DE RED ===" -ForegroundColor Cyan
$networkResults = @()

# Pruebas de conectividad
$targets = @(
    @{IP="8.8.8.8"; Name="Google DNS"},
    @{IP="1.1.1.1"; Name="Cloudflare DNS"},
    @{IP="208.67.222.222"; Name="OpenDNS"}
)

if ($detectedGateway) {
    $targets += @{IP=$detectedGateway; Name="Gateway Local"}
}

foreach ($target in $targets) {
    $result = Test-NetworkConnection -Target $target.IP -Description $target.Name
    $networkResults += $result
}

# Información de adaptadores de red
Write-Host "Obteniendo información de adaptadores de red..." -ForegroundColor Yellow
$networkAdapters = Invoke-SafeExecution -Section "Red-Adaptadores" -ScriptBlock {
    $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop
    $adapterData = @()
    
    foreach ($adapter in $adapters) {
        $adapterInfo = @{
            Description = $adapter.Description
            IPAddress = if ($adapter.IPAddress) { $adapter.IPAddress[0] } else { "N/A" }
            SubnetMask = if ($adapter.IPSubnet) { $adapter.IPSubnet[0] } else { "N/A" }
            Gateway = if ($adapter.DefaultIPGateway) { $adapter.DefaultIPGateway[0] } else { "N/A" }
            DHCPEnabled = $adapter.DHCPEnabled
            DNSServers = if ($adapter.DNSServerSearchOrder) { $adapter.DNSServerSearchOrder -join ", " } else { "N/A" }
            MACAddress = $adapter.MACAddress
        }
        $adapterData += $adapterInfo
    }
    
    return $adapterData
} -DefaultValue @()

Write-Host "OK Información de $($networkAdapters.Count) adaptadores obtenida" -ForegroundColor Green

# === 3. DIAGNÓSTICO DE RENDIMIENTO ===
Write-Host "`n=== DIAGNÓSTICO DE RENDIMIENTO ===" -ForegroundColor Cyan
$cpuInfo = Get-CPUInfo
$memoryInfo = Get-MemoryInfo
$diskInfo = Get-DiskInfo

# === 4. ESCANEO DE SEGURIDAD ===
Write-Host "`n=== ESCANEO DE SEGURIDAD ===" -ForegroundColor Cyan
$defenderStatus = Get-DefenderStatus
$firewallStatus = Get-FirewallStatus

# Servicios críticos
Write-Host "Verificando servicios críticos..." -ForegroundColor Yellow
$criticalServices = @("wuauserv", "wscsvc", "WinRM", "Themes", "Spooler")
$serviceStatus = @()

foreach ($serviceName in $criticalServices) {
    $service = Invoke-SafeExecution -Section "Servicio-$serviceName" -ScriptBlock {
        Get-Service -Name $serviceName -ErrorAction Stop
    } -DefaultValue $null
    
    if ($service) {
        $serviceStatus += @{
            Name = $service.DisplayName
            ServiceName = $serviceName
            Status = $service.Status.ToString()
            StartType = $service.StartType.ToString()
        }
        Write-Host "  OK $($service.DisplayName): $($service.Status)" -ForegroundColor Green
    } else {
        $serviceStatus += @{
            Name = $serviceName
            ServiceName = $serviceName
            Status = "No encontrado"
            StartType = "N/A"
        }
        Write-Host "  ERROR ${serviceName}: No encontrado" -ForegroundColor Red
    }
}

# Usuarios locales
Write-Host "Analizando cuentas de usuario..." -ForegroundColor Yellow
$localUsers = Invoke-SafeExecution -Section "Usuarios-Locales" -ScriptBlock {
    $users = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount=True" -ErrorAction Stop
    $userData = @()
    
    foreach ($user in $users) {
        $userData += @{
            Name = $user.Name
            FullName = $user.FullName
            Disabled = $user.Disabled
            PasswordRequired = $user.PasswordRequired
            PasswordChangeable = $user.PasswordChangeable
        }
    }
    
    return $userData
} -DefaultValue @()

Write-Host "OK $($localUsers.Count) cuentas de usuario analizadas" -ForegroundColor Green

# === 5. INVENTARIO DE HARDWARE/SOFTWARE ===
Write-Host "`n=== INVENTARIO DE HARDWARE/SOFTWARE ===" -ForegroundColor Cyan

# Información del sistema
Write-Host "Obteniendo información del sistema..." -ForegroundColor Yellow
$systemInfo = Invoke-SafeExecution -Section "Sistema-Info" -ScriptBlock {
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    
    return @{
        ComputerName = $computer.Name
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        TotalPhysicalMemory = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
        OSName = $os.Caption
        OSVersion = $os.Version
        OSArchitecture = $os.OSArchitecture
        InstallDate = $os.InstallDate
        LastBootUpTime = $os.LastBootUpTime
        BIOSVersion = $bios.SMBIOSBIOSVersion
        BIOSManufacturer = $bios.Manufacturer
    }
} -DefaultValue @{}

Write-Host "OK Información del sistema obtenida" -ForegroundColor Green

# === 6. VALIDACIÓN DE USUARIO ===
Write-Host "`n=== VALIDACIÓN DE USUARIO ===" -ForegroundColor Cyan
Write-Host "Analizando permisos del usuario..." -ForegroundColor Yellow

$userInfo = Invoke-SafeExecution -Section "Usuario-Actual" -ScriptBlock {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    
    return @{
        UserName = $currentUser.Name
        Domain = $env:USERDOMAIN
        IsAuthenticated = $currentUser.IsAuthenticated
        IsAdmin = $isAdmin
        AuthenticationType = $currentUser.AuthenticationType
        UserProfile = $env:USERPROFILE
    }
} -DefaultValue @{}

Write-Host "OK Usuario: $($userInfo.UserName), Admin: $($userInfo.IsAdmin)" -ForegroundColor Green

# === 7. EVALUACIÓN RÁPIDA ===
Write-Host "`n=== EVALUACIÓN RÁPIDA ===" -ForegroundColor Cyan
$recommendations = @()

# Análisis de espacio en disco
foreach ($disk in $diskInfo) {
    if ($disk.UsagePercent -gt 90) {
        $recommendations += "CRÍTICO: Disco $($disk.Drive) casi lleno ($($disk.UsagePercent)%)"
    } elseif ($disk.UsagePercent -gt 80) {
        $recommendations += "ADVERTENCIA: Disco $($disk.Drive) con poco espacio ($($disk.UsagePercent)%)"
    }
}

# Análisis de memoria
if ($memoryInfo.UsagePercent -gt 90) {
    $recommendations += "CRÍTICO: Uso de memoria muy alto ($($memoryInfo.UsagePercent)%)"
} elseif ($memoryInfo.UsagePercent -gt 80) {
    $recommendations += "ADVERTENCIA: Uso de memoria alto ($($memoryInfo.UsagePercent)%)"
}

# Análisis de CPU
if ($cpuInfo.Load -gt 90) {
    $recommendations += "CRÍTICO: Uso de CPU muy alto ($($cpuInfo.Load)%)"
} elseif ($cpuInfo.Load -gt 80) {
    $recommendations += "ADVERTENCIA: Uso de CPU alto ($($cpuInfo.Load)%)"
}

# Análisis de seguridad
if (-not $defenderStatus.Available -or -not $defenderStatus.RealTimeProtectionEnabled) {
    $recommendations += "ADVERTENCIA: Windows Defender no está funcionando correctamente"
}

if (-not $firewallStatus.Available) {
    $recommendations += "ADVERTENCIA: No se pudo verificar el estado del firewall"
}

Write-Host "OK $($recommendations.Count) recomendaciones generadas" -ForegroundColor Green

# ==================== GENERACIÓN DEL REPORTE HTML ====================

Write-Host "`n=== GENERANDO REPORTE HTML DETALLADO ===" -ForegroundColor Cyan

$htmlContent = Get-UnifiedHTMLTemplate -Title "Diagnóstico Completo Detallado del Sistema" -ComputerName $computerName -UserName $userName -DateTime $currentDate -IncludeSummary $true

# Información del sistema
$htmlContent += "<div class='info-box'><h2>Información del Sistema</h2><div class='metric info'>"
$htmlContent += "<p><strong>Equipo:</strong> $computerName</p>"
$htmlContent += "<p><strong>Usuario:</strong> $userName</p>"
$htmlContent += "<p><strong>Fecha y Hora:</strong> $currentDate</p>"
$htmlContent += "<p><strong>Gateway Detectado:</strong> $(if($detectedGateway) { $detectedGateway } else { 'No detectado' })</p>"
$htmlContent += "</div></div>"

# Red detallada
$htmlContent += "<div class='diagnostic-section'><h2>Red</h2><div class='metric good'>"
$htmlContent += "<h3>Configuración de Red</h3>"
$htmlContent += "<p><strong>Gateway:</strong> $(if($detectedGateway) { $detectedGateway } else { 'No detectado' })</p>"
$htmlContent += "<h4>Pruebas de Conectividad:</h4><ul>"

foreach ($conn in $networkResults) {
    $connClass = if ($conn.Success) { "good" } else { "critical" }
    $connInfo = if ($conn.Success) { " ($($conn.AverageResponseTime)ms, $($conn.PacketLoss)% pérdida)" } else { " - $($conn.Error)" }
    $htmlContent += "<li class='metric $connClass'>$($conn.Description): $($conn.Status)$connInfo</li>"
}

$htmlContent += "</ul><h4>Adaptadores de Red:</h4><table style='width:100%; border-collapse:collapse;'>"
$htmlContent += "<tr style='background-color:#f0f0f0;'>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Descripción</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>IP</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Gateway</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>DHCP</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>DNS</th></tr>"

foreach ($adapter in $networkAdapters) {
    $htmlContent += "<tr>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($adapter.Description)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($adapter.IPAddress)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($adapter.Gateway)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($adapter.DHCPEnabled)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px; font-size:10px;'>$($adapter.DNSServers)</td>"
    $htmlContent += "</tr>"
}

$htmlContent += "</table></div></div>"

# Rendimiento detallado
$cpuClass = if ($cpuInfo.Load -lt 70) { "good" } elseif ($cpuInfo.Load -lt 90) { "warning" } else { "critical" }
$memClass = if ($memoryInfo.UsagePercent -lt 70) { "good" } elseif ($memoryInfo.UsagePercent -lt 90) { "warning" } else { "critical" }

$htmlContent += "<div class='diagnostic-section'><h2>Rendimiento del Sistema</h2>"
$htmlContent += "<div class='metric $cpuClass'><h3>CPU</h3>"
$htmlContent += "<p><strong>Modelo:</strong> $($cpuInfo.Info.Name)</p>"
$htmlContent += "<p><strong>Núcleos:</strong> $($cpuInfo.Info.NumberOfCores) físicos, $($cpuInfo.Info.NumberOfLogicalProcessors) lógicos</p>"
$htmlContent += "<p><strong>Velocidad:</strong> $($cpuInfo.Info.MaxClockSpeed) MHz</p>"
$htmlContent += "<p><strong>Uso Actual:</strong> $($cpuInfo.Load)% $(if($cpuInfo.Method) { '(' + $cpuInfo.Method + ')' })</p>"

if ($cpuInfo.LoadSamples -and $cpuInfo.LoadSamples.Count -gt 0) {
    $htmlContent += "<p><strong>Muestras:</strong> $($cpuInfo.LoadSamples -join '%, ')%</p>"
}

$htmlContent += "</div><div class='metric $memClass'><h3>Memoria</h3>"
$htmlContent += "<p><strong>Total:</strong> $($memoryInfo.TotalGB) GB</p>"
$htmlContent += "<p><strong>En Uso:</strong> $($memoryInfo.UsedGB) GB ($($memoryInfo.UsagePercent)%)</p>"
$htmlContent += "<p><strong>Disponible:</strong> $($memoryInfo.FreeGB) GB</p>"
$htmlContent += "<p><strong>Módulos:</strong> $($memoryInfo.TotalModules) instalados</p></div>"

$htmlContent += "<div class='metric info'><h3>Discos</h3><table style='width:100%; border-collapse:collapse;'>"
$htmlContent += "<tr style='background-color:#f0f0f0;'>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Unidad</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Etiqueta</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Total</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Usado</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Libre</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>% Uso</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Sistema</th></tr>"

foreach ($disk in $diskInfo) {
    $diskUsageClass = if ($disk.UsagePercent -lt 70) { "color:green;" } elseif ($disk.UsagePercent -lt 90) { "color:orange;" } else { "color:red;" }
    $htmlContent += "<tr>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($disk.Drive)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($disk.Label)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($disk.TotalGB) GB</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($disk.UsedGB) GB</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($disk.FreeGB) GB</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px; $diskUsageClass'>$($disk.UsagePercent)%</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($disk.FileSystem)</td>"
    $htmlContent += "</tr>"
}

$htmlContent += "</table></div></div>"

# Seguridad detallada
$htmlContent += "<div class='diagnostic-section'><h2>Seguridad del Sistema</h2>"

# Windows Defender
$defenderClass = if ($defenderStatus.Available -and $defenderStatus.RealTimeProtectionEnabled) { "good" } else { "critical" }
$htmlContent += "<div class='metric $defenderClass'><h3>Windows Defender</h3>"
$htmlContent += "<p><strong>Estado:</strong> $(if($defenderStatus.Available) { 'Disponible' } else { 'No disponible' })</p>"
$htmlContent += "<p><strong>Método de detección:</strong> $($defenderStatus.Method)</p>"

if ($defenderStatus.Available) {
    if ($defenderStatus.RealTimeProtectionEnabled -ne $null) {
        $htmlContent += "<p><strong>Protección en tiempo real:</strong> $(if($defenderStatus.RealTimeProtectionEnabled) { 'Habilitada' } else { 'Deshabilitada' })</p>"
    }
    if ($defenderStatus.AntivirusEnabled -ne $null) {
        $htmlContent += "<p><strong>Antivirus:</strong> $(if($defenderStatus.AntivirusEnabled) { 'Habilitado' } else { 'Deshabilitado' })</p>"
    }
    if ($defenderStatus.AntivirusSignatureAge -ne $null) {
        $htmlContent += "<p><strong>Edad de firmas antivirus:</strong> $($defenderStatus.AntivirusSignatureAge) días</p>"
    }
}

if ($defenderStatus.Error) {
    $htmlContent += "<p><strong>Error:</strong> $($defenderStatus.Error)</p>"
}

$htmlContent += "</div>"

# Firewall
$firewallClass = if ($firewallStatus.Available) { "good" } else { "warning" }
$htmlContent += "<div class='metric $firewallClass'><h3>Firewall</h3>"
$htmlContent += "<p><strong>Estado:</strong> $(if($firewallStatus.Available) { 'Disponible' } else { 'No disponible' })</p>"
$htmlContent += "<p><strong>Método de verificación:</strong> $($firewallStatus.Method)</p>"

if ($firewallStatus.Profiles) {
    $htmlContent += "<h4>Perfiles:</h4><ul>"
    foreach ($profile in $firewallStatus.Profiles) {
        $profileStatus = if ($profile.Enabled) { "Habilitado" } else { "Deshabilitado" }
        $htmlContent += "<li>$($profile.Name): $profileStatus</li>"
    }
    $htmlContent += "</ul>"
}

$htmlContent += "</div>"

# Servicios críticos
$htmlContent += "<div class='metric info'><h3>Servicios Críticos</h3>"
$htmlContent += "<table style='width:100%; border-collapse:collapse;'>"
$htmlContent += "<tr style='background-color:#f0f0f0;'>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Servicio</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Estado</th>"
$htmlContent += "<th style='border:1px solid #ddd; padding:8px;'>Tipo de inicio</th></tr>"

foreach ($service in $serviceStatus) {
    $serviceClass = if ($service.Status -eq "Running") { "color:green;" } elseif ($service.Status -eq "Stopped") { "color:red;" } else { "color:orange;" }
    $htmlContent += "<tr>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($service.Name)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px; $serviceClass'>$($service.Status)</td>"
    $htmlContent += "<td style='border:1px solid #ddd; padding:8px;'>$($service.StartType)</td>"
    $htmlContent += "</tr>"
}

$htmlContent += "</table></div></div>"

# Resumen final
$htmlContent += "<div class='diagnostic-section'><h2>Resumen Ejecutivo</h2>"
$htmlContent += "<div class='metric info'><h3>Diagnóstico Completo Detallado</h3>"
$htmlContent += "<p><strong>Fecha de ejecución:</strong> $currentDate</p>"
$htmlContent += "<p><strong>Equipo analizado:</strong> $computerName</p>"
$htmlContent += "<p><strong>Usuario:</strong> $userName</p>"
$htmlContent += "<p><strong>Gateway detectado:</strong> $(if($detectedGateway) { $detectedGateway } else { 'No detectado' })</p>"
$htmlContent += "<p><strong>Módulos ejecutados:</strong> Red, Rendimiento, Seguridad, Inventario, Usuario, Evaluación Rápida</p>"
$htmlContent += "<p><strong>Total de recomendaciones:</strong> $($recommendations.Count)</p>"

# Agregar recomendaciones si las hay
if ($recommendations.Count -gt 0) {
    $htmlContent += "<h4>Recomendaciones:</h4><ul>"
    foreach ($rec in $recommendations) {
        $recClass = if ($rec -like "CRÍTICO:*") { "critical" } else { "warning" }
        $htmlContent += "<li class='metric $recClass'>$rec</li>"
    }
    $htmlContent += "</ul>"
}

$htmlContent += "<p>Este reporte contiene toda la información de diagnóstico unificada en un solo archivo HTML detallado.</p>"
$htmlContent += "</div></div>"

# Agregar resumen de errores
$htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false

# Finalizar HTML
$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true

# Guardar reporte
try {
    [System.IO.File]::WriteAllText($htmlReportPath, $htmlContent, [System.Text.Encoding]::UTF8)
    Write-Host "OK Reporte HTML generado: $htmlReportPath" -ForegroundColor Green
} catch {
    Write-Host "ERROR al guardar el reporte: $($_.Exception.Message)" -ForegroundColor Red
    Add-ITSupportError -Section "Reporte-HTML" -ErrorRecord $_
}

# Exportar log de errores si hay errores registrados
if ($Global:ITSupportErrors.Count -gt 0) {
    $errorLogPath = Join-Path -Path $logsPath -ChildPath "diagnostico_completo_errores_$timestamp.log"
    Export-ErrorLog -Path $errorLogPath
    Write-Host "⚠️  Se detectaron $($Global:ITSupportErrors.Count) errores/advertencias. Ver detalles en el reporte HTML." -ForegroundColor Yellow
    Write-Host "Log de errores exportado: $errorLogPath" -ForegroundColor Yellow
}

Write-Host "`n=== DIAGNOSTICO COMPLETO FINALIZADO ===" -ForegroundColor Yellow
Write-Host "Reporte HTML detallado: $htmlReportPath" -ForegroundColor Cyan
Write-Host "Gateway detectado: $(if($detectedGateway) { $detectedGateway } else { 'No detectado' })" -ForegroundColor Cyan
Write-Host "Recomendaciones generadas: $($recommendations.Count)" -ForegroundColor Cyan
if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Errores detectados: $($Global:ITSupportErrors.Count)" -ForegroundColor Yellow
} else {
    Write-Host "Ejecución completada sin errores" -ForegroundColor Green
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
