#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArguments = @()
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

$script:HarnessVersion = "0.2.0"
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 这份清单既用于 init 生成文件，也用于 validate 做结构校验。
$script:RequiredDocs = @(
    "project.md",
    "architecture.md",
    "conventions.md",
    "testing.md",
    "risk-boundaries.md",
    "tooling.md"
)

$script:RequiredTemplates = @(
    "proposal.md",
    "design.md",
    "tasks.md",
    "review.md",
    "verify.md",
    "archive.md",
    "delta-spec.md"
)

# 各类工件的最小校验规则。严格模式下如果仍保留模板占位文本，会被判定为错误。
$script:ArtifactRules = @{
    "proposal.md" = @{
        Headings = @("## 背景", "## 目标", "## 范围")
        Placeholders = @("本次变更为什么要做。", "本次要解决什么问题。")
    }
    "design.md" = @{
        Headings = @("## 核心思路", "## 影响范围", "## 回滚方案")
        Placeholders = @("整体怎么做。", "出问题时怎么退回。")
    }
    "tasks.md" = @{
        Headings = @("## 任务列表", "## 完成定义")
        Placeholders = @("每个任务完成的判定标准是什么。")
    }
    "review.md" = @{
        Headings = @("## 评审范围", "## 风险结论", "## 评审结论")
        Placeholders = @("这次评审覆盖哪些内容。", "本次变更的总体风险级别是什么。")
    }
    "verify.md" = @{
        Headings = @("## 执行的检查", "## 结果", "## 最终结论")
        Placeholders = @("分别记录通过、失败、跳过。", "这次没有验证到什么。")
    }
    "archive.md" = @{
        Headings = @("## 最终完成内容", "## 实际影响范围")
        Placeholders = @("这次实际完成了什么。", "最终改到了哪些模块、流程或对象。")
    }
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Stop-Script {
    param(
        [string]$Message,
        [int]$Code = 1
    )

    Write-Host "[ERR]  $Message" -ForegroundColor Red
    exit $Code
}

function Get-ProjectRoot {
    return (Get-Location).Path
}

function Get-ProjectName {
    param([string]$RootPath)

    $name = Split-Path -Leaf $RootPath
    if ([string]::IsNullOrWhiteSpace($name)) {
        return "project"
    }

    return $name
}

function Ensure-Directory {
    param(
        [string]$Path,
        [hashtable]$Summary
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        if ($null -ne $Summary) {
            $Summary.DirectoriesExisting += $Path
        }
        return
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    if ($null -ne $Summary) {
        $Summary.DirectoriesCreated += $Path
    }
}

function New-WriteSummary {
    return @{
        Created = @()
        Updated = @()
        Skipped = @()
        DirectoriesCreated = @()
        DirectoriesExisting = @()
    }
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        Ensure-Directory -Path $directory -Summary $null
    }

    $normalizedContent = $Content
    if (-not $normalizedContent.EndsWith("`n")) {
        $normalizedContent += "`r`n"
    }

    [System.IO.File]::WriteAllText($Path, $normalizedContent, $script:Utf8NoBom)
}

function Set-ManagedFile {
    param(
        [string]$Path,
        [string]$Content,
        [bool]$Force,
        [hashtable]$Summary
    )

    $exists = Test-Path -LiteralPath $Path -PathType Leaf
    if ($exists -and -not $Force) {
        $Summary.Skipped += $Path
        return
    }

    Write-Utf8File -Path $Path -Content $Content
    if ($exists) {
        $Summary.Updated += $Path
    }
    else {
        $Summary.Created += $Path
    }
}

function ConvertTo-Slug {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "名称不能为空。"
    }

    $slug = $Value.Trim().ToLowerInvariant()
    $slug = $slug -replace "[\s_]+", "-"
    $slug = $slug -replace "[^\p{L}\p{Nd}-]+", "-"
    $slug = $slug -replace "-{2,}", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "名称经过规范化后为空，请换一个更明确的名称。"
    }

    return $slug
}

function Format-Title {
    param(
        [string]$RawName,
        [string]$ExplicitTitle
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitTitle)) {
        return $ExplicitTitle.Trim()
    }

    return $RawName.Trim()
}

function Format-ChangeId {
    param(
        [string]$NamingRule,
        [string]$Slug
    )

    $dateText = Get-Date -Format "yyyyMMdd"
    $changeId = $NamingRule.Replace("{date}", $dateText).Replace("{slug}", $Slug)
    return $changeId
}

function ConvertTo-YamlScalar {
    param([object]$Value)

    if ($Value -is [bool]) {
        return ($Value.ToString().ToLowerInvariant())
    }

    if ($Value -is [int] -or $Value -is [long]) {
        return $Value.ToString()
    }

    $text = [string]$Value
    if ($text -match "^[A-Za-z0-9._/\-{}]+$") {
        return $text
    }

    $escaped = $text.Replace("'", "''")
    return "'$escaped'"
}

function ConvertTo-SimpleYaml {
    param(
        [hashtable]$Data,
        [string]$Indent = ""
    )

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        if ($value -is [System.Collections.IDictionary]) {
            $lines.Add("${Indent}${key}:")
            $nestedYaml = ConvertTo-SimpleYaml -Data $value -Indent "$Indent  "
            foreach ($nestedLine in ($nestedYaml -split "`r?`n")) {
                if (-not [string]::IsNullOrWhiteSpace($nestedLine)) {
                    $lines.Add($nestedLine)
                }
            }
        }
        else {
            $lines.Add("${Indent}${key}: $(ConvertTo-YamlScalar -Value $value)")
        }
    }

    return ($lines -join "`r`n")
}

function ConvertFrom-YamlScalar {
    param([string]$Text)

    $value = $Text.Trim()
    if (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"'))) {
        $value = $value.Substring(1, $value.Length - 2)
    }

    switch -Regex ($value.ToLowerInvariant()) {
        "^true$" { return $true }
        "^false$" { return $false }
        "^\d+$" { return [int]$value }
        default { return $value }
    }
}

function Read-SimpleYaml {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{}
    }

    $result = [ordered]@{}
    $currentSection = $null
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine -replace "`t", "  "
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line.TrimStart().StartsWith("#")) {
            continue
        }

        if ($line -match "^(?<indent>\s*)(?<key>[A-Za-z0-9_-]+):(?:\s*(?<value>.*))?$") {
            $indentLength = $matches["indent"].Length
            $key = $matches["key"]
            $value = $matches["value"]

            if ($indentLength -eq 0) {
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $result[$key] = [ordered]@{}
                    $currentSection = $key
                }
                else {
                    $result[$key] = ConvertFrom-YamlScalar -Text $value
                    $currentSection = $null
                }
            }
            elseif ($indentLength -eq 2 -and -not [string]::IsNullOrWhiteSpace($currentSection)) {
                if (-not ($result[$currentSection] -is [System.Collections.IDictionary])) {
                    $result[$currentSection] = [ordered]@{}
                }
                $result[$currentSection][$key] = ConvertFrom-YamlScalar -Text $value
            }
        }
    }

    return $result
}

function Merge-Hashtable {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $merged = [ordered]@{}
    foreach ($key in $Base.Keys) {
        $baseValue = $Base[$key]
        if ($Override.Contains($key)) {
            $overrideValue = $Override[$key]
            if (($baseValue -is [System.Collections.IDictionary]) -and ($overrideValue -is [System.Collections.IDictionary])) {
                $merged[$key] = Merge-Hashtable -Base $baseValue -Override $overrideValue
            }
            else {
                $merged[$key] = $overrideValue
            }
        }
        else {
            $merged[$key] = $baseValue
        }
    }

    foreach ($key in $Override.Keys) {
        if (-not $merged.Contains($key)) {
            $merged[$key] = $Override[$key]
        }
    }

    return $merged
}

function New-DefaultConfig {
    param(
        [string]$ToolName = "codex",
        [string]$Profile = "core"
    )

    return [ordered]@{
        version = 1
        profile = $Profile
        tool = [ordered]@{
            name = $ToolName
            generateToolHints = ($ToolName -ne "none")
        }
        paths = [ordered]@{
            docs = ".harness/docs"
            specs = ".harness/specs"
            changes = ".harness/changes"
            templates = ".harness/templates"
            generatedPrompts = ".harness/generated/prompts"
        }
        change = [ordered]@{
            naming = "CHG-{date}-{slug}"
            defaultCapability = "general"
            defaultFastMode = $true
        }
        artifacts = [ordered]@{
            includeReview = $true
            includeVerify = $true
            includeArchive = $true
            includeDeltaSpec = $true
        }
        validate = [ordered]@{
            failOnWarningsInStrict = $true
        }
        archive = [ordered]@{
            requireValidate = $true
            moveTo = ".harness/changes/archive"
        }
    }
}

function Get-HarnessConfig {
    param([string]$RootPath)

    $defaults = New-DefaultConfig
    $configPath = Join-Path $RootPath ".harness/config.yaml"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return $defaults
    }

    $loaded = Read-SimpleYaml -Path $configPath
    return (Merge-Hashtable -Base $defaults -Override $loaded)
}

function Resolve-ConfiguredPath {
    param(
        [string]$RootPath,
        [string]$ConfiguredPath
    )

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        return $ConfiguredPath
    }

    return Join-Path $RootPath $ConfiguredPath
}

function Get-HarnessPaths {
    param(
        [string]$RootPath,
        [hashtable]$Config
    )

    $docs = Resolve-ConfiguredPath -RootPath $RootPath -ConfiguredPath $Config.paths.docs
    $specs = Resolve-ConfiguredPath -RootPath $RootPath -ConfiguredPath $Config.paths.specs
    $changes = Resolve-ConfiguredPath -RootPath $RootPath -ConfiguredPath $Config.paths.changes
    $templates = Resolve-ConfiguredPath -RootPath $RootPath -ConfiguredPath $Config.paths.templates
    $generatedPrompts = Resolve-ConfiguredPath -RootPath $RootPath -ConfiguredPath $Config.paths.generatedPrompts
    $archiveRoot = Resolve-ConfiguredPath -RootPath $RootPath -ConfiguredPath $Config.archive.moveTo

    return [ordered]@{
        Root = $RootPath
        Harness = Join-Path $RootPath ".harness"
        Docs = $docs
        Specs = $specs
        Changes = $changes
        Archive = $archiveRoot
        Templates = $templates
        GeneratedPrompts = $generatedPrompts
    }
}

function Render-Template {
    param(
        [string]$Template,
        [hashtable]$Variables
    )

    $rendered = $Template
    foreach ($key in $Variables.Keys) {
        $token = '${' + $key + '}'
        $rendered = $rendered.Replace($token, [string]$Variables[$key])
    }

    return $rendered
}

function Get-InitTemplateMap {
    param(
        [string]$ProjectName,
        [string]$ToolName,
        [string]$Profile
    )

    $variables = @{
        PROJECT_NAME = $ProjectName
        TOOL_NAME = $ToolName
        PROFILE = $Profile
    }

    $map = [ordered]@{
        "AGENTS.md" = @'
# AI 工作入口

## 目标
本仓库使用 harness 方式管理 AI 协作，目标是让需求、设计、实现、评审、验证、归档形成闭环。

## 首次进入必须先读
1. `.harness/docs/project.md`
2. `.harness/docs/architecture.md`
3. `.harness/docs/conventions.md`
4. `.harness/docs/testing.md`
5. `.harness/docs/risk-boundaries.md`

## 标准流程
1. 先确认本次工作是否已有 change
2. 如果没有 change，先创建 change，再开始工作
3. 先写 proposal，明确目标、范围、风险
4. 再写 design，明确方案、影响、回滚
5. 再拆 tasks，确保任务可执行、可验收
6. 再实现
7. 实现后先 review，再 verify
8. 完成后 archive
9. 需要长期保留的知识，回写到 `.harness/docs`，而不是停留在 change 中

## 强约束
- 没有 change，不允许直接开发
- 不允许跳过 proposal 和 design 直接大改
- review 和 verify 必须分开
- 高风险目录和高风险操作必须遵守 `.harness/docs/risk-boundaries.md`
- 长期知识写入 `.harness/docs`
- 单次需求过程写入 `.harness/changes`

## 文档职责
- `AGENTS.md` 只负责导航和流程
- `.harness/docs` 负责长期知识
- `.harness/templates` 负责统一格式
- `.harness/changes` 负责单次变更记录
'@
        ".harness/docs/project.md" = @'
# 项目概览

## 项目名称
${PROJECT_NAME}

## 项目目标
- 这个项目解决什么问题
- 面向哪些用户
- 最核心的业务目标是什么

## 业务边界
- 本项目负责什么
- 本项目不负责什么
- 与外部系统的边界是什么
'@
        ".harness/docs/architecture.md" = @'
# 架构说明

## 总体结构
- 项目分为哪些层或模块
- 每层或每模块的职责是什么

## 关键数据流
1. 数据从哪里来
2. 经过哪些处理
3. 最终写到哪里或展示到哪里
'@
        ".harness/docs/conventions.md" = @'
# 通用规范

## 命名规范
- 目录命名规则
- 文件命名规则
- 变量命名规则
- 方法命名规则

## 提交规范
- commit 信息格式
- 一个提交应只做一类事情
- 禁止把无关改动混进同一个提交
'@
        ".harness/docs/testing.md" = @'
# 测试规范

## 必跑检查
- 构建检查
- 静态检查
- 单元测试
- 集成测试

## 验收标准
- 功能正确
- 没有明显回归
- 风险已说明
'@
        ".harness/docs/risk-boundaries.md" = @'
# 风险边界

## 高风险目录
- 配置目录
- 部署脚本目录
- 数据迁移目录
- 公共基础模块目录

## 高风险操作
- 批量删除
- 批量更新
- 修改核心配置
- 修改发布流程
'@
        ".harness/docs/tooling.md" = @'
# 工具接入说明

## 当前推荐工具
${TOOL_NAME}

## 当前接入档位
${PROFILE}

## 推荐命令
- `.\harness.ps1 init`
- `.\harness.ps1 new-change <name> -Fast`
- `.\harness.ps1 gen-apply-prompt <change-id>`
- `.\harness.ps1 validate`
- `.\harness.ps1 archive <change-id>`
'@
        ".harness/specs/README.md" = @'
# 当前规格说明

这个目录用于记录当前系统已经成立的长期事实。

建议只保留：

- 当前模块能力边界
- 当前接口契约
- 当前重要业务规则
- 当前稳定存在的数据约束
'@
        ".harness/templates/proposal.md" = @'
# 变更提案

## Change ID
`${CHANGE_ID}`

## 变更标题
${CHANGE_TITLE}

## 背景
本次变更为什么要做。

## 目标
本次要解决什么问题。

## 范围
本次明确会改什么。
'@
        ".harness/templates/design.md" = @'
# 设计方案

## Change ID
`${CHANGE_ID}`

## 核心思路
整体怎么做。

## 影响范围
- 影响模块
- 影响接口
- 影响数据

## 回滚方案
出问题时怎么退回。
'@
        ".harness/templates/tasks.md" = @'
# 任务拆分

## Change ID
`${CHANGE_ID}`

## 任务列表
- [ ] 任务 1
- [ ] 任务 2
- [ ] 任务 3

## 完成定义
每个任务完成的判定标准是什么。
'@
        ".harness/templates/review.md" = @'
# 评审记录

## Change ID
`${CHANGE_ID}`

## 评审范围
这次评审覆盖哪些内容。

## 风险结论
本次变更的总体风险级别是什么。

## 评审结论
- 通过
- 有条件通过
- 不通过
'@
        ".harness/templates/verify.md" = @'
# 验证结果

## Change ID
`${CHANGE_ID}`

## 执行的检查
- 构建
- 静态检查
- 自动化测试

## 结果
分别记录通过、失败、跳过。

## 最终结论
是否满足合入或发布条件。
'@
        ".harness/templates/archive.md" = @'
# 归档记录

## Change ID
`${CHANGE_ID}`

## 最终完成内容
这次实际完成了什么。

## 实际影响范围
最终改到了哪些模块、流程或对象。
'@
        ".harness/templates/delta-spec.md" = @'
# Capability Delta

## Change ID
`${CHANGE_ID}`

## Capability
${CAPABILITY}

## ADDED Requirements

### Requirement: 示例需求
系统 SHALL ...
'@
    }

    $renderedMap = [ordered]@{}
    foreach ($path in $map.Keys) {
        $renderedMap[$path] = Render-Template -Template $map[$path] -Variables $variables
    }

    return $renderedMap
}

function Get-ChangeTemplateMap {
    param(
        [string]$ChangeId,
        [string]$ChangeTitle,
        [string]$Capability
    )

    $variables = @{
        CHANGE_ID = $ChangeId
        CHANGE_TITLE = $ChangeTitle
        CAPABILITY = $Capability
    }

    $map = [ordered]@{
        "proposal.md" = @'
# 变更提案

## Change ID
`${CHANGE_ID}`

## 变更标题
${CHANGE_TITLE}

## 背景
本次变更为什么要做。

## 目标
本次要解决什么问题。

## 范围
本次明确会改什么。
'@
        "design.md" = @'
# 设计方案

## Change ID
`${CHANGE_ID}`

## 核心思路
整体怎么做。

## 影响范围
- 影响模块
- 影响接口
- 影响数据

## 回滚方案
出问题时怎么退回。
'@
        "tasks.md" = @'
# 任务拆分

## Change ID
`${CHANGE_ID}`

## 任务列表
- [ ] 任务 1
- [ ] 任务 2
- [ ] 任务 3

## 完成定义
每个任务完成的判定标准是什么。
'@
        "review.md" = @'
# 评审记录

## Change ID
`${CHANGE_ID}`

## 评审范围
这次评审覆盖哪些内容。

## 风险结论
本次变更的总体风险级别是什么。

## 评审结论
- 通过
- 有条件通过
- 不通过
'@
        "verify.md" = @'
# 验证结果

## Change ID
`${CHANGE_ID}`

## 执行的检查
- 构建
- 静态检查
- 自动化测试

## 结果
分别记录通过、失败、跳过。

## 最终结论
是否满足合入或发布条件。
'@
        "archive.md" = @'
# 归档记录

## Change ID
`${CHANGE_ID}`

## 最终完成内容
这次实际完成了什么。

## 实际影响范围
最终改到了哪些模块、流程或对象。
'@
        "spec.md" = @'
# Capability Delta

## Change ID
`${CHANGE_ID}`

## Capability
${CAPABILITY}

## ADDED Requirements

### Requirement: 示例需求
系统 SHALL ...
'@
    }

    $renderedMap = [ordered]@{}
    foreach ($path in $map.Keys) {
        $renderedMap[$path] = Render-Template -Template $map[$path] -Variables $variables
    }

    return $renderedMap
}

function Parse-CommandArguments {
    param(
        [string[]]$Arguments,
        [string[]]$Switches = @(),
        [string[]]$ValueOptions = @()
    )

    $switchMap = @{}
    foreach ($item in $Switches) {
        $switchMap[$item.ToLowerInvariant()] = $true
    }

    $valueMap = @{}
    foreach ($item in $ValueOptions) {
        $valueMap[$item.ToLowerInvariant()] = $true
    }

    $parsed = [ordered]@{
        Positionals = New-Object "System.Collections.Generic.List[string]"
        Switches = @{}
        Options = @{}
    }

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $token = $Arguments[$index]
        if ($token.StartsWith("-")) {
            $optionName = $token.TrimStart("-").ToLowerInvariant()
            if ($switchMap.ContainsKey($optionName)) {
                $parsed.Switches[$optionName] = $true
                continue
            }

            if ($valueMap.ContainsKey($optionName)) {
                if ($index + 1 -ge $Arguments.Count) {
                    throw ("参数 {0} 缺少值。" -f $token)
                }

                $value = $Arguments[$index + 1]
                if ($value.StartsWith("-")) {
                    throw ("参数 {0} 的值不能再是选项。" -f $token)
                }

                $parsed.Options[$optionName] = $value
                $index++
                continue
            }

            throw "未知参数：$token"
        }

        $parsed.Positionals.Add($token)
    }

    return $parsed
}

function Resolve-ChangeDirectory {
    param(
        [hashtable]$Paths,
        [string]$Subject,
        [switch]$IncludeArchived
    )

    if ([string]::IsNullOrWhiteSpace($Subject)) {
        throw "必须提供 change id 或 change slug。"
    }

    $candidatePaths = New-Object "System.Collections.Generic.List[string]"
    if (Test-Path -LiteralPath $Subject -PathType Container) {
        $candidatePaths.Add((Resolve-Path -LiteralPath $Subject).Path)
    }

    $activeDirectories = @()
    if (Test-Path -LiteralPath $Paths.Changes -PathType Container) {
        $activeDirectories = Get-ChildItem -LiteralPath $Paths.Changes -Directory | Where-Object { $_.Name -ne "archive" }
    }

    foreach ($directory in $activeDirectories) {
        if (($directory.Name -eq $Subject) -or $directory.Name.EndsWith("-$Subject")) {
            $candidatePaths.Add($directory.FullName)
        }
    }

    if ($IncludeArchived -and (Test-Path -LiteralPath $Paths.Archive -PathType Container)) {
        foreach ($directory in (Get-ChildItem -LiteralPath $Paths.Archive -Directory)) {
            if (($directory.Name -eq $Subject) -or $directory.Name.EndsWith("-$Subject")) {
                $candidatePaths.Add($directory.FullName)
            }
        }
    }

    $distinct = @($candidatePaths | Select-Object -Unique)
    if ($distinct.Count -eq 0) {
        throw "未找到 change：$Subject"
    }

    if ($distinct.Count -gt 1) {
        throw "找到多个匹配的 change，请使用完整 change id。"
    }

    return $distinct[0]
}

function Read-ChangeMetadata {
    param([string]$ChangeDirectory)
    return (Read-SimpleYaml -Path (Join-Path $ChangeDirectory ".change.yaml"))
}

function Write-ChangeMetadata {
    param(
        [string]$ChangeDirectory,
        [hashtable]$Metadata
    )

    Write-Utf8File -Path (Join-Path $ChangeDirectory ".change.yaml") -Content (ConvertTo-SimpleYaml -Data $Metadata)
}

function New-ChangeMetadata {
    param(
        [string]$ChangeId,
        [string]$Slug,
        [string]$Title,
        [string]$Capability,
        [bool]$FastMode
    )

    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    return [ordered]@{
        id = $ChangeId
        slug = $Slug
        title = $Title
        status = "draft"
        createdAt = $now
        updatedAt = $now
        capability = $Capability
        mode = $(if ($FastMode) { "fast" } else { "guided" })
        reviewStatus = "pending"
        verifyStatus = "pending"
        archivedAt = ""
    }
}

function Add-ValidationIssue {
    param(
        [System.Collections.ArrayList]$Issues,
        [string]$Severity,
        [string]$Code,
        [string]$Path,
        [string]$Message
    )

    [void]$Issues.Add([pscustomobject]@{
        severity = $Severity
        code = $Code
        path = $Path
        message = $Message
    })
}

function Test-Headings {
    param(
        [string]$Content,
        [string[]]$Headings
    )

    foreach ($heading in $Headings) {
        if ($Content -notmatch [regex]::Escape($heading)) {
            return $false
        }
    }

    return $true
}

function Test-Placeholders {
    param(
        [string]$Content,
        [string[]]$Placeholders
    )

    foreach ($placeholder in $Placeholders) {
        if ($Content.Contains($placeholder)) {
            return $true
        }
    }

    return $false
}

function Invoke-ValidateHarness {
    param(
        [string]$RootPath,
        [string]$Subject,
        [bool]$StrictMode
    )

    $issues = New-Object System.Collections.ArrayList
    $config = Get-HarnessConfig -RootPath $RootPath
    $paths = Get-HarnessPaths -RootPath $RootPath -Config $config

    foreach ($filePath in @(
        (Join-Path $RootPath "AGENTS.md"),
        (Join-Path $paths.Harness "config.yaml"),
        (Join-Path $paths.Specs "README.md")
    )) {
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            Add-ValidationIssue -Issues $issues -Severity "error" -Code "missing_file" -Path $filePath -Message "缺少必需文件。"
        }
    }

    foreach ($docFile in $script:RequiredDocs) {
        $docPath = Join-Path $paths.Docs $docFile
        if (-not (Test-Path -LiteralPath $docPath -PathType Leaf)) {
            Add-ValidationIssue -Issues $issues -Severity "error" -Code "missing_doc" -Path $docPath -Message "缺少必需文档。"
        }
    }

    foreach ($templateFile in $script:RequiredTemplates) {
        $templatePath = Join-Path $paths.Templates $templateFile
        if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
            Add-ValidationIssue -Issues $issues -Severity "error" -Code "missing_template" -Path $templatePath -Message "缺少必需模板。"
        }
    }

    if (-not (Test-Path -LiteralPath $paths.Archive -PathType Container)) {
        Add-ValidationIssue -Issues $issues -Severity "error" -Code "missing_archive_dir" -Path $paths.Archive -Message "缺少归档目录。"
    }

    $changeDirectories = @()
    if ([string]::IsNullOrWhiteSpace($Subject)) {
        if (Test-Path -LiteralPath $paths.Changes -PathType Container) {
            $changeDirectories = Get-ChildItem -LiteralPath $paths.Changes -Directory | Where-Object { $_.Name -ne "archive" } | Select-Object -ExpandProperty FullName
        }
    }
    else {
        $changeDirectories = @((Resolve-ChangeDirectory -Paths $paths -Subject $Subject))
    }

    foreach ($changeDirectory in $changeDirectories) {
        $changeName = Split-Path -Leaf $changeDirectory
        if ($changeName -notmatch "^CHG-\d{8}-.+$") {
            Add-ValidationIssue -Issues $issues -Severity "error" -Code "invalid_change_name" -Path $changeDirectory -Message "change 目录命名不符合规范。"
        }

        $metadataPath = Join-Path $changeDirectory ".change.yaml"
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            Add-ValidationIssue -Issues $issues -Severity "error" -Code "missing_metadata" -Path $metadataPath -Message "缺少 .change.yaml。"
            continue
        }

        $metadata = Read-ChangeMetadata -ChangeDirectory $changeDirectory
        foreach ($requiredMetadataKey in @("id", "slug", "title", "status", "capability", "mode")) {
            if (-not $metadata.Contains($requiredMetadataKey)) {
                Add-ValidationIssue -Issues $issues -Severity "error" -Code "metadata_missing_key" -Path $metadataPath -Message "元数据缺少字段：$requiredMetadataKey"
            }
        }

        foreach ($artifactName in @("proposal.md", "design.md", "tasks.md", "review.md", "verify.md", "archive.md")) {
            $artifactPath = Join-Path $changeDirectory $artifactName
            if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
                Add-ValidationIssue -Issues $issues -Severity "error" -Code "missing_artifact" -Path $artifactPath -Message "缺少变更工件：$artifactName"
                continue
            }

            $artifactContent = Get-Content -LiteralPath $artifactPath -Raw
            $rule = $script:ArtifactRules[$artifactName]
            if ($null -ne $rule) {
                if (-not (Test-Headings -Content $artifactContent -Headings $rule.Headings)) {
                    Add-ValidationIssue -Issues $issues -Severity "error" -Code "heading_missing" -Path $artifactPath -Message "文档缺少必需标题。"
                }

                if (Test-Placeholders -Content $artifactContent -Placeholders $rule.Placeholders) {
                    $severity = $(if ($StrictMode) { "error" } else { "warning" })
                    Add-ValidationIssue -Issues $issues -Severity $severity -Code "placeholder_left" -Path $artifactPath -Message "文档仍保留模板占位文本。"
                }
            }

            if ($artifactName -eq "tasks.md" -and $artifactContent -notmatch "(?m)^- \[[ xX]\]") {
                Add-ValidationIssue -Issues $issues -Severity "error" -Code "tasks_empty" -Path $artifactPath -Message "tasks.md 至少要有一个复选任务。"
            }
        }

        $capability = if ($metadata.Contains("capability")) { [string]$metadata.capability } else { "general" }
        $deltaSpecPath = Join-Path $changeDirectory "specs/$capability/spec.md"
        if (-not (Test-Path -LiteralPath $deltaSpecPath -PathType Leaf)) {
            Add-ValidationIssue -Issues $issues -Severity "warning" -Code "missing_delta_spec" -Path $deltaSpecPath -Message "缺少当前 capability 对应的 delta spec。"
        }
    }

    $errorCount = @($issues | Where-Object { $_.severity -eq "error" }).Count
    $warningCount = @($issues | Where-Object { $_.severity -eq "warning" }).Count

    return [pscustomobject]@{
        checkedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        root = $RootPath
        subject = $(if ([string]::IsNullOrWhiteSpace($Subject)) { "all" } else { $Subject })
        strict = $StrictMode
        valid = ($errorCount -eq 0 -and (-not $StrictMode -or $warningCount -eq 0))
        errorCount = $errorCount
        warningCount = $warningCount
        issues = @($issues)
    }
}

function Show-ValidationResult {
    param(
        [pscustomobject]$Result,
        [bool]$AsJson
    )

    if ($AsJson) {
        $Result | ConvertTo-Json -Depth 6
        return
    }

    Write-Info "校验目标：$($Result.subject)"
    Write-Info "错误数：$($Result.errorCount)；警告数：$($Result.warningCount)"

    if ($Result.issues.Count -eq 0) {
        Write-Success "校验通过，没有发现问题。"
        return
    }

    foreach ($issue in $Result.issues) {
        $prefix = if ($issue.severity -eq "error") { "[ERROR]" } else { "[WARN] " }
        Write-Host "$prefix $($issue.message) [$($issue.code)] -> $($issue.path)"
    }
}

function Get-TaskChecklistStats {
    param([string]$TasksFile)

    if (-not (Test-Path -LiteralPath $TasksFile -PathType Leaf)) {
        return [ordered]@{
            total = 0
            completed = 0
            pending = 0
        }
    }

    $content = Get-Content -LiteralPath $TasksFile -Raw
    $taskMatches = [regex]::Matches($content, '(?m)^- \[(?<state>[ xX])\]')
    $completed = 0
    foreach ($match in $taskMatches) {
        if ($match.Groups["state"].Value -match '[xX]') {
            $completed++
        }
    }

    return [ordered]@{
        total = $taskMatches.Count
        completed = $completed
        pending = ($taskMatches.Count - $completed)
    }
}

function Get-ChangeArtifactStatus {
    param(
        [string]$ChangeDirectory,
        [string]$Capability
    )

    $artifacts = [ordered]@{}
    foreach ($artifactName in @("proposal.md", "design.md", "tasks.md", "review.md", "verify.md", "archive.md")) {
        $artifacts[$artifactName] = (Test-Path -LiteralPath (Join-Path $ChangeDirectory $artifactName) -PathType Leaf)
    }

    $artifacts["specs/$Capability/spec.md"] = (Test-Path -LiteralPath (Join-Path $ChangeDirectory "specs/$Capability/spec.md") -PathType Leaf)
    return $artifacts
}

function Get-ChangeStatusReport {
    param(
        [string]$RootPath,
        [hashtable]$Paths,
        [string]$ChangeDirectory
    )

    $metadata = Read-ChangeMetadata -ChangeDirectory $ChangeDirectory
    $changeId = if ($metadata.Contains("id")) { [string]$metadata.id } else { (Split-Path -Leaf $ChangeDirectory) }
    $capability = if ($metadata.Contains("capability")) { [string]$metadata.capability } else { "general" }
    $validation = Invoke-ValidateHarness -RootPath $RootPath -Subject $ChangeDirectory -StrictMode $true
    $taskStats = Get-TaskChecklistStats -TasksFile (Join-Path $ChangeDirectory "tasks.md")
    $artifactStatus = Get-ChangeArtifactStatus -ChangeDirectory $ChangeDirectory -Capability $capability

    $blockers = New-Object System.Collections.Generic.List[string]
    $lifecycleStatus = if ($metadata.Contains("status")) { [string]$metadata.status } else { "unknown" }
    $reviewStatus = if ($metadata.Contains("reviewStatus")) { [string]$metadata.reviewStatus } else { "unknown" }
    $verifyStatus = if ($metadata.Contains("verifyStatus")) { [string]$metadata.verifyStatus } else { "unknown" }

    if ($lifecycleStatus -ne "active") {
        $blockers.Add(("status 不是 active，而是 {0}" -f $lifecycleStatus))
    }
    if ($reviewStatus -ne "passed") {
        $blockers.Add(("reviewStatus 不是 passed，而是 {0}" -f $reviewStatus))
    }
    if ($verifyStatus -ne "passed") {
        $blockers.Add(("verifyStatus 不是 passed，而是 {0}" -f $verifyStatus))
    }
    if ($taskStats.pending -gt 0) {
        $blockers.Add(("tasks.md 仍有 {0} 个未完成任务" -f $taskStats.pending))
    }
    if (-not $validation.valid) {
        $blockers.Add(("严格校验未通过（错误 {0}，警告 {1}）" -f $validation.errorCount, $validation.warningCount))
    }

    return [pscustomobject]@{
        id = $changeId
        title = if ($metadata.Contains("title")) { [string]$metadata.title } else { $changeId }
        path = $ChangeDirectory
        capability = $capability
        mode = if ($metadata.Contains("mode")) { [string]$metadata.mode } else { "" }
        status = $lifecycleStatus
        reviewStatus = $reviewStatus
        verifyStatus = $verifyStatus
        createdAt = if ($metadata.Contains("createdAt")) { [string]$metadata.createdAt } else { "" }
        updatedAt = if ($metadata.Contains("updatedAt")) { [string]$metadata.updatedAt } else { "" }
        archivedAt = if ($metadata.Contains("archivedAt")) { [string]$metadata.archivedAt } else { "" }
        taskStats = [pscustomobject]$taskStats
        artifacts = [pscustomobject]$artifactStatus
        strictValidation = [pscustomobject]@{
            valid = $validation.valid
            errorCount = $validation.errorCount
            warningCount = $validation.warningCount
            issues = @($validation.issues)
        }
        canArchive = ($blockers.Count -eq 0)
        blockers = @($blockers)
    }
}

function Show-StatusReport {
    param(
        [object[]]$Reports,
        [bool]$AsJson
    )

    $reportList = @($Reports)
    if ($AsJson) {
        if ($reportList.Count -eq 1) {
            $reportList[0] | ConvertTo-Json -Depth 6
        }
        else {
            $reportList | ConvertTo-Json -Depth 6
        }
        return
    }

    if ($reportList.Count -eq 0) {
        Write-Info "当前没有可展示的 change。"
        return
    }

    if ($reportList.Count -eq 1) {
        $report = $reportList[0]
        Write-Info "change：$($report.id)"
        Write-Host "标题：$($report.title)"
        Write-Host "路径：$($report.path)"
        Write-Host "状态：$($report.status)；review：$($report.reviewStatus)；verify：$($report.verifyStatus)；mode：$($report.mode)"
        Write-Host "任务：$($report.taskStats.completed)/$($report.taskStats.total) 已完成"
        Write-Host "严格校验：$(if ($report.strictValidation.valid) { '通过' } else { '未通过' })；错误：$($report.strictValidation.errorCount)；警告：$($report.strictValidation.warningCount)"
        Write-Host "可归档：$(if ($report.canArchive) { '是' } else { '否' })"
        Write-Host "工件：proposal=$($report.artifacts.'proposal.md') design=$($report.artifacts.'design.md') tasks=$($report.artifacts.'tasks.md') review=$($report.artifacts.'review.md') verify=$($report.artifacts.'verify.md') archive=$($report.artifacts.'archive.md') spec=$($report.artifacts.('specs/' + $report.capability + '/spec.md'))"
        if ($report.blockers.Count -gt 0) {
            Write-Host "阻塞项："
            foreach ($blocker in $report.blockers) {
                Write-Host "- $blocker"
            }
        }
        return
    }

    Write-Info "active changes：$($reportList.Count)"
    foreach ($report in $reportList) {
        $label = if ($report.canArchive) { "[READY]" } else { "[HOLD ]" }
        Write-Host ("{0} {1} | status={2} | review={3} | verify={4} | tasks={5}/{6} | strict={7}" -f `
            $label,
            $report.id,
            $report.status,
            $report.reviewStatus,
            $report.verifyStatus,
            $report.taskStats.completed,
            $report.taskStats.total,
            $(if ($report.strictValidation.valid) { "ok" } else { "fail" }))
    }
}

function Show-Help {
    param([string]$Topic)

    $normalizedTopic = if ([string]::IsNullOrWhiteSpace($Topic)) { "help" } else { $Topic.ToLowerInvariant() }
    switch ($normalizedTopic) {
        "init" {
            @'
用法：
  .\harness.ps1 init [-Tool codex|claude|cursor|none] [-Profile core|expanded] [-Force]
'@ | Write-Host
        }
        "new-change" {
            @'
用法：
  .\harness.ps1 new-change <name> [-Title <title>] [-Capability <capability>] [-Fast] [-Force]
'@ | Write-Host
        }
        "gen-apply-prompt" {
            @'
用法：
  .\harness.ps1 gen-apply-prompt <change-id-or-slug> [-OutFile <path>] [-Force]
'@ | Write-Host
        }
        "gen-review-prompt" {
            @'
用法：
  .\harness.ps1 gen-review-prompt <change-id-or-slug> [-OutFile <path>] [-Force]
'@ | Write-Host
        }
        "gen-verify-prompt" {
            @'
用法：
  .\harness.ps1 gen-verify-prompt <change-id-or-slug> [-OutFile <path>] [-Force]
'@ | Write-Host
        }
        "status" {
            @'
用法：
  .\harness.ps1 status [change-id-or-slug] [-Json]
'@ | Write-Host
        }
        "validate" {
            @'
用法：
  .\harness.ps1 validate [change-id-or-slug] [-Strict] [-Json]
'@ | Write-Host
        }
        "archive" {
            @'
用法：
  .\harness.ps1 archive <change-id-or-slug> [-Force] [-SkipValidate]
'@ | Write-Host
        }
        default {
            @'
Harness CLI

可用命令：
  init
  new-change
  gen-apply-prompt
  gen-review-prompt
  gen-verify-prompt
  status
  validate
  archive
  help

示例：
  .\harness.ps1 init -Tool codex
  .\harness.ps1 new-change login-refactor -Title 登录流程重构 -Capability auth -Fast
  .\harness.ps1 gen-apply-prompt CHG-20260413-login-refactor
  .\harness.ps1 gen-review-prompt CHG-20260413-login-refactor
  .\harness.ps1 gen-verify-prompt CHG-20260413-login-refactor
  .\harness.ps1 status CHG-20260413-login-refactor
  .\harness.ps1 validate -Strict
  .\harness.ps1 archive CHG-20260413-login-refactor
'@ | Write-Host
        }
    }
}

function Invoke-InitCommand {
    param([string[]]$Arguments)

    $parsed = Parse-CommandArguments -Arguments $Arguments -Switches @("force") -ValueOptions @("tool", "profile")
    $toolName = if ($parsed.Options.ContainsKey("tool")) { $parsed.Options["tool"] } else { "codex" }
    $profile = if ($parsed.Options.ContainsKey("profile")) { $parsed.Options["profile"] } else { "core" }
    $force = $parsed.Switches.ContainsKey("force")

    if ($toolName -notin @("codex", "claude", "cursor", "none")) {
        throw "不支持的工具类型：$toolName"
    }

    if ($profile -notin @("core", "expanded")) {
        throw "不支持的 profile：$profile"
    }

    $rootPath = Get-ProjectRoot
    $projectName = Get-ProjectName -RootPath $rootPath
    $summary = New-WriteSummary
    $config = New-DefaultConfig -ToolName $toolName -Profile $profile
    $paths = Get-HarnessPaths -RootPath $rootPath -Config $config

    foreach ($directoryPath in @(
        $paths.Harness,
        $paths.Docs,
        $paths.Specs,
        $paths.Changes,
        $paths.Archive,
        $paths.Templates,
        (Split-Path -Parent $paths.GeneratedPrompts),
        $paths.GeneratedPrompts
    )) {
        Ensure-Directory -Path $directoryPath -Summary $summary
    }

    $templateMap = Get-InitTemplateMap -ProjectName $projectName -ToolName $toolName -Profile $profile
    foreach ($relativePath in $templateMap.Keys) {
        $targetPath = Join-Path $rootPath $relativePath
        Set-ManagedFile -Path $targetPath -Content $templateMap[$relativePath] -Force $force -Summary $summary
    }

    Set-ManagedFile -Path (Join-Path $paths.Harness "config.yaml") -Content (ConvertTo-SimpleYaml -Data $config) -Force $force -Summary $summary

    Write-Success "harness 初始化完成。"
    Write-Info "目录创建：$($summary.DirectoriesCreated.Count)；文件创建：$($summary.Created.Count)；文件更新：$($summary.Updated.Count)；文件跳过：$($summary.Skipped.Count)"
    Write-Info "下一步建议：.\harness.ps1 new-change <name> -Fast"
}

function Invoke-NewChangeCommand {
    param([string[]]$Arguments)

    $parsed = Parse-CommandArguments -Arguments $Arguments -Switches @("fast", "force") -ValueOptions @("title", "capability")
    if ($parsed.Positionals.Count -lt 1) {
        throw "new-change 必须提供名称。"
    }

    $rawName = $parsed.Positionals[0]
    $title = if ($parsed.Options.ContainsKey("title")) { $parsed.Options["title"] } else { $null }
    $capability = if ($parsed.Options.ContainsKey("capability")) { $parsed.Options["capability"] } else { $null }
    $force = $parsed.Switches.ContainsKey("force")

    $rootPath = Get-ProjectRoot
    $config = Get-HarnessConfig -RootPath $rootPath
    $paths = Get-HarnessPaths -RootPath $rootPath -Config $config
    if (-not (Test-Path -LiteralPath $paths.Harness -PathType Container)) {
        throw "当前目录尚未初始化 harness，请先执行 .\harness.ps1 init"
    }

    $slug = ConvertTo-Slug -Value $rawName
    $displayTitle = Format-Title -RawName $rawName -ExplicitTitle $title
    $resolvedCapability = if (-not [string]::IsNullOrWhiteSpace($capability)) { $capability } else { [string]$config.change.defaultCapability }
    $fastMode = if ($parsed.Switches.ContainsKey("fast")) { $true } else { [bool]$config.change.defaultFastMode }
    $changeId = Format-ChangeId -NamingRule ([string]$config.change.naming) -Slug $slug
    $changeDirectory = Join-Path $paths.Changes $changeId

    if ((Test-Path -LiteralPath $changeDirectory -PathType Container) -and -not $force) {
        throw "change 已存在：$changeId"
    }

    $summary = New-WriteSummary
    Ensure-Directory -Path $changeDirectory -Summary $summary
    Ensure-Directory -Path (Join-Path $changeDirectory "specs") -Summary $summary
    Ensure-Directory -Path (Join-Path $changeDirectory "specs/$resolvedCapability") -Summary $summary

    $metadata = New-ChangeMetadata -ChangeId $changeId -Slug $slug -Title $displayTitle -Capability $resolvedCapability -FastMode $fastMode
    Set-ManagedFile -Path (Join-Path $changeDirectory ".change.yaml") -Content (ConvertTo-SimpleYaml -Data $metadata) -Force $force -Summary $summary

    $templateMap = Get-ChangeTemplateMap -ChangeId $changeId -ChangeTitle $displayTitle -Capability $resolvedCapability
    foreach ($fileName in @("proposal.md", "design.md", "tasks.md", "review.md", "verify.md", "archive.md")) {
        Set-ManagedFile -Path (Join-Path $changeDirectory $fileName) -Content $templateMap[$fileName] -Force $force -Summary $summary
    }

    Set-ManagedFile -Path (Join-Path $changeDirectory "specs/$resolvedCapability/spec.md") -Content $templateMap["spec.md"] -Force $force -Summary $summary

    Write-Success "change 创建完成：$changeId"
    Write-Info "change 目录：$changeDirectory"
    Write-Info "下一步建议：.\harness.ps1 gen-apply-prompt $changeId"
}

function Append-FileSection {
    param(
        [System.Text.StringBuilder]$Builder,
        [string]$Title,
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw
    [void]$Builder.AppendLine("## $Title")
    [void]$Builder.AppendLine("路径：$Path")
    [void]$Builder.AppendLine('```md')
    [void]$Builder.AppendLine($content.TrimEnd())
    [void]$Builder.AppendLine('```')
    [void]$Builder.AppendLine()
}

function Append-HarnessContextSections {
    param(
        [System.Text.StringBuilder]$Builder,
        [string]$RootPath,
        [hashtable]$Paths
    )

    Append-FileSection -Builder $Builder -Title "全局入口规则" -Path (Join-Path $RootPath "AGENTS.md")
    foreach ($docFile in $script:RequiredDocs) {
        Append-FileSection -Builder $Builder -Title "长期知识：$docFile" -Path (Join-Path $Paths.Docs $docFile)
    }
}

function Append-ChangeContextSections {
    param(
        [System.Text.StringBuilder]$Builder,
        [string]$ChangeDirectory,
        [string]$Capability
    )

    foreach ($artifactPath in @(
        (Join-Path $ChangeDirectory ".change.yaml"),
        (Join-Path $ChangeDirectory "proposal.md"),
        (Join-Path $ChangeDirectory "design.md"),
        (Join-Path $ChangeDirectory "tasks.md"),
        (Join-Path $ChangeDirectory "review.md"),
        (Join-Path $ChangeDirectory "verify.md"),
        (Join-Path $ChangeDirectory "archive.md")
    )) {
        Append-FileSection -Builder $Builder -Title "变更工件：$(Split-Path -Leaf $artifactPath)" -Path $artifactPath
    }

    Append-FileSection -Builder $Builder -Title "Delta Spec：$Capability" -Path (Join-Path $ChangeDirectory "specs/$Capability/spec.md")
}

# 不同阶段的 prompt 共享同一套上下文拼接，只在目标文案和输出文件名前缀上做差异化。
function Get-PromptCommandSpec {
    param(
        [ValidateSet("apply", "review", "verify")]
        [string]$PromptKind
    )

    switch ($PromptKind) {
        "apply" {
            return [ordered]@{
                CommandName = "gen-apply-prompt"
                Title = "Harness Apply Prompt"
                OutputPrefix = "apply"
                SuccessMessage = "执行提示已生成"
                GoalTemplate = '你现在要执行 change `{0}`。请优先遵守根目录 `AGENTS.md` 和 `.harness/docs` 中的长期规则，只在本次变更范围内实现代码。'
                Requirements = @(
                    "先理解 proposal、design、tasks，再动代码"
                    "如果 proposal / design / tasks 不一致，先回写工件，再继续实现"
                    "严格遵守 risk-boundaries，不要擅自扩大影响范围"
                    "review 和 verify 是独立动作，不要把它们混成同一步"
                    "完成后明确列出改动范围、验证方式和风险说明"
                )
            }
        }
        "review" {
            return [ordered]@{
                CommandName = "gen-review-prompt"
                Title = "Harness Review Prompt"
                OutputPrefix = "review"
                SuccessMessage = "评审提示已生成"
                GoalTemplate = '你现在要评审 change `{0}` 对应的实现结果。请以缺陷、回归风险、边界遗漏和测试缺口为核心输出，不要写泛泛而谈的总结。'
                Requirements = @(
                    "先理解 proposal、design、tasks、review，再看实现代码"
                    "以具体 findings 为主，优先标出文件、行号和风险点"
                    "重点检查行为回归、边界条件、异常处理、兼容性和遗漏测试"
                    "如果证据不足，明确说明假设、未查看范围和未验证项"
                    "不要把 verify 结果混入 review 结论"
                )
            }
        }
        "verify" {
            return [ordered]@{
                CommandName = "gen-verify-prompt"
                Title = "Harness Verify Prompt"
                OutputPrefix = "verify"
                SuccessMessage = "验证提示已生成"
                GoalTemplate = '你现在要验证 change `{0}` 是否满足 proposal、design、tasks 和 review 中定义的完成条件，并明确记录通过、失败、跳过和未覆盖项。'
                Requirements = @(
                    "先对照 proposal、design、tasks、review，再决定验证范围"
                    "优先执行最小必要命令，记录命令、结果和未覆盖项"
                    "结果必须区分通过、失败、跳过，不要写模糊结论"
                    "如果存在高风险未验证内容，明确标记并说明原因"
                    "不要在 verify 阶段悄悄改需求或扩大实现范围"
                )
            }
        }
    }
}

function Invoke-GeneratePromptCommand {
    param(
        [string]$PromptKind,
        [string[]]$Arguments
    )

    $promptSpec = Get-PromptCommandSpec -PromptKind $PromptKind
    $parsed = Parse-CommandArguments -Arguments $Arguments -Switches @("force") -ValueOptions @("outfile")
    if ($parsed.Positionals.Count -lt 1) {
        throw ("{0} 必须提供 change id 或 slug。" -f $promptSpec.CommandName)
    }

    $subject = $parsed.Positionals[0]
    $force = $parsed.Switches.ContainsKey("force")
    $rootPath = Get-ProjectRoot
    $config = Get-HarnessConfig -RootPath $rootPath
    $paths = Get-HarnessPaths -RootPath $rootPath -Config $config
    $changeDirectory = Resolve-ChangeDirectory -Paths $paths -Subject $subject
    $metadata = Read-ChangeMetadata -ChangeDirectory $changeDirectory
    $changeId = [string]$metadata.id
    $capability = if ($metadata.Contains("capability")) { [string]$metadata.capability } else { "general" }

    $promptPath = if ($parsed.Options.ContainsKey("outfile")) {
        Resolve-ConfiguredPath -RootPath $rootPath -ConfiguredPath $parsed.Options["outfile"]
    }
    else {
        Join-Path $paths.GeneratedPrompts ("{0}-{1}.md" -f $promptSpec.OutputPrefix, $changeId)
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine("# $($promptSpec.Title)")
    [void]$builder.AppendLine()
    [void]$builder.AppendLine("## 执行目标")
    [void]$builder.AppendLine(($promptSpec.GoalTemplate -f $changeId))
    [void]$builder.AppendLine()
    [void]$builder.AppendLine("## 执行要求")
    foreach ($requirement in $promptSpec.Requirements) {
        [void]$builder.AppendLine("- $requirement")
    }
    [void]$builder.AppendLine()

    Append-HarnessContextSections -Builder $builder -RootPath $rootPath -Paths $paths
    Append-ChangeContextSections -Builder $builder -ChangeDirectory $changeDirectory -Capability $capability

    Set-ManagedFile -Path $promptPath -Content $builder.ToString() -Force $force -Summary (New-WriteSummary)
    Write-Success ("{0}：{1}" -f $promptSpec.SuccessMessage, $promptPath)
}

function Invoke-ValidateCommand {
    param([string[]]$Arguments)

    $parsed = Parse-CommandArguments -Arguments $Arguments -Switches @("strict", "json") -ValueOptions @()
    $subject = if ($parsed.Positionals.Count -gt 0) { $parsed.Positionals[0] } else { $null }
    $strictMode = $parsed.Switches.ContainsKey("strict")
    $asJson = $parsed.Switches.ContainsKey("json")

    $result = Invoke-ValidateHarness -RootPath (Get-ProjectRoot) -Subject $subject -StrictMode $strictMode
    Show-ValidationResult -Result $result -AsJson $asJson

    if (-not $result.valid) {
        exit 1
    }
}

function Invoke-StatusCommand {
    param([string[]]$Arguments)

    $parsed = Parse-CommandArguments -Arguments $Arguments -Switches @("json") -ValueOptions @()
    $subject = if ($parsed.Positionals.Count -gt 0) { $parsed.Positionals[0] } else { $null }
    $asJson = $parsed.Switches.ContainsKey("json")

    $rootPath = Get-ProjectRoot
    $config = Get-HarnessConfig -RootPath $rootPath
    $paths = Get-HarnessPaths -RootPath $rootPath -Config $config

    $changeDirectories = @()
    if ([string]::IsNullOrWhiteSpace($subject)) {
        if (Test-Path -LiteralPath $paths.Changes -PathType Container) {
            $changeDirectories = @(Get-ChildItem -LiteralPath $paths.Changes -Directory | Where-Object { $_.Name -ne "archive" } | Select-Object -ExpandProperty FullName)
        }
    }
    else {
        $changeDirectories = @((Resolve-ChangeDirectory -Paths $paths -Subject $subject -IncludeArchived:$true))
    }

    $reports = @()
    foreach ($changeDirectory in $changeDirectories) {
        $reports += Get-ChangeStatusReport -RootPath $rootPath -Paths $paths -ChangeDirectory $changeDirectory
    }

    Show-StatusReport -Reports $reports -AsJson $asJson
}

function Ensure-ArchiveStamp {
    param(
        [string]$ArchiveFile,
        [hashtable]$Metadata
    )

    $content = if (Test-Path -LiteralPath $ArchiveFile -PathType Leaf) {
        Get-Content -LiteralPath $ArchiveFile -Raw
    }
    else {
        "# 归档记录`r`n"
    }

    if ($content -notmatch "## 归档时间") {
        $content = $content.TrimEnd() + "`r`n`r`n## 归档时间`r`n$($Metadata.archivedAt)`r`n`r`n## 归档状态`r`n- status: $($Metadata.status)`r`n- reviewStatus: $($Metadata.reviewStatus)`r`n- verifyStatus: $($Metadata.verifyStatus)`r`n"
        Write-Utf8File -Path $ArchiveFile -Content $content
    }
}

function Invoke-ArchiveCommand {
    param([string[]]$Arguments)

    $parsed = Parse-CommandArguments -Arguments $Arguments -Switches @("force", "skipvalidate") -ValueOptions @()
    if ($parsed.Positionals.Count -lt 1) {
        throw "archive 必须提供 change id 或 slug。"
    }

    $subject = $parsed.Positionals[0]
    $force = $parsed.Switches.ContainsKey("force")
    $skipValidate = $parsed.Switches.ContainsKey("skipvalidate")

    $rootPath = Get-ProjectRoot
    $config = Get-HarnessConfig -RootPath $rootPath
    $paths = Get-HarnessPaths -RootPath $rootPath -Config $config
    $changeDirectory = Resolve-ChangeDirectory -Paths $paths -Subject $subject

    if ($changeDirectory.StartsWith($paths.Archive, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "目标 change 已经位于 archive 目录，无需重复归档。"
    }

    if (-not $skipValidate) {
        $validation = Invoke-ValidateHarness -RootPath $rootPath -Subject $subject -StrictMode $true
        if (-not $validation.valid -and -not $force) {
            Show-ValidationResult -Result $validation -AsJson $false
            throw "严格校验未通过，归档已中止。可先修复问题，或显式传入 -Force。"
        }
    }

    $metadata = Read-ChangeMetadata -ChangeDirectory $changeDirectory
    $metadata.status = "archived"
    $metadata.updatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $metadata.archivedAt = $metadata.updatedAt

    $targetLeaf = Split-Path -Leaf $changeDirectory
    $targetPath = Join-Path $paths.Archive $targetLeaf
    if (Test-Path -LiteralPath $targetPath) {
        $targetPath = Join-Path $paths.Archive ("{0}-{1}" -f $targetLeaf, (Get-Date -Format "yyyyMMddHHmmss"))
    }

    Ensure-Directory -Path $paths.Archive -Summary $null
    Move-Item -LiteralPath $changeDirectory -Destination $targetPath
    Write-ChangeMetadata -ChangeDirectory $targetPath -Metadata $metadata
    Ensure-ArchiveStamp -ArchiveFile (Join-Path $targetPath "archive.md") -Metadata $metadata

    Write-Success "归档完成：$targetPath"
}

try {
    switch ($Command.ToLowerInvariant()) {
        "help" { Show-Help -Topic $(if ($CommandArguments.Count -gt 0) { $CommandArguments[0] } else { $null }) }
        "init" { Invoke-InitCommand -Arguments $CommandArguments }
        "new-change" { Invoke-NewChangeCommand -Arguments $CommandArguments }
        "gen-apply-prompt" { Invoke-GeneratePromptCommand -PromptKind "apply" -Arguments $CommandArguments }
        "gen-review-prompt" { Invoke-GeneratePromptCommand -PromptKind "review" -Arguments $CommandArguments }
        "gen-verify-prompt" { Invoke-GeneratePromptCommand -PromptKind "verify" -Arguments $CommandArguments }
        "status" { Invoke-StatusCommand -Arguments $CommandArguments }
        "validate" { Invoke-ValidateCommand -Arguments $CommandArguments }
        "archive" { Invoke-ArchiveCommand -Arguments $CommandArguments }
        default { throw "未知命令：$Command" }
    }
}
catch {
    Stop-Script -Message $_.Exception.Message -Code 1
}
