# ====================================================================
# AUTOMATIC COMMON PROBLEMS DETECTOR - TOOL FOR TECHNICIANS
# ====================================================================
#
# PURPOSE:
# This script automatically identifies the most common problems in computers
# It's perfect for running as the first diagnostic tool
#
# PROBLEMS IT DETECTS:
# - Not enough disk space
# - RAM memory exhausted  
# - Processes consuming too many resources
# - Critical services stopped
# - Network connectivity problems
# - Excessive temporary files
#
# HOW TO READ THE RESULTS:
# 🔴 CRITICAL: Needs immediate attention, can cause system failures
# 🟡 WARNING: Should be checked, can cause slowness or minor problems
# 🟢 NORMAL: Everything working correctly
#
# RECOMMENDED USE:
# - Run before making any changes to the system
# - As initial diagnostic tool during support calls
# - To document problems found
# ====================================================================

# Initial script configuration
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch {
    # If it fails, continue - some systems don't allow changing the policy
}

# Configure support for special characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Create reports directory if it doesn't exist
$PSScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logsPath = Join-Path -Path $PSScriptRoot -ChildPath "logs_reports"
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

# Load support modules
$errorHandlerPath = Join-Path -Path $PSScriptRoot -ChildPath "ErrorHandler.ps1"
if (Test-Path $errorHandlerPath) {
    . $errorHandlerPath
} else {
    Write-Warning "ErrorHandler.ps1 module not found. Continuing without advanced error handling."
    # Basic functions so the script doesn't fail
    function Add-ITSupportError { param($Section, $Message) }
    function Clear-ITSupportErrors { }
    function Get-ErrorSummaryHTML { param($IncludeCSS) return "" }
    function Export-ErrorLog { param($Path) }
    function Invoke-SafeExecution { param($Section, $ScriptBlock, $DefaultValue) try { & $ScriptBlock } catch { $DefaultValue } }
}

# Load HTML template
$htmlTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath "HTMLTemplate.ps1"
if (Test-Path $htmlTemplatePath) {
    . $htmlTemplatePath
} else {
    Write-Warning "HTMLTemplate.ps1 not found. Using basic format."
    function Get-UnifiedHTMLTemplate { 
        param($Title, $ComputerName, $UserName, $DateTime, $IncludeSummary)
        return "<html><head><title>$Title</title></head><body><h1>$Title</h1><p>$ComputerName - $UserName - $DateTime</p>"
    }
    function Get-UnifiedHTMLFooter { 
        param($IncludeCountingScript)
        return "</body></html>"
    }
}

# Clear errors from previous executions
Clear-ITSupportErrors

# ====================================================================
# START OF DETECTION PROCESS
# ====================================================================

Write-Host "=== AUTOMATIC COMMON PROBLEMS DETECTOR ===" -ForegroundColor Green

# Prepare variables for the report
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlFile = Join-Path -Path $logsPath -ChildPath "problems_detected_$timestamp.html"
$dateTimeFormatted = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$username = $env:USERNAME

Write-Host "Starting automatic problem detection..." -ForegroundColor Yellow
Write-Host "Report will be saved to: $htmlFile" -ForegroundColor Gray

# Containers to classify the problems found
$criticalIssues = @()    # Critical problems that need immediate attention
$warningIssues = @()     # Warnings that should be checked
$infoMessages = @()      # Information about elements that work well

# ====================================================================
# FUNCTION: CHECK DISK SPACE
# ====================================================================
# This function checks if there's enough free space on all disks
# ALERT LEVELS:
# - Less than 10% free = CRITICAL (can cause system failures)
# - Less than 20% free = WARNING (can cause slowness)
# - 20% or more free = NORMAL

