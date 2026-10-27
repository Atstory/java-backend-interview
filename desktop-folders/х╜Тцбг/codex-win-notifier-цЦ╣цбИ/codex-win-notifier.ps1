[CmdletBinding()]
param(
    [string]$SessionsRoot = "$env:USERPROFILE\.codex\sessions",
    [int]$PollIntervalMs = 1200,
    [int]$PopupAutoCloseSeconds = 10,
    [switch]$SelfTest,
    [switch]$NoToast,
    [switch]$NoPopup
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$SCRIPT_NAME = 'Codex Win Notifier'
$TITLE_TEXT = 'Codex 已完成'
$STATUS_TEXT = '状态：已完成'
$MAX_SUMMARY_LENGTH = 220
$MAX_DETAILS_LENGTH = 1600
$POPUP_WIDTH = 520
$POPUP_HEIGHT = 360
$POPUP_MARGIN = 18
$TOAST_APP_ID = 'PowerShell'
$SCRIPT_FILE_PATH = $MyInvocation.MyCommand.Path
$HISTORY_FILE_NAME = 'codex-win-notifier-history.jsonl'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:config = [ordered]@{
    sessionsRoot = $SessionsRoot
    pollIntervalMs = [Math]::Max($PollIntervalMs, 800)
    popupAutoCloseSeconds = [Math]::Max($PopupAutoCloseSeconds, 1)
    toastEnabled = (-not $NoToast.IsPresent)
    popupEnabled = (-not $NoPopup.IsPresent)
    skipExistingHistory = $true
}
$script:fileStates = @{}
$script:seen = @{}
$script:notifyIcon = $null
$script:pollTimer = $null
$script:cleanupTimer = $null
$script:trayContext = $null
$script:popupForms = New-Object System.Collections.ArrayList

function Convert-ToSingleLineText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    return (($Text -replace "`r`n", ' ' -replace "`n", ' ') -replace '\s{2,}', ' ').Trim()
}

function Limit-TextLength {
    param([string]$Text, [int]$MaxLength)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    if ($Text.Length -le $MaxLength) { return $Text }
    return $Text.Substring(0, $MaxLength).TrimEnd() + '...'
}

function Convert-ToLocalTimeText {
    param([string]$UtcText)
    try {
        return ([DateTime]::Parse($UtcText).ToLocalTime()).ToString('yyyy-MM-dd HH:mm:ss')
    }
    catch {
        return (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
}

function Convert-ToHash {
    param([string]$Text)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return (([BitConverter]::ToString($sha256.ComputeHash($bytes))) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Convert-ToXmlSafeText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    return [System.Security.SecurityElement]::Escape($Text)
}
function Get-HistoryFilePath {
    return (Join-Path (Split-Path -Path $SCRIPT_FILE_PATH -Parent) $HISTORY_FILE_NAME)
}

function Write-CompletionHistory {
    param($Item)

    try {
        $historyRecord = [pscustomobject]@{
            timestamp = $Item.timestamp
            sessionFile = $Item.sessionFile
            sessionId = $Item.sessionId
            model = $Item.model
            workingDirectory = $Item.workingDirectory
            summary = $Item.summary
            details = $Item.details
            fingerprint = $Item.fingerprint
        }
        $jsonLine = ($historyRecord | ConvertTo-Json -Compress -Depth 6)
        Add-Content -LiteralPath (Get-HistoryFilePath) -Value $jsonLine -Encoding UTF8
    }
    catch {
    }
}

function New-RoundedRegion {
    param([int]$Width, [int]$Height, [int]$Radius)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $path.AddArc($Width - $diameter - 1, 0, $diameter, $diameter, 270, 90)
    $path.AddArc($Width - $diameter - 1, $Height - $diameter - 1, $diameter, $diameter, 0, 90)
    $path.AddArc(0, $Height - $diameter - 1, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return New-Object System.Drawing.Region($path)
}

function Initialize-SessionStates {
    if (-not (Test-Path -LiteralPath $script:config.sessionsRoot)) {
        throw "未找到 Codex 会话目录：$($script:config.sessionsRoot)"
    }

    Get-ChildItem -LiteralPath $script:config.sessionsRoot -Recurse -File -Filter '*.jsonl' | ForEach-Object {
        $script:fileStates[$_.FullName] = @{
            offset = if ($script:config.skipExistingHistory) { [int64]$_.Length } else { 0L }
            time = $_.LastWriteTimeUtc
            sessionId = ''
            model = ''
            workingDirectory = ''
        }
    }
}

function Get-FileState {
    param([System.IO.FileInfo]$FileInfo)

    if (-not $script:fileStates.ContainsKey($FileInfo.FullName)) {
        $script:fileStates[$FileInfo.FullName] = @{
            offset = if ($script:config.skipExistingHistory) { [int64]$FileInfo.Length } else { 0L }
            time = $FileInfo.LastWriteTimeUtc
            sessionId = ''
            model = ''
            workingDirectory = ''
        }
    }

    return $script:fileStates[$FileInfo.FullName]
}

function Read-NewRecords {
    param([System.IO.FileInfo]$FileInfo)

    $state = Get-FileState -FileInfo $FileInfo
    if ($FileInfo.Length -lt $state.offset) {
        $state.offset = 0L
    }
    if ($FileInfo.Length -eq $state.offset -and $FileInfo.LastWriteTimeUtc -le $state.time) {
        return @()
    }

    $items = New-Object 'System.Collections.Generic.List[object]'
    $fileStream = [System.IO.File]::Open($FileInfo.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        [void]$fileStream.Seek([int64]$state.offset, [System.IO.SeekOrigin]::Begin)
        $reader = New-Object System.IO.StreamReader($fileStream, [System.Text.UTF8Encoding]::new($false), $true, 4096, $true)
        try {
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try {
                    $items.Add(($line | ConvertFrom-Json -ErrorAction Stop))
                }
                catch {
                }
            }
        }
        finally {
            $reader.Dispose()
        }

        $state.offset = [int64]$fileStream.Position
        $state.time = $FileInfo.LastWriteTimeUtc
    }
    finally {
        $fileStream.Dispose()
    }

    return $items.ToArray()
}

function Update-SessionMeta {
    param($State, $Record)

    if ($Record.type -ne 'session_meta' -or $null -eq $Record.payload) {
        return
    }

    if ($Record.payload.PSObject.Properties.Name -contains 'id') {
        $State.sessionId = [string]$Record.payload.id
    }
    if ($Record.payload.PSObject.Properties.Name -contains 'model_provider') {
        $State.model = [string]$Record.payload.model_provider
    }
    if ($Record.payload.PSObject.Properties.Name -contains 'cwd') {
        $State.workingDirectory = [string]$Record.payload.cwd
    }
}

function New-CompletionItem {
    param([string]$FilePath, $State, $Record)

    if ($Record.type -ne 'event_msg' -or $null -eq $Record.payload) { return $null }
    if ($Record.payload.type -ne 'agent_message') { return $null }
    if ($Record.payload.phase -ne 'final_answer') { return $null }

    $rawMessage = [string]$Record.payload.message
    if ([string]::IsNullOrWhiteSpace($rawMessage)) { return $null }

    $fingerprint = Convert-ToHash -Text "$FilePath|$($Record.timestamp)|$rawMessage"
    if ($script:seen.ContainsKey($fingerprint)) { return $null }
    $script:seen[$fingerprint] = Get-Date

    return [pscustomobject]@{
        title = $TITLE_TEXT
        status = $STATUS_TEXT
        timestamp = Convert-ToLocalTimeText -UtcText ([string]$Record.timestamp)
        sessionFile = [System.IO.Path]::GetFileName($FilePath)
        sessionPath = $FilePath
        sessionId = $State.sessionId
        model = $State.model
        workingDirectory = $State.workingDirectory
        summary = Limit-TextLength -Text (Convert-ToSingleLineText -Text $rawMessage) -MaxLength $MAX_SUMMARY_LENGTH
        details = $rawMessage
        fingerprint = $fingerprint
    }
}

function Show-ToastNotification {
    param($Item)

    if (-not $script:config.toastEnabled) { return }

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] > $null
        [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime] > $null
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] > $null

        $toastXml = @"
<toast duration="short">
  <visual>
    <binding template="ToastGeneric">
      <text>$(Convert-ToXmlSafeText -Text $Item.title)</text>
      <text>$(Convert-ToXmlSafeText -Text $Item.summary)</text>
      <text>$(Convert-ToXmlSafeText -Text $Item.timestamp)</text>
    </binding>
  </visual>
  <audio silent="true" />
</toast>
"@

        $xmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xmlDocument.LoadXml($toastXml)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xmlDocument)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($TOAST_APP_ID).Show($toast)
    }
    catch {
        if ($null -ne $script:notifyIcon) {
            $script:notifyIcon.BalloonTipTitle = $Item.title
            $script:notifyIcon.BalloonTipText = $Item.summary
            $script:notifyIcon.ShowBalloonTip(3000)
        }
    }
}

function Show-CursorStylePopup {
    param($Item)

    if (-not $script:config.popupEnabled) { return }

    $backgroundColor = [System.Drawing.Color]::FromArgb(29, 31, 35)
    $cardColor = [System.Drawing.Color]::FromArgb(31, 33, 37)
    $accentColor = [System.Drawing.Color]::FromArgb(93, 156, 255)
    $titleColor = [System.Drawing.Color]::FromArgb(246, 247, 249)
    $contentColor = [System.Drawing.Color]::FromArgb(203, 208, 216)
    $metaColor = [System.Drawing.Color]::FromArgb(143, 149, 159)
    $chipColor = [System.Drawing.Color]::FromArgb(41, 44, 50)

    $form = New-Object System.Windows.Forms.Form
    $form.Width = $POPUP_WIDTH
    $form.Height = $POPUP_HEIGHT
    $form.FormBorderStyle = 'None'
    $form.StartPosition = 'Manual'
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.BackColor = $backgroundColor
    $form.Opacity = 0.99
    $form.Region = New-RoundedRegion -Width $form.Width -Height $form.Height -Radius 16

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Left = $workingArea.Right - $form.Width - $POPUP_MARGIN
    $form.Top = $workingArea.Bottom - $form.Height - $POPUP_MARGIN

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Left = 1
    $panel.Top = 1
    $panel.Width = $form.Width - 2
    $panel.Height = $form.Height - 2
    $panel.BackColor = $cardColor
    $panel.BorderStyle = 'FixedSingle'
    $form.Controls.Add($panel)

    $accentBar = New-Object System.Windows.Forms.Panel
    $accentBar.Left = 0
    $accentBar.Top = 0
    $accentBar.Width = 5
    $accentBar.Height = $panel.Height
    $accentBar.BackColor = $accentColor
    $panel.Controls.Add($accentBar)

    $title = New-Object System.Windows.Forms.Label
    $title.Left = 20
    $title.Top = 16
    $title.Width = 320
    $title.Height = 24
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10.5, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $titleColor
    $title.Text = $Item.title
    $panel.Controls.Add($title)

    $time = New-Object System.Windows.Forms.Label
    $time.Left = 20
    $time.Top = 40
    $time.Width = 320
    $time.Height = 18
    $time.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.2)
    $time.ForeColor = $metaColor
    $time.Text = $Item.timestamp
    $panel.Controls.Add($time)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Left = $panel.Width - 46
    $closeButton.Top = 10
    $closeButton.Width = 30
    $closeButton.Height = 26
    $closeButton.FlatStyle = 'Flat'
    $closeButton.FlatAppearance.BorderSize = 0
    $closeButton.BackColor = $cardColor
    $closeButton.ForeColor = $metaColor
    $closeButton.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $closeButton.Text = '×'
    $popupFormRef = $form
    $closeButton.Add_Click({
        param($sender, $args)
        if ($null -ne $popupFormRef -and -not $popupFormRef.IsDisposed) {
            $popupFormRef.Close()
        }
    }.GetNewClosure())
    $panel.Controls.Add($closeButton)

    $statusChip = New-Object System.Windows.Forms.Label
    $statusChip.Left = 20
    $statusChip.Top = 66
    $statusChip.Width = 88
    $statusChip.Height = 24
    $statusChip.TextAlign = 'MiddleCenter'
    $statusChip.BackColor = $chipColor
    $statusChip.ForeColor = $accentColor
    $statusChip.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.4, [System.Drawing.FontStyle]::Bold)
    $statusChip.Text = '已完成'
    $statusChip.Region = New-RoundedRegion -Width 88 -Height 24 -Radius 8
    $panel.Controls.Add($statusChip)

    $modelChip = New-Object System.Windows.Forms.Label
    $modelChip.Left = 118
    $modelChip.Top = 66
    $modelChip.Width = 132
    $modelChip.Height = 24
    $modelChip.TextAlign = 'MiddleCenter'
    $modelChip.BackColor = $chipColor
    $modelChip.ForeColor = $metaColor
    $modelChip.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.1)
    $modelChip.Text = if ([string]::IsNullOrWhiteSpace([string]$Item.model)) { 'unknown' } else { [string]$Item.model }
    $modelChip.Region = New-RoundedRegion -Width 132 -Height 24 -Radius 8
    $panel.Controls.Add($modelChip)

    $summaryLabel = New-Object System.Windows.Forms.Label
    $summaryLabel.Left = 20
    $summaryLabel.Top = 104
    $summaryLabel.Width = 70
    $summaryLabel.Height = 18
    $summaryLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.4, [System.Drawing.FontStyle]::Bold)
    $summaryLabel.ForeColor = $metaColor
    $summaryLabel.Text = '摘要'
    $panel.Controls.Add($summaryLabel)

    $summaryBox = New-Object System.Windows.Forms.TextBox
    $summaryBox.Left = 20
    $summaryBox.Top = 126
    $summaryBox.Width = $panel.Width - 40
    $summaryBox.Height = 52
    $summaryBox.Multiline = $true
    $summaryBox.ReadOnly = $true
    $summaryBox.BorderStyle = 'None'
    $summaryBox.BackColor = $cardColor
    $summaryBox.ForeColor = $contentColor
    $summaryBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $summaryBox.Text = $Item.summary
    $panel.Controls.Add($summaryBox)

    $detailsLabel = New-Object System.Windows.Forms.Label
    $detailsLabel.Left = 20
    $detailsLabel.Top = 186
    $detailsLabel.Width = 70
    $detailsLabel.Height = 18
    $detailsLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.4, [System.Drawing.FontStyle]::Bold)
    $detailsLabel.ForeColor = $metaColor
    $detailsLabel.Text = '详情'
    $panel.Controls.Add($detailsLabel)

    $detailsBox = New-Object System.Windows.Forms.TextBox
    $detailsBox.Left = 20
    $detailsBox.Top = 208
    $detailsBox.Width = $panel.Width - 40
    $detailsBox.Height = 108
    $detailsBox.Multiline = $true
    $detailsBox.ReadOnly = $true
    $detailsBox.ScrollBars = 'Vertical'
    $detailsBox.BorderStyle = 'FixedSingle'
    $detailsBox.BackColor = [System.Drawing.Color]::FromArgb(25, 27, 31)
    $detailsBox.ForeColor = $contentColor
    $detailsBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.8)
    $detailsBox.Text = [string]$Item.details
    $panel.Controls.Add($detailsBox)

    $footer = New-Object System.Windows.Forms.Label
    $footer.Left = 20
    $footer.Top = 324
    $footer.Width = $panel.Width - 40
    $footer.Height = 18
    $footer.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 7.7)
    $footer.ForeColor = $metaColor
    $footer.Text = "$($script:config.popupAutoCloseSeconds) 秒后自动关闭，可手动关闭 · 已写入本地归档"
    $panel.Controls.Add($footer)

    $closeTimer = New-Object System.Windows.Forms.Timer
    $closeTimer.Interval = [int]($script:config.popupAutoCloseSeconds * 1000)
    $popupFormRef = $form
    $timerRef = $closeTimer
    $closeTimer.Add_Tick({
        param($sender, $args)
        if ($null -ne $timerRef) { $timerRef.Stop() }
        if ($null -ne $popupFormRef -and -not $popupFormRef.IsDisposed) {
            $popupFormRef.Close()
        }
    }.GetNewClosure())

    $form.Add_Shown({
        param($sender, $args)
        if ($null -ne $timerRef) { $timerRef.Start() }
    }.GetNewClosure())
    $form.Add_FormClosed({
        param($sender, $args)
        try { if ($null -ne $timerRef) { $timerRef.Stop(); $timerRef.Dispose() } } catch { }
        try { if ($null -ne $script:popupForms) { [void]$script:popupForms.Remove($popupFormRef) } } catch { }
    }.GetNewClosure())

    [void]$script:popupForms.Add($form)
    [void]$form.Show()
}

function Notify-Completion {
    param($Item)
    Write-CompletionHistory -Item $Item
    Show-ToastNotification -Item $Item
    Show-CursorStylePopup -Item $Item
}

function Watch-Once {
    try {
        Get-ChildItem -LiteralPath $script:config.sessionsRoot -Recurse -File -Filter '*.jsonl' | ForEach-Object {
            $fileInfo = $_
            $isNew = -not $script:fileStates.ContainsKey($fileInfo.FullName)
            $state = Get-FileState -FileInfo $fileInfo

            if ($isNew -and $script:config.skipExistingHistory) {
                $state.offset = [int64]$fileInfo.Length
                $state.time = $fileInfo.LastWriteTimeUtc
                return
            }

            foreach ($record in (Read-NewRecords -FileInfo $fileInfo)) {
                Update-SessionMeta -State $state -Record $record
                $item = New-CompletionItem -FilePath $fileInfo.FullName -State $state -Record $record
                if ($null -ne $item) {
                    Notify-Completion -Item $item
                }
            }
        }
    }
    catch {
        Write-Warning "[$SCRIPT_NAME] 监听异常：$($_.Exception.Message)"
    }
}

function Cleanup-SeenCache {
    $expireTime = (Get-Date).AddHours(-12)
    foreach ($key in @($script:seen.Keys)) {
        if ($script:seen[$key] -lt $expireTime) {
            [void]$script:seen.Remove($key)
        }
    }
}

function Open-Path {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Start-Process explorer.exe -ArgumentList $Path | Out-Null
    }
}

function New-MenuItem {
    param([string]$Text, [scriptblock]$OnClick, [bool]$Enabled = $true)

    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    $item.Enabled = $Enabled
    if ($null -ne $OnClick) {
        $item.Add_Click($OnClick)
    }
    return $item
}

function Start-SelfTest {
    $item = [pscustomobject]@{
        title = $TITLE_TEXT
        status = $STATUS_TEXT
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        sessionFile = 'self-test-session.jsonl'
        sessionPath = ''
        sessionId = 'self-test'
        model = 'cursor-style-preview'
        workingDirectory = ''
        summary = '这是一条用于验证托盘常驻、Toast 与深色卡片样式的测试通知。'
        details = 'Codex 通知器自检成功。'
        fingerprint = [guid]::NewGuid().ToString('N')
    }
    Notify-Completion -Item $item
    Write-Host "[$SCRIPT_NAME] 自检通知已触发。" -ForegroundColor Yellow
}

function Start-TrayResidentApp {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    Initialize-SessionStates

    $script:trayContext = New-Object System.Windows.Forms.ApplicationContext
    $script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:notifyIcon.Text = 'Codex Win Notifier - 监听中'
    $script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
    $script:notifyIcon.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    [void]$menu.Items.Add((New-MenuItem -Text '状态：监听中' -OnClick $null -Enabled $false))
    [void]$menu.Items.Add('-')
    [void]$menu.Items.Add((New-MenuItem -Text '测试通知' -OnClick { Start-SelfTest }.GetNewClosure()))
    [void]$menu.Items.Add((New-MenuItem -Text '打开会话目录' -OnClick { Open-Path -Path $script:config.sessionsRoot }.GetNewClosure()))
    [void]$menu.Items.Add((New-MenuItem -Text '打开脚本目录' -OnClick { Open-Path -Path (Split-Path -Path $PSCommandPath -Parent) }.GetNewClosure()))
    [void]$menu.Items.Add('-')
    [void]$menu.Items.Add((New-MenuItem -Text '退出' -OnClick {
        if ($null -ne $script:pollTimer) { $script:pollTimer.Stop() }
        if ($null -ne $script:cleanupTimer) { $script:cleanupTimer.Stop() }
        foreach ($popupForm in @($script:popupForms)) {
            try { if ($null -ne $popupForm -and -not $popupForm.IsDisposed) { $popupForm.Close() } } catch { }
        }
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
        $menu.Dispose()
        $script:trayContext.ExitThread()
    }.GetNewClosure()))

    $script:notifyIcon.ContextMenuStrip = $menu
    $script:notifyIcon.Add_DoubleClick({ Start-SelfTest }.GetNewClosure())

    $script:pollTimer = New-Object System.Windows.Forms.Timer
    $script:pollTimer.Interval = $script:config.pollIntervalMs
    $script:pollTimer.Add_Tick({ Watch-Once }.GetNewClosure())
    $script:pollTimer.Start()

    $script:cleanupTimer = New-Object System.Windows.Forms.Timer
    $script:cleanupTimer.Interval = 60000
    $script:cleanupTimer.Add_Tick({ Cleanup-SeenCache }.GetNewClosure())
    $script:cleanupTimer.Start()

    Write-Host "[$SCRIPT_NAME] 托盘常驻已启动，监听目录：$($script:config.sessionsRoot)" -ForegroundColor Green
    Write-Host "[$SCRIPT_NAME] Toast=$($script:config.toastEnabled) Popup=$($script:config.popupEnabled)" -ForegroundColor Green
    [System.Windows.Forms.Application]::Run($script:trayContext)
}

if ($SelfTest) {
    Start-SelfTest
    Start-Sleep -Seconds ([Math]::Max($script:config.popupAutoCloseSeconds + 1, 2))
    return
}

Start-TrayResidentApp


