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

## change 命名
统一格式：

`CHG-YYYYMMDD-简短名称`

示例：

`CHG-20260410-login-refactor`
