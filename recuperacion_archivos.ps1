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

# Recuperación de Archivos Avanzada
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlFile = Join-Path -Path $logsPath -ChildPath "recuperacion_archivos_$timestamp.html"

$username = $env:USERNAME
$computerName = $env:COMPUTERNAME
$dateTimeFormatted = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Host "=== INICIANDO RECUPERACIÓN AVANZADA DE ARCHIVOS ===" -ForegroundColor Green
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

# Función para calcular hash de archivo
function Get-FileHashSafe {
    param([string]$FilePath)
    try {
        if (Test-Path $FilePath) {
            $hash = Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction SilentlyContinue
            return $hash.Hash.Substring(0, 16) # Primeros 16 caracteres
        }
        return "N/A"
    } catch {
        return "Error"
    }
}

# Variables para estadísticas
$recoveryStats = @{
    FilesFound = 0
    BackupFilesFound = 0
    TempFilesFound = 0
    RecycleBinItems = 0
    ShadowCopiesFound = 0
    RecentFilesFound = 0
    TotalSizeFound = 0
    RecoverableFiles = 0
}

# Función para buscar archivos de respaldo
function Find-BackupFiles {
    Write-Host "🔍 Buscando archivos de respaldo..." -ForegroundColor Cyan
    
    $backupPatterns = @("*.bak", "*.backup", "*.old", "*.orig", "*~", "*.tmp")
    $searchPaths = @(
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Pictures",
        "$env:USERPROFILE\Videos",
        "$env:USERPROFILE\Music"
    )
    
    $backupFiles = @()
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            foreach ($pattern in $backupPatterns) {
                $files = Invoke-SafeExecution -Seccion "Busqueda-Respaldos" -DefaultValue @() -ScriptBlock {
                    Get-ChildItem -Path $path -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue | 
                    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) } # Solo últimos 30 días
                }
                
                foreach ($file in $files) {
                    $backupFiles += [PSCustomObject]@{
                        Name = $file.Name
                        FullPath = $file.FullName
                        Size = $file.Length
                        LastModified = $file.LastWriteTime
                        Extension = $file.Extension
                        Directory = $file.DirectoryName
                        Hash = Get-FileHashSafe -FilePath $file.FullName
                        Type = "Backup"
                        Recoverable = $true
                    }
                }
            }
        }
    }
    
    $recoveryStats.BackupFilesFound = $backupFiles.Count
    $recoveryStats.FilesFound += $backupFiles.Count
    $recoveryStats.TotalSizeFound += ($backupFiles | Measure-Object -Property Size -Sum).Sum
    
    return $backupFiles
}

# Función para buscar archivos temporales recuperables
function Find-RecoverableTempFiles {
    Write-Host "🔍 Buscando archivos temporales recuperables..." -ForegroundColor Cyan
    
    $tempPaths = @(
        "$env:USERPROFILE\AppData\Local\Temp",
        "$env:USERPROFILE\AppData\Roaming\Microsoft\Office\UnsavedFiles",
        "$env:USERPROFILE\AppData\Roaming\Microsoft\Word",
        "$env:USERPROFILE\AppData\Roaming\Microsoft\Excel",
        "$env:USERPROFILE\AppData\Roaming\Microsoft\PowerPoint"
    )
    
    $tempFiles = @()
    $recoverableExtensions = @(".docx", ".xlsx", ".pptx", ".pdf", ".txt", ".rtf", ".jpg", ".png", ".mp4", ".avi")
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $files = Invoke-SafeExecution -Seccion "Busqueda-Temporales" -DefaultValue @() -ScriptBlock {
                Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { 
                    $_.Extension -in $recoverableExtensions -and 
                    $_.LastWriteTime -gt (Get-Date).AddDays(-7) -and
                    $_.Length -gt 0
                }
            }
            
            foreach ($file in $files) {
                $tempFiles += [PSCustomObject]@{
                    Name = $file.Name
                    FullPath = $file.FullName
                    Size = $file.Length
                    LastModified = $file.LastWriteTime
                    Extension = $file.Extension
                    Directory = $file.DirectoryName
                    Hash = Get-FileHashSafe -FilePath $file.FullName
                    Type = "Temporal"
                    Recoverable = $true
                }
            }
        }
    }
    
    $recoveryStats.TempFilesFound = $tempFiles.Count
    $recoveryStats.FilesFound += $tempFiles.Count
    $recoveryStats.TotalSizeFound += ($tempFiles | Measure-Object -Property Size -Sum).Sum
    
    return $tempFiles
}

# Función para analizar la papelera de reciclaje
function Analyze-RecycleBin {
    Write-Host "🗑️ Analizando papelera de reciclaje..." -ForegroundColor Cyan
    
    $recycleBinItems = @()
    
    $result = Invoke-SafeExecution -Seccion "Analisis-PapeleraReciclaje" -DefaultValue @() -ScriptBlock {
        try {
            # Usar COM object para acceder a la papelera
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            
            if ($recycleBin) {
                $items = $recycleBin.Items()
                foreach ($item in $items) {
                    try {
                        $itemSize = if ($item.Size) { [long]$item.Size } else { 0 }
                        $recycleBinItems += [PSCustomObject]@{
                            Name = $item.Name
                            OriginalPath = $item.Path
                            Size = $itemSize
                            LastModified = if ($item.ModifyDate) { [DateTime]$item.ModifyDate } else { Get-Date }
                            Type = "Papelera"
                            Recoverable = $true
                            Hash = "N/A"
                        }
                    } catch {
                        # Ignorar elementos que no se pueden procesar
                    }
                }
            }
        } catch {
            # Si no se puede acceder por COM, intentar método alternativo
            $recycleBinPath = "$env:SystemDrive\`$Recycle.Bin"
            if (Test-Path $recycleBinPath) {
                Get-ChildItem -Path $recycleBinPath -Recurse -Force -ErrorAction SilentlyContinue | 
                Where-Object { $_.PSIsContainer -eq $false } |
                ForEach-Object {
                    $recycleBinItems += [PSCustomObject]@{
                        Name = $_.Name
                        OriginalPath = $_.FullName
                        Size = $_.Length
                        LastModified = $_.LastWriteTime
                        Type = "Papelera"
                        Recoverable = $true
                        Hash = "N/A"
                    }
                }
            }
        }
        
        return $recycleBinItems
    }
    
    $recoveryStats.RecycleBinItems = $result.Count
    $recoveryStats.FilesFound += $result.Count
    $recoveryStats.TotalSizeFound += ($result | Measure-Object -Property Size -Sum).Sum
    
    return $result
}

# Función para buscar copias de sombra (Shadow Copies)
function Find-ShadowCopies {
    Write-Host "👻 Buscando copias de sombra disponibles..." -ForegroundColor Cyan
    
    $shadowCopies = @()
    
    $result = Invoke-SafeExecution -Seccion "Busqueda-CopiaSombra" -DefaultValue @() -ScriptBlock {
        try {
            # Listar snapshots disponibles
            $vssSnapshots = vssadmin list shadows 2>$null
            if ($vssSnapshots) {
                $snapshots = $vssSnapshots | Select-String "Creation Time:|Shadow Copy Volume:" | 
                Group-Object -Every 2 | ForEach-Object {
                    $creationTime = ($_.Group[0] -split "Creation Time: ")[1]
                    $volume = ($_.Group[1] -split "Shadow Copy Volume: ")[1]
                    
                    [PSCustomObject]@{
                        Volume = $volume.Trim()
                        CreationTime = [DateTime]::Parse($creationTime.Trim())
                        Type = "Copia de Sombra"
                        Recoverable = $true
                    }
                }
                
                return $snapshots
            }
        } catch {
            # Error al acceder a VSS
        }
        
        return @()
    }
    
    $recoveryStats.ShadowCopiesFound = $result.Count
    
    return $result
}

# Función para buscar archivos recientes
function Find-RecentFiles {
    Write-Host "📅 Buscando archivos recientes..." -ForegroundColor Cyan
    
    $recentPaths = @(
        "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Recent",
        "$env:USERPROFILE\Recent"
    )
    
    $recentFiles = @()
    
    foreach ($path in $recentPaths) {
        if (Test-Path $path) {
            $files = Invoke-SafeExecution -Seccion "Busqueda-Recientes" -DefaultValue @() -ScriptBlock {
                Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue | 
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-14) }
            }
            
            foreach ($file in $files) {
                # Resolver accesos directos
                $targetPath = $file.FullName
                if ($file.Extension -eq ".lnk") {
                    try {
                        $shell = New-Object -ComObject WScript.Shell
                        $shortcut = $shell.CreateShortcut($file.FullName)
                        $targetPath = $shortcut.TargetPath
                    } catch {
                        $targetPath = $file.FullName
                    }
                }
                
                $recentFiles += [PSCustomObject]@{
                    Name = $file.Name
                    FullPath = $file.FullName
                    TargetPath = $targetPath
                    Size = $file.Length
                    LastAccessed = $file.LastWriteTime
                    Type = "Reciente"
                    Exists = if ($targetPath -and $targetPath -ne $file.FullName) { Test-Path $targetPath } else { $true }
                    Recoverable = $true
                }
            }
        }
    }
    
    $recoveryStats.RecentFilesFound = $recentFiles.Count
    $recoveryStats.FilesFound += $recentFiles.Count
    
    return $recentFiles
}

# Función para buscar versiones anteriores de archivos
function Find-FileVersions {
    Write-Host "📁 Buscando versiones anteriores de archivos..." -ForegroundColor Cyan
    
    $versionedFiles = @()
    $importantFolders = @(
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Desktop"
    )
    
    foreach ($folder in $importantFolders) {
        if (Test-Path $folder) {
            $result = Invoke-SafeExecution -Seccion "Busqueda-Versiones" -DefaultValue @() -ScriptBlock {
                # Buscar archivos con múltiples versiones (numerados)
                Get-ChildItem -Path $folder -File -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { 
                    $_.BaseName -match ".*\(\d+\)$" -or 
                    $_.BaseName -match ".*_v\d+$" -or
                    $_.BaseName -match ".*-\d+$"
                } |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.Name
                        FullPath = $_.FullName
                        Size = $_.Length
                        LastModified = $_.LastWriteTime
                        Type = "Versión"
                        Pattern = if ($_.BaseName -match "\(\d+\)$") { "Copia numerada" } 
                                 elseif ($_.BaseName -match "_v\d+$") { "Versión" }
                                 else { "Variante" }
                        Recoverable = $true
                    }
                }
            }
            
            $versionedFiles += $result
        }
    }
    
    $recoveryStats.FilesFound += $versionedFiles.Count
    $recoveryStats.TotalSizeFound += ($versionedFiles | Measure-Object -Property Size -Sum).Sum
    
    return $versionedFiles
}

# EJECUTAR TODAS LAS FUNCIONES DE BÚSQUEDA
Write-Host "`n🚀 Iniciando búsqueda exhaustiva de archivos recuperables..." -ForegroundColor Green

$backupFiles = Find-BackupFiles
$tempFiles = Find-RecoverableTempFiles
$recycleBinItems = Analyze-RecycleBin
$shadowCopies = Find-ShadowCopies
$recentFiles = Find-RecentFiles
$versionedFiles = Find-FileVersions

# Calcular estadísticas finales
$allFiles = @()
$allFiles += $backupFiles
$allFiles += $tempFiles
$allFiles += $recycleBinItems
$allFiles += $recentFiles
$allFiles += $versionedFiles

$recoveryStats.RecoverableFiles = ($allFiles | Where-Object { $_.Recoverable }).Count

Write-Host "`n📊 Generando reporte HTML detallado..." -ForegroundColor Yellow

# GENERAR REPORTE HTML
$htmlContent = Get-UnifiedHTMLTemplate -Title "Reporte de Recuperación de Archivos" -ComputerName $computerName -UserName $username -DateTime $dateTimeFormatted -IncludeSummary $true

$htmlContent += @"
        <div class="diagnostic-section">
            <h2>Resumen de Recuperación</h2>
            <div class="metric good">
                <h4>Total de Archivos Encontrados: $($recoveryStats.FilesFound)</h4>
                <p>Archivos Recuperables: $($recoveryStats.RecoverableFiles)</p>
                <p>Tamaño Total: $(ConvertTo-ReadableSize $recoveryStats.TotalSizeFound)</p>
            </div>
            
            <div class="metrics-grid">
                <div class="metric-item">
                    <h4>🔄 Archivos de Respaldo</h4>
                    <p class="metric-value">$($recoveryStats.BackupFilesFound)</p>
                </div>
                <div class="metric-item">
                    <h4>📄 Archivos Temporales</h4>
                    <p class="metric-value">$($recoveryStats.TempFilesFound)</p>
                </div>
                <div class="metric-item">
                    <h4>🗑️ Papelera de Reciclaje</h4>
                    <p class="metric-value">$($recoveryStats.RecycleBinItems)</p>
                </div>
                <div class="metric-item">
                    <h4>👻 Copias de Sombra</h4>
                    <p class="metric-value">$($recoveryStats.ShadowCopiesFound)</p>
                </div>
                <div class="metric-item">
                    <h4>📅 Archivos Recientes</h4>
                    <p class="metric-value">$($recoveryStats.RecentFilesFound)</p>
                </div>
            </div>
        </div>
"@

# Sección de archivos de respaldo
if ($backupFiles.Count -gt 0) {
    $htmlContent += @"
        <div class="diagnostic-section">
            <h2>🔄 Archivos de Respaldo Encontrados</h2>
            <table>
                <tr>
                    <th>Nombre</th>
                    <th>Ruta</th>
                    <th>Tamaño</th>
                    <th>Última Modificación</th>
                    <th>Hash</th>
                    <th>Estado</th>
                </tr>
"@
    
    foreach ($file in $backupFiles | Sort-Object LastModified -Descending) {
        $sizeFormatted = ConvertTo-ReadableSize $file.Size
        $dateFormatted = $file.LastModified.ToString("yyyy-MM-dd HH:mm")
        $htmlContent += "<tr class='good'><td>$($file.Name)</td><td title='$($file.FullPath)'>$($file.Directory)</td><td>$sizeFormatted</td><td>$dateFormatted</td><td>$($file.Hash)</td><td>✅ Recuperable</td></tr>"
    }
    
    $htmlContent += "</table></div>"
}

# Sección de archivos temporales
if ($tempFiles.Count -gt 0) {
    $htmlContent += @"
        <div class="diagnostic-section">
            <h2>📄 Archivos Temporales Recuperables</h2>
            <table>
                <tr>
                    <th>Nombre</th>
                    <th>Ruta</th>
                    <th>Tamaño</th>
                    <th>Última Modificación</th>
                    <th>Extensión</th>
                    <th>Estado</th>
                </tr>
"@
    
    foreach ($file in $tempFiles | Sort-Object LastModified -Descending) {
        $sizeFormatted = ConvertTo-ReadableSize $file.Size
        $dateFormatted = $file.LastModified.ToString("yyyy-MM-dd HH:mm")
        $htmlContent += "<tr class='warning'><td>$($file.Name)</td><td title='$($file.FullPath)'>$($file.Directory)</td><td>$sizeFormatted</td><td>$dateFormatted</td><td>$($file.Extension)</td><td>⚠️ Temporal</td></tr>"
    }
    
    $htmlContent += "</table></div>"
}

# Sección de papelera de reciclaje
if ($recycleBinItems.Count -gt 0) {
    $htmlContent += @"
        <div class="diagnostic-section">
            <h2>🗑️ Elementos en Papelera de Reciclaje</h2>
            <table>
                <tr>
                    <th>Nombre</th>
                    <th>Ruta Original</th>
                    <th>Tamaño</th>
                    <th>Fecha de Eliminación</th>
                    <th>Estado</th>
                </tr>
"@
    
    foreach ($item in $recycleBinItems | Sort-Object LastModified -Descending) {
        $sizeFormatted = ConvertTo-ReadableSize $item.Size
        $dateFormatted = $item.LastModified.ToString("yyyy-MM-dd HH:mm")
        $htmlContent += "<tr class='critical'><td>$($item.Name)</td><td>$($item.OriginalPath)</td><td>$sizeFormatted</td><td>$dateFormatted</td><td>🔄 Restaurable</td></tr>"
    }
    
    $htmlContent += "</table></div>"
}

# Sección de copias de sombra
if ($shadowCopies.Count -gt 0) {
    $htmlContent += @"
        <div class="diagnostic-section">
            <h2>👻 Copias de Sombra Disponibles</h2>
            <table>
                <tr>
                    <th>Volumen</th>
                    <th>Fecha de Creación</th>
                    <th>Estado</th>
                    <th>Acción</th>
                </tr>
"@
    
    foreach ($shadow in $shadowCopies | Sort-Object CreationTime -Descending) {
        $dateFormatted = $shadow.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
        $htmlContent += "<tr class='good'><td>$($shadow.Volume)</td><td>$dateFormatted</td><td>✅ Disponible</td><td>Accesible para recuperación</td></tr>"
    }
    
    $htmlContent += "</table></div>"
}

# Sección de archivos recientes
if ($recentFiles.Count -gt 0) {
    $htmlContent += @"
        <div class="diagnostic-section">
            <h2>📅 Archivos Recientes Accedidos</h2>
            <table>
                <tr>
                    <th>Nombre</th>
                    <th>Ruta Destino</th>
                    <th>Último Acceso</th>
                    <th>Existe</th>
                    <th>Estado</th>
                </tr>
"@
    
    foreach ($file in $recentFiles | Sort-Object LastAccessed -Descending) {
        $dateFormatted = $file.LastAccessed.ToString("yyyy-MM-dd HH:mm")
        $exists = if ($file.Exists) { "✅ Sí" } else { "❌ No" }
        $statusClass = if ($file.Exists) { "good" } else { "critical" }
        $htmlContent += "<tr class='$statusClass'><td>$($file.Name)</td><td title='$($file.TargetPath)'>$($file.TargetPath)</td><td>$dateFormatted</td><td>$exists</td><td>$(if ($file.Exists) { "Disponible" } else { "Eliminado" })</td></tr>"
    }
    
    $htmlContent += "</table></div>"
}

# Sección de versiones de archivos
if ($versionedFiles.Count -gt 0) {
    $htmlContent += @"
        <div class="diagnostic-section">
            <h2>📁 Versiones Anteriores de Archivos</h2>
            <table>
                <tr>
                    <th>Nombre</th>
                    <th>Ruta</th>
                    <th>Tamaño</th>
                    <th>Última Modificación</th>
                    <th>Patrón</th>
                    <th>Estado</th>
                </tr>
"@
    
    foreach ($file in $versionedFiles | Sort-Object LastModified -Descending) {
        $sizeFormatted = ConvertTo-ReadableSize $file.Size
        $dateFormatted = $file.LastModified.ToString("yyyy-MM-dd HH:mm")
        $htmlContent += "<tr class='good'><td>$($file.Name)</td><td title='$($file.FullPath)'>$($file.FullPath)</td><td>$sizeFormatted</td><td>$dateFormatted</td><td>$($file.Pattern)</td><td>✅ Disponible</td></tr>"
    }
    
    $htmlContent += "</table></div>"
}

# Sección de recomendaciones
$htmlContent += @"
        <div class="diagnostic-section">
            <h2>🔧 Recomendaciones de Recuperación</h2>
            <div class="metric good">
                <h3>Acciones Inmediatas:</h3>
                <ul>
                    <li>✅ Restaure archivos importantes desde la papelera de reciclaje</li>
                    <li>🔄 Copie archivos de respaldo (.bak, .backup) a ubicaciones seguras</li>
                    <li>💾 Respalde archivos temporales importantes antes de que se eliminen</li>
                    <li>👻 Use "Versiones anteriores" en propiedades de carpeta para acceder a copias de sombra</li>
                </ul>
                
                <h3>Prevención a Futuro:</h3>
                <ul>
                    <li>🔄 Configure copias de seguridad automáticas regulares</li>
                    <li>☁️ Use sincronización en la nube (OneDrive, Google Drive)</li>
                    <li>📱 Active el historial de archivos de Windows</li>
                    <li>⚠️ No vacíe la papelera inmediatamente después de eliminar archivos</li>
                    <li>🔒 Configure puntos de restauración del sistema regularmente</li>
                </ul>
                
                <h3>Herramientas Adicionales:</h3>
                <ul>
                    <li>🛠️ Use software especializado como Recuva o PhotoRec para recuperación profunda</li>
                    <li>💿 Considere herramientas de recuperación de particiones si es necesario</li>
                    <li>🔍 Explore versiones anteriores usando "cmd → vssadmin list shadows"</li>
                </ul>
            </div>
        </div>
"@

# Agregar sección de errores si los hay
if ($Global:ITSupportErrors.Count -gt 0) {
    $htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false
}

# Definir nombre del módulo para conteo específico
$moduleName = "FileRecovery"

# Finalizar HTML con conteo específico del módulo
$htmlContent += Get-UnifiedHTMLFooter -IncludeCountingScript $true -ModuleName $moduleName

# Guardar archivo HTML
$htmlContent | Out-File -FilePath $htmlFile -Encoding UTF8

Write-Host "`n✅ RECUPERACIÓN DE ARCHIVOS COMPLETADA" -ForegroundColor Green
Write-Host "📊 Reporte HTML generado: $htmlFile" -ForegroundColor Cyan
if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores/advertencias durante la recuperación. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}
Write-Host "🔍 Archivos encontrados: $($recoveryStats.FilesFound)" -ForegroundColor Yellow
Write-Host "💾 Archivos recuperables: $($recoveryStats.RecoverableFiles)" -ForegroundColor Yellow
Write-Host "📦 Tamaño total: $(ConvertTo-ReadableSize $recoveryStats.TotalSizeFound)" -ForegroundColor Yellow

if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "⚠️ Se encontraron $($Global:ITSupportErrors.Count) errores/advertencias. Ver log: $errorLogFile" -ForegroundColor Yellow
}

# Abrir reporte HTML automáticamente
try {
    Start-Process $htmlFile
    Write-Host "🌐 Reporte HTML abierto automáticamente" -ForegroundColor Green
} catch {
    Write-Host "ℹ️ No se pudo abrir automáticamente. Abra manualmente: $htmlFile" -ForegroundColor Blue
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")