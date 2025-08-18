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

# DiagnA³stico de Rendimiento en Windows
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlFile = Join-Path -Path $logsPath -ChildPath "diagnostico_rendimiento_$timestamp.html"

# Function to get CPU information with multiple methods
function Get-CPUInfo {
    Write-Host "Midiendo uso de CPU..." -ForegroundColor Yellow
    
    $cpuData = @{
        Load = 0
        Info = $null
        LoadSamples = @()
    }
    
    # Get processor information
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
            }
        }
        return $null
    } -DefaultValue $null
    
    # Método 2: Fallback usando WMI (menos preciso pero más compatible)
    if (-not $cpuLoad) {
        $cpuLoad = Invoke-SafeExecution -Section "Rendimiento-CPU-WMI" -ScriptBlock {
            Write-Host "  Usando método WMI como respaldo..." -ForegroundColor Gray
            $wmiSamples = @()
            
            for ($i = 1; $i -le 2; $i++) {
                try {
                    $wmiCpu = Get-CimInstance -ClassName Win32_PerfRawData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
                    Start-Sleep -Seconds 1
                    $wmiCpu2 = Get-CimInstance -ClassName Win32_PerfRawData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
                    
                    # Calcular porcentaje de CPU
                    $percent = [math]::Round((1 - (($wmiCpu2.PercentIdleTime - $wmiCpu.PercentIdleTime) / ($wmiCpu2.TimeStamp_Sys100NS - $wmiCpu.TimeStamp_Sys100NS))) * 100, 2)
                    if ($percent -ge 0 -and $percent -le 100) {
                        $wmiSamples += $percent
                    }
                } catch {
                    continue
                }
            }
            
            if ($wmiSamples.Count -gt 0) {
                $avgLoad = [math]::Round(($wmiSamples | Measure-Object -Average).Average, 2)
                return @{
                    Average = $avgLoad
                    Samples = $wmiSamples
                }
            }
            return $null
        } -DefaultValue $null
    }
    
    # Método 3: Último recurso usando proceso PowerShell
    if (-not $cpuLoad) {
        $cpuLoad = Invoke-SafeExecution -Section "Rendimiento-CPU-Process" -ScriptBlock {
            Write-Host "  Estimando CPU desde procesos..." -ForegroundColor Gray
            # Estimar carga basada en procesos activos (muy aproximado)
            $processes = Get-Process | Where-Object { $_.CPU -gt 0 }
            $totalProcesses = ($processes | Measure-Object).Count
            $estimatedLoad = [math]::Min(($totalProcesses / 50) * 100, 100)
            
            return @{
                Average = [math]::Round($estimatedLoad, 2)
                Samples = @($estimatedLoad)
            }
        } -DefaultValue @{ Average = 0; Samples = @() }
    }
    
    $cpuData.Load = if ($cpuLoad) { $cpuLoad.Average } else { 0 }
    $cpuData.LoadSamples = if ($cpuLoad) { $cpuLoad.Samples } else { @() }
    
    return $cpuData
}

# Function to get memory information with robust methods
function Get-MemoryInfo {
    Write-Host "Analizando uso de memoria..." -ForegroundColor Yellow
    
    # Método 1: Usar Win32_OperatingSystem (más confiable)
    $memory = Invoke-SafeExecution -Section "Rendimiento-Memoria" -ScriptBlock {
        Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    } -DefaultValue $null
    
    if ($memory) {
        $freeMemoryKB = $memory.FreePhysicalMemory
        $totalMemoryKB = $memory.TotalVisibleMemorySize
        
        $memoryPercentFree = [math]::Round(($freeMemoryKB / $totalMemoryKB) * 100, 2)
        $memoryPercentUsed = [math]::Round(100 - $memoryPercentFree, 2)
        $freeMemoryGB = [math]::Round($freeMemoryKB/1MB, 2)
        $totalMemoryGB = [math]::Round($totalMemoryKB/1MB, 2)
        $usedMemoryGB = [math]::Round($totalMemoryGB - $freeMemoryGB, 2)
        
        return @{
            PercentFree = $memoryPercentFree
            PercentUsed = $memoryPercentUsed
            FreeGB = $freeMemoryGB
            TotalGB = $totalMemoryGB
            UsedGB = $usedMemoryGB
            Method = "Win32_OperatingSystem"
        }
    }
    
    # Método 2: Fallback usando Get-Counter
    $memoryCounter = Invoke-SafeExecution -Section "Rendimiento-Memoria-Counter" -ScriptBlock {
        $availableBytes = Get-Counter "\Memory\Available Bytes" -ErrorAction Stop
        $commitLimit = Get-Counter "\Memory\Commit Limit" -ErrorAction Stop
        
        $availableGB = [math]::Round($availableBytes.CounterSamples[0].CookedValue / 1GB, 2)
        $totalGB = [math]::Round($commitLimit.CounterSamples[0].CookedValue / 1GB, 2)
        $usedGB = [math]::Round($totalGB - $availableGB, 2)
        $percentFree = [math]::Round(($availableGB / $totalGB) * 100, 2)
        $percentUsed = [math]::Round(100 - $percentFree, 2)
        
        return @{
            PercentFree = $percentFree
            PercentUsed = $percentUsed
            FreeGB = $availableGB
            TotalGB = $totalGB
            UsedGB = $usedGB
            Method = "Performance Counter"
        }
    } -DefaultValue $null
    
    if ($memoryCounter) {
        return $memoryCounter
    }
    
    Add-ITSupportError -Section "Rendimiento-Memoria" -Message "Could not get memory information with any method" -Severity "Error"
    return $null
}

