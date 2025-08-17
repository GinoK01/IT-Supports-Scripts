# Intentar configurar la política de ejecución (silenciando errores si falla)
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

# Inventario de Hardware y Software en Windows
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$htmlFile = Join-Path -Path $logsPath -ChildPath "inventario_hw_sw_$timestamp.html"

Write-Host "Iniciando inventario de hardware y software..." -ForegroundColor Green

# Función para obtener información de hardware
function Get-HardwareInfo {
    Write-Host "Recopilando información de hardware..." -ForegroundColor Yellow
    
    $hardwareInfo = @{}
    
    # Información del sistema
    $hardwareInfo.System = Invoke-SafeExecution -Seccion "Inventario-Sistema" -ScriptBlock {
        Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    } -DefaultValue $null
    
    # Información del procesador
    $hardwareInfo.Processor = Invoke-SafeExecution -Seccion "Inventario-Procesador" -ScriptBlock {
        Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
    } -DefaultValue $null
    
    # Información de memoria
    $hardwareInfo.Memory = Invoke-SafeExecution -Seccion "Inventario-Memoria" -ScriptBlock {
        Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
    } -DefaultValue @()
    
    # Información de discos
    $hardwareInfo.Disks = Invoke-SafeExecution -Seccion "Inventario-Discos" -ScriptBlock {
        Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop
    } -DefaultValue @()
    
    # Información de adaptadores de red
    $hardwareInfo.NetworkAdapters = Invoke-SafeExecution -Seccion "Inventario-Red" -ScriptBlock {
        Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "NetConnectionStatus=2" -ErrorAction Stop
    } -DefaultValue @()
    
    # Información de la placa madre
    $hardwareInfo.Motherboard = Invoke-SafeExecution -Seccion "Inventario-PlacaMadre" -ScriptBlock {
        Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
    } -DefaultValue $null
    
    # Información de video
    $hardwareInfo.VideoController = Invoke-SafeExecution -Seccion "Inventario-Video" -ScriptBlock {
        Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    } -DefaultValue @()
    
    return $hardwareInfo
}

# Función para obtener información de software
function Get-SoftwareInfo {
    Write-Host "Recopilando información de software..." -ForegroundColor Yellow
    
    $softwareInfo = @{}
    
    # Sistema operativo
    $softwareInfo.OS = Invoke-SafeExecution -Seccion "Inventario-SO" -ScriptBlock {
        Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    } -DefaultValue $null
    
    # Software instalado desde el registro (más rápido que Win32_Product)
    $softwareInfo.InstalledPrograms = Invoke-SafeExecution -Seccion "Inventario-Software-Registro" -ScriptBlock {
        $programs = @()
        
        Write-Host "  Escaneando programas instalados..." -ForegroundColor Gray
        
        # Método 1: Get-WmiObject Win32_Product (más lento pero más confiable)
        try {
            Write-Host "    Usando Win32_Product..." -ForegroundColor Gray
            $wmiPrograms = Get-CimInstance -ClassName Win32_Product -ErrorAction Stop |
                          Select-Object Name, Version, Vendor |
                          Where-Object { $_.Name -and $_.Name.Trim() -ne "" }
            
            if ($wmiPrograms) {
                $programs = $wmiPrograms | ForEach-Object {
                    [PSCustomObject]@{
                        DisplayName = $_.Name
                        DisplayVersion = $_.Version
                        Publisher = $_.Vendor
                    }
                }
                Write-Host "    Encontrados $($programs.Count) programas con Win32_Product" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    Error con Win32_Product: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Método 2: Registro (si el método anterior falló)
        if ($programs.Count -eq 0) {
            try {
                Write-Host "    Usando registro del sistema..." -ForegroundColor Gray
                
                # Obtener lista de claves de registro directamente
                $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                $subKeys = Get-ChildItem -Path $uninstallKey -ErrorAction SilentlyContinue
                
                foreach ($key in $subKeys) {
                    try {
                        $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                        if ($props.DisplayName -and $props.DisplayName.Trim() -ne "") {
                            $programs += [PSCustomObject]@{
                                DisplayName = $props.DisplayName
                                DisplayVersion = if ($props.DisplayVersion) { $props.DisplayVersion } else { "N/A" }
                                Publisher = if ($props.Publisher) { $props.Publisher } else { "N/A" }
                            }
                        }
                    } catch {
                        # Continuar con la siguiente clave si hay error
                        continue
                    }
                }
                
                # También revisar 32-bit en sistemas 64-bit
                $uninstallKey32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                if (Test-Path $uninstallKey32) {
                    $subKeys32 = Get-ChildItem -Path $uninstallKey32 -ErrorAction SilentlyContinue
                    
                    foreach ($key in $subKeys32) {
                        try {
                            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                            if ($props.DisplayName -and $props.DisplayName.Trim() -ne "") {
                                $programs += [PSCustomObject]@{
                                    DisplayName = $props.DisplayName
                                    DisplayVersion = if ($props.DisplayVersion) { $props.DisplayVersion } else { "N/A" }
                                    Publisher = if ($props.Publisher) { $props.Publisher } else { "N/A" }
                                }
                            }
                        } catch {
                            # Continuar con la siguiente clave si hay error
                            continue
                        }
                    }
                }
                
                Write-Host "    Encontrados $($programs.Count) programas en registro" -ForegroundColor Gray
            } catch {
                Write-Host "    Error con registro: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Método 3: Get-Package (PowerShell 5.0+)
        if ($programs.Count -eq 0) {
            try {
                Write-Host "    Usando Get-Package..." -ForegroundColor Gray
                $packagePrograms = Get-Package -ErrorAction Stop |
                                  Where-Object { $_.Name -and $_.Name.Trim() -ne "" } |
                                  Select-Object Name, Version, Source
                
                if ($packagePrograms) {
                    $programs = $packagePrograms | ForEach-Object {
                        [PSCustomObject]@{
                            DisplayName = $_.Name
                            DisplayVersion = $_.Version
                            Publisher = $_.Source
                        }
                    }
                    Write-Host "    Encontrados $($programs.Count) programas con Get-Package" -ForegroundColor Gray
                }
            } catch {
                Write-Host "    Error con Get-Package: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Eliminar duplicados
        if ($programs.Count -gt 0) {
            $uniquePrograms = $programs | Sort-Object DisplayName | Group-Object DisplayName | ForEach-Object { $_.Group[0] }
            Write-Host "    Total único: $($uniquePrograms.Count) programas" -ForegroundColor Gray
            return $uniquePrograms
        }
        
        return @()
    } -DefaultValue @()
    
    # Servicios importantes
    $softwareInfo.Services = Invoke-SafeExecution -Seccion "Inventario-Servicios" -ScriptBlock {
        Get-Service -ErrorAction Stop | Where-Object { 
            $_.Status -eq 'Running' -and 
            ($_.Name -like "*antivirus*" -or 
             $_.Name -like "*firewall*" -or 
             $_.Name -like "*defender*" -or 
             $_.Name -eq "Spooler" -or 
             $_.Name -eq "BITS" -or 
             $_.Name -eq "Themes" -or
             $_.Name -eq "AudioSrv")
        } | Select-Object Name, DisplayName, Status
    } -DefaultValue @()
    
    # Procesos actuales (top 10)
    $softwareInfo.TopProcesses = Invoke-SafeExecution -Seccion "Inventario-Procesos" -ScriptBlock {
        Get-Process -ErrorAction Stop | 
        Sort-Object WorkingSet -Descending | 
        Select-Object -First 10 |
        Select-Object ProcessName, Id, @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet/1MB, 2)}}
    } -DefaultValue @()
    
    return $softwareInfo
}

# Ejecutar recopilación de información
$hardwareInfo = Get-HardwareInfo
$softwareInfo = Get-SoftwareInfo

# Crear archivo HTML
$htmlContent = Get-UnifiedHTMLTemplate -Title "Inventario de Hardware y Software" -IncludeSummary $true

$htmlContent += "<div class=`"diagnostic-section`">"
$htmlContent += "<h2>Resumen del Sistema</h2>"
$htmlContent += "<div class=`"metric good`">"
if ($hardwareInfo.System) {
    $htmlContent += "<p><strong>Equipo:</strong> $($hardwareInfo.System.Manufacturer) $($hardwareInfo.System.Model)</p>"
    $htmlContent += "<p><strong>Memoria Total:</strong> $([math]::Round($hardwareInfo.System.TotalPhysicalMemory/1GB, 2)) GB</p>"
}
if ($softwareInfo.OS) {
    $htmlContent += "<p><strong>Sistema Operativo:</strong> $($softwareInfo.OS.Caption) ($($softwareInfo.OS.OSArchitecture))</p>"
    $htmlContent += "<p><strong>Versión:</strong> $($softwareInfo.OS.Version)</p>"
}
$htmlContent += "</div></div>"

# Hardware detallado en HTML
$htmlContent += "<div class=`"diagnostic-section`">"
$htmlContent += "<h2>Información de Hardware</h2>"

if ($hardwareInfo.Processor) {
    $htmlContent += "<div class=`"metric good`">"
    $htmlContent += "<h3>Procesador</h3>"
    $htmlContent += "<p><strong>Modelo:</strong> $($hardwareInfo.Processor.Name)</p>"
    $htmlContent += "<p><strong>Núcleos:</strong> $($hardwareInfo.Processor.NumberOfCores) físicos, $($hardwareInfo.Processor.NumberOfLogicalProcessors) lógicos</p>"
    $htmlContent += "<p><strong>Velocidad:</strong> $($hardwareInfo.Processor.MaxClockSpeed) MHz</p>"
    $htmlContent += "</div>"
}

if ($hardwareInfo.Disks.Count -gt 0) {
    $htmlContent += "<div class=`"metric`">"
    $htmlContent += "<h3>Discos</h3>"
    $htmlContent += "<table><tr><th>Unidad</th><th>Total (GB)</th><th>Libre (GB)</th><th>% Libre</th><th>Estado</th></tr>"
    foreach ($disk in $hardwareInfo.Disks) {
        if ($disk.Size) {
            $size = [math]::Round($disk.Size/1GB, 2)
            $free = [math]::Round($disk.FreeSpace/1GB, 2)
            $percentFree = [math]::Round(($free/$size)*100, 1)
            $diskClass = if($percentFree -lt 10){"critical"}elseif($percentFree -lt 20){"warning"}else{"good"}
            $statusText = if($percentFree -lt 10){"CRÍTICO"}elseif($percentFree -lt 20){"Advertencia"}else{"OK"}
            
            # Registrar problemas de espacio en disco
            if ($percentFree -lt 10) {
                Add-ITSupportError -Seccion "Inventario - Disco" -Mensaje "Espacio en disco crítico en unidad $($disk.DeviceID): $percentFree% libre" -Severidad "Critical"
            } elseif ($percentFree -lt 20) {
                Add-ITSupportError -Seccion "Inventario - Disco" -Mensaje "Espacio en disco bajo en unidad $($disk.DeviceID): $percentFree% libre" -Severidad "Warning"
            }
            
            $htmlContent += "<tr class='$diskClass'><td>$($disk.DeviceID)</td><td>$size</td><td>$free</td><td>$percentFree%</td><td>$statusText</td></tr>"
        }
    }
    $htmlContent += "</table></div>"
}

$htmlContent += "</div>"

# Software en HTML
$htmlContent += "<div class=`"diagnostic-section`">"
$htmlContent += "<h2>Software Instalado</h2>"
$htmlContent += "<div class=`"metric`">"

if ($softwareInfo.InstalledPrograms.Count -gt 0) {
    $htmlContent += "<p><strong>Total de programas encontrados:</strong> $($softwareInfo.InstalledPrograms.Count)</p>"
    $htmlContent += "<table><tr><th>Programa</th><th>Versión</th><th>Editor</th></tr>"
    $softwareInfo.InstalledPrograms | Select-Object -First 20 | ForEach-Object {
        $version = if ($_.DisplayVersion) { $_.DisplayVersion } else { "N/A" }
        $publisher = if ($_.Publisher) { $_.Publisher } else { "N/A" }
        $htmlContent += "<tr><td>$($_.DisplayName)</td><td>$version</td><td>$publisher</td></tr>"
    }
    $htmlContent += "</table>"
    
    if ($softwareInfo.InstalledPrograms.Count -gt 20) {
        $htmlContent += "<p><em>Mostrando los primeros 20 de $($softwareInfo.InstalledPrograms.Count) programas total</em></p>"
    }
} else {
    # Registrar que no se pudieron detectar programas instalados
    Add-ITSupportError -Seccion "Inventario - Software" -Mensaje "No se pudieron detectar programas instalados - puede deberse a permisos insuficientes" -Severidad "Critical"
    
    $htmlContent += "<p class='critical'><strong>ERROR:</strong> No se pudieron detectar programas instalados</p>"
    $htmlContent += "<p>Esto puede deberse a permisos insuficientes o problemas de acceso al registro</p>"
}

$htmlContent += "</div></div>"

# Definir nombre del módulo para conteo específico
$moduleName = "HardwareSoftwareInventory"

# Agregar resumen de errores
$htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false

# Finalizar HTML con conteo específico del módulo
$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true -ModuleName $moduleName

# Guardar archivos
[System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "Inventario completado." -ForegroundColor Green
Write-Host "Reporte HTML: $htmlFile" -ForegroundColor Cyan
if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores/advertencias. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")