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

# Limpieza y Mantenimiento Avanzado de Windows
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlFile = Join-Path -Path $logsPath -ChildPath "limpieza_mantenimiento_$timestamp.html"

$username = $env:USERNAME
$dateTimeFormatted = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Host "=== INICIANDO LIMPIEZA Y MANTENIMIENTO AVANZADO ===" -ForegroundColor Green
Write-Host "Se generará un reporte detallado en: $htmlFile" -ForegroundColor Cyan

# Función para convertir bytes a formato legible
function ConvertTo-ReadableSize {
    param([long]$Bytes)
    if ($Bytes -eq 0) { return "0 B" }
    $sizes = @("B", "KB", "MB", "GB", "TB")
    $index = [math]::Floor([math]::Log($Bytes) / [math]::Log(1024))
    $size = [math]::Round($Bytes / [math]::Pow(1024, $index), 2)
    return "$size $($sizes[$index])"
}

# Función para obtener el tamaño de una carpeta
function Get-FolderSize {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            return if ($size) { $size } else { 0 }
        }
        return 0
    } catch {
        return 0
    }
}

# Variables para estadísticas
$cleanupStats = @{
    TotalSpaceFreed = 0
    TempFilesFreed = 0
    RecycleBinFreed = 0
    LogFilesFreed = 0
    ThumbnailsFreed = 0
    UpdateCacheFreed = 0
    ErrorsEncountered = 0
    ItemsCleaned = 0
}

Write-Host "Analizando espacio disponible antes de la limpieza..." -ForegroundColor Yellow

# Función para limpiar archivos temporales del usuario
function Clear-UserTempFiles {
    Write-Host "🗑️ Limpiando archivos temporales del usuario..." -ForegroundColor Cyan
    
    $tempPaths = @(
        "$env:USERPROFILE\AppData\Local\Temp",
        "$env:TEMP",
        "$env:TMP"
    )
    
    $totalFreed = 0
    $results = @()
    
    foreach ($tempPath in $tempPaths | Select-Object -Unique) {
        if (Test-Path $tempPath) {
            $sizeBefore = Get-FolderSize -Path $tempPath
            
            $result = Invoke-SafeExecution -Section "Limpieza-TempUsuario" -DefaultValue $null -ScriptBlock {
                Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue | 
                ForEach-Object {
                    try {
                        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    } catch {
                        # Ignorar archivos en uso
                    }
                }
            }
            
            $sizeAfter = Get-FolderSize -Path $tempPath
            $freed = $sizeBefore - $sizeAfter
            $totalFreed += $freed
            
            $results += [PSCustomObject]@{
                Path = $tempPath
                SizeBefore = $sizeBefore
                SizeAfter = $sizeAfter
                SpaceFreed = $freed
                Status = if ($freed -gt 0) { "Limpiado" } else { "Sin cambios" }
            }
        }
    }
    
    $cleanupStats.TempFilesFreed = $totalFreed
    $cleanupStats.TotalSpaceFreed += $totalFreed
    $cleanupStats.ItemsCleaned += 1
    
    return $results
}

# Función para limpiar archivos temporales del sistema
function Clear-SystemTempFiles {
    Write-Host "🗑️ Limpiando archivos temporales del sistema..." -ForegroundColor Cyan
    
    $systemTempPaths = @(
        "$env:WINDIR\Temp",
        "$env:WINDIR\Prefetch"
    )
    
    $totalFreed = 0
    $results = @()
    
    foreach ($tempPath in $systemTempPaths) {
        if (Test-Path $tempPath) {
            $sizeBefore = Get-FolderSize -Path $tempPath
            
            # Solo archivos más antiguos de 1 día para Prefetch
            $daysOld = if ($tempPath -like "*Prefetch*") { 1 } else { 0 }
            
            $result = Invoke-SafeExecution -Section "Limpieza-TempSistema" -DefaultValue $null -ScriptBlock {
                $cutoffDate = (Get-Date).AddDays(-$daysOld)
                Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue | 
                Where-Object { $_.LastWriteTime -lt $cutoffDate } |
                ForEach-Object {
                    try {
                        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    } catch {
                        # Ignorar archivos en uso
                    }
                }
            }
            
            $sizeAfter = Get-FolderSize -Path $tempPath
            $freed = $sizeBefore - $sizeAfter
            $totalFreed += $freed
            
            $results += [PSCustomObject]@{
                Path = $tempPath
                SizeBefore = $sizeBefore
                SizeAfter = $sizeAfter
                SpaceFreed = $freed
                Status = if ($freed -gt 0) { "Limpiado" } else { "Sin cambios" }
            }
        }
    }
    
    $cleanupStats.TotalSpaceFreed += $totalFreed
    $cleanupStats.ItemsCleaned += 1
    
    return $results
}