# Function to get disk information with better detail
function Get-DiskInfo {
    Write-Host "Analizando espacio en disco..." -ForegroundColor Yellow
    
    # Método 1: Usar Get-CimInstance (más moderno)
    $disks = Invoke-SafeExecution -Section "Rendimiento-Discos-CIM" -ScriptBlock {
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop | 
        Where-Object { $_.Size -gt 0 } |
        Select-Object DeviceID, 
                      @{Name="Size";Expression={[math]::Round($_.Size/1GB, 2)}},
                      @{Name="FreeSpace";Expression={[math]::Round($_.FreeSpace/1GB, 2)}},
                      @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100, 2)}},
                      @{Name="UsedSpace";Expression={[math]::Round(($_.Size - $_.FreeSpace)/1GB, 2)}},
                      VolumeName, FileSystem
    } -DefaultValue @()
    
    # Método 2: Fallback usando WMI clásico
    if ($disks.Count -eq 0) {
        $disks = Invoke-SafeExecution -Section "Rendimiento-Discos-WMI" -ScriptBlock {
            Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop |
            Where-Object { $_.Size -gt 0 } |
            Select-Object DeviceID,
                          @{Name="Size";Expression={[math]::Round($_.Size/1GB, 2)}},
                          @{Name="FreeSpace";Expression={[math]::Round($_.FreeSpace/1GB, 2)}},
                          @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100, 2)}},
                          @{Name="UsedSpace";Expression={[math]::Round(($_.Size - $_.FreeSpace)/1GB, 2)}},
                          VolumeName, FileSystem
        } -DefaultValue @()
    }
    
    # Método 3: Último recurso usando Get-PSDrive
    if ($disks.Count -eq 0) {
        $disks = Invoke-SafeExecution -Section "Rendimiento-Discos-PSDrive" -ScriptBlock {
            Get-PSDrive -PSProvider FileSystem -ErrorAction Stop |
            Where-Object { $_.Used -gt 0 -and $_.Free -gt 0 } |
            Select-Object @{Name="DeviceID";Expression={"$($_.Name):"}},
                          @{Name="Size";Expression={[math]::Round(($_.Used + $_.Free)/1GB, 2)}},
                          @{Name="FreeSpace";Expression={[math]::Round($_.Free/1GB, 2)}},
                          @{Name="PercentFree";Expression={[math]::Round(($_.Free/($_.Used + $_.Free))*100, 2)}},
                          @{Name="UsedSpace";Expression={[math]::Round($_.Used/1GB, 2)}},
                          @{Name="VolumeName";Expression={"N/A"}},
                          @{Name="FileSystem";Expression={"N/A"}}
        } -DefaultValue @()
    }
    
    return $disks
}

