const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");

const TARGET = "https://stephecurry.asia";
const PORT = 8787;

const app = express();
app.use(express.json({ limit: "10mb" }));

// Cursor 某些场景会向 /v1/chat/completions 发送 input 字段，这里统一转换为 messages
app.use("/v1/chat/completions", (req, _res, next) => {
  const body = req.body || {};
  if (!body.messages && body.input) {
    const content =
      typeof body.input === "string" ? body.input : JSON.stringify(body.input);
    body.messages = [{ role: "user", content }];
    delete body.input;
    req.body = body;
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

app.listen(PORT, () => {
  console.log(`compat gateway running at http://127.0.0.1:${PORT}/v1`);
});