# Función para vaciar la papelera de reciclaje
function Clear-RecycleBin {
    Write-Host "🗑️ Vaciando papelera de reciclaje..." -ForegroundColor Cyan
    
    $result = Invoke-SafeExecution -Section "Limpieza-PapeleraReciclaje" -DefaultValue $null -ScriptBlock {
        # Obtener tamaño antes
        $recycleBinSize = 0
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            if ($recycleBin) {
                $recycleBinSize = ($recycleBin.Items() | Measure-Object -Property Size -Sum).Sum
            }
        } catch {
            $recycleBinSize = 0
        }
        
        # Vaciar papelera
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        } catch {
            # Método alternativo
            cmd /c "rd /s /q %systemdrive%\`$Recycle.Bin\" 2>$null
        }
        
        return $recycleBinSize
    }
    
    $freedSpace = if ($result) { $result } else { 0 }
    $cleanupStats.RecycleBinFreed = $freedSpace
    $cleanupStats.TotalSpaceFreed += $freedSpace
    $cleanupStats.ItemsCleaned += 1
    
    return [PSCustomObject]@{
        SpaceFreed = $freedSpace
        Status = if ($freedSpace -gt 0) { "Vaciada" } else { "Ya estaba vacía" }
    }
}

# Función para limpiar logs del sistema
function Clear-SystemLogs {
    Write-Host "📄 Limpiando logs antiguos del sistema..." -ForegroundColor Cyan
    
    $logPaths = @(
        "$env:WINDIR\Logs",
        "$env:WINDIR\System32\LogFiles",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\WebCache"
    )
    
    $totalFreed = 0
    $results = @()
    
    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            $sizeBefore = Get-FolderSize -Path $logPath
            
            Invoke-SafeExecution -Section "Limpieza-LogsSistema" -DefaultValue $null -ScriptBlock {
                # Solo eliminar archivos más antiguos de 7 días
                $cutoffDate = (Get-Date).AddDays(-7)
                Get-ChildItem -Path $logPath -Recurse -File -ErrorAction SilentlyContinue | 
                Where-Object { $_.LastWriteTime -lt $cutoffDate -and $_.Extension -in @('.log', '.tmp', '.old') } |
                ForEach-Object {
                    try {
                        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                    } catch {
                        # Ignorar archivos en uso
                    }
                }
            }
            
            $sizeAfter = Get-FolderSize -Path $logPath
            $freed = $sizeBefore - $sizeAfter
            $totalFreed += $freed
            
            $results += [PSCustomObject]@{
                Path = $logPath
                SpaceFreed = $freed
                Status = if ($freed -gt 0) { "Limpiado" } else { "Sin cambios" }
            }
        }
    }
    
    $cleanupStats.LogFilesFreed = $totalFreed
    $cleanupStats.TotalSpaceFreed += $totalFreed
    $cleanupStats.ItemsCleaned += 1
    
    return $results
}

# Función para limpiar thumbnails y caché de Windows
function Clear-WindowsCache {
    Write-Host "🖼️ Limpiando thumbnails y caché de Windows..." -ForegroundColor Cyan
    
    $cachePaths = @(
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer",
        "$env:USERPROFILE\AppData\Local\IconCache.db",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache"
    )
    
    $totalFreed = 0
    $results = @()
    
    foreach ($cachePath in $cachePaths) {
        if (Test-Path $cachePath) {
            $sizeBefore = if ((Get-Item $cachePath) -is [System.IO.DirectoryInfo]) {
                Get-FolderSize -Path $cachePath
            } else {
                (Get-Item $cachePath).Length
            }
            
            Invoke-SafeExecution -Section "Limpieza-CacheWindows" -DefaultValue $null -ScriptBlock {
                if ((Get-Item $cachePath) -is [System.IO.DirectoryInfo]) {
                    Get-ChildItem -Path $cachePath -Force -ErrorAction SilentlyContinue | 
                    ForEach-Object {
                        try {
                            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        } catch {
                            # Ignorar archivos en uso
                        }
                    }
                } else {
                    try {
                        Remove-Item -Path $cachePath -Force -ErrorAction SilentlyContinue
                    } catch {
                        # Ignorar si está en uso
                    }
                }
            }
            
            $sizeAfter = if (Test-Path $cachePath) {
                if ((Get-Item $cachePath) -is [System.IO.DirectoryInfo]) {
                    Get-FolderSize -Path $cachePath
                } else {
                    (Get-Item $cachePath).Length
                }
            } else {
                0
            }
            
            $freed = $sizeBefore - $sizeAfter
            $totalFreed += $freed
            
            $results += [PSCustomObject]@{
                Path = $cachePath
                SpaceFreed = $freed
                Status = if ($freed -gt 0) { "Limpiado" } else { "Sin cambios" }
            }
        }
    }
    
    $cleanupStats.ThumbnailsFreed = $totalFreed
    $cleanupStats.TotalSpaceFreed += $totalFreed
    $cleanupStats.ItemsCleaned += 1
    
    return $results
}

