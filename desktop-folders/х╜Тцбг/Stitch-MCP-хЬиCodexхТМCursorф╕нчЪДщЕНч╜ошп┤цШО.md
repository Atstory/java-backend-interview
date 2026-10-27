# Stitch MCP 在 Codex 和 Cursor 中的配置说明

## 结论

- `Stitch AI MCP` 官方仓库当前明确给了 `Claude Desktop` 的配置示例。
- `Codex` 和 `Cursor` 的写法，需要基于各自官方 MCP 配置方式，套用 Stitch 官方提供的启动命令和环境变量。
- 因此下面的 `Codex` / `Cursor` 配置属于高置信适配方案，不是 Stitch README 里直接给出的原文示例。

## 一、前置准备

先把 Stitch MCP 拉到本地并安装依赖：

```bash
git clone https://github.com/StitchAI/stitch-ai-mcp.git
cd stitch-ai-mcp
npm install
npm install -D ts-node typescript @types/node
```

Stitch 仓库里当前可确认的信息：

- 启动脚本基于 `npx ts-node src/server.ts`
- `.env.example` 中主要环境变量是：
  - `API_KEY`
  - `BASE_URL`
  - `PORT`

通常至少需要：

```env
API_KEY=你的_STITCH_API_KEY
BASE_URL=https://api-demo.stitch-ai.co
```

## 二、Codex 中怎么配置

Codex 官方文档确认支持 MCP，通常可通过 `~/.codex/config.toml` 配置 MCP 服务。

Windows 常见位置：

```text
C:\Users\你的用户名\.codex\config.toml
```

可以加入下面这一段：

```toml
[mcp_servers.stitchai]
command = "npx"
args = ["ts-node", "C:\\path\\to\\stitch-ai-mcp\\src\\server.ts"]
env = { API_KEY = "你的_STITCH_API_KEY", BASE_URL = "https://api-demo.stitch-ai.co" }
```

如果你的 Windows 环境里 `npx` 不稳定，建议改成绝对路径：

```toml
[mcp_servers.stitchai]
command = "C:\\Program Files\\nodejs\\npx.cmd"
args = ["ts-node", "C:\\path\\to\\stitch-ai-mcp\\src\\server.ts"]
env = { API_KEY = "你的_STITCH_API_KEY", BASE_URL = "https://api-demo.stitch-ai.co" }
```

配置完成后：

1. 完全退出 Codex
2. 重新打开 Codex
3. 再测试 Stitch MCP 是否已被识别

## 三、Cursor 中怎么配置

Cursor 官方文档支持通过 `mcp.json` 配置 MCP 服务。

常见位置有两种：

- 项目级：`.cursor/mcp.json`
- 全局：`C:\Users\你的用户名\.cursor\mcp.json`

推荐先用全局配置，示例：

```json
{
  "mcpServers": {
    "stitchai": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "ts-node",
        "C:\\path\\to\\stitch-ai-mcp\\src\\server.ts"
      ],
      "env": {
        "API_KEY": "你的_STITCH_API_KEY",
        "BASE_URL": "https://api-demo.stitch-ai.co"
      }
    }
  }
}
```

Windows 下更稳的写法：

```json
{
  "mcpServers": {
    "stitchai": {
      "type": "stdio",
      "command": "C:\\Program Files\\nodejs\\npx.cmd",
      "args": [
        "ts-node",
        "C:\\path\\to\\stitch-ai-mcp\\src\\server.ts"
      ],
      "env": {
        "API_KEY": "你的_STITCH_API_KEY",
        "BASE_URL": "https://api-demo.stitch-ai.co"
      }
    }
  }
}
```

配置完成后：

1. 重启 Cursor
2. 打开 MCP / Tools 面板
3. 检查 `stitchai` 是否已连接

## 四、推荐做法

- `Codex`：优先写 `C:\Users\你的用户名\.codex\config.toml`
- `Cursor`：优先写 `C:\Users\你的用户名\.cursor\mcp.json`
- Windows 下优先使用 `npx.cmd` 的绝对路径
- 先只配置 `API_KEY` 和 `BASE_URL`
- `PORT` 只有在 Stitch 服务明确要求固定端口时再加

## 五、排查建议

如果配置后不可用，优先检查这几项：

1. `node`、`npm`、`npx` 是否可用
2. `ts-node` 是否已安装
3. `src/server.ts` 路径是否写成了真实绝对路径
4. `API_KEY` 是否正确
5. `BASE_URL` 是否与 Stitch 当前环境一致
6. `Codex` / `Cursor` 是否已经完全重启

## 六、说明

这份文档里的 `Codex` 和 `Cursor` 配置，不是 Stitch 官方 README 的逐字示例，而是：

- 依据 Stitch 官方仓库给出的启动方式和环境变量
- 再结合 Codex / Cursor 官方 MCP 配置格式整理出的可落地版本

如果后续 Stitch 官方补充了专门针对 Codex 或 Cursor 的示例，应优先以官方最新示例为准。

## 参考来源

- Stitch 官方仓库：<https://github.com/StitchAI/stitch-ai-mcp>
- Stitch README：<https://github.com/StitchAI/stitch-ai-mcp/blob/main/README.md>
- Stitch `package.json`：<https://github.com/StitchAI/stitch-ai-mcp/blob/main/package.json>
- Stitch `.env.example`：<https://github.com/StitchAI/stitch-ai-mcp/blob/main/.env.example>
- OpenAI Codex MCP 文档：<https://developers.openai.com/learn/docs-mcp>
- Cursor MCP 文档：<https://docs.cursor.com/en/context/mcp>
