# ====================================================================
# UNIFIED HTML TEMPLATE FOR IT SUPPORT REPORTS
# ====================================================================
#
# PURPOSE:
# This file contains functions that generate professional HTML reports
# Technicians can use these reports for:
# - Show results to clients visually
# - Document system status before/after service
# - Send technical reports by email
#
# MAIN FUNCTIONS:
# - Get-UnifiedHTMLTemplate: Creates the base structure of the report
# - Get-UnifiedHTMLFooter: Closes the report and adds scripts
# - Get-ModuleStatusClass: Assigns colors according to status (good/warning/critical)
#
# NOTE FOR TECHNICIANS:
# Reports are automatically saved in the "logs_reports" folder
# They are compatible with any web browser and can be printed
# ====================================================================

function Get-UnifiedHTMLTemplate {
    # This function creates the initial structure of the HTML report
    param(
        [string]$Title,                    # Report title (e.g., "Network Diagnosis")
        [string]$ComputerName = $env:COMPUTERNAME,  # Name of the analyzed computer
        [string]$UserName = $env:USERNAME,          # Current user
        [string]$DateTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),  # Report date and time
        [bool]$IncludeSummary = $true      # Whether to include the visual summary with counters
    )

    # Create the visual summary section (colored boxes with counters)
    # This helps the technician and client quickly see the general status
    $summarySection = if ($IncludeSummary) {
        @'
        <div class="summary">
            <div class="summary-box good">
                <h3>All Good</h3>
                <p id="goodCount">-</p>
            </div>
            <div class="summary-box warning">
                <h3>Warnings</h3>
                <p id="warningCount">-</p>
            </div>
            <div class="summary-box critical">
                <h3>Critical Problems</h3>
                <p id="criticalCount">-</p>
            </div>
        </div>
'@
    } else { "" }

    $headerHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <title>$Title - $ComputerName</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5;
            color: #333;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 15px;
            border-bottom: 2px solid #3498db;
        }
        .diagnostic-section {
            margin-bottom: 30px;
            padding: 20px;
            border-radius: 8px;
            background-color: #f9f9f9;
            border-left: 4px solid #3498db;
        }
        .section {
            margin-bottom: 25px;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #ddd;
        }
        .metric {
            margin: 10px 0;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #ddd;
        }
        .good {
            background-color: #d4edda;
            color: #155724;
            border-left-color: #28a745;
        }
        .warning {
            background-color: #fff3cd;
            color: #856404;
            border-left-color: #ffc107;
        }
        .critical {
            background-color: #f8d7da;
            color: #721c24;
            border-left-color: #dc3545;
        }
        .info {
            background-color: #d1ecf1;
            color: #0c5460;
            border-left-color: #17a2b8;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            border-left-color: #dc3545;
        }
        h1 { 
            color: #2c3e50; 
            margin: 0;
            font-size: 2.2em;
            font-weight: 300;
        }
        h2 { 
            color: #3498db; 
            border-bottom: 2px solid #3498db;
            padding-bottom: 8px;
            margin-top: 0;
            font-weight: 400;
        }
        h3 { 
            margin-top: 0; 
            color: #2c3e50;
            font-weight: 500;
        }
        h4 {
            color: #34495e;
            margin-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
            background-color: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            table-layout: fixed;
        }
        .table-container {
            overflow-x: auto;
            margin: 15px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
            word-wrap: break-word;
            overflow-wrap: break-word;
            max-width: 200px;
        }
        th {
            background-color: #3498db;
            color: white;
            font-weight: 500;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 0.5px;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        tr:last-child td {
            border-bottom: none;
        }
        pre {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            overflow-x: auto;
            border-left: 4px solid #3498db;
        }
        code {
            background-color: #e9ecef;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: 'Consolas', 'Monaco', monospace;
        }
        .summary {
            display: flex;
            justify-content: space-between;
            flex-wrap: wrap;
            margin-bottom: 30px;
            gap: 15px;
        }
        .summary-box {
            flex: 1;
            min-width: 200px;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            transition: transform 0.2s;
        }
        .summary-box:hover {
            transform: translateY(-2px);
        }
        .summary-box h3 {
            margin: 0 0 10px 0;
            font-size: 1.1em;
        }
        .summary-box p {
            margin: 0;
            font-size: 2em;
            font-weight: bold;
        }
        .process-list {
            background-color: white;
            border-radius: 8px;
            padding: 10px;
        }
        .network-adapter {
            background-color: white;
            margin: 10px 0;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #17a2b8;
        }
        .issue-item {
            margin: 8px 0;
            padding: 12px;
            border-left: 4px solid;
            border-radius: 4px;
            background-color: rgba(255,255,255,0.8);
        }
        .issue-critical {
            border-left-color: #dc3545;
            background-color: #f8d7da;
        }
        .issue-warning {
            border-left-color: #ffc107;
            background-color: #fff3cd;
        }
        .issue-ok {
            border-left-color: #28a745;
            background-color: #d4edda;
        }
        .status-badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: bold;
            text-transform: uppercase;
        }
        .status-ok {
            background-color: #28a745;
            color: white;
        }
        .status-warning {
            background-color: #ffc107;
            color: #212529;
        }
        .status-critical {
            background-color: #dc3545;
            color: white;
        }
        .backup-item {
            margin: 15px 0;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid;
        }
        .backup-item.success {
            border-left-color: #28a745;
            background-color: #d4edda;
        }
        .backup-item.failure {
            border-left-color: #dc3545;
            background-color: #f8d7da;
        }
        .footer-info {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            text-align: center;
            color: #6c757d;
            font-size: 0.9em;
        }
        @media (max-width: 768px) {
            .container {
                margin: 10px;
                padding: 15px;
            }
            .summary {
                flex-direction: column;
            }
            table, th, td {
                font-size: 0.9em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$Title</h1>
            <p><strong>Computer:</strong> $ComputerName | <strong>User:</strong> $UserName</p>
            <p><strong>Date:</strong> $DateTime</p>
        </div>
        
        $summarySection
"@

    return $headerHtml
}

function Get-UnifiedHTMLFooter {
    param(
        [bool]$IncludeCountingScript = $true,
        [string]$ModuleName = $null
    )

    $script = if ($IncludeCountingScript) {
        if ($ModuleName) {
            # Script for individual counting by module - improved to be more specific
            @"
        <script>
            // Count elements by status for specific module: $ModuleName
            window.addEventListener('load', function() {
                const modulePrefix = '$ModuleName';
                
                // Count only elements within diagnostic-section sections
                // This avoids counting elements from other modules or error summary
                const diagnosticSections = document.querySelectorAll('.diagnostic-section');
                let goodItems = 0;
                let warningItems = 0;
                let criticalItems = 0;
                
                diagnosticSections.forEach(function(section) {
                    goodItems += section.querySelectorAll('.metric.good, .section.good, .good').length;
                    warningItems += section.querySelectorAll('.metric.warning, .section.warning, .warning').length;
                    criticalItems += section.querySelectorAll('.metric.critical, .section.critical, .critical').length;
                });
                
                const goodCountElement = document.getElementById('goodCount');
                const warningCountElement = document.getElementById('warningCount');
                const criticalCountElement = document.getElementById('criticalCount');
                
                if (goodCountElement) goodCountElement.textContent = goodItems;
                if (warningCountElement) warningCountElement.textContent = warningItems;
                if (criticalCountElement) criticalCountElement.textContent = criticalItems;
                
                console.log('Estadísticas de ' + modulePrefix + ' cargadas: OK=' + goodItems + ', Advertencias=' + warningItems + ', Críticos=' + criticalItems);
            });
        </script>
"@
        } else {
            # Script original para conteo global - también mejorado
            @'
        <script>
            // Contar elementos por estado
            window.addEventListener('load', function() {
                // Contar solo elementos dentro de secciones diagnostic-section
                // Esto evita contar elementos del resumen de errores
                const diagnosticSections = document.querySelectorAll('.diagnostic-section');
                let goodItems = 0;
                let warningItems = 0;
                let criticalItems = 0;
                
                diagnosticSections.forEach(function(section) {
                    goodItems += section.querySelectorAll('.metric.good, .section.good, .good').length;
                    warningItems += section.querySelectorAll('.metric.warning, .section.warning, .warning').length;
                    criticalItems += section.querySelectorAll('.metric.critical, .section.critical, .critical').length;
                });
                
                const goodCountElement = document.getElementById('goodCount');
                const warningCountElement = document.getElementById('warningCount');
                const criticalCountElement = document.getElementById('criticalCount');
                
                if (goodCountElement) goodCountElement.textContent = goodItems;
                if (warningCountElement) warningCountElement.textContent = warningItems;
                if (criticalCountElement) criticalCountElement.textContent = criticalItems;
                
                console.log('Estadísticas cargadas: OK=' + goodItems + ', Advertencias=' + warningItems + ', Críticos=' + criticalItems);
            });
        </script>
'@
        }
    } else { "" }

    return @"
        <div class="footer-info">
            <p>Report automatically generated by IT Support Scripts</p>
            <p>Generation date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
        $script
    </div>
</body>
</html>
"@
}

# Las funciones están disponibles cuando se incluye este archivo

function Get-ModuleStatusClass {
    param(
        [string]$ModuleName,
        [string]$Status  # 'good', 'warning', 'critical'
    )
    
    if ($ModuleName) {
        return "$Status $ModuleName-$Status"
    } else {
        return $Status
    }
}

function Get-ModuleCountingScript {
    param(
        [string]$ModuleName
    )
    
    if (-not $ModuleName) {
        Write-Warning "Se requiere un nombre de módulo para generar el script de conteo individual"
        return ""
    }
    
    return @"
        <script>
            // Contar elementos específicos del módulo: $ModuleName
            window.addEventListener('load', function() {
                const modulePrefix = '$ModuleName';
                
                // Contar elementos que pertenecen específicamente a este módulo
                const goodSelector = '.metric.good.' + modulePrefix + '-good, .section.good.' + modulePrefix + '-good, .' + modulePrefix + '-good';
                const warningSelector = '.metric.warning.' + modulePrefix + '-warning, .section.warning.' + modulePrefix + '-warning, .' + modulePrefix + '-warning';
                const criticalSelector = '.metric.critical.' + modulePrefix + '-critical, .section.critical.' + modulePrefix + '-critical, .' + modulePrefix + '-critical';
                
                const goodItems = document.querySelectorAll(goodSelector).length;
                const warningItems = document.querySelectorAll(warningSelector).length;
                const criticalItems = document.querySelectorAll(criticalSelector).length;
                
                // Buscar elementos de conteo específicos del módulo o generales
                const goodCountElement = document.getElementById(modulePrefix + 'GoodCount') || document.getElementById('goodCount');
                const warningCountElement = document.getElementById(modulePrefix + 'WarningCount') || document.getElementById('warningCount');
                const criticalCountElement = document.getElementById(modulePrefix + 'CriticalCount') || document.getElementById('criticalCount');
                
                if (goodCountElement) goodCountElement.textContent = goodItems;
                if (warningCountElement) warningCountElement.textContent = warningItems;
                if (criticalCountElement) criticalCountElement.textContent = criticalItems;
                
                console.log('Estadísticas del módulo ' + modulePrefix + ' cargadas: OK=' + goodItems + ', Advertencias=' + warningItems + ', Críticos=' + criticalItems);
            });
        </script>
"@
}