# Función para ejecutar Disk Cleanup
function Invoke-DiskCleanup {
    Write-Host "💿 Ejecutando limpieza de disco del sistema..." -ForegroundColor Cyan
    
    $result = Invoke-SafeExecution -Section "Limpieza-DiskCleanup" -DefaultValue $null -ScriptBlock {
        # Create configuration file for cleanmgr
        $sageset = "StateFlags0001=2"
        $cleanupItems = @(
            "Active Setup Temp Folders",
            "BranchCache",
            "Device Driver Packages",
            "Downloaded Program Files",
            "Internet Cache Files",
            "Offline Pages Files",
            "Old ChkDsk Files",
            "Previous Installations",
            "Recycle Bin",
            "Setup Log Files",
            "System error memory dump files",
            "System error minidump files",
            "Temporary Files",
            "Temporary Setup Files",
            "Thumbnail Cache",
            "Update Cleanup",
            "User file versions",
            "Windows Defender",
            "Windows Error Reporting Archive Files",
            "Windows Error Reporting Queue Files",
            "Windows Error Reporting System Archive Files",
            "Windows Error Reporting System Queue Files",
            "Windows ESD installation files",
            "Windows Update Cleanup"
        )
        
        # Configurar elementos para limpiar automáticamente
        foreach ($item in $cleanupItems) {
            $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$item"
            if (Test-Path $keyPath) {
                Set-ItemProperty -Path $keyPath -Name "StateFlags0001" -Value 2 -ErrorAction SilentlyContinue
            }
        }
        
        # Run cleanmgr with automatic configuration
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        
        return "Ejecutado"
    }
    
    $cleanupStats.ItemsCleaned += 1
    
    return [PSCustomObject]@{
        Status = if ($result) { "Ejecutado correctamente" } else { "Error al ejecutar" }
        Tool = "Windows Disk Cleanup"
    }
}

# Get disk information before cleanup
$diskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | 
            Select-Object DeviceID, 
                         @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB, 2)}},
                         @{Name="FreeSpaceGB";Expression={[math]::Round($_.FreeSpace/1GB, 2)}},
                         @{Name="UsedSpaceGB";Expression={[math]::Round(($_.Size - $_.FreeSpace)/1GB, 2)}},
                         @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100, 2)}}

Write-Host "💾 Espacio en disco antes de la limpieza:" -ForegroundColor Blue
foreach ($disk in $diskInfo) {
    Write-Host "  Disco $($disk.DeviceID) - Libre: $($disk.FreeSpaceGB) GB de $($disk.SizeGB) GB ($($disk.PercentFree)%)" -ForegroundColor Gray
}

# EJECUTAR TODAS LAS FUNCIONES DE LIMPIEZA
Write-Host "`n🚀 Iniciando proceso de limpieza completo..." -ForegroundColor Green

$tempUserResults = Clear-UserTempFiles
$tempSystemResults = Clear-SystemTempFiles
$recycleBinResult = Clear-RecycleBin
$systemLogsResults = Clear-SystemLogs
$windowsCacheResults = Clear-WindowsCache
$diskCleanupResult = Invoke-DiskCleanup