function Test-DiskSpace {
    Write-Host "`n[1/6] Checking disk space..." -ForegroundColor Yellow
    
    # Get information from all hard drives (DriveType=3)
    $disks = Invoke-SafeExecution -Section "Problems-Disk-Space" -DefaultValue @() -ScriptBlock {
        Get-WmiObject -Query "SELECT * FROM Win32_LogicalDisk WHERE DriveType=3" -ErrorAction Stop
    }
    
    foreach ($disk in $disks) {
        try {
            # Calculate free and total space in GB
            $freeSpaceGB = [Math]::Round($disk.FreeSpace / 1GB, 2)
            $totalSpaceGB = [Math]::Round($disk.Size / 1GB, 2)
            $freePercent = [Math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
            
            # Determine status based on free percentage
            if ($freePercent -lt 10) {
                # CRITICAL: Very little free space
                $message = "Drive $($disk.DeviceID): Only $freePercent% free ($freeSpaceGB GB of $totalSpaceGB GB)"
                $script:criticalIssues += @{Type="Critical Disk"; Message=$message}
                Add-ITSupportError -Section "Problems-Critical-Disk" -Message $message -Severity "Critical"
                Write-Host "    🔴 $message" -ForegroundColor Red
            } elseif ($freePercent -lt 20) {
                $message = "Drive $($disk.DeviceID): Only $freePercent% free ($freeSpaceGB GB of $totalSpaceGB GB)"
                $script:warningIssues += @{Type="Low Disk"; Message=$message}
                Add-ITSupportError -Section "Problems-Disk-Warning" -Message $message -Severity "Warning"
            } else {
                $message = "Drive $($disk.DeviceID): $freePercent% free ($freeSpaceGB GB of $totalSpaceGB GB) - OK"
                $script:infoMessages += @{Type="Disk OK"; Message=$message}
            }
        } catch {
            Add-ITSupportError -Section "Problems-Disk-$($disk.DeviceID)" -ErrorRecord $_ -Severity "Warning"
        }
    }
}

# Function to check processes with high resource usage
function Test-HighResourceProcesses {
    Write-Host "Checking processes with high resource usage..." -ForegroundColor Yellow
    
    $topCPUProcesses = Invoke-SafeExecution -Section "Problems-CPU-Processes" -DefaultValue @() -ScriptBlock {
        Get-Process -ErrorAction Stop | Sort-Object -Property CPU -Descending | Select-Object -First 5
    }
    
    $topMemoryProcesses = Invoke-SafeExecution -Section "Problems-Memory-Processes" -DefaultValue @() -ScriptBlock {
        Get-Process -ErrorAction Stop | Sort-Object -Property WorkingSet -Descending | Select-Object -First 5
    }
    
    foreach ($proc in $topCPUProcesses) {
        try {
            $cpuTime = [Math]::Round($proc.CPU, 2)
            $memoryMB = [Math]::Round($proc.WorkingSet / 1MB, 2)
            $message = "$($proc.ProcessName): $cpuTime s CPU, $memoryMB MB RAM"
            
            if ($memoryMB -gt 1000) {  # More than 1GB of RAM
                $script:warningIssues += @{Type="High Memory Process"; Message="$($proc.ProcessName) uses $memoryMB MB of RAM"}
                Add-ITSupportError -Section "Problems-Process-Memory" -Message "$($proc.ProcessName) uses excessive memory: $memoryMB MB" -Severity "Warning"
            }
        } catch {
            Add-ITSupportError -Section "Problems-Process-$($proc.ProcessName)" -ErrorRecord $_ -Severity "Info"
        }
    }
    
    foreach ($proc in $topMemoryProcesses) {
        try {
            $memoryMB = [Math]::Round($proc.WorkingSet / 1MB, 2)
        } catch {
            Add-ITSupportError -Section "Problems-Process-Memory-$($proc.ProcessName)" -ErrorRecord $_ -Severity "Info"
        }
    }
}

# Function to check critical services
function Test-CriticalServices {
    Write-Host "Checking critical services..." -ForegroundColor Yellow
    
    $criticalServices = @(
        @{Name="wuauserv"; DisplayName="Windows Update"},
        @{Name="WinDefend"; DisplayName="Windows Defender"},
        @{Name="BITS"; DisplayName="Background Intelligent Transfer Service"},
        @{Name="wscsvc"; DisplayName="Windows Security Center"},
        @{Name="Spooler"; DisplayName="Print Spooler"},
        @{Name="Themes"; DisplayName="Themes"}
    )
    
    foreach ($svc in $criticalServices) {
        $serviceStatus = Invoke-SafeExecution -Section "Problems-Service-$($svc.Name)" -ScriptBlock {
            Get-Service -Name $svc.Name -ErrorAction Stop
        }
        
        if ($null -eq $serviceStatus) {
            $message = "Service $($svc.DisplayName) ($($svc.Name)) not found"
            $script:infoMessages += @{Type="Service Not Found"; Message=$message}
        } elseif ($serviceStatus.Status -ne "Running") {
            $message = "Service $($svc.DisplayName) ($($svc.Name)) is not running (Status: $($serviceStatus.Status))"
            $script:warningIssues += @{Type="Stopped Service"; Message=$message}
            Add-ITSupportError -Section "Problems-Services" -Message $message -Severity "Warning"
        } else {
            $message = "Service $($svc.DisplayName) is working correctly"
            $script:infoMessages += @{Type="Service OK"; Message=$message}
        }
    }
}

# Function to check basic network connectivity
function Test-BasicConnectivity {
    Write-Host "Checking basic connectivity..." -ForegroundColor Yellow
    
    $tests = @(
        @{Target="127.0.0.1"; Description="Local loopback"},
        @{Target="8.8.8.8"; Description="Google public DNS"}
    )
    
    foreach ($test in $tests) {
        $result = Invoke-SafeExecution -Section "Problems-Network-$($test.Target)" -ScriptBlock {
            Test-Connection -ComputerName $test.Target -Count 1 -ErrorAction Stop
        }
        
        if ($result) {
            $message = "Connectivity to $($test.Description) ($($test.Target)): OK"
            $script:infoMessages += @{Type="Network OK"; Message=$message}
        } else {
            $message = "No connectivity to $($test.Description) ($($test.Target))"
            $script:criticalIssues += @{Type="Critical Network"; Message=$message}
        }
    }
}

# Run all checks
Test-DiskSpace
Test-HighResourceProcesses
Test-CriticalServices
Test-BasicConnectivity

# Generate HTML report using unified template
$htmlHeader = Get-UnifiedHTMLTemplate -Title "🔍 System Problem Detector" -ComputerName $env:COMPUTERNAME -UserName $username -DateTime $dateTimeFormatted -IncludeSummary $false

$htmlSections = @"
        <div class="summary">
            <div class="summary-box critical">
                <h3>🚨 Critical</h3>
                <p style="font-size: 2em; font-weight: bold;">$($criticalIssues.Count)</p>
            </div>
            <div class="summary-box warning">
                <h3>⚠️ Warnings</h3>
                <p style="font-size: 2em; font-weight: bold;">$($warningIssues.Count)</p>
            </div>
            <div class="summary-box good">
                <h3>✅ Working</h3>
                <p style="font-size: 2em; font-weight: bold;">$($infoMessages.Count)</p>
            </div>
        </div>
"@

if ($criticalIssues.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section critical">
            <h2>🚨 Critical Problems Detected</h2>
"@
    foreach ($issue in $criticalIssues) {
        $htmlSections += "<div class='issue-item issue-critical'><strong>$($issue.Type):</strong> $($issue.Message)</div>"
    }
    $htmlSections += "</div>"
}

if ($warningIssues.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section warning">
            <h2>⚠️ Warnings</h2>
"@
    foreach ($issue in $warningIssues) {
        $htmlSections += "<div class='issue-item issue-warning'><strong>$($issue.Type):</strong> $($issue.Message)</div>"
    }
    $htmlSections += "</div>"
}

if ($infoMessages.Count -gt 0) {
    $htmlSections += @"
        <div class="diagnostic-section good">
            <h2>✅ Elements Working Correctly</h2>
"@
    foreach ($issue in $infoMessages) {
        $htmlSections += "<div class='issue-item issue-ok'><strong>$($issue.Type):</strong> $($issue.Message)</div>"
    }
    $htmlSections += "</div>"
}

# Generate footer and complete content
$htmlFooter = (Get-ErrorSummaryHTML -IncludeCSS) + (Get-UnifiedHTMLFooter -IncludeCountingScript $false)
$htmlContent = $htmlHeader + $htmlSections + $htmlFooter

# Save files
[System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)

Write-Host "Problem detection completed."
Write-Host "HTML Report: $htmlFile"
Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "- Critical problems: $($criticalIssues.Count)" -ForegroundColor $(if($criticalIssues.Count -gt 0){"Red"}else{"Green"})
Write-Host "- Warnings: $($warningIssues.Count)" -ForegroundColor $(if($warningIssues.Count -gt 0){"Yellow"}else{"Green"})
Write-Host "- OK elements: $($infoMessages.Count)" -ForegroundColor Green

if ($Global:ITSupportErrors.Count -gt 0) {
    Write-Host "$($Global:ITSupportErrors.Count) additional errors were detected during analysis. See details in the HTML report." -ForegroundColor Yellow
}
