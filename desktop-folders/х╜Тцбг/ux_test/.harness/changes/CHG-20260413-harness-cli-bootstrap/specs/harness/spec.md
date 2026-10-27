# Capability Delta

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## Capability
harness

## ADDED Requirements

### Requirement: Bootstrap Harness Structure
系统 SHALL 在任意项目根目录通过 `init` 创建 `.harness` 必需结构，并在未显式传入 `-Force` 时跳过已有文件。

### Requirement: Create Change Workspace
系统 SHALL 通过 `new-change` 创建符合 `CHG-YYYYMMDD-slug` 规则的 change 目录、元数据和标准工件。

### Requirement: Generate Apply Prompt
系统 SHALL 通过 `gen-apply-prompt` 聚合 `AGENTS.md`、`.harness/docs` 和当前 change 工件，生成可直接交给 AI 使用的执行提示。

### Requirement: Generate Review Prompt
系统 SHALL 通过 `gen-review-prompt` 聚合 `AGENTS.md`、`.harness/docs` 和当前 change 工件，生成以缺陷、回归风险和测试缺口为核心的评审提示。

### Requirement: Generate Verify Prompt
系统 SHALL 通过 `gen-verify-prompt` 聚合 `AGENTS.md`、`.harness/docs` 和当前 change 工件，生成以通过、失败、跳过和未覆盖项为核心的验证提示。

### Requirement: Show Change Status
系统 SHALL 通过 `status` 输出 change 的 metadata、任务进度、严格校验结果、工件存在性以及是否达到可归档状态。

### Requirement: Validate Harness Artifacts
系统 SHALL 通过 `validate` 检查基础结构、变更工件、任务勾选以及严格模式下的模板占位文本残留。

### Requirement: Archive Completed Change
系统 SHALL 通过 `archive` 在默认严格校验后更新 `.change.yaml` 并移动 change 到 archive 目录，目标冲突时自动追加时间戳避免覆盖。
