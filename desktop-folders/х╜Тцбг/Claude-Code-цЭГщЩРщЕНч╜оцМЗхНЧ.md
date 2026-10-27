# Claude Code 权限配置指南（免审批）

> 文档生成日期：2026-03-30

---

## 配置文件位置

| 范围 | 文件路径 | 说明 |
|------|----------|------|
| 全局（个人） | `~/.claude/settings.json` | 所有项目生效 |
| 项目（共享） | `.claude/settings.json` | 提交到 git，团队共享 |
| 项目（本地） | `.claude/settings.local.json` | 不提交，个人专用 |

---

## 配置文件基本结构

```json
{
  "permissions": {
    "allow": [],
    "ask": [],
    "deny": []
  }
}
```

> **优先级**：`deny` > `allow` > `ask`，deny 中的规则始终生效。

---

## 快捷方案：跳过所有审批

### 方法一：命令行参数（临时，单次生效）

```bash
claude --dangerously-skip-permissions
```

### 方法二：settings.json 设置默认模式（持久生效）

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

### defaultMode 可选值

| 值 | 说明 |
|----|------|
| `"default"` | 正常询问（默认） |
| `"acceptEdits"` | 自动接受文件编辑，Bash 命令仍询问 |
| `"bypassPermissions"` | 完全跳过所有权限审批 |

---

## 分语言配置示例

### 通用基础配置（推荐所有项目）

```json
{
  "permissions": {
    "allow": [
      "Read(**/*)",
      "Edit(**/*)",
      "Bash(git *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Read(.env)",
      "Read(**/secrets/**)"
    ]
  }
}
```

---

### Java 项目配置

```json
{
  "permissions": {
    "allow": [
      "Read(**/*)",
      "Edit(**/*.java)",
      "Edit(**/pom.xml)",
      "Edit(**/build.gradle)",
      "Edit(**/*.xml)",
      "Edit(**/*.yml)",
      "Edit(**/*.yaml)",
      "Bash(git *)",
      "Bash(mvn *)",
      "Bash(gradle *)",
      "Bash(java *)",
      "Bash(javac *)"
    ],
    "deny": [
      "Read(**/application-prod.yml)",
      "Read(.env)"
    ]
  }
}
```

---

### Node.js 前端项目配置

```json
{
  "permissions": {
    "allow": [
      "Read(**/*)",
      "Edit(**/*.js)",
      "Edit(**/*.ts)",
      "Edit(**/*.jsx)",
      "Edit(**/*.tsx)",
      "Edit(**/*.css)",
      "Edit(**/*.html)",
      "Edit(**/package.json)",
      "Edit(**/*.json)",
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(node *)",
      "Bash(bun *)",
      "Bash(pnpm *)"
    ],
    "deny": [
      "Read(.env)",
      "Read(.env.local)",
      "Read(**/secrets/**)"
    ]
  }
}
```

---

### Python 项目配置

```json
{
  "permissions": {
    "allow": [
      "Read(**/*)",
      "Edit(**/*.py)",
      "Edit(**/requirements*.txt)",
      "Edit(**/pyproject.toml)",
      "Edit(**/*.yml)",
      "Edit(**/*.yaml)",
      "Bash(git *)",
      "Bash(python *)",
      "Bash(python3 *)",
      "Bash(pip *)",
      "Bash(pip3 *)",
      "Bash(uv *)",
      "Bash(pytest *)",
      "Bash(ruff *)",
      "Bash(black *)"
    ],
    "deny": [
      "Read(.env)",
      "Read(**/secrets/**)"
    ]
  }
}
```

---

## Java + Node 前端 + Python 全栈项目（合并配置）

适合 monorepo 或多语言项目，放在项目根目录 `.claude/settings.json`：

```json
{
  "permissions": {
    "allow": [
      "Read(**/*)",
      "Edit(**/*.java)",
      "Edit(**/*.py)",
      "Edit(**/*.js)",
      "Edit(**/*.ts)",
      "Edit(**/*.jsx)",
      "Edit(**/*.tsx)",
      "Edit(**/*.css)",
      "Edit(**/*.html)",
      "Edit(**/*.json)",
      "Edit(**/*.yml)",
      "Edit(**/*.yaml)",
      "Edit(**/*.xml)",
      "Edit(**/pom.xml)",
      "Edit(**/build.gradle)",
      "Edit(**/requirements*.txt)",
      "Edit(**/pyproject.toml)",
      "Bash(git *)",
      "Bash(mvn *)",
      "Bash(gradle *)",
      "Bash(java *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(node *)",
      "Bash(bun *)",
      "Bash(pnpm *)",
      "Bash(python *)",
      "Bash(python3 *)",
      "Bash(pip *)",
      "Bash(uv *)",
      "Bash(pytest *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Read(.env)",
      "Read(.env.local)",
      "Read(.env.production)",
      "Read(**/application-prod.yml)",
      "Read(**/secrets/**)",
      "WebFetch"
    ]
  }
}
```

---

## 实用建议

1. **个人开发机**：在 `~/.claude/settings.json` 配置全局 allow，所有项目复用，省去重复配置。
2. **团队项目**：`.claude/settings.json` 只放安全的 allow 规则并提交 git；敏感或个人配置放 `.claude/settings.local.json`（已自动 gitignore）。
3. **生产环境保护**：始终在 deny 中加入 `.env`、`secrets/`、生产配置文件。
4. **快速验证配置**：运行 `claude /config` 可在交互界面查看当前生效的权限状态。

---

## 权限规则语法参考

| 规则 | 说明 | 示例 |
|------|------|------|
| `Read(pattern)` | 读取文件权限 | `Read(**/*.java)` |
| `Edit(pattern)` | 编辑文件权限 | `Edit(**/src/**)`  |
| `Bash(pattern)` | 执行命令权限 | `Bash(git *)` |
| `WebFetch` | 网络请求权限 | `WebFetch` |
| `**` | 匹配任意路径 | `Read(**/*.env)` |
| `*` | 匹配单层通配 | `Bash(npm *)` |

---

*来源：[Claude Code 官方文档](https://code.claude.com/docs/en/settings)*
