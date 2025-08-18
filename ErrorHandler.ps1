# Error Management Module for IT Support Scripts
# This module provides common functions to capture and display errors

# Initialize global error collection if it doesn't exist
if (-not $Global:ITSupportErrors) { 
    $Global:ITSupportErrors = New-Object System.Collections.ArrayList 
}

function Add-ITSupportError {
    <#
    .SYNOPSIS
    Adds an error to the global error collection
    
    .PARAMETER Section
    The section or module where the error occurred
    
    .PARAMETER ErrorRecord
    The PowerShell ErrorRecord object
    
    .PARAMETER Message
    Custom error message (optional)
    
    .PARAMETER Severity
    Severity level: Info, Warning, Error, Critical
    #>
    param(
        [string]$Section,
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null,
        [string]$Message = "",
        [ValidateSet("Info", "Warning", "Error", "Critical")]
        [string]$Severity = "Error"
    )
    
    try {
        $errorObj = [pscustomobject]@{
            Timestamp = (Get-Date)
            Section   = $Section
            Message   = if ($ErrorRecord) { $ErrorRecord.Exception.Message } else { $Message }
            Category = if ($ErrorRecord) { $ErrorRecord.CategoryInfo.Category } else { "General" }
            Target  = if ($ErrorRecord) { $ErrorRecord.TargetObject } else { "" }
            Severity = $Severity
            ErrorLine = if ($ErrorRecord) { $ErrorRecord.InvocationInfo.ScriptLineNumber } else { 0 }
            Command   = if ($ErrorRecord) { $ErrorRecord.InvocationInfo.MyCommand.Name } else { "" }
        }
        
        $null = $Global:ITSupportErrors.Add($errorObj)
        
        # Also write to error log if in verbose mode
        if ($VerbosePreference -eq "Continue") {
            Write-Verbose "[$Severity] $Section`: $($errorObj.Message)"
        }
    } catch {
        # If error registration fails, at least write it to console
        Write-Warning "Error registering error in section '$Section': $_"
    }
}

function Invoke-SafeExecution {
    <#
    .SYNOPSIS
    Executes a scriptblock safely, automatically capturing errors
    
    .PARAMETER Section
    The section where the code is executed
    
    .PARAMETER ScriptBlock
    The code to execute
    
    .PARAMETER DefaultValue
    Value to return if there's an error
    
    .PARAMETER SuppressErrors
    Whether to suppress errors (not show them in console)
    #>
    param(
        [string]$Section,
        [scriptblock]$ScriptBlock,
        [object]$DefaultValue = $null,
        [switch]$SuppressErrors
    )
    
    try {
        return & $ScriptBlock
    } catch {
        Add-ITSupportError -Section $Section -ErrorRecord $_
        
        if (-not $SuppressErrors) {
            Write-Warning "Error in section '$Section': $($_.Exception.Message)"
        }
        
        return $DefaultValue
    }
}

function Get-ErrorSummaryHTML {
    <#
    .SYNOPSIS
    Generates HTML with the summary of detected errors
    
    .PARAMETER IncludeCSS
    Whether to include CSS styles in the HTML
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
        .error-table th:nth-child(1) { width: 15%; } /* Time */
        .error-table th:nth-child(2) { width: 20%; } /* Section */
        .error-table th:nth-child(3) { width: 10%; } /* Severity */
        .error-table th:nth-child(4) { width: 40%; } /* Message */
        .error-table th:nth-child(5) { width: 15%; } /* Category */
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
            <h2>✅ Error Status</h2>
            <p><strong>No errors detected during execution.</strong></p>
        </div>
'@
    }
    
    # Group errors by severity
    $errorsBySeverity = $Global:ITSupportErrors | Group-Object -Property Severity
    $criticalCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Critical" } | Select-Object -ExpandProperty Count) -or 0
    $errorCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Error" } | Select-Object -ExpandProperty Count) -or 0
    $warningCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Warning" } | Select-Object -ExpandProperty Count) -or 0
    $infoCount = ($errorsBySeverity | Where-Object { $_.Name -eq "Info" } | Select-Object -ExpandProperty Count) -or 0
    
    # Ensure they are integer numbers
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
            <h2>⚠️ Errors and Warnings Detected</h2>
            <p><strong>Total incidents: $($Global:ITSupportErrors.Count)</strong></p>
            <ul>
                <li>Critical: <strong>$criticalCount</strong></li>
                <li>Errors: <strong>$errorCount</strong></li>
                <li>Warnings: <strong>$warningCount</strong></li>
                <li>Informational: <strong>$infoCount</strong></li>
            </ul>
            
            <h3>Incident Details</h3>
            <div class="error-table-container">
                <table class="error-table">
                    <thead>
                        <tr>
                            <th>Time</th>
                            <th>Section</th>
                            <th>Severity</th>
                            <th>Message</th>
                            <th>Category</th>
                        </tr>
                    </thead>
                    <tbody>
"@
    
    foreach ($error in $Global:ITSupportErrors | Sort-Object Timestamp) {
        $encodedSection = [System.Web.HttpUtility]::HtmlEncode($error.Section)
        $encodedMessage = [System.Web.HttpUtility]::HtmlEncode($error.Message)
        # Truncate message if too long for initial view
        $displayMessage = if ($encodedMessage.Length -gt 100) {
            $encodedMessage.Substring(0, 97) + "..."
        } else {
            $encodedMessage
        }
        
        $html += @"
                        <tr class="error-row $($error.Severity.ToLower())" title="$encodedMessage">
                            <td>$($error.Timestamp.ToString('HH:mm:ss'))</td>
                            <td>$encodedSection</td>
                            <td>$($error.Severity)</td>
                            <td>$displayMessage</td>
                            <td>$($error.Category)</td>
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
    Clears the error collection
    #>
    if ($Global:ITSupportErrors) {
        $Global:ITSupportErrors.Clear()
    }
}

function Export-ErrorLog {
    <#
    .SYNOPSIS
    Exports errors to a log file
    
    .PARAMETER Path
    Log file path
    #>
    param(
        [string]$Path
    )
    
    if ($Global:ITSupportErrors.Count -eq 0) {
        "No errors recorded." | Out-File -FilePath $Path -Encoding UTF8
        return
    }
    
    $logContent = @()
    $logContent += "=== IT SUPPORT ERROR LOG ==="
    $logContent += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logContent += "Total errors: $($Global:ITSupportErrors.Count)"
    $logContent += ""
    
    foreach ($error in $Global:ITSupportErrors | Sort-Object Timestamp) {
        $logContent += "[$($error.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))] [$($error.Severity)] $($error.Section)"
        $logContent += "  Message: $($error.Message)"
        $logContent += "  Category: $($error.Category)"
        if ($error.Target) {
            $logContent += "  Target: $($error.Target)"
        }
        if ($error.ErrorLine -gt 0) {
            $logContent += "  Line: $($error.ErrorLine)"
        }
        $logContent += ""
    }
    
    $logContent | Out-File -FilePath $Path -Encoding UTF8
}

# Functions are automatically available when the script is included with . (dot source)
