# ============================================================
# 磁盘异常快照抓取脚本
# 用法：磁盘飚满时，右键此文件 → 使用 PowerShell 运行
# 输出：桌面/_归档目录/disk_snapshots/时间戳目录/
# ============================================================

$ErrorActionPreference = 'Continue'

try {

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = "$env:USERPROFILE\Desktop\_归档目录\disk_snapshots\$timestamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Write-Host '========================================' -ForegroundColor Cyan
Write-Host " 磁盘异常快照抓取中... $timestamp" -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

# ----------------------------------------------------------
# 1. 磁盘 I/O 最高的进程 TOP 30
# ----------------------------------------------------------
Write-Host '[1/7] 抓取进程 I/O 信息...' -ForegroundColor Yellow
try {
    $procList = @(Get-Process | Where-Object { $_.Id -ne 0 } | ForEach-Object {
        try {
            [PSCustomObject]@{
                Name      = $_.Name
                PID       = $_.Id
                ReadMB    = [math]::Round(($_.ReadTransferCount / 1MB), 2)
                WriteMB   = [math]::Round(($_.WriteTransferCount / 1MB), 2)
                TotalIOMB = [math]::Round(($_.ReadTransferCount + $_.WriteTransferCount) / 1MB, 2)
                Handles   = $_.HandleCount
                WorkingSetMB = [math]::Round(($_.WorkingSet64 / 1MB), 2)
            }
        } catch {
            $null
        }
    } | Where-Object { $_ -ne $null })

    if ($procList.Count -gt 0) {
        $procList | Sort-Object TotalIOMB -Descending |
            Select-Object -First 30 |
            Export-Csv "$outDir\01_process_io_top30.csv" -NoTypeInformation -Encoding UTF8
    } else {
        'no data' | Out-File "$outDir\01_process_io_top30.csv" -Encoding UTF8
    }
} catch {
    Write-Host '  [!] 进程I/O采集失败' -ForegroundColor Red
}

# ----------------------------------------------------------
# 2. 性能计数器 - 磁盘实时读写速率
# ----------------------------------------------------------
Write-Host '[2/7] 采集磁盘性能计数器（约5秒）...' -ForegroundColor Yellow
try {
    $counters = @(
        '\PhysicalDisk(*)\% Disk Time'
        '\PhysicalDisk(*)\% Idle Time'
        '\PhysicalDisk(*)\Avg. Disk Queue Length'
        '\PhysicalDisk(*)\Disk Read Bytes/sec'
        '\PhysicalDisk(*)\Disk Write Bytes/sec'
        '\PhysicalDisk(*)\Disk Reads/sec'
        '\PhysicalDisk(*)\Disk Writes/sec'
    )
    $samples = Get-Counter -Counter $counters -SampleInterval 1 -MaxSamples 5 -ErrorAction Stop
    $sampleData = @($samples | ForEach-Object {
        $_.CounterSamples | ForEach-Object {
            [PSCustomObject]@{
                Timestamp = $_.Timestamp
                Path      = $_.Path
                Value     = [math]::Round($_.CookedValue, 2)
            }
        }
    })
    if ($sampleData.Count -gt 0) {
        $sampleData | Export-Csv "$outDir\02_disk_perf_counters.csv" -NoTypeInformation -Encoding UTF8
    }
} catch {
    Write-Host '  [!] 性能计数器采集失败（可能需要管理员权限）' -ForegroundColor Red
}

# ----------------------------------------------------------
# 3. 文件级磁盘活动
# ----------------------------------------------------------
Write-Host '[3/7] 抓取文件级磁盘活动（需管理员权限）...' -ForegroundColor Yellow
try {
    $diskActivity = Get-Counter '\Process(*)\IO Read Bytes/sec','\Process(*)\IO Write Bytes/sec' -SampleInterval 1 -MaxSamples 3 -ErrorAction Stop
    $actData = @($diskActivity | ForEach-Object {
        $_.CounterSamples | Where-Object { $_.CookedValue -gt 0 } | ForEach-Object {
            [PSCustomObject]@{
                Timestamp   = $_.Timestamp
                ProcessName = ($_.Path -split '\\')[-2] -replace '[()]',''
                Counter     = ($_.Path -split '\\')[-1]
                BytesPerSec = [math]::Round($_.CookedValue, 0)
            }
        }
    })
    if ($actData.Count -gt 0) {
        $actData | Sort-Object BytesPerSec -Descending |
            Export-Csv "$outDir\03_file_io_activity.csv" -NoTypeInformation -Encoding UTF8
    }
} catch {
    Write-Host '  [!] 文件级I/O采集失败' -ForegroundColor Red
}

# ----------------------------------------------------------
# 4. 服务状态 - 常见磁盘杀手
# ----------------------------------------------------------
Write-Host '[4/7] 检查常见高磁盘占用服务...' -ForegroundColor Yellow
$suspectServices = @('WSearch','SysMain','wuauserv','WinDefend','BITS','DiagTrack')
$svcResults = [System.Collections.ArrayList]::new()
foreach ($svcName in $suspectServices) {
    try {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $svcResults.Add([PSCustomObject]@{
                ServiceName = $svcName
                DisplayName = $svc.DisplayName
                Status      = [string]$svc.Status
                StartType   = [string]$svc.StartType
            }) | Out-Null
        } else {
            $svcResults.Add([PSCustomObject]@{
                ServiceName = $svcName
                DisplayName = 'not found'
                Status      = 'N/A'
                StartType   = 'N/A'
            }) | Out-Null
        }
    } catch {
        $svcResults.Add([PSCustomObject]@{
            ServiceName = $svcName
            DisplayName = 'query failed'
            Status      = 'N/A'
            StartType   = 'N/A'
        }) | Out-Null
    }
}
$svcResults | Export-Csv "$outDir\04_suspect_services.csv" -NoTypeInformation -Encoding UTF8

