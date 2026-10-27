# 评审记录

## Change ID
`CHG-20260413-harness-cli-bootstrap`

## 评审范围
- 命令参数解析与错误处理
- 模板渲染、prompt 生成和路径拼接
- change 定位、结构校验和归档逻辑
- 默认不覆盖策略与严格校验行为
- 新增的 review / verify prompt 阶段配置与 help 暴露
- `status` 的 readiness 判定规则与摘要输出

## 风险结论
- 总体风险为低到中
- 风险点 1：简单 YAML 解析只覆盖脚本约定结构，不适用于复杂自定义配置
- 风险点 2：当前实现聚焦 PowerShell 环境，跨平台 Shell 不是本版目标
- 风险点 3：严格模式依赖模板占位文案，后续若调整模板文案需同步更新校验规则

## 评审结论
- 结论：通过
- 已修复 Markdown 围栏字符串导致的 PowerShell 解析失败
- 已修复 change 唯一命中时对象退化为字符串而缺少 `Count` 的问题
- 已将阶段 prompt 收敛为统一生成逻辑，降低 apply / review / verify 后续分叉维护成本
- 已把可归档判定统一收口到 `status`，避免使用时反复手工比对 metadata、tasks 和 validate
