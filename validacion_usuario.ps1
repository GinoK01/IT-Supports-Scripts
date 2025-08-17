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

# Función auxiliar para crear hashtables de forma segura
function New-SafeHashtable {
    param(
        [hashtable]$InputHash
    )
    
    $safeHash = [ordered]@{}
    foreach ($key in $InputHash.Keys) {
        if (-not $safeHash.ContainsKey($key)) {
            $safeHash[$key] = $InputHash[$key]
        } else {
            Write-Warning "Clave duplicada detectada y omitida: $key"
        }
    }
    return $safeHash
}

# Validación de Configuración de Usuario en Windows
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlFile = Join-Path -Path $logsPath -ChildPath "validacion_usuario_$timestamp.html"
$dateTimeFormatted = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$username = $env:USERNAME

Write-Host "Iniciando validación de configuración de usuario..." -ForegroundColor Green

# Limpiar variables de ejecuciones anteriores cuando se ejecuta desde el script maestro
if (Get-Variable -Name "userValidationResults" -Scope Script -ErrorAction SilentlyContinue) {
    Remove-Variable -Name "userValidationResults" -Scope Script -Force
}

# Limpiar funciones que podrían causar conflictos en dot-sourcing
$functionsToClean = @('Test-UserFolders', 'Test-UserPermissions', 'Test-EnvironmentVariables', 'New-SafeHashtable')
foreach ($func in $functionsToClean) {
    if (Get-Command -Name $func -ErrorAction SilentlyContinue) {
        Remove-Item -Path "Function:\$func" -Force -ErrorAction SilentlyContinue
    }
}

# Variables para reporte HTML - usar scope específico para evitar conflictos
$script:userValidationResults = @()

# Función para validar acceso a carpetas clave del usuario
function Test-UserFolders {
    Write-Host "Validando acceso a carpetas del usuario..." -ForegroundColor Yellow
    
    $userFolders = @(
        @{Path="$env:USERPROFILE\Documents"; Name="Documentos"},
        @{Path="$env:USERPROFILE\Desktop"; Name="Escritorio"},
        @{Path="$env:USERPROFILE\Downloads"; Name="Descargas"},
        @{Path="$env:USERPROFILE\Pictures"; Name="Imágenes"},
        @{Path="$env:USERPROFILE\Videos"; Name="Videos"},
        @{Path="$env:USERPROFILE\Music"; Name="Música"},
        @{Path="$env:APPDATA"; Name="AppData Roaming"},
        @{Path="$env:LOCALAPPDATA"; Name="AppData Local"},
        @{Path="$env:TEMP"; Name="Carpeta Temporal"}
    )
    
    foreach ($folder in $userFolders) {
        $result = Invoke-SafeExecution -Seccion "Validacion-Usuario-$($folder.Name)" -ScriptBlock {
            $exists = Test-Path $folder.Path -ErrorAction Stop
            $readable = if ($exists) { 
                try { Get-ChildItem $folder.Path -ErrorAction Stop | Out-Null; $true } catch { $false }
            } else { $false }
            
            # Crear hashtable de forma segura para evitar duplicados
            $resultHash = [ordered]@{}
            $resultHash['Name'] = $folder.Name
            $resultHash['Path'] = $folder.Path
            $resultHash['Exists'] = $exists
            $resultHash['Readable'] = $readable
            $resultHash['Status'] = if ($exists -and $readable) { "OK" } elseif ($exists) { "Acceso Limitado" } else { "No Encontrada" }
            
            return $resultHash
        } -DefaultValue @{
            Name = $folder.Name
            Path = $folder.Path
            Exists = $false
            Readable = $false
            Status = "Error"
        }
        
        $script:userValidationResults += $result
    }
}

# Función para validar permisos de usuario
function Test-UserPermissions {
    Write-Host "Validando permisos del usuario..." -ForegroundColor Yellow
    
    # Verificar si es administrador
    $isAdmin = Invoke-SafeExecution -Seccion "Validacion-Usuario-Admin" -ScriptBlock {
        ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    } -DefaultValue $false
    
    # Información del usuario actual
    $userInfo = Invoke-SafeExecution -Seccion "Validacion-Usuario-Info" -ScriptBlock {
        # Crear hashtable de forma segura para evitar duplicados
        $infoHash = [ordered]@{}
        $infoHash['UserName'] = $env:USERNAME
        $infoHash['UserDomain'] = $env:USERDOMAIN
        $infoHash['UserProfile'] = $env:USERPROFILE
        $infoHash['ComputerName'] = $env:COMPUTERNAME
        $infoHash['IsAdmin'] = $isAdmin
        
        return $infoHash
    } -DefaultValue @{
        UserName = $env:USERNAME
        UserDomain = "Unknown"
        UserProfile = $env:USERPROFILE
        ComputerName = $env:COMPUTERNAME
        IsAdmin = $false
    }
    
    $script:userValidationResults += @{
        Name = "Información del Usuario"
        Details = $userInfo
        Status = "Info"
    }
}

# Función para validar variables de entorno
function Test-EnvironmentVariables {
    Write-Host "Validando variables de entorno..." -ForegroundColor Yellow
    
    $envVars = @(
        "USERNAME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", 
        "TEMP", "TMP", "PATH", "COMPUTERNAME", "USERDOMAIN"
    )
    
    foreach ($var in $envVars) {
        $value = Invoke-SafeExecution -Seccion "Validacion-Usuario-Env-$var" -ScriptBlock {
            [Environment]::GetEnvironmentVariable($var)
        } -DefaultValue $null
        
        $script:userValidationResults += @{
            Name = "Variable $var"
            Value = if ($value) { $value } else { "No definida" }
            Status = if ($value) { "OK" } else { "Faltante" }
        }
    }
}

# Ejecutar todas las validaciones
Test-UserFolders
Test-UserPermissions
Test-EnvironmentVariables

# Generar reporte HTML usando plantilla unificada
$htmlHeader = Get-UnifiedHTMLTemplate -Title "🔍 Validación de Configuración de Usuario" -ComputerName $env:COMPUTERNAME -UserName $username -DateTime $dateTimeFormatted -IncludeSummary $false

# Contar resultados por estado
$okCount = ($script:userValidationResults | Where-Object { $_.Status -eq "OK" }).Count
$warningCount = ($script:userValidationResults | Where-Object { $_.Status -in @("Acceso Limitado", "Faltante") }).Count
$errorCount = ($script:userValidationResults | Where-Object { $_.Status -in @("No Encontrada", "Error") }).Count

$htmlSections = @"
        <div class="summary">
            <div class="summary-box good">
                <h3>✅ Configuraciones OK</h3>
                <p style="font-size: 2em; font-weight: bold;">$okCount</p>
            </div>
            <div class="summary-box warning">
                <h3>⚠️ Advertencias</h3>
                <p style="font-size: 2em; font-weight: bold;">$warningCount</p>
            </div>
            <div class="summary-box critical">
                <h3>🚨 Errores</h3>
                <p style="font-size: 2em; font-weight: bold;">$errorCount</p>
            </div>
        </div>
"@

# Sección de carpetas de usuario
$folderResults = $script:userValidationResults | Where-Object { $_.Path -ne $null }
if ($folderResults.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section">
            <h2>📁 Carpetas de Usuario</h2>
            <table>
                <tr><th>Carpeta</th><th>Ruta</th><th>Existe</th><th>Accesible</th><th>Estado</th></tr>
"@
    foreach ($result in $folderResults) {
        $statusClass = switch ($result.Status) {
            "OK" { "good" }
            "Acceso Limitado" { "warning" }
            default { "critical" }
        }
        $htmlSections += "<tr class='$statusClass'><td>$($result.Name)</td><td>$($result.Path)</td><td>$(if($result.Exists){'✅'}else{'❌'})</td><td>$(if($result.Readable){'✅'}else{'❌'})</td><td>$($result.Status)</td></tr>"
    }
    $htmlSections += "</table></div>"
}

# Sección de información del usuario
$userInfo = ($script:userValidationResults | Where-Object { $_.Name -eq "Información del Usuario" }).Details
if ($userInfo) {
    $htmlSections += @"
        <div class="diagnostic-section">
            <h2>👤 Información del Usuario</h2>
            <div class="metric $(if($userInfo.IsAdmin){'warning'}else{'good'})">
                <p><strong>Usuario:</strong> $($userInfo.UserName)</p>
                <p><strong>Dominio:</strong> $($userInfo.UserDomain)</p>
                <p><strong>Perfil:</strong> $($userInfo.UserProfile)</p>
                <p><strong>Equipo:</strong> $($userInfo.ComputerName)</p>
                <p><strong>Administrador:</strong> $(if($userInfo.IsAdmin){'✅ Sí'}else{'❌ No'})</p>
            </div>
        </div>
"@
}

# Sección de variables de entorno
$envResults = $script:userValidationResults | Where-Object { $_.Name -like "Variable *" }
if ($envResults.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section">
            <h2>🔧 Variables de Entorno</h2>
            <table>
                <tr><th>Variable</th><th>Valor</th><th>Estado</th></tr>
"@
    foreach ($result in $envResults) {
        $statusClass = if ($result.Status -eq "OK") { "good" } else { "warning" }
        $htmlSections += "<tr class='$statusClass'><td>$($result.Name -replace 'Variable ', '')</td><td style='max-width: 300px; word-wrap: break-word;'>$($result.Value)</td><td>$($result.Status)</td></tr>"
    }
    $htmlSections += "</table></div>"
}

# Generar footer y contenido completo
$htmlFooter = (Get-ErrorSummaryHTML -IncludeCSS) + (Get-UnifiedHTMLFooter -IncludeCountingScript $false)
$htmlContent = $htmlHeader + $htmlSections + $htmlFooter

# Guardar archivo HTML
[System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "Validación de configuración de usuario completada."
Write-Host "Reporte HTML: $htmlFile"
Write-Host ""
Write-Host "RESUMEN:" -ForegroundColor Cyan
Write-Host "- Configuraciones OK: $okCount" -ForegroundColor Green
Write-Host "- Advertencias: $warningCount" -ForegroundColor $(if($warningCount -gt 0){"Yellow"}else{"Green"})
Write-Host "- Errores: $errorCount" -ForegroundColor $(if($errorCount -gt 0){"Red"}else{"Green"})

if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "Se detectaron $($Global:ITSupportErrors.Count) errores adicionales durante la validación. Ver detalles en el reporte HTML." -ForegroundColor Yellow
}

# Al final del script añade:
Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")