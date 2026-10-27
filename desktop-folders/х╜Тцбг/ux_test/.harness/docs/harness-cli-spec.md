# Harness CLI 实现规格

## 目标
本规格定义仓库内通用 harness 脚本 `harness.ps1` 的最小可用实现。

设计目标如下：

- 适配任意项目，不绑定语言和框架
- 通过单文件脚本完成初始化、变更脚手架、提示词生成、校验、归档
- 提示词生成覆盖 apply、review、verify 三个阶段
- 提供 `status` 命令统一查看 change 当前状态和归档准备度
- 兼容已有仓库，默认不覆盖现有文件，只有显式传入 `-Force` 才覆盖
- 生成的是 harness 工件和 AI 执行上下文，而不是直接生成业务代码
- 目录结构参考 OpenSpec 思想，但保持当前仓库的 `.harness/` 规范

## 命令范围

### `init`
初始化 harness 基础骨架。

输入：

- `-Tool codex|claude|cursor|none`
- `-Profile core|expanded`
- `-Force`

输出：

- 根目录 `AGENTS.md`
- `.harness/config.yaml`
- `.harness/docs/*`
- `.harness/specs/README.md`
- `.harness/templates/*`
- `.harness/changes/archive/`
- `.harness/generated/prompts/`

### `new-change`
创建新的 change 工作区。

输入：

- `<name>`
- `-Title`
- `-Capability`
- `-Fast`
- `-Force`

输出：

- `.harness/changes/CHG-YYYYMMDD-<slug>/`
- `.change.yaml`
- `proposal.md`
- `design.md`
- `tasks.md`
- `review.md`
- `verify.md`
- `archive.md`
- `specs/<capability>/spec.md`

### `gen-apply-prompt`
读取全局规则、长期知识和当前 change 工件，生成交给 AI 的标准执行上下文。

输入：

- `<change-id-or-slug>`
- `-OutFile`
- `-Force`

输出：

- 默认输出到 `.harness/generated/prompts/apply-<change-id>.md`

### `gen-review-prompt`
读取全局规则、长期知识和当前 change 工件，生成交给 AI 的标准评审上下文。

输入：

- `<change-id-or-slug>`
- `-OutFile`
- `-Force`

输出：

- 默认输出到 `.harness/generated/prompts/review-<change-id>.md`

### `gen-verify-prompt`
读取全局规则、长期知识和当前 change 工件，生成交给 AI 的标准验证上下文。

输入：

- `<change-id-or-slug>`
- `-OutFile`
- `-Force`

输出：

- 默认输出到 `.harness/generated/prompts/verify-<change-id>.md`

### `status`
查看当前仓库 change 的状态摘要，或单个 change 的详细状态。

输入：

- 可选 `<change-id-or-slug>`
- `-Json`

输出：

- 默认输出文本摘要
- 单个 change 时包含 metadata、任务进度、严格校验结果、工件存在性、是否可归档
- 多个 change 时输出 active changes 汇总列表

### `validate`
校验 harness 基础结构和 change 工件完整性。

输入：

- 可选 `<change-id-or-slug>`
- `-Strict`
- `-Json`

输出：

- 控制台文本报告，或 JSON 结构化报告

### `archive`
将已完成的 change 归档到 `.harness/changes/archive/`。

输入：

- `<change-id-or-slug>`
- `-Force`
- `-SkipValidate`

输出：

- 归档后的 change 目录
- 更新后的 `.change.yaml`
- 补充归档时间的 `archive.md`

## 目录规范

```text
/
├─ AGENTS.md
└─ .harness/
   ├─ config.yaml
   ├─ docs/
   │  ├─ project.md
   │  ├─ architecture.md
   │  ├─ conventions.md
   │  ├─ testing.md
   │  ├─ risk-boundaries.md
   │  └─ tooling.md
   ├─ specs/
   │  └─ README.md
   ├─ changes/
   │  ├─ archive/
   │  └─ CHG-YYYYMMDD-xxx/
   │     ├─ .change.yaml
   │     ├─ proposal.md
   │     ├─ design.md
   │     ├─ tasks.md
   │     ├─ review.md
   │     ├─ verify.md
   │     ├─ archive.md
   │     └─ specs/
   │        └─ <capability>/
   │           └─ spec.md
   ├─ templates/
   │  ├─ proposal.md
   │  ├─ design.md
   │  ├─ tasks.md
   │  ├─ review.md
   │  ├─ verify.md
   │  ├─ archive.md
   │  └─ delta-spec.md
   └─ generated/
      └─ prompts/
```

## 配置文件约束

`config.yaml` 采用两层嵌套的简单 YAML 结构，不依赖额外 YAML 模块。

包含以下顶层字段：

- `version`
- `profile`
- `tool`
- `paths`
- `change`
- `artifacts`
- `validate`
- `archive`

脚本内部只解析它自己生成的结构，不承诺兼容任意复杂 YAML。

## 元数据约束

每个 change 目录中的 `.change.yaml` 使用平铺结构：

- `id`
- `slug`
- `title`
- `status`
- `createdAt`
- `updatedAt`
- `capability`
- `mode`
- `reviewStatus`
- `verifyStatus`
- `archivedAt`

推荐状态：

- `draft`
- `active`
- `archived`

## 校验规则

### 根结构校验

- `AGENTS.md` 必须存在
- `.harness/config.yaml` 必须存在
- `.harness/docs/` 必须存在且包含必需文档
- `.harness/templates/` 必须存在且包含必需模板
- `.harness/specs/README.md` 必须存在
- `.harness/changes/archive/` 必须存在

### change 校验

- 目录名必须符合 `CHG-YYYYMMDD-xxx`
- `.change.yaml` 必须存在
- `proposal.md`、`design.md`、`tasks.md` 必须存在
- `review.md`、`verify.md`、`archive.md` 在默认配置下必须存在
- `tasks.md` 至少要包含一个勾选任务
- 严格模式下，如果文件仍保留模板占位文本，视为未完成

## 归档规则

- 默认归档前执行严格校验
- 严格校验失败时，除非显式传入 `-Force`，否则不允许归档
- 归档时更新 `.change.yaml` 的 `status`、`updatedAt`、`archivedAt`
- 归档目标路径冲突时，自动追加时间戳，避免覆盖已有归档

## 代码实现约束

- 保持单文件脚本，不依赖第三方模块
- 用详细中文注释说明关键实现
- 抽离公共函数，避免命令实现中出现大段重复逻辑
- 对外部输入统一校验
- 对关键文件写入路径统一做存在性和覆盖控制
- 默认以“保守不覆盖”作为写入策略

## 非目标

当前版本不做以下事情：

- 不自动生成业务代码
- 不自动生成 hooks、permissions、skills
- 不接入 CI
- 不处理复杂 YAML 自定义语法
- 不处理跨仓库依赖分析

## 推荐演进顺序

1. 先稳定 `init`
2. 再稳定 `new-change`
3. 再稳定 `gen-apply-prompt`
4. 再补强 `validate`
5. 最后稳定 `archive`

该顺序保证脚本先可用，再逐步补完闭环治理能力。