# ----------------------------------------------------------
# 5. 磁盘基本信息和健康状态
# ----------------------------------------------------------
Write-Host '[5/7] 获取磁盘信息和健康状态...' -ForegroundColor Yellow
try {
    $diskData = @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
        [PSCustomObject]@{
            FriendlyName = $_.FriendlyName
            MediaType    = $_.MediaType
            Size_GB      = [math]::Round($_.Size / 1GB, 2)
            HealthStatus = $_.HealthStatus
            BusType      = $_.BusType
        }
    })
    if ($diskData.Count -gt 0) {
        $diskData | Export-Csv "$outDir\05_disk_health.csv" -NoTypeInformation -Encoding UTF8
    }
} catch {
    Write-Host '  [!] 磁盘健康信息采集失败（需要管理员权限）' -ForegroundColor Red
    'need admin' | Out-File "$outDir\05_disk_health_error.txt" -Encoding UTF8
}

# 磁盘分区使用率
try {
    $volData = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter } | ForEach-Object {
        [PSCustomObject]@{
            Drive       = $_.DriveLetter
            FileSystem  = $_.FileSystemType
            Size_GB     = [math]::Round($_.Size / 1GB, 2)
            FreeSpace_GB = [math]::Round($_.SizeRemaining / 1GB, 2)
            UsedPercent = if ($_.Size -gt 0) { [math]::Round((1 - $_.SizeRemaining / $_.Size) * 100, 1) } else { 0 }
        }
    })
    if ($volData.Count -gt 0) {
        $volData | Export-Csv "$outDir\05_volume_usage.csv" -NoTypeInformation -Encoding UTF8
    }
} catch {
    Write-Host '  [!] Get-Volume失败，回退WMI...' -ForegroundColor Yellow
    try {
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
            [PSCustomObject]@{
                Drive       = $_.DeviceID
                FileSystem  = $_.FileSystem
                Size_GB     = [math]::Round($_.Size / 1GB, 2)
                FreeSpace_GB = [math]::Round($_.FreeSpace / 1GB, 2)
                UsedPercent = if ($_.Size -gt 0) { [math]::Round((1 - $_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
            }
        } | Export-Csv "$outDir\05_volume_usage.csv" -NoTypeInformation -Encoding UTF8
    } catch {
        Write-Host '  [!] WMI分区信息也获取失败' -ForegroundColor Red
    }
}

# ----------------------------------------------------------
# 6. 最近系统事件日志
# ----------------------------------------------------------
Write-Host '[6/7] 提取最近磁盘相关事件日志...' -ForegroundColor Yellow
try {
    $evtData = @(Get-WinEvent -LogName System -MaxEvents 200 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match 'disk|I/O|ntfs|storage|volume' -or $_.Id -in @(7,9,11,15,51,52,55,98,129,153) } |
        Select-Object -First 30 TimeCreated, Id, LevelDisplayName, ProviderName, Message)
    if ($evtData.Count -gt 0) {
        $evtData | Export-Csv "$outDir\06_system_events.csv" -NoTypeInformation -Encoding UTF8
    }
} catch {
    'event log read failed' | Out-File "$outDir\06_events_error.txt" -Encoding UTF8
}

# ----------------------------------------------------------
# 7. 汇总报告
# ----------------------------------------------------------
Write-Host '[7/7] 生成汇总报告...' -ForegroundColor Yellow

$diskInfoStr = '(need admin)'
try {
    $pd = Get-PhysicalDisk -ErrorAction Stop
    if ($pd) { $diskInfoStr = $pd | Format-Table FriendlyName, MediaType, @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}}, HealthStatus, BusType -AutoSize | Out-String }
} catch {}

$volumeStr = '(unavailable)'
try {
    $vol = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter }
    if ($vol) { $volumeStr = $vol | Format-Table DriveLetter, FileSystemType, @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}}, @{N='Free(GB)';E={[math]::Round($_.SizeRemaining/1GB,2)}}, @{N='Used%';E={if($_.Size -gt 0){[math]::Round((1-$_.SizeRemaining/$_.Size)*100,1)}else{0}}} -AutoSize | Out-String }
} catch {
    try {
        $wmiVol = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3'
        if ($wmiVol) { $volumeStr = $wmiVol | Format-Table DeviceID, FileSystem, @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}}, @{N='Free(GB)';E={[math]::Round($_.FreeSpace/1GB,2)}}, @{N='Used%';E={if($_.Size -gt 0){[math]::Round((1-$_.FreeSpace/$_.Size)*100,1)}else{0}}} -AutoSize | Out-String }
    } catch {}
}

$ioTopStr = '(no data)'
if (Test-Path "$outDir\01_process_io_top30.csv") {
    $csvData = Import-Csv "$outDir\01_process_io_top30.csv" -ErrorAction SilentlyContinue
    if ($csvData) { $ioTopStr = $csvData | Select-Object -First 10 | Format-Table Name, PID, ReadMB, WriteMB, TotalIOMB -AutoSize | Out-String }
}

$suspectStr = '(no data)'
if (Test-Path "$outDir\04_suspect_services.csv") {
    $svcData = Import-Csv "$outDir\04_suspect_services.csv" -ErrorAction SilentlyContinue
    if ($svcData) { $suspectStr = $svcData | Format-Table ServiceName, DisplayName, Status, StartType -AutoSize | Out-String }
}

$report = @"
============================================================
Disk Snapshot Report
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME
============================================================

[Disk Info]
$diskInfoStr

[Volume Usage]
$volumeStr

[Top 10 I/O Processes]
$ioTopStr

[Suspect Services]
$suspectStr

See CSV files in same directory for details.
============================================================
"@

$report | Out-File "$outDir\00_summary_report.txt" -Encoding UTF8

# ----------------------------------------------------------
# Done
# ----------------------------------------------------------
Write-Host ''
Write-Host '========================================' -ForegroundColor Green
Write-Host " Snapshot saved to: $outDir" -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Files:' -ForegroundColor Cyan
Get-ChildItem $outDir | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ''

} catch {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Red
    Write-Host ' Script error!' -ForegroundColor Red
    Write-Host '========================================' -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ''
} finally {
    Write-Host 'Press any key to exit...' -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