# Función para obtener procesos que más consumen recursos
function Get-TopProcesses {
    Write-Host "Analizando procesos con mayor consumo de recursos..." -ForegroundColor Yellow
    
    # Obtener top procesos por uso acumulado de CPU (más confiable)
    $topCPUProcesses = Invoke-SafeExecution -Section "Rendimiento-Procesos-CPU" -DefaultValue @() -ScriptBlock {
        Get-Process -ErrorAction Stop | 
        Where-Object {$_.CPU -gt 0} | 
        Sort-Object -Property CPU -Descending | 
        Select-Object -First 10 |
        Select-Object ProcessName, Id, 
                     @{Name="CPUTime";Expression={[math]::Round($_.CPU, 2)}},
                     @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet/1MB, 2)}}
    }
    
    # Intentar obtener uso de CPU en tiempo real usando contadores de performance
    $realtimeCPUProcesses = Invoke-SafeExecution -Section "Rendimiento-Procesos-CPU-Tiempo-Real" -DefaultValue @() -ScriptBlock {
        try {
            # Usar Get-Counter para obtener uso actual de CPU por proceso
            $counter = Get-Counter "\Process(*)\% Processor Time" -ErrorAction Stop
            $cpuData = $counter.CounterSamples | 
                      Where-Object {$_.CookedValue -gt 0 -and $_.InstanceName -ne "_total" -and $_.InstanceName -ne "idle"} |
                      Sort-Object CookedValue -Descending |
                      Select-Object -First 5 |
                      ForEach-Object {
                          $processName = $_.InstanceName -replace "#.*", ""  # Remover sufijos numericos
                          [PSCustomObject]@{
                              ProcessName = $processName
                              CPUPercent = [math]::Round($_.CookedValue, 2)
                          }
                      }
            return $cpuData
        } catch {
            # Si falla, devolver array vacío
            return @()
        }
    }
    
    # Si tenemos datos en tiempo real, combinarlos con los datos de procesos
    if ($realtimeCPUProcesses.Count -gt 0) {
        $combinedCPUData = @()
        foreach ($rtProc in $realtimeCPUProcesses) {
            $procInfo = Get-Process -Name $rtProc.ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($procInfo) {
                $combinedCPUData += [PSCustomObject]@{
                    ProcessName = $rtProc.ProcessName
                    Id = $procInfo.Id
                    CPUPercent = $rtProc.CPUPercent
                    MemoryMB = [math]::Round($procInfo.WorkingSet/1MB, 2)
                }
            }
        }
        $finalCPUProcesses = $combinedCPUData
    } else {
        # Fallback: usar datos acumulados pero presentarlos como "Top CPU"
        $finalCPUProcesses = $topCPUProcesses | Select-Object -First 5 | ForEach-Object {
            [PSCustomObject]@{
                ProcessName = $_.ProcessName
                Id = $_.Id
                CPUPercent = $_.CPUTime  # Mostrar tiempo acumulado como referencia
                MemoryMB = $_.MemoryMB
            }
        }
    }
    
    $topMemoryProcesses = Invoke-SafeExecution -Section "Rendimiento-Procesos-Memoria" -DefaultValue @() -ScriptBlock {
        Get-Process -ErrorAction Stop | 
        Sort-Object -Property WorkingSet -Descending | 
        Select-Object -First 5 |
        Select-Object ProcessName, Id, @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet/1MB, 2)}}
    }
    
    return @{
        CPU = $finalCPUProcesses
        Memory = $topMemoryProcesses
    }
}

# Ejecutar diagnósticos
$cpuInfo = Get-CPUInfo
$memoryInfo = Get-MemoryInfo
$diskInfo = Get-DiskInfo
$processInfo = Get-TopProcesses

# Usar el template unificado con módulo específico
$moduleName = "PerformanceDiagnostic"
$htmlContent = Get-UnifiedHTMLTemplate -Title "Diagnóstico de Rendimiento" -IncludeSummary $true

# === SECCIÓN: PROCESADOR (CPU) ===
$cpuClass = if($cpuInfo.Load -gt 80){'critical'}elseif($cpuInfo.Load -gt 60){'warning'}else{'good'}

# Registrar problemas de CPU
if ($cpuInfo.Load -gt 80) {
    Add-ITSupportError -Section "Rendimiento - CPU" -Message "El uso de CPU es crítico: $($cpuInfo.Load)%" -Severity "Critical"
} elseif ($cpuInfo.Load -gt 60) {
    Add-ITSupportError -Section "Rendimiento - CPU" -Message "El uso de CPU es alto: $($cpuInfo.Load)%" -Severity "Warning"
}
$htmlContent += "`n<div class=`"diagnostic-section $(Get-ModuleStatusClass -ModuleName $moduleName -Status $cpuClass)`">`n"
$htmlContent += "<h2>Procesador (CPU)</h2>`n"

$htmlContent += "<div class=`"metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $cpuClass)`">`n"
$htmlContent += "<h3>Uso Actual</h3>`n"
$htmlContent += "<p>Uso actual: <strong>$($cpuInfo.Load)%</strong></p>`n"

if ($cpuInfo.LoadSamples.Count -gt 1) {
    $htmlContent += "<p>Muestras tomadas: $($cpuInfo.LoadSamples -join '%, ')%</p>`n"
}
$htmlContent += "</div>`n"

