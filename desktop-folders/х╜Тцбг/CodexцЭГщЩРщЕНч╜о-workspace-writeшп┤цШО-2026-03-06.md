# Codex 权限配置说明

## 结论
如果想把 Codex 的默认权限从“工作区只读”改为“工作区写入”，核心做法是修改 `~/.codex/config.toml`，增加或调整以下配置：

```toml
sandbox_mode = "workspace-write"
approval_policy = "on-request"
```

如果希望默认自动执行、尽量少打断，也可以使用：

```toml
sandbox_mode = "workspace-write"
approval_policy = "never"
```

## 关键点
- 真正控制 `read-only / workspace-write / danger-full-access` 的字段是 `sandbox_mode`
- `workspace-write` 表示：允许在当前工作区内写入，但不允许越界写入系统或项目外目录
- `approval_policy` 控制的是“是否询问你批准”，不是文件系统权限本身

## 常见配置方式
### 1. 全局默认配置
文件位置：`C:\Users\7\.codex\config.toml`

推荐写法：

```toml
model = "gpt-5.3-codex"
model_reasoning_effort = "xhigh"
web_search = "live"
approval_policy = "never"
suppress_unstable_features_warning = true
personality = "pragmatic"

sandbox_mode = "workspace-write"

[windows]
sandbox = "elevated"
```

### 2. 单次启动临时指定
只在本次启动生效：

```powershell
codex -s workspace-write
```

### 3. 使用快捷预设

```powershell
codex --full-auto
```

该参数会启用低干预自动执行模式，并带上 `workspace-write`。

## 你当前机器上的情况
根据本机现有配置：
- 已设置 `approval_policy = "never"`
- 已设置 `[windows] sandbox = "elevated"`
- 但未看到 `sandbox_mode = "workspace-write"`

这说明：
- `windows.sandbox = "elevated"` 不是“默认工作区写入”的配置项
- 如果没有显式设置 `sandbox_mode`，实际行为可能仍然不是你想要的 `workspace-write`

因此，最直接的修正方式就是在 `C:\Users\7\.codex\config.toml` 中补上：

```toml
sandbox_mode = "workspace-write"
```

## 建议
日常开发建议优先使用：
- `sandbox_mode = "workspace-write"`
- `approval_policy = "never"` 或 `approval_policy = "on-request"`

不建议默认使用：

```toml
danger-full-access
```

因为这会取消沙箱限制，风险明显更高。

## 参考
- Codex CLI 参数帮助：`codex --help`
- Codex 官方文档主页：`https://developers.openai.com/codex`
