# Harness Apply Prompt

## 执行目标
你现在要执行 change `CHG-20260413-harness-cli-bootstrap`。请优先遵守根目录 `AGENTS.md` 和 `.harness/docs` 中的长期规则，只在本次变更范围内实现代码。

## 执行要求
- 先理解 proposal、design、tasks，再动代码
- 如果 proposal / design / tasks 不一致，先回写工件，再继续实现
- 严格遵守 risk-boundaries，不要擅自扩大影响范围
- review 和 verify 是独立动作，不要把它们混成同一步
- 完成后明确列出改动范围、验证方式和风险说明

## 全局入口规则
路径：C:\Users\7\Desktop\归档\ux_test\AGENTS.md
```md
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
```

## 长期知识：project.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\docs\project.md
```md
# 项目概览

## 项目目标
- 这个项目解决什么问题
- 面向哪些用户
- 最核心的业务目标是什么

## 业务边界
- 本项目负责什么
- 本项目不负责什么
- 与外部系统的边界是什么

## 核心模块
- 模块 A：职责
- 模块 B：职责
- 模块 C：职责

## 运行方式
- 本地如何启动
- 依赖什么环境
- 必须准备哪些资源

## 构建方式
- 如何构建
- 构建产物是什么
- 常见失败原因是什么

## 发布方式
- 如何发布
- 发布前必须检查什么
- 发布后如何确认成功

## 术语表
- 术语 1：定义
- 术语 2：定义
- 术语 3：定义
```

## 长期知识：architecture.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\docs\architecture.md
```md
# 架构说明

## 总体结构
- 项目分为哪些层或模块
- 每层或每模块的职责是什么

## 模块划分
### 模块 A
- 输入
- 输出
- 依赖
- 边界

### 模块 B
- 输入
- 输出
- 依赖
- 边界

## 关键数据流
1. 数据从哪里来
2. 经过哪些处理
3. 最终写到哪里或展示到哪里

## 外部依赖
- 第三方服务
- 基础设施
- 外部接口
- 外部文件或数据源

## 扩展点
- 哪些地方允许扩展
- 哪些地方不允许随意扩展

## 禁止事项
- 禁止跨层调用的情况
- 禁止直接依赖的情况
- 禁止绕过统一入口的情况
```

## 长期知识：conventions.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\docs\conventions.md
```md
# 通用规范

## 命名规范
- 目录命名规则
- 文件命名规则
- 变量命名规则
- 方法命名规则
- 组件或模块命名规则

## 目录规范
- 什么文件放哪里
- 什么文件不允许放在业务目录
- 临时文件如何处理

## 配置规范
- 配置如何分层
- 敏感配置如何处理
- 环境差异如何管理

## 错误处理规范
- 错误如何抛出
- 错误如何记录
- 错误如何向上游返回

## 日志规范
- 记录什么
- 不记录什么
- 日志字段是否统一

## 注释规范
- 什么情况必须写注释
- 什么情况不要写废话注释
- 注释应描述什么信息

## 提交规范
- commit 信息格式
- 一个提交应只做一类事情
- 禁止把无关改动混进同一个提交
```

## 长期知识：testing.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\docs\testing.md
```md
# 测试规范

## 必跑检查
- 构建检查
- 静态检查
- 单元测试
- 集成测试
- 冒烟测试

## 测试分层
- 单元测试覆盖什么
- 集成测试覆盖什么
- 端到端测试覆盖什么
- 手工验证覆盖什么

## 验收标准
- 功能正确
- 没有明显回归
- 风险已说明
- 证据可追溯

## 回归要求
- 哪些模块一改就必须回归
- 哪些公共能力一改就必须补验证

## 证据要求
- 哪些检查要贴结果
- 哪些测试要记录范围
- 哪些未覆盖项必须显式说明
```

## 长期知识：risk-boundaries.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\docs\risk-boundaries.md
```md
# 风险边界

## 高风险目录
- 配置目录
- 部署脚本目录
- 数据迁移目录
- 公共基础模块目录
- 鉴权、计费、库存、订单等关键模块目录

## 高风险操作
- 批量删除
- 批量更新
- 修改核心配置
- 修改发布流程
- 修改数据库结构
- 修改公共接口契约
- 修改安全相关逻辑

## 必须人工确认的动作
- 影响生产数据的操作
- 影响外部接口兼容性的操作
- 影响权限、安全、计费的操作
- 影响发布流程的操作

## 回滚要求
- 变更前必须有回滚路径
- 回滚步骤必须可执行
- 无法快速回滚的变更必须提前说明

## 发布前检查项
- 影响范围是否明确
- 风险是否明确
- 测试是否完成
- 未覆盖项是否明确
- 回滚方案是否明确
```

## 长期知识：tooling.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\docs\tooling.md
```md
# 工具接入说明

## 当前推荐工具
codex

## 当前接入档位
core

## 推荐命令
- `.\harness.ps1 init`
- `.\harness.ps1 new-change <name> -Fast`
- `.\harness.ps1 gen-apply-prompt <change-id>`
- `.\harness.ps1 validate`
- `.\harness.ps1 archive <change-id>`
```

## 变更工件：.change.yaml
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\.change.yaml
```md
updatedAt: '2026-04-13 19:54:36'
verifyStatus: passed
slug: harness-cli-bootstrap
id: CHG-20260413-harness-cli-bootstrap
title: 'Harness CLI 启动脚本实现'
reviewStatus: passed
status: active
mode: fast
archivedAt: ''
capability: harness
createdAt: '2026-04-13 19:51:16'
```

## 变更工件：proposal.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\proposal.md
```md
# 变更提案

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 变更标题
Harness CLI 启动脚本实现

## 背景
当前仓库已经有 harness 目录规范和模板，但还缺一个可在任意项目快速落地的统一脚本。没有脚本时，初始化、创建 change、生成 AI 执行上下文、校验和归档都只能靠手工处理，规范很难稳定复用。

## 目标
- 提供单文件 PowerShell 脚本 `harness.ps1`
- 覆盖 `init`、`new-change`、`gen-apply-prompt`、`validate`、`archive` 五个核心命令
- 保持语言无关、默认不覆盖已有文件、不依赖第三方模块
- 让脚本能在当前仓库和临时目录中完成基本闭环

## 范围
- 修改根目录脚本 `harness.ps1`
- 用脚本补齐当前仓库 `.harness/` 基础结构
- 为本次实现创建并回写 change 工件
- 完成临时目录端到端验证
- 不包含业务代码生成、CI 接入和复杂 YAML 兼容
```

## 变更工件：design.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\design.md
```md
# 设计方案

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 核心思路
- 采用单文件脚本集中管理命令分发、模板渲染、简单 YAML 读写、路径解析和验证逻辑
- `init` 负责补齐 `.harness` 目录、默认配置和标准模板，默认跳过已有文件
- `new-change` 按统一命名规则创建 change 目录、元数据和标准工件
- `gen-apply-prompt` 聚合 `AGENTS.md`、`.harness/docs` 和当前 change 工件，输出可直接交给 AI 的执行上下文
- `validate` 负责检查基础结构、文档标题、任务勾选和严格模式下的占位文本残留
- `archive` 先做严格校验，再更新 `.change.yaml` 并移动目录到 archive，冲突时自动追加时间戳

## 影响范围
- 影响模块：`harness.ps1`、`.harness/config.yaml`、`.harness/templates/*`
- 影响接口：`help`、`init`、`new-change`、`gen-apply-prompt`、`validate`、`archive`
- 影响数据：`.change.yaml`、`.harness/generated/prompts/*`、`.harness/changes/*`
- 不影响业务模块、数据库和外部服务

## 回滚方案
- 回退 `harness.ps1` 到修改前版本
- 删除本次新增的 `.harness/changes/CHG-20260413-harness-cli-bootstrap`
- 如需恢复初始化前状态，可移除本次新增的 `.harness/changes`、`.harness/generated`、`.harness/specs` 等目录
```

## 变更工件：tasks.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\tasks.md
```md
# 任务拆分

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 任务列表
- [x] 修复 `harness.ps1` 的解析错误，恢复 `help` 和 `init` 入口可用
- [x] 补齐当前仓库的 `.harness` 基础结构，并创建本次改动对应的 change 工作区
- [x] 在临时目录中跑通 `init`、`new-change`、`gen-apply-prompt`、`validate`、`archive` 命令链路
- [x] 回写 review、verify 和 delta spec，形成可追溯的闭环记录

## 完成定义
- `harness.ps1` 主命令可以直接执行
- 当前仓库存在完整的 `.harness` 结构和本次 change 工件
- 临时目录端到端验证结果符合设计预期
- 风险、验证结果和影响范围都有明确记录
```

## 变更工件：review.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\review.md
```md
# 评审记录

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 评审范围
- 命令参数解析与错误处理
- 模板渲染、prompt 生成和路径拼接
- change 定位、结构校验和归档逻辑
- 默认不覆盖策略与严格校验行为

## 风险结论
- 总体风险为低到中
- 风险点 1：简单 YAML 解析只覆盖脚本约定结构，不适用于复杂自定义配置
- 风险点 2：当前实现聚焦 PowerShell 环境，跨平台 Shell 不是本版目标
- 风险点 3：严格模式依赖模板占位文案，后续若调整模板文案需同步更新校验规则

## 评审结论
- 结论：通过
- 已修复 Markdown 围栏字符串导致的 PowerShell 解析失败
- 已修复 change 唯一命中时对象退化为字符串而缺少 `Count` 的问题
```

## 变更工件：verify.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\verify.md
```md
# 验证结果

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 执行的检查
- `& .\harness.ps1 help`
- `& .\harness.ps1 help init`
- `& .\harness.ps1 init -Tool codex`
- `& .\harness.ps1 new-change harness-cli-bootstrap -Title 'Harness CLI 启动脚本实现' -Capability harness -Fast`
- 在 `_tmp_harness_validation` 目录执行 `init`、`new-change`、`gen-apply-prompt`、`validate`、`validate -Strict`、`archive -Force`

## 结果
- 通过：`help`、`help init`、当前仓库 `init`、当前仓库 `new-change`
- 通过：临时目录 `init`、`new-change`、`gen-apply-prompt`、`validate`
- 预期失败：临时目录 `validate -Strict` 因模板占位文本未替换而返回错误
- 通过：临时目录 `archive -Force` 在严格校验失败时仍按设计完成归档
- 未覆盖：并发执行、复杂 YAML、自定义 profile 扩展场景

## 最终结论
当前版本已经满足“快速初始化 + change 脚手架 + AI 执行提示 + 校验 + 归档”的基础闭环，可作为通用 harness bootstrapper 的第一版继续演进。
```

## 变更工件：archive.md
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\archive.md
```md
# 归档记录

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 最终完成内容
- 新增并修复单文件脚本 `harness.ps1`
- 落地 `init`、`new-change`、`gen-apply-prompt`、`validate`、`archive` 五个命令
- 用脚本补齐当前仓库的 `.harness` 基础结构
- 完成临时目录端到端验证并记录结果

## 实际影响范围
- 根目录入口文件：`harness.ps1`
- harness 目录：`.harness/config.yaml`、`.harness/docs/*`、`.harness/templates/*`、`.harness/changes/*`
- 生成物目录：`.harness/generated/prompts/*`
- 未触及业务代码、数据库和外部接口
```

## Delta Spec：harness
路径：C:\Users\7\Desktop\归档\ux_test\.harness\changes\CHG-20260413-harness-cli-bootstrap\specs\harness\spec.md
```md
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

### Requirement: Validate Harness Artifacts
系统 SHALL 通过 `validate` 检查基础结构、变更工件、任务勾选以及严格模式下的模板占位文本残留。

### Requirement: Archive Completed Change
系统 SHALL 通过 `archive` 在默认严格校验后更新 `.change.yaml` 并移动 change 到 archive 目录，目标冲突时自动追加时间戳避免覆盖。
```

