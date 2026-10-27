# 设计方案

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 核心思路
- 采用单文件脚本集中管理命令分发、模板渲染、简单 YAML 读写、路径解析和验证逻辑
- `init` 负责补齐 `.harness` 目录、默认配置和标准模板，默认跳过已有文件
- `new-change` 按统一命名规则创建 change 目录、元数据和标准工件
- prompt 生成统一走同一套阶段定义，分别输出 apply、review、verify 三类上下文文件
- `status` 读取 metadata、tasks 和严格校验结果，统一计算当前 change 是否达到可归档状态
- `validate` 负责检查基础结构、文档标题、任务勾选和严格模式下的占位文本残留
- `archive` 先做严格校验，再更新 `.change.yaml` 并移动目录到 archive，冲突时自动追加时间戳

## 影响范围
- 影响模块：`harness.ps1`、`.harness/config.yaml`、`.harness/templates/*`、`.harness/docs/tooling.md`
- 影响接口：`help`、`init`、`new-change`、`gen-apply-prompt`、`gen-review-prompt`、`gen-verify-prompt`、`status`、`validate`、`archive`
- 影响数据：`.change.yaml`、`.harness/generated/prompts/*.md`、`.harness/changes/*`
- 不影响业务模块、数据库和外部服务

## 回滚方案
- 回退 `harness.ps1` 到修改前版本
- 删除本次新增的 `.harness/changes/CHG-20260413-harness-cli-bootstrap`
- 如需恢复初始化前状态，可移除本次新增的 `.harness/changes`、`.harness/generated`、`.harness/specs` 等目录
