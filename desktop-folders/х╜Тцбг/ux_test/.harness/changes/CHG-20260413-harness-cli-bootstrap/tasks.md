# 任务拆分

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 任务列表
- [x] 修复 `harness.ps1` 的解析错误，恢复 `help` 和 `init` 入口可用
- [x] 补齐当前仓库的 `.harness` 基础结构，并创建本次改动对应的 change 工作区
- [x] 在临时目录中跑通 `init`、`new-change`、`gen-apply-prompt`、`validate`、`archive` 命令链路
- [x] 回写 review、verify 和 delta spec，形成可追溯的闭环记录
- [x] 抽出统一 prompt 生成逻辑，新增 `gen-review-prompt` 与 `gen-verify-prompt`
- [x] 更新规格、工具说明和 change 工件，使实现范围与文档保持一致
- [x] 在临时目录中补跑 review / verify prompt 生成链路
- [x] 新增 `status` 命令，汇总 metadata、任务进度、严格校验和可归档结论
- [x] 补跑 `status` 在当前仓库和临时目录下的展示与 JSON 输出验证

## 完成定义
- `harness.ps1` 主命令可以直接执行
- 当前仓库存在完整的 `.harness` 结构和本次 change 工件
- 临时目录端到端验证结果符合设计预期
- apply、review、verify 三类 prompt 都能稳定生成
- `status` 能清晰输出单个 change 详情和 active changes 摘要
- 风险、验证结果和影响范围都有明确记录
