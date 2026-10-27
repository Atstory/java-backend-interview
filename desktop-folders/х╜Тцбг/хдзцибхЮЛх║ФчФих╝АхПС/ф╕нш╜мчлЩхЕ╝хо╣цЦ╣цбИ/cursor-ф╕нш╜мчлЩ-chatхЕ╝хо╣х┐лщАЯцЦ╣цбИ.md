# Cursor 中转站兼容快速方案

## 目标

解决 Cursor 发 `chat/completions` 时出现：

`field messages is required`

核心做法：在本地加一层兼容网关，把 `input` 自动转换为 `messages`。

## 目录建议

- 当前目录：`中转站兼容方案`
- 脚本文件：`compat-gateway.js`

## 1. 新建网关脚本

创建 `compat-gateway.js`，内容如下：

```js
const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");

const TARGET = "https://stephecurry.asia"; // 中转根域名
const app = express();

app.use(express.json({ limit: "10mb" }));

// 兼容 Cursor -> /v1/chat/completions 但 body 里只有 input 的情况
app.use("/v1/chat/completions", (req, _res, next) => {
  const b = req.body || {};
  if (!b.messages && b.input) {
    const content = typeof b.input === "string" ? b.input : JSON.stringify(b.input);
    b.messages = [{ role: "user", content }];
    delete b.input;
    req.body = b;
  }
  next();
});

app.use(
  "/v1",
  createProxyMiddleware({
    target: TARGET,
    changeOrigin: true,
    onProxyReq: (proxyReq, req) => {
      if (req.body && ["POST", "PUT", "PATCH"].includes(req.method)) {
        const bodyData = JSON.stringify(req.body);
        proxyReq.setHeader("Content-Type", "application/json");
        proxyReq.setHeader("Content-Length", Buffer.byteLength(bodyData));
        proxyReq.write(bodyData);
      }
    },
  })
);

app.listen(8787, () => {
  console.log("compat gateway running: http://127.0.0.1:8787");
});
```

## 2. 安装依赖并启动

```bash
npm i express http-proxy-middleware
node compat-gateway.js
```

## 3. Cursor 配置

- Base URL: `http://127.0.0.1:8787/v1`
- Model: `gpt-5.3-codex`
- API Key: 使用你新的中转 key

## 4. 快速验证

```bash
curl -X POST "http://127.0.0.1:8787/v1/chat/completions" ^
  -H "Authorization: Bearer <NEW_KEY>" ^
  -H "Content-Type: application/json" ^
  -d "{\"model\":\"gpt-5.3-codex\",\"input\":\"hi\"}"
```

返回不再出现 `messages is required` 即表示兼容成功。

## 5. 安全提醒

你之前的 key 已在终端信息中暴露，务必立即作废并更换新 key。