if ($cpuInfo.Info) {
    $htmlContent += "<div class=`"metric`">`n"
    $htmlContent += "<h3>Información del Procesador</h3>`n"
    $htmlContent += "<p>Modelo: <strong>$($cpuInfo.Info.Name)</strong></p>`n"
    $htmlContent += "<p>Núcleos físicos: <strong>$($cpuInfo.Info.NumberOfCores)</strong></p>`n"
    $htmlContent += "<p>Procesadores lógicos: <strong>$($cpuInfo.Info.NumberOfLogicalProcessors)</strong></p>`n"
    $htmlContent += "<p>Velocidad máxima: <strong>$($cpuInfo.Info.MaxClockSpeed) MHz</strong></p>`n"
    $htmlContent += "</div>`n"
}

$htmlContent += "</div>`n" # Cerrar sección CPU

# === SECCIÓN: MEMORIA RAM ===
$memoryClass = if($memoryInfo -and $memoryInfo.PercentUsed -gt 90){'critical'}elseif($memoryInfo -and $memoryInfo.PercentUsed -gt 75){'warning'}else{'good'}

# Registrar problemas de memoria
if ($memoryInfo) {
    if ($memoryInfo.PercentUsed -gt 90) {
        Add-ITSupportError -Section "Rendimiento - Memoria" -Message "El uso de memoria RAM es crítico: $($memoryInfo.PercentUsed)%" -Severity "Critical"
    } elseif ($memoryInfo.PercentUsed -gt 75) {
        Add-ITSupportError -Section "Rendimiento - Memoria" -Message "El uso de memoria RAM es alto: $($memoryInfo.PercentUsed)%" -Severity "Warning"
    }
} else {
    Add-ITSupportError -Section "Rendimiento - Memoria" -Message "Could not get RAM memory information" -Severity "Warning"
}
$htmlContent += "`n<div class=`"diagnostic-section $(Get-ModuleStatusClass -ModuleName $moduleName -Status $memoryClass)`">`n"
$htmlContent += "<h2>Memoria RAM</h2>`n"

if ($memoryInfo) {
    $htmlContent += "<div class=`"metric $(Get-ModuleStatusClass -ModuleName $moduleName -Status $memoryClass)`">`n"
    $htmlContent += "<h3>Estado de la Memoria</h3>`n"
    $htmlContent += "<p>Memoria en uso: <strong>$($memoryInfo.PercentUsed)%</strong> ($($memoryInfo.UsedGB) GB de $($memoryInfo.TotalGB) GB)</p>`n"
    $htmlContent += "<p>Memoria libre: <strong>$($memoryInfo.PercentFree)%</strong> ($($memoryInfo.FreeGB) GB)</p>`n"
    $htmlContent += "<p><small>Método de detección: $($memoryInfo.Method)</small></p>`n"
    $htmlContent += "</div>`n"
} else {
    $htmlContent += "<div class=`"metric critical`">`n"
    $htmlContent += "<p>Could not get memory information</p>`n"
    $htmlContent += "</div>`n"
}

$htmlContent += "</div>`n" # Cerrar sección Memoria

# === SECCIÓN: ESPACIO EN DISCO ===
$htmlContent += "`n<div class=`"diagnostic-section`">`n"
$htmlContent += "<h2>Espacio en Disco</h2>`n"

