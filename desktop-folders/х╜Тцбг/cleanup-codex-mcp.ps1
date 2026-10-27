[CmdletBinding()]
param(
    [ValidateRange(0, 60)]
    [int]$VerifyDelaySeconds = 8,

    [switch]$DryRun,

    [switch]$PauseOnExit
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

# These patterns are limited to the MCP services confirmed in the diagnosis.
# The goal is to avoid touching IDEA language servers, business dev servers,
# Codex main process, or any unrelated Node.js workload.
$TARGET_NODE_PATTERNS = @(
    '@benborla29[/\\]mcp-server-mysql',
    '@upstash[/\\]context7-mcp',
    '@modelcontextprotocol[/\\]server-sequential-thinking',
    '@negokaz[/\\]excel-mcp-server',
    'apifox-mcp-server',
    '@playwright[/\\]mcp'
)

$TARGET_CMD_PATTERNS = @(
    'mcp-server-mysql',
    'context7-mcp',
    'server-sequential-thinking',
    'excel-mcp-server',
    'apifox-mcp-server',
    'playwright-mcp'
)

Add-Type -AssemblyName Microsoft.VisualBasic

function Convert-BytesToGb {
    param(
        [double]$Bytes
    )

    if ($Bytes -le 0) {
        return 0
    }

    return [math]::Round($Bytes / 1GB, 2)
}

function Convert-BytesToMb {
    param(
        [double]$Bytes
    )

    if ($Bytes -le 0) {
        return 0
    }

    return [math]::Round($Bytes / 1MB, 0)
}

function Test-MatchAny {
    param(
        [AllowNull()]
        [string]$Text,

        [string[]]$Patterns
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    foreach ($pattern in $Patterns) {
        if ($Text -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-FilteredProcessInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcessName,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns,

        [Parameter(Mandatory = $true)]
        [string]$Kind
    )

    $cimProcesses = @(
        Get-CimInstance Win32_Process -Filter "Name = '$ProcessName'" -ErrorAction SilentlyContinue
    )

    $results = foreach ($process in $cimProcesses) {
        if (-not (Test-MatchAny -Text $process.CommandLine -Patterns $Patterns)) {
            continue
        }

        [pscustomobject]@{
            Kind            = $Kind
            Name            = $process.Name
            ProcessId       = [int]$process.ProcessId
            ParentProcessId = [int]$process.ParentProcessId
            WorkingSetBytes = [double]$process.WorkingSetSize
            WorkingSetMB    = Convert-BytesToMb -Bytes $process.WorkingSetSize
            CommandLine     = $process.CommandLine
        }
    }

    return @($results)
}

function Get-TargetProcesses {
    $nodeProcesses = Get-FilteredProcessInfo -ProcessName 'node.exe' -Patterns $TARGET_NODE_PATTERNS -Kind 'node'
    $cmdProcesses = Get-FilteredProcessInfo -ProcessName 'cmd.exe' -Patterns $TARGET_CMD_PATTERNS -Kind 'cmd'
    $allProcesses = @($nodeProcesses + $cmdProcesses)

    if (-not $allProcesses) {
        return @()
    }

    return @(
        $allProcesses |
            Group-Object ProcessId |
            ForEach-Object { $_.Group[0] } |
            Sort-Object @{ Expression = { if ($_.Kind -eq 'node') { 0 } else { 1 } } }, ProcessId
    )
}

function Get-Snapshot {
    param(
        [object[]]$TargetProcesses
    )

    $computerInfo = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
    $allNodeProcesses = @(Get-Process -Name node -ErrorAction SilentlyContinue)
    $targetProcessList = @($TargetProcesses)
    $targetWorkingSetBytes = ($targetProcessList | Measure-Object WorkingSetBytes -Sum).Sum
    $usedMemoryBytes = $computerInfo.TotalPhysicalMemory - $computerInfo.AvailablePhysicalMemory

    return [pscustomobject]@{
        Timestamp           = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        AvailableMemoryGB   = Convert-BytesToGb -Bytes $computerInfo.AvailablePhysicalMemory
        UsedMemoryGB        = Convert-BytesToGb -Bytes $usedMemoryBytes
        MemoryUsagePercent  = [math]::Round(($usedMemoryBytes * 100.0) / $computerInfo.TotalPhysicalMemory, 1)
        TotalNodeCount      = $allNodeProcesses.Count
        TotalNodeWS_GB      = Convert-BytesToGb -Bytes (($allNodeProcesses | Measure-Object WorkingSet64 -Sum).Sum)
        TargetProcessCount  = $targetProcessList.Count
        TargetProcessWS_GB  = Convert-BytesToGb -Bytes $targetWorkingSetBytes
    }
}

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ('=' * 76)
    Write-Host $Title
    Write-Host ('=' * 76)
}

function Write-ObjectBlock {
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    Write-Host ($InputObject | Format-List | Out-String)
}

function Write-TargetPreview {
    param(
        [object[]]$TargetProcesses
    )

    $processList = @($TargetProcesses)

    Write-Section -Title 'Matched Target Summary'

    if (-not $processList) {
        Write-Host 'No matched MCP residual process.'
        return
    }

    $groupSummary = $processList |
        Group-Object Kind |
        ForEach-Object {
            [pscustomobject]@{
                Kind      = $_.Name
                Count     = $_.Count
                WorkingGB = Convert-BytesToGb -Bytes (($_.Group | Measure-Object WorkingSetBytes -Sum).Sum)
            }
        } |
        Sort-Object Kind

    Write-Host ($groupSummary | Format-Table -AutoSize | Out-String)

    $topTargets = $processList |
        Sort-Object WorkingSetBytes -Descending |
        Select-Object -First 12 Kind, ProcessId, ParentProcessId, WorkingSetMB, CommandLine

    Write-Host ($topTargets | Format-Table -Wrap -AutoSize | Out-String)
}

function Stop-TargetProcesses {
    param(
        [object[]]$TargetProcesses,
        [switch]$DryRun
    )

    $processList = @($TargetProcesses)
    $processIds = @($processList | Select-Object -ExpandProperty ProcessId -Unique)

    if (-not $processIds) {
        return [pscustomobject]@{
            Requested = 0
            Stopped   = 0
            Failed    = 0
            DryRun    = [bool]$DryRun
        }
    }

    if ($DryRun) {
        return [pscustomobject]@{
            Requested = $processIds.Count
            Stopped   = 0
            Failed    = 0
            DryRun    = $true
        }
    }

    $stoppedCount = 0
    $failedCount = 0

    foreach ($processId in ($processIds | Sort-Object -Descending)) {
        try {
            Stop-Process -Id $processId -Force -ErrorAction Stop
            $stoppedCount++
        }
        catch {
            if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
                $stoppedCount++
                continue
            }

            $failedCount++
            Write-Warning ("Failed to stop process {0}: {1}" -f $processId, $_.Exception.Message)
        }
    }

    return [pscustomobject]@{
        Requested = $processIds.Count
        Stopped   = $stoppedCount
        Failed    = $failedCount
        DryRun    = $false
    }
}

function Write-DeltaReport {
    param(
        [Parameter(Mandatory = $true)]
        [object]$BeforeSnapshot,

        [Parameter(Mandatory = $true)]
        [object]$AfterSnapshot
    )

    $report = [pscustomobject]@{
        NodeCountReduced        = $BeforeSnapshot.TotalNodeCount - $AfterSnapshot.TotalNodeCount
        NodeWorkingSetSavedGB   = [math]::Round($BeforeSnapshot.TotalNodeWS_GB - $AfterSnapshot.TotalNodeWS_GB, 2)
        TargetWorkingSetSavedGB = [math]::Round($BeforeSnapshot.TargetProcessWS_GB - $AfterSnapshot.TargetProcessWS_GB, 2)
        MemoryFreedGB           = [math]::Round($AfterSnapshot.AvailableMemoryGB - $BeforeSnapshot.AvailableMemoryGB, 2)
        MemoryUsageDropPercent  = [math]::Round($BeforeSnapshot.MemoryUsagePercent - $AfterSnapshot.MemoryUsagePercent, 1)
    }

    Write-Section -Title 'Cleanup Delta'
    Write-ObjectBlock -InputObject $report
}

try {
    $beforeTargets = Get-TargetProcesses
    $beforeSnapshot = Get-Snapshot -TargetProcesses $beforeTargets

    Write-Section -Title 'Before Cleanup'
    Write-ObjectBlock -InputObject $beforeSnapshot
    Write-TargetPreview -TargetProcesses $beforeTargets

    if (-not $beforeTargets) {
        Write-Host 'No MCP residual process needs cleanup.'
        return
    }

    $stopResult = Stop-TargetProcesses -TargetProcesses $beforeTargets -DryRun:$DryRun
    Write-Section -Title 'Cleanup Result'
    Write-ObjectBlock -InputObject $stopResult

    if ($DryRun) {
        return
    }

    Start-Sleep -Seconds 2

    $afterTargets = Get-TargetProcesses
    $afterSnapshot = Get-Snapshot -TargetProcesses $afterTargets

    Write-Section -Title 'After Cleanup (Immediate)'
    Write-ObjectBlock -InputObject $afterSnapshot
    Write-DeltaReport -BeforeSnapshot $beforeSnapshot -AfterSnapshot $afterSnapshot

    if ($VerifyDelaySeconds -gt 0) {
        Start-Sleep -Seconds $VerifyDelaySeconds

        $delayedTargets = Get-TargetProcesses
        $delayedSnapshot = Get-Snapshot -TargetProcesses $delayedTargets

        Write-Section -Title ("After Cleanup (Delayed {0}s)" -f $VerifyDelaySeconds)
        Write-ObjectBlock -InputObject $delayedSnapshot
    }
}
catch {
    Write-Error ("Cleanup failed: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if ($PauseOnExit) {
        Read-Host 'Press Enter to exit' | Out-Null
    }
}
