# Codex 配置 MySQL MCP（可直接照做）

## 方式一：命令行一条添加（推荐）
```powershell
codex mcp add mysql --env MYSQL_DATABASE=qunde2 --env MYSQL_HOST=8.138.84.226 --env MYSQL_PORT=3306 --env MYSQL_USER=qunde2 --env MYSQL_PASSWORD=YOUR_PASSWORD -- npx -y @fhuang/mcp-mysql-server
```

验证：
```powershell
codex mcp list
codex mcp get mysql
```

## 方式二：手动编辑 config.toml
文件位置：`C:\Users\7\.codex\config.toml`

```toml
[mcp_servers.mysql]
command = "npx"
args = ["-y", "@fhuang/mcp-mysql-server"]

[mcp_servers.mysql.env]
MYSQL_DATABASE = "qunde2"
MYSQL_HOST = "8.138.84.226"
MYSQL_PORT = "3306"
MYSQL_USER = "qunde2"
MYSQL_PASSWORD = "YOUR_PASSWORD"
```

## 使用检查
1. 确认本机有 Node.js（`npx -v` 可执行）。
2. 重开 Codex 会话。
3. 在 Codex 内使用 `/mcp` 查看是否已加载。

## 安全建议
- 不要把真实数据库密码写进公开仓库。
- 建议改用环境变量/密钥管理。
- 如果密码已在聊天中明文发送，建议立即轮换密码。

## 参考
- https://developers.openai.com/codex/mcp
- https://developers.openai.com/codex/config-reference#model-context-protocol-mcp