if ($diskInfo.Count -gt 0) {
    $htmlContent += "<div class=`"metric`">`n"
    $htmlContent += "<p><strong>Unidades detectadas:</strong> $($diskInfo.Count)</p>`n"
    $htmlContent += "</div>`n"
    
    $htmlContent += "<div class=`"table-container`">`n"
    $htmlContent += @"
<table>
    <tr>
        <th>Unidad</th>
        <th>Etiqueta</th>
        <th>Sistema de Archivos</th>
        <th>Tamaño Total (GB)</th>
        <th>Usado (GB)</th>
        <th>Libre (GB)</th>
        <th>% Libre</th>
        <th>Estado</th>
    </tr>

"@

    foreach ($disk in $diskInfo) {
        $diskClass = if($disk.PercentFree -lt 10){"critical"}elseif($disk.PercentFree -lt 20){"warning"}else{"good"}
        $diskClassWithModule = Get-ModuleStatusClass -ModuleName $moduleName -Status $diskClass
        $statusText = if($disk.PercentFree -lt 10){"CRÍTICO"}elseif($disk.PercentFree -lt 20){"Advertencia"}else{"OK"}
        $volumeName = if($disk.VolumeName) { $disk.VolumeName } else { "Sin etiqueta" }
        $fileSystem = if($disk.FileSystem) { $disk.FileSystem } else { "N/A" }
        
        # Registrar problemas de espacio en disco
        if ($disk.PercentFree -lt 10) {
            Add-ITSupportError -Section "Rendimiento - Disco" -Message "Espacio en disco crítico en unidad $($disk.DeviceID): $($disk.PercentFree)% libre" -Severity "Critical"
        } elseif ($disk.PercentFree -lt 20) {
            Add-ITSupportError -Section "Rendimiento - Disco" -Message "Espacio en disco bajo en unidad $($disk.DeviceID): $($disk.PercentFree)% libre" -Severity "Warning"
        }
        
        $htmlContent += "<tr class='$diskClassWithModule'>`n"
        $htmlContent += "<td>$($disk.DeviceID)</td>`n"
        $htmlContent += "<td>$volumeName</td>`n"
        $htmlContent += "<td>$fileSystem</td>`n"
        $htmlContent += "<td>$($disk.Size)</td>`n"
        $htmlContent += "<td>$($disk.UsedSpace)</td>`n"
        $htmlContent += "<td>$($disk.FreeSpace)</td>`n"
        $htmlContent += "<td>$($disk.PercentFree)%</td>`n"
        $htmlContent += "<td>$statusText</td>`n"
        $htmlContent += "</tr>`n"
    }

    $htmlContent += "</table>`n"
    $htmlContent += "</div>`n"
} else {
    # Registrar que no se pudieron detectar discos
    Add-ITSupportError -Section "Rendimiento - Disco" -Message "No se pudieron detectar unidades de disco" -Severity "Critical"
    
    $htmlContent += "<div class=`"metric critical`">`n"
    $htmlContent += "<p>No se pudieron detectar unidades de disco</p>`n"
    $htmlContent += "</div>`n"
}

$htmlContent += "</div>`n" # Cerrar sección Disco

# === SECCIÓN: PROCESOS QUE MÁS RECURSOS CONSUMEN ===
$htmlContent += "`n<div class=`"diagnostic-section`">`n"
$htmlContent += "<h2>Procesos que Más Recursos Consumen</h2>`n"

$htmlContent += "<div class=`"metric`">`n"
$htmlContent += "<h3>Top Procesos por CPU</h3>`n"
$htmlContent += "<div class=`"table-container`">`n"
$htmlContent += @"
<table>
    <tr>
        <th>Proceso</th>
        <th>CPU %/Tiempo</th>
        <th>Memoria (MB)</th>
        <th>PID</th>
    </tr>

"@

foreach ($proc in $processInfo.CPU) {
    $cpuClass = if($proc.CPUPercent -gt 50) {'critical'} elseif($proc.CPUPercent -gt 20) {'warning'} else {'good'}
    $procClassWithModule = Get-ModuleStatusClass -ModuleName $moduleName -Status $cpuClass
    $htmlContent += "<tr class=`"$procClassWithModule`">`n"
    $htmlContent += "<td>$($proc.ProcessName)</td>`n"
    $htmlContent += "<td>$($proc.CPUPercent)</td>`n"
    $htmlContent += "<td>$($proc.MemoryMB)</td>`n"
    $htmlContent += "<td>$($proc.Id)</td>`n"
    $htmlContent += "</tr>`n"
}

$htmlContent += "</table>`n"
$htmlContent += "</div>`n"
$htmlContent += "</div>`n"

$htmlContent += "<div class=`"metric`">`n"
$htmlContent += "<h3>Top Procesos por Memoria</h3>`n"
$htmlContent += "<div class=`"table-container`">`n"
$htmlContent += @"
<table>
    <tr>
        <th>Proceso</th>
        <th>Memoria (MB)</th>
        <th>PID</th>
    </tr>

"@

foreach ($proc in $processInfo.Memory) {
    $memClass = if($proc.MemoryMB -gt 500) {'warning'} elseif($proc.MemoryMB -gt 1000) {'critical'} else {'good'}
    $procMemClassWithModule = Get-ModuleStatusClass -ModuleName $moduleName -Status $memClass
    $htmlContent += "<tr class=`"$procMemClassWithModule`">`n"
    $htmlContent += "<td>$($proc.ProcessName)</td>`n"
    $htmlContent += "<td>$($proc.MemoryMB)</td>`n"
    $htmlContent += "<td>$($proc.Id)</td>`n"
    $htmlContent += "</tr>`n"
}

$htmlContent += "</table>`n"
$htmlContent += "</div>`n"
$htmlContent += "</div>`n"

$htmlContent += "</div>`n" # Cerrar sección Procesos

# Agregar resumen de errores
$htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false

# Finalizar HTML con el template unificado y conteo específico del módulo
$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true -ModuleName $moduleName

# Guardar archivos
[System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "DiagnA³stico de rendimiento completado."
Write-Host "Reporte HTML: $htmlFile"
if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")