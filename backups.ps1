# Intentar configurar la polA­tica de ejecuciA³n (silenciando errores si falla)
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch {
    # Continuar sin mostrar error
}

# Configurar soporte UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Script de Backup de Datos
# Guarda backups de carpetas importantes en HTML

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

$backupDir = Join-Path -Path $logsPath -ChildPath "backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlReportPath = Join-Path -Path $logsPath -ChildPath "backup_report_$timestamp.html"
$dateTimeFormatted = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$username = $env:USERNAME

# FunciA³n para crear una copia de seguridad de una carpeta
function Backup-Folder {
    param (
        [string]$sourcePath,
        [string]$destinationPath,
        [string]$folderName
    )
    
    $backupResult = @{
        FolderName = $folderName
        SourcePath = $sourcePath
        DestinationPath = $destinationPath
        Success = $false
        Files = 0
        Size = 0
        ErrorMessage = ""
    }
    
    if (-not (Test-Path $sourcePath)) {
        $backupResult.ErrorMessage = "La carpeta de origen no existe"
        Add-ITSupportError -Seccion "Backup-$folderName" -Mensaje "La carpeta de origen no existe: $sourcePath" -Severidad "Warning"
        return $backupResult
    }
    
    $backupResult = Invoke-SafeExecution -Seccion "Backup-$folderName" -DefaultValue $backupResult -ScriptBlock {
        $destinationFolder = Join-Path -Path $destinationPath -ChildPath "$folderName-$timestamp"
        New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
        
        $files = Get-ChildItem -Path $sourcePath -Recurse -File -ErrorAction Stop
        $totalSize = 0
        $copiedFiles = 0
        
        foreach ($file in $files) {
            try {
                $relativePath = $file.FullName.Substring($sourcePath.Length)
                $targetPath = Join-Path -Path $destinationFolder -ChildPath $relativePath
                $targetDir = Split-Path -Parent $targetPath
                
                if (-not (Test-Path $targetDir)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }
                
                Copy-Item -Path $file.FullName -Destination $targetPath -Force -ErrorAction Stop
                $totalSize += $file.Length
                $copiedFiles++
            } catch {
                Add-ITSupportError -Seccion "Backup-$folderName-File" -ErrorRecord $_ -Severidad "Warning"
            }
        }
        
        $backupResult.Success = $true
        $backupResult.Files = $copiedFiles
        $backupResult.Size = $totalSize
        
        return $backupResult
    }
    
    if (-not $backupResult.Success -and -not $backupResult.ErrorMessage) {
        $backupResult.ErrorMessage = "Error durante el proceso de backup"
    }
    
    return $backupResult
}

# Carpetas para realizar copias de seguridad
$foldersToBackup = @(
    @{
        Name = "Documentos"
        Path = "$env:USERPROFILE\Documents"
    },
    @{
        Name = "Escritorio"
        Path = "$env:USERPROFILE\Desktop"
    },
    @{
        Name = "ImA¡genes"
        Path = "$env:USERPROFILE\Pictures"
    }
)

# Realizar las copias de seguridad
$backupResults = @()

foreach ($folder in $foldersToBackup) {
    Write-Host "Realizando copia de seguridad de $($folder.Name)..."
    $result = Backup-Folder -sourcePath $folder.Path -destinationPath $backupDir -folderName $folder.Name
    $backupResults += $result
}

# Usar el template unificado
$htmlContent = Get-UnifiedHTMLTemplate -Title "Informe de Backup" -IncludeSummary $true

# Actualizar el resumen de la página con conteos de backups
$successCount = ($backupResults | Where-Object { $_.Success } | Measure-Object).Count
$failCount = ($backupResults | Where-Object { -not $_.Success } | Measure-Object).Count

# Personalizar los títulos de los summary boxes para backups
$htmlContent = $htmlContent.Replace('<h3>Todo en Orden</h3>', '<h3>Backups Exitosos</h3>')
$htmlContent = $htmlContent.Replace('<h3>Advertencias</h3>', '<h3>Backups Fallidos</h3>')
$htmlContent = $htmlContent.Replace('<h3>Problemas Criticos</h3>', '<h3>Total de Carpetas</h3>')

# Añadir contenido específico del backup
$htmlContent += "<div class=`"diagnostic-section`">"
$htmlContent += "<h2>Detalles de Backups</h2>"

$htmlSections = ""

foreach ($result in $backupResults) {
    $status = if ($result.Success) { "good" } else { "critical" }
    $size = if ($result.Size -gt 0) {
        if ($result.Size -gt 1GB) {
            "$([Math]::Round($result.Size / 1GB, 2)) GB"
        } elseif ($result.Size -gt 1MB) {
            "$([Math]::Round($result.Size / 1MB, 2)) MB"
        } else {
            "$([Math]::Round($result.Size / 1KB, 2)) KB"
        }
    } else {
        "0 bytes"
    }
    
    $htmlSections += "<div class=`"metric $status`">"
    $htmlSections += "<h3>Backup de $($result.FolderName)</h3>"
    
    if ($result.Success) {
        $htmlSections += "<p>Estado: <strong>Completado</strong></p>"
        $htmlSections += "<p>Origen: <code>$($result.SourcePath)</code></p>"
        $htmlSections += "<p>Destino: <code>$($result.DestinationPath)</code></p>"
        $htmlSections += "<p>Archivos copiados: <strong>$($result.Files)</strong></p>"
        $htmlSections += "<p>Tamaño total: <strong>$size</strong></p>"
    } else {
        $htmlSections += "<p>Estado: <strong>Fallido</strong></p>"
        $htmlSections += "<p>Error: <strong>$($result.ErrorMessage)</strong></p>"
    }
    
    $htmlSections += "</div>"
}

$htmlContent += $htmlSections
$htmlContent += "</div>" # Cerrar diagnostic-section

# Agregar resumen de errores
$htmlContent += Get-ErrorSummaryHTML -IncludeCSS $false

# Finalizar HTML con el template unificado
$htmlContent += Get-UnifiedHTMLFooter

# Personalizar el JavaScript para mostrar conteos correctos de backup
$htmlContent = $htmlContent.Replace(
    'document.getElementById(''goodCount'').textContent = goodItems;',
    "document.getElementById('goodCount').textContent = '$successCount';"
)
$htmlContent = $htmlContent.Replace(
    'document.getElementById(''warningCount'').textContent = warningItems;',
    "document.getElementById('warningCount').textContent = '$failCount';"
)
$htmlContent = $htmlContent.Replace(
    'document.getElementById(''criticalCount'').textContent = criticalItems;',
    "document.getElementById('criticalCount').textContent = '$($backupResults.Count)';"
)

# Guardar usando WriteAllText para asegurar UTF-8 sin BOM
[System.IO.File]::WriteAllText($htmlReportPath, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "Backup completado. Informe HTML generado en $htmlReportPath"
if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores/advertencias durante el backup. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}
Invoke-Item $htmlReportPath

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")