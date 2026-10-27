# VSIX 插件逆向方法

> 整理日期：2026-03-18  
> VSIX 是 VS Code / Cursor 扩展的发布格式，本质是 ZIP 压缩包。

---

## 一、解包 VSIX

VSIX 本质上是一个 **ZIP 压缩包**，直接改后缀名即可解压：

```bash
# 方法1：改后缀解压
mv extension.vsix extension.zip
unzip extension.zip

# 方法2：直接解压
unzip extension.vsix -d extracted/
```

解压后的核心结构：

```
extension/
├── package.json          # 插件元数据、命令、配置声明
├── extension.js          # 主入口（通常被打包/混淆）
├── dist/                 # 打包产物
│   ├── extension.js      # Webpack/esbuild 打包后的代码
│   └── *.mjs             # ESM 格式模块
└── node_modules/         # 依赖（部分插件会内嵌）
```

## 二、代码还原

### 1. 反混淆 / 美化

```bash
# 用 prettier 或 js-beautify 格式化压缩代码
npx prettier --write dist/extension.js
npx js-beautify -f dist/extension.js -o extension-formatted.js
```

### 2. Source Map 还原（最佳情况）

如果插件包含 `.map` 文件，可以直接还原源码：

```bash
# 检查是否有 source map
find . -name "*.map"

# 使用 shuji 还原
npx shuji dist/extension.js.map -o src-restored/
```

### 3. Webpack/esbuild Bundle 分析

```bash
# 如果是 webpack 打包，找到模块边界
# 搜索 __webpack_require__ 或 __webpack_modules__

# 使用 webcrack 反打包
npx webcrack dist/extension.js -o unpacked/
```

## 三、关键分析点

| 目标 | 位置/方法 |
|------|----------|
| **插件能力** | `package.json` → `contributes`（命令、菜单、配置） |
| **激活条件** | `package.json` → `activationEvents` |
| **API 调用** | 搜索 `vscode.` 开头的 API 调用 |
| **网络请求** | 搜索 `fetch`、`axios`、`http`、`request` |
| **密钥/Token** | 搜索 `key`、`token`、`secret`、`password` |
| **文件读写** | 搜索 `readFile`、`writeFile`、`fs.` |
| **MCP 通信** | 搜索 `stdin`、`stdout`、`spawn`、`child_process` |
| **WebView** | 搜索 `createWebviewPanel`，查看嵌入的 HTML/JS |

## 四、动态调试

```bash
# 在 VS Code 中以开发模式加载
# 1. 打开解压后的插件目录
# 2. F5 启动 Extension Development Host
# 3. 在 extension.js 中设断点

# 或者直接在已安装插件中调试
# 插件安装位置：
# Windows: %USERPROFILE%\.cursor\extensions\
# macOS:   ~/.cursor/extensions/
# Linux:   ~/.cursor/extensions/
```

## 五、常用工具汇总

| 工具 | 用途 |
|------|------|
| `js-beautify` | 格式化压缩 JS |
| `webcrack` | Webpack bundle 反打包 |
| `shuji` | Source Map 还原源码 |
| `ast-explorer` | AST 分析混淆代码 |
| `de4js` | 在线 JS 反混淆 |
| `Chrome DevTools` | 在 Electron 内调试 |

## 六、Electron 级别深度逆向

Cursor / VS Code 基于 Electron，可以更深入：

```bash
# 提取 Electron app.asar
npx @electron/asar extract app.asar app-extracted/

# 注入调试代码
# 在 app.asar 的入口文件中添加 DevTools 快捷键

# 使用 Chrome 远程调试
# 启动时加参数：--inspect=9229
# 然后 chrome://inspect 连接
```