# Get disk information after cleanup
$diskInfoAfter = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | 
                 Select-Object DeviceID, 
                              @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB, 2)}},
                              @{Name="FreeSpaceGB";Expression={[math]::Round($_.FreeSpace/1GB, 2)}},
                              @{Name="UsedSpaceGB";Expression={[math]::Round(($_.Size - $_.FreeSpace)/1GB, 2)}},
                              @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100, 2)}}

Write-Host "`n💾 Espacio en disco después de la limpieza:" -ForegroundColor Blue
foreach ($disk in $diskInfoAfter) {
    $diskBefore = $diskInfo | Where-Object {$_.DeviceID -eq $disk.DeviceID}
    $spaceGained = $disk.FreeSpaceGB - $diskBefore.FreeSpaceGB
    Write-Host "  Disco $($disk.DeviceID) - Libre: $($disk.FreeSpaceGB) GB de $($disk.SizeGB) GB ($($disk.PercentFree)%)" -ForegroundColor Gray
    if ($spaceGained -gt 0) {
        Write-Host "    ✅ Espacio liberado: $([math]::Round($spaceGained, 2)) GB" -ForegroundColor Green
    }
}

Write-Host "`n📊 Generando reporte HTML detallado..." -ForegroundColor Yellow

# GENERAR REPORTE HTML
$htmlContent = Get-UnifiedHTMLTemplate -Title "Reporte de Limpieza y Mantenimiento" -IncludeSummary $true

$htmlContent += @"
        <div class="diagnostic-section">
            <h2>Resumen de Limpieza</h2>
            <div class="metric good">
                <h4>Espacio Total Liberado: $(ConvertTo-ReadableSize $cleanupStats.TotalSpaceFreed)</h4>
                <p>Procesos completados: $($cleanupStats.ItemsCleaned)</p>
                <p>Errores encontrados: $($cleanupStats.ErrorsEncountered)</p>
            </div>
        </div>

        <div class="diagnostic-section">
            <h2>Espacio en Disco - Antes vs Después</h2>
            <table>
                <tr>
                    <th>Disco</th>
                    <th>Tamaño Total</th>
                    <th>Libre Antes</th>
                    <th>Libre Después</th>
                    <th>Espacio Ganado</th>
                    <th>% Libre Final</th>
                </tr>
"@

foreach ($disk in $diskInfoAfter) {
    $diskBefore = $diskInfo | Where-Object {$_.DeviceID -eq $disk.DeviceID}
    $spaceGained = $disk.FreeSpaceGB - $diskBefore.FreeSpaceGB
    $diskClass = if($disk.PercentFree -lt 10){"critical"}elseif($disk.PercentFree -lt 20){"warning"}else{"good"}
    
    $htmlContent += "<tr class='$diskClass'><td>$($disk.DeviceID)</td><td>$($disk.SizeGB) GB</td><td>$($diskBefore.FreeSpaceGB) GB</td><td>$($disk.FreeSpaceGB) GB</td><td>+$([math]::Round($spaceGained, 2)) GB</td><td>$($disk.PercentFree)%</td></tr>"
}

$htmlContent += @"
            </table>
        </div>

        <div class="diagnostic-section">
            <h2>Detalle de Limpieza por Categoría</h2>
            
            <div class="metric">
                <h3>🗑️ Archivos Temporales de Usuario</h3>
                <p><strong>Espacio liberado:</strong> $(ConvertTo-ReadableSize $cleanupStats.TempFilesFreed)</p>
                <table>
                    <tr><th>Ruta</th><th>Tamaño Antes</th><th>Tamaño Después</th><th>Liberado</th><th>Estado</th></tr>
"@

foreach ($result in $tempUserResults) {
    $statusClass = if($result.Status -eq "Limpiado"){"good"}else{"warning"}
    $htmlContent += "<tr class='$statusClass'><td>$($result.Path)</td><td>$(ConvertTo-ReadableSize $result.SizeBefore)</td><td>$(ConvertTo-ReadableSize $result.SizeAfter)</td><td>$(ConvertTo-ReadableSize $result.SpaceFreed)</td><td>$($result.Status)</td></tr>"
}

$htmlContent += @"
                </table>
            </div>

            <div class="metric">
                <h3>🗑️ Archivos Temporales del Sistema</h3>
                <table>
                    <tr><th>Ruta</th><th>Tamaño Antes</th><th>Tamaño Después</th><th>Liberado</th><th>Estado</th></tr>
"@

