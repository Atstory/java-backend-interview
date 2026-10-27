# Vue 项目使用 shadcn/ui 接入说明

> 更新时间：2026-03-26

## 结论

截至 2026-03-26，**Vue 项目不能直接按原版 `shadcn/ui` 官方 React 文档接入**。

如果你的项目是：

- `Vue 3 + Vite`
- `Nuxt 3`

推荐使用 **`shadcn-vue`**，这是面向 Vue 生态的实现方案，使用方式和 `shadcn/ui` 的思想基本一致：通过 CLI 将组件代码直接加到你的项目里，而不是单纯安装一个组件库包。

## 适用场景

### 1. React 项目

如果你的项目是以下之一：

- `React`
- `Next.js`
- `Vite React`

应使用原版 `shadcn/ui`：

- 官方文档：<https://ui.shadcn.com/docs/installation>

### 2. Vue 项目

如果你的项目是以下之一：

- `Vue 3`
- `Vite + Vue`
- `Nuxt 3`

应使用 `shadcn-vue`：

- 官方文档：<https://www.shadcn-vue.com/docs/installation>

## 为什么 Vue 不能直接用原版 shadcn/ui

原因很简单：

- 原版 `shadcn/ui` 官方组件代码是基于 `React` 写的
- 组件实现依赖 React 生态的写法和约定
- Vue 项目即使能照着安装部分依赖，也无法直接使用官方 React 组件源码

因此，Vue 里正确做法不是“强行接原版”，而是改用 **Vue 版适配实现 `shadcn-vue`**

## Vue 项目推荐接入方案

下面以 **Vue 3 + Vite + TypeScript** 为例。

## 一、安装 Tailwind

如果你的项目还没有接入 Tailwind，先安装：

```bash
pnpm add tailwindcss @tailwindcss/vite
```

如果你使用 `npm`：

```bash
npm install tailwindcss @tailwindcss/vite
```

如果你使用 `yarn`：

```bash
yarn add tailwindcss @tailwindcss/vite
```

## 二、配置 `vite.config.ts`

示例：

```ts
import path from 'node:path'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

### 说明

- `@` 别名是后续 `shadcn-vue` 组件导入的常见路径前缀
- 不建议省略，否则后面手动修路径会比较乱

## 三、配置 TypeScript 路径别名

在 `tsconfig.json` 或 `tsconfig.app.json` 中加入：

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

## 四、引入 Tailwind 样式

在你的主样式文件中添加：

例如 `src/style.css`：

```css
@import "tailwindcss";
```

然后在入口文件中确保该样式已被引入。

例如 `src/main.ts`：

```ts
import './style.css'
```

## 五、初始化 shadcn-vue

执行：

```bash
pnpm dlx shadcn-vue@latest init
```

或：

```bash
npx shadcn-vue@latest init
```

执行过程中通常会让你确认：

- 组件输出目录
- 样式文件位置
- 组件别名前缀
- 是否生成 `components.json`

一般按默认推荐即可。

## 六、添加组件

例如添加 `button` 组件：

```bash
pnpm dlx shadcn-vue@latest add button
```

或：

```bash
npx shadcn-vue@latest add button
```

执行后，组件代码通常会被写入类似目录：

```text
src/components/ui/button/
```

## 七、在 Vue 页面中使用

示例：

```vue
<script setup lang="ts">
import { Button } from '@/components/ui/button'
</script>

<template>
  <Button>Click me</Button>
</template>
```

## 手动安装方式

如果你不想使用 CLI 初始化，也可以按 `shadcn-vue` 官方手动安装方案处理。

常见需要的依赖包括：

```bash
pnpm add class-variance-authority clsx tailwind-merge lucide-vue-next tw-animate-css
```

手动方式通常还需要你自己补这些内容：

- `cn` 工具函数
- `components.json`
- Tailwind 主题变量
- 基础 UI 目录结构

因此，如果不是有特殊定制需求，**更推荐直接使用 CLI 初始化**

## 推荐目录结构

一个比较常见的 Vue 项目结构如下：

```text
src/
  components/
    ui/
      button/
      input/
      dialog/
  lib/
    utils.ts
  style.css
  App.vue
  main.ts
```

## 常见问题

### 1. 为什么执行了 `init` 但组件不能正常显示

常见原因：

- Tailwind 没有正确接入
- 样式文件没有在入口文件中导入
- `@` 路径别名没有配置
- TypeScript 路径配置和 Vite 路径配置不一致

### 2. 为什么 Vue 项目里搜到的很多教程是 `shadcn/ui`

因为很多文章会用“shadcn/ui”泛指这一套设计和组件组织方式，但真正到 Vue 落地时，通常实际指的是 **`shadcn-vue`**

### 3. Nuxt 3 能不能用

可以。  
Nuxt 3 推荐直接看 `shadcn-vue` 的 Nuxt 安装文档，不建议完全照搬 Vite 的步骤。

## 推荐做法

如果你现在要在 Vue 项目里落地，我的建议是：

1. 先确认你项目是不是 `Vue 3 + Vite` 或 `Nuxt 3`
2. 接入 Tailwind
3. 使用 `shadcn-vue` 的 CLI 初始化
4. 先添加最常用的基础组件

建议优先添加：

- `button`
- `input`
- `card`
- `dialog`
- `dropdown-menu`
- `form`

这样后续搭页面效率最高。

## 相关链接

- `shadcn/ui` 官方安装文档  
  <https://ui.shadcn.com/docs/installation>

- `shadcn/ui` 官方 Vite 文档  
  <https://ui.shadcn.com/docs/installation/vite>

- `shadcn-vue` 官方安装文档  
  <https://www.shadcn-vue.com/docs/installation>

- `shadcn-vue` 官方 Vite 安装文档  
  <https://www.shadcn-vue.com/docs/installation/vite>

- `shadcn-vue` 手动安装文档  
  <https://www.shadcn-vue.com/docs/installation/manual>

- `shadcn-vue` GitHub  
  <https://github.com/unovue/shadcn-vue>

## 一句话总结

**Vue 项目不要直接接原版 `shadcn/ui`，应使用 `shadcn-vue`。**

