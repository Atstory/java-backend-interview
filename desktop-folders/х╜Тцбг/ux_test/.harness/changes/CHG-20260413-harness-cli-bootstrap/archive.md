# 归档记录

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 最终完成内容
- 新增并修复单文件脚本 `harness.ps1`
- 落地 `init`、`new-change`、`gen-apply-prompt`、`gen-review-prompt`、`gen-verify-prompt`、`status`、`validate`、`archive` 八个命令
- 用脚本补齐当前仓库的 `.harness` 基础结构
- 完成临时目录端到端验证并记录结果

## 实际影响范围
- 根目录入口文件：`harness.ps1`
- harness 目录：`.harness/config.yaml`、`.harness/docs/*`、`.harness/templates/*`、`.harness/changes/*`
- 生成物目录：`.harness/generated/prompts/*`
- 未触及业务代码、数据库和外部接口
