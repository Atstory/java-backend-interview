# Codex `/agent` 指令通俗说明

## 一句话理解
`/agent` 的作用是：在“已经存在的子代理线程”之间切换。
它不是用来创建新 agent 的。

## 什么时候用
- 你已经开启了多代理能力（Multi-agents）
- 你让 Codex 并行跑了多个子任务
- 你想切到某个子任务里继续追问或查看进度

## 最快上手（4步）
1. 输入 `/experimental`，开启 `Multi-agents`，然后重启 Codex。
2. 让 Codex 并行创建子代理（例如：安全、性能、测试覆盖）。
3. 输入 `/agent`。
4. 在弹出的线程列表中选中目标线程并回车。

## 常见误区
- 误区：`/agent` 会新建代理。
  结论：不会，它只做“切换线程”。
- 误区：`/agent` 列表为空说明命令坏了。
  结论：通常是没开启 Multi-agents，或当前还没有子线程。

## 实战示例
先发给 Codex：
`请并行开 3 个子 agent：安全、性能、测试覆盖，最后汇总。`

再输入：
`/agent`

然后选中一个线程继续问：
`把高风险问题按严重级排序，并给出修复优先级。`

## 参考链接
- https://developers.openai.com/codex/cli/slash-commands
- https://developers.openai.com/codex/multi-agent
- https://github.com/openai/codex/blob/main/docs/slash_commands.md

## 什么是“归档线程”

一句话：归档线程就是把某个会话“收起来”，不在默认列表里显示，但并没有删除。

要点：
- 归档后，线程会被移到归档目录（`archived_sessions`）。
- 默认 `thread/list` 不会返回它（除非显式使用 `archived=true`）。
- 需要时可以 `unarchive`，恢复到普通会话继续使用。

容易混淆：
- `/agent` 只负责切换线程，不负责归档。

参考：
- https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md
- https://github.com/openai/codex/blob/main/codex-rs/tui/src/slash_command.rs
