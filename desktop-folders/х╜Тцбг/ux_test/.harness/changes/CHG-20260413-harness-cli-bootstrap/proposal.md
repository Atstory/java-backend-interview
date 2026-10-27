# 变更提案

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 变更标题
Harness CLI 启动脚本实现

## 背景
当前仓库已经有 harness 目录规范和模板，但还缺一个可在任意项目快速落地的统一脚本。没有脚本时，初始化、创建 change、生成 AI 执行上下文、校验和归档都只能靠手工处理，规范很难稳定复用。

## 目标
- 提供单文件 PowerShell 脚本 `harness.ps1`
- 覆盖 `init`、`new-change`、`gen-apply-prompt`、`gen-review-prompt`、`gen-verify-prompt`、`status`、`validate`、`archive` 八个核心命令
- 保持语言无关、默认不覆盖已有文件、不依赖第三方模块
- 让脚本能在当前仓库和临时目录中完成“实现、评审、验证”三个阶段的基本闭环

## 范围
- 修改根目录脚本 `harness.ps1`
- 用脚本补齐当前仓库 `.harness/` 基础结构
- 为本次实现创建并回写 change 工件
- 完成临时目录端到端验证
- 补齐 review / verify 阶段的 prompt 生成能力
- 增加统一查看 change readiness 的 `status` 命令
- 不包含业务代码生成、CI 接入和复杂 YAML 兼容