foreach ($result in $tempSystemResults) {
    $statusClass = if($result.Status -eq "Limpiado"){"good"}else{"warning"}
    $htmlContent += "<tr class='$statusClass'><td>$($result.Path)</td><td>$(ConvertTo-ReadableSize $result.SizeBefore)</td><td>$(ConvertTo-ReadableSize $result.SizeAfter)</td><td>$(ConvertTo-ReadableSize $result.SpaceFreed)</td><td>$($result.Status)</td></tr>"
}

$htmlContent += @"
                </table>
            </div>

            <div class="metric">
                <h3>🗑️ Papelera de Reciclaje</h3>
                <p><strong>Espacio liberado:</strong> $(ConvertTo-ReadableSize $cleanupStats.RecycleBinFreed)</p>
                <p><strong>Estado:</strong> $($recycleBinResult.Status)</p>
            </div>

            <div class="metric">
                <h3>📄 Logs del Sistema</h3>
                <p><strong>Espacio liberado:</strong> $(ConvertTo-ReadableSize $cleanupStats.LogFilesFreed)</p>
                <table>
                    <tr><th>Ruta</th><th>Espacio Liberado</th><th>Estado</th></tr>
"@

foreach ($result in $systemLogsResults) {
    $statusClass = if($result.Status -eq "Limpiado"){"good"}else{"warning"}
    $htmlContent += "<tr class='$statusClass'><td>$($result.Path)</td><td>$(ConvertTo-ReadableSize $result.SpaceFreed)</td><td>$($result.Status)</td></tr>"
}

$htmlContent += @"
                </table>
            </div>

            <div class="metric">
                <h3>🖼️ Caché y Thumbnails de Windows</h3>
                <p><strong>Espacio liberado:</strong> $(ConvertTo-ReadableSize $cleanupStats.ThumbnailsFreed)</p>
                <table>
                    <tr><th>Ruta</th><th>Espacio Liberado</th><th>Estado</th></tr>
"@

foreach ($result in $windowsCacheResults) {
    $statusClass = if($result.Status -eq "Limpiado"){"good"}else{"warning"}
    $htmlContent += "<tr class='$statusClass'><td>$($result.Path)</td><td>$(ConvertTo-ReadableSize $result.SpaceFreed)</td><td>$($result.Status)</td></tr>"
}

$htmlContent += @"
                </table>
            </div>

            <div class="metric">
                <h3>💿 Limpieza de Disco del Sistema</h3>
                <p><strong>Herramienta:</strong> $($diskCleanupResult.Tool)</p>
                <p><strong>Estado:</strong> $($diskCleanupResult.Status)</p>
            </div>
        </div>

        <div class="diagnostic-section">
            <h2>Recomendaciones de Mantenimiento</h2>
            <div class="metric good">
                <ul>
                    <li>✅ Ejecute esta limpieza cada 1-2 semanas para mantener el rendimiento óptimo</li>
                    <li>🔄 Configure la limpieza automática de archivos temporales en Configuración > Sistema > Almacenamiento</li>
                    <li>📊 Monitoreee el espacio en disco regularmente, mantenga al menos 15% libre</li>
                    <li>🛡️ Use Windows Defender para eliminar archivos maliciosos que pueden acumular basura</li>
                    <li>📱 Desinstale aplicaciones que no use para liberar espacio permanentemente</li>
                    <li>☁️ Considere mover archivos grandes a almacenamiento en la nube</li>
                </ul>
            </div>
        </div>
"@

# Agregar sección de errores si los hay
if ($Global:ITSupportErrors.Count -gt 0) {
    $htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false
}

# Definir nombre del módulo para conteo específico
$moduleName = "CleanupMaintenance"

# Finalizar HTML con conteo específico del módulo
$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true -ModuleName $moduleName

# Guardar archivo HTML
$htmlContent | Out-File -FilePath $htmlFile -Encoding UTF8

Write-Host "`n✅ LIMPIEZA Y MANTENIMIENTO COMPLETADO" -ForegroundColor Green
Write-Host "📊 Reporte HTML generado: $htmlFile" -ForegroundColor Cyan
Write-Host "💾 Espacio total liberado: $(ConvertTo-ReadableSize $cleanupStats.TotalSpaceFreed)" -ForegroundColor Yellow
Write-Host "🔧 Procesos completados: $($cleanupStats.ItemsCleaned)" -ForegroundColor Yellow

if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "⚠️ Se encontraron $($Global:ITSupportErrors.Count) errores/advertencias. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")