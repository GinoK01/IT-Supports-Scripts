# Módulo de Manejo de Errores para Scripts de IT Support
# Este módulo proporciona funciones comunes para capturar y mostrar errores

# Inicializar colección global de errores si no existe
if (-not $Global:ITSupportErrors) { 
    $Global:ITSupportErrors = New-Object System.Collections.ArrayList 
}

function Add-ITSupportError {
    <#
    .SYNOPSIS
    Agrega un error a la colección global de errores
    
    .PARAMETER Seccion
    La sección o módulo donde ocurrió el error
    
    .PARAMETER ErrorRecord
    El objeto ErrorRecord de PowerShell
    
    .PARAMETER Mensaje
    Mensaje personalizado del error (opcional)
    
    .PARAMETER Severidad
    Nivel de severidad: Info, Warning, Error, Critical
    #>
    param(
        [string]$Seccion,
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null,
        [string]$Mensaje = "",
        [ValidateSet("Info", "Warning", "Error", "Critical")]
        [string]$Severidad = "Error"
    )
    
    try {
        $errorObj = [pscustomobject]@{
            Timestamp = (Get-Date)
            Seccion   = $Seccion
            Mensaje   = if ($ErrorRecord) { $ErrorRecord.Exception.Message } else { $Mensaje }
            Categoria = if ($ErrorRecord) { $ErrorRecord.CategoryInfo.Category } else { "General" }
            Objetivo  = if ($ErrorRecord) { $ErrorRecord.TargetObject } else { "" }
            Severidad = $Severidad
            LineaError = if ($ErrorRecord) { $ErrorRecord.InvocationInfo.ScriptLineNumber } else { 0 }
            Comando   = if ($ErrorRecord) { $ErrorRecord.InvocationInfo.MyCommand.Name } else { "" }
        }
        
        $null = $Global:ITSupportErrors.Add($errorObj)
        
        # Escribir también al log de errores si está en modo verbose
        if ($VerbosePreference -eq "Continue") {
            Write-Verbose "[$Severidad] $Seccion`: $($errorObj.Mensaje)"
        }
    } catch {
        # Si falla el registro del error, al menos escribirlo a la consola
        Write-Warning "Error registrando error en sección '$Seccion': $_"
    }
}

function Invoke-SafeExecution {
    <#
    .SYNOPSIS
    Ejecuta un scriptblock de forma segura, capturando errores automáticamente
    
    .PARAMETER Seccion
    La sección donde se ejecuta el código
    
    .PARAMETER ScriptBlock
    El código a ejecutar
    
    .PARAMETER DefaultValue
    Valor a retornar si hay error
    
    .PARAMETER SuppressErrors
    Si se deben suprimir los errores (no mostrarlos en consola)
    #>
    param(
        [string]$Seccion,
        [scriptblock]$ScriptBlock,
        [object]$DefaultValue = $null,
        [switch]$SuppressErrors
    )
    
    try {
        return & $ScriptBlock
    } catch {
        Add-ITSupportError -Seccion $Seccion -ErrorRecord $_
        
        if (-not $SuppressErrors) {
            Write-Warning "Error en sección '$Seccion': $($_.Exception.Message)"
        }
        
        return $DefaultValue
    }
}

function Get-ErrorSummaryHTML {
    <#
    .SYNOPSIS
    Genera HTML con el resumen de errores detectados
    
    .PARAMETER IncludeCSS
    Si incluir estilos CSS en el HTML
    #>
    param(
        [switch]$IncludeCSS
    )
    
    $css = if ($IncludeCSS) {
        @'
        <style>
        .error-section { 
            margin: 20px 0; 
            padding: 15px; 
            border-radius: 5px;
            border-left: 5px solid #dc3545;
        }
        .error-section.critical { background-color: #f8d7da; border-left-color: #721c24; }
        .error-section.error { background-color: #f8d7da; border-left-color: #dc3545; }
        .error-section.warning { background-color: #fff3cd; border-left-color: #856404; }
        .error-section.info { background-color: #d1ecf1; border-left-color: #0c5460; }
        .error-section.none { background-color: #d4edda; border-left-color: #155724; }
        .error-table-container {
            overflow-x: auto;
            margin-top: 10px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            max-height: 400px;
            overflow-y: auto;
            max-width: 100%;
        }
        .error-table { 
            border-collapse: collapse; 
            width: 100%; 
            table-layout: fixed;
            max-width: 100%;
        }
        .error-table th, .error-table td { 
            border: 1px solid #ddd; 
            padding: 8px 12px; 
            text-align: left;
            word-wrap: break-word;
            overflow-wrap: break-word;
            vertical-align: top;
        }
        .error-table th { 
            background-color: #f2f2f2; 
            position: sticky;
            top: 0;
            z-index: 10;
            font-weight: bold;
        }
        .error-table th:nth-child(1) { width: 15%; } /* Hora */
        .error-table th:nth-child(2) { width: 20%; } /* Sección */
        .error-table th:nth-child(3) { width: 10%; } /* Severidad */
        .error-table th:nth-child(4) { width: 40%; } /* Mensaje */
        .error-table th:nth-child(5) { width: 15%; } /* Categoría */
        .error-table td {
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .error-table td:nth-child(4) {
            white-space: normal;
            word-break: break-word;
            max-height: 60px;
            overflow: hidden;
        }
        .error-table tr:hover td {
            white-space: normal;
            overflow: visible;
            max-height: none;
        }
        .error-row.critical { background-color: #f5c6cb; }
        .error-row.error { background-color: #f5c6cb; }
        .error-row.warning { background-color: #ffeaa7; }
        .error-row.info { background-color: #bee5eb; }
        </style>
'@
    } else { "" }
    
    if ($Global:ITSupportErrors.Count -eq 0) {
        return $css + @'
        <div class="error-section none">
            <h2>✅ Estado de Errores</h2>
            <p><strong>No se detectaron errores durante la ejecución.</strong></p>
        </div>
'@
    }
    
    # Agrupar errores por severidad
    $errorsBySeverity = $Global:ITSupportErrors | Group-Object -Property Severidad
    $criticalCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Critical" } | Select-Object -ExpandProperty Count) -or 0
    $errorCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Error" } | Select-Object -ExpandProperty Count) -or 0
    $warningCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Warning" } | Select-Object -ExpandProperty Count) -or 0
    $infoCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Info" } | Select-Object -ExpandProperty Count) -or 0
    
    # Asegurar que sean números enteros
    $criticalCount = [int]$criticalCount
    $errorCount = [int]$errorCount  
    $warningCount = [int]$warningCount
    $infoCount = [int]$infoCount
    
    $sectionClass = if ($criticalCount -gt 0) { "critical" } 
                   elseif ($errorCount -gt 0) { "error" }
                   elseif ($warningCount -gt 0) { "warning" }
                   else { "info" }
    
    $html = $css + @"
        <div class="error-section $sectionClass">
            <h2>⚠️ Errores y Advertencias Detectados</h2>
            <p><strong>Total de incidencias: $($Global:ITSupportErrors.Count)</strong></p>
            <ul>
                <li>Críticos: <strong>$criticalCount</strong></li>
                <li>Errores: <strong>$errorCount</strong></li>
                <li>Advertencias: <strong>$warningCount</strong></li>
                <li>Informativos: <strong>$infoCount</strong></li>
            </ul>
            
            <h3>Detalle de Incidencias</h3>
            <div class="error-table-container">
                <table class="error-table">
                    <thead>
                        <tr>
                            <th>Hora</th>
                            <th>Sección</th>
                            <th>Severidad</th>
                            <th>Mensaje</th>
                            <th>Categoría</th>
                        </tr>
                    </thead>
                    <tbody>
"@
    
    foreach ($error in $Global:ITSupportErrors | Sort-Object Timestamp) {
        $encodedSeccion = [System.Web.HttpUtility]::HtmlEncode($error.Seccion)
        $encodedMensaje = [System.Web.HttpUtility]::HtmlEncode($error.Mensaje)
        # Truncar mensaje si es muy largo para la vista inicial
        $displayMensaje = if ($encodedMensaje.Length -gt 100) {
            $encodedMensaje.Substring(0, 97) + "..."
        } else {
            $encodedMensaje
        }
        
        $html += @"
                        <tr class="error-row $($error.Severidad.ToLower())" title="$encodedMensaje">
                            <td>$($error.Timestamp.ToString('HH:mm:ss'))</td>
                            <td>$encodedSeccion</td>
                            <td>$($error.Severidad)</td>
                            <td>$displayMensaje</td>
                            <td>$($error.Categoria)</td>
                        </tr>
"@
    }
    
    $html += @"
                    </tbody>
                </table>
            </div>
        </div>
"@
    
    return $html
}

function Clear-ITSupportErrors {
    <#
    .SYNOPSIS
    Limpia la colección de errores
    #>
    if ($Global:ITSupportErrors) {
        $Global:ITSupportErrors.Clear()
    }
}

function Export-ErrorLog {
    <#
    .SYNOPSIS
    Exporta los errores a un archivo de log
    
    .PARAMETER Path
    Ruta del archivo de log
    #>
    param(
        [string]$Path
    )
    
    if ($Global:ITSupportErrors.Count -eq 0) {
        "No hay errores registrados." | Out-File -FilePath $Path -Encoding UTF8
        return
    }
    
    $logContent = @()
    $logContent += "=== LOG DE ERRORES IT SUPPORT ==="
    $logContent += "Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logContent += "Total de errores: $($Global:ITSupportErrors.Count)"
    $logContent += ""
    
    foreach ($error in $Global:ITSupportErrors | Sort-Object Timestamp) {
        $logContent += "[$($error.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))] [$($error.Severidad)] $($error.Seccion)"
        $logContent += "  Mensaje: $($error.Mensaje)"
        $logContent += "  Categoría: $($error.Categoria)"
        if ($error.Objetivo) {
            $logContent += "  Objetivo: $($error.Objetivo)"
        }
        if ($error.LineaError -gt 0) {
            $logContent += "  Línea: $($error.LineaError)"
        }
        $logContent += ""
    }
    
    $logContent | Out-File -FilePath $Path -Encoding UTF8
}

# Las funciones están disponibles automáticamente cuando se incluye el script con . (dot source)
