# Asstar 首页 Canvas 动效拆解与复刻提示词

> 采样时间：2026-03-06（基于线上源码）

## 1. 一句话结论
这个站的“高级感动效”不是单一 Canvas，而是 **多层叠加**：
- 背景层：Three.js 全屏星空粒子（WebGL canvas）
- 内容层：普通 DOM + CSS 动效 + 时间裂缝式 3D section 切换
- Hero 层：第二个 Three.js 粒子球 canvas（局部）
- 质感层：固定噪点遮罩（CSS data-uri）

核心观感来自“**双 WebGL + DOM 过渡 + 交互吸附**”的组合。

## 2. 结构拆解（你要复刻的关键）

### 2.1 背景 Canvas（全屏宇宙）
实现位置：`js/script.js` 中 `CosmicUniverse` 类。

主要做法：
- `THREE.Scene + FogExp2`
- `THREE.PerspectiveCamera`
- `THREE.WebGLRenderer({ antialias: true, alpha: true })`
- 两层 `Points`：
  - 前景粒子约 3000
  - 背景蓝色星点约 5000
- `requestAnimationFrame` 循环里做：
  - 缓慢自转
  - 鼠标驱动的视差旋转
  - 相机位置缓动（parallax）

性能处理：
- `renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))`（限制 DPR，防止 4K 屏爆算力）

### 2.2 Hero Canvas（粒子球）
实现位置：`index.html` 内联脚本（`#hero-3d-container`）。

主要做法：
- 用 `SphereGeometry(8,128,128)` 采样为点云 (`THREE.Points`)
- 点位按三角函数噪声做“呼吸形变”
- 维护两套状态：
  - chaos（混沌）
  - awake（高斯钟形有序态）
- 点击时用 GSAP 改 `progress`，实现 chaos -> awake 过渡
- 鼠标靠近时做“磁吸 + 弹性缩放 + 追随旋转”

### 2.3 非 Canvas 但很关键的“高级感”来源
- `time-rift.js`：所有 section 用 `translate3d + scale + opacity` 做时空切片切换
- SVG 星系时间轴（项目区）：路径 + 光子沿路径运动 + 节点漂浮
- 噪点蒙层：提升电影质感

## 3. 为什么它看起来“贵”
不是因为算法特别复杂，而是以下组合正确：
- 分层：背景慢、前景快、交互层灵敏
- 对比：深色底 + 少量高亮粒子 + additive blending
- 缓动：所有交互都不是硬跟随，而是 lerp/gsap 缓动
- 叙事：Hero 有“未觉醒 -> 觉醒”的状态机，不是单纯旋转球

## 4. 你复刻时最容易踩坑
- 只做一个 Canvas：会“像特效演示”，不像完整网站
- 粒子数过高 + DPR 不限：移动端直接掉帧
- 交互无阻尼：鼠标一动就抖，廉价感明显
- 所有层都在动：视觉噪音大，主信息不可读

## 5. 复刻路线（建议）
1. 先做全屏星空（第一层）
2. 再做 Hero 粒子球（第二层）
3. 最后加 section 切换和 SVG 时间轴（第三层）
4. 最后做性能压测（移动端优先）

最低可用参数建议：
- 背景粒子：桌面 2000~3500，移动端 800~1500
- 背景远星：桌面 3000~5000，移动端 1200~2500
- Hero 点云：3k~8k 点
- `pixelRatio`: `Math.min(devicePixelRatio, 1.5~2)`

## 6. 可直接复制的提示词（最实用）

### 提示词 A：一把出“可运行复刻版”（推荐）
```text
你是资深前端图形工程师。请用原生 HTML/CSS/JavaScript + Three.js + GSAP，生成一个单页网站，视觉风格参考 asstar-x.github.io 首页，但不要复制其源码。

目标：
1) 全屏背景 WebGL 星空粒子（两层 Points，AdditiveBlending，带 Fog）
2) Hero 区域一个独立的 WebGL 点云球体，可鼠标磁吸、缓动旋转、呼吸形变
3) 点击 Hero 球体触发“混沌->有序”状态过渡（progress 驱动）
4) 增加轻量噪点遮罩层（CSS）
5) section 切换使用 translate3d + scale + opacity 的时间裂缝感过渡

工程要求：
- 输出完整可运行代码（一个 index.html + 一个 main.js + 一个 styles.css）
- 代码注释清晰，函数命名语义化
- 必须做性能保护：DPR 上限、窗口 resize、防止内存泄漏、移动端自动降级粒子数
- 动画参数集中到 CONFIG 对象，便于调参
- 不要引入框架，不要用 TypeScript

验收标准：
- 60fps 目标（中端笔记本）
- 移动端不花屏，交互平滑
- 视觉层级清楚：背景<内容<交互提示
```

### 提示词 B：让 AI 先产“架构”，再写代码（更稳）
```text
先不要写代码。先给我一个 Web 动效架构设计：
- 分层设计（背景 WebGL、Hero WebGL、DOM 内容层、遮罩层）
- 每层职责、渲染顺序、z-index 规则
- 动画循环如何组织（一个 RAF 还是多个 RAF）
- 性能策略（粒子预算、DPR、降级开关、暂停策略）
- 交互策略（鼠标/触摸/滚轮）

然后再按该设计输出代码。
```

### 提示词 C：专门优化卡顿
```text
请对我现有 Three.js 粒子页面做性能体检，输出：
1) 明确瓶颈点（CPU/GPU/布局重排）
2) 逐条优化建议（含优先级）
3) 可直接替换的代码片段
4) 目标：移动端 FPS 提升到 45+，桌面端 60fps 稳定

请重点检查：
- requestAnimationFrame 内是否有对象频繁创建
- BufferGeometry 更新粒度
- pixelRatio 上限
- 粒子数量按设备分档
- 事件监听是否可清理
```

## 7. 复刻时的最小实现骨架
你至少要有这 3 个模块：
- `initBackgroundUniverse()`：全屏星空
- `initHeroParticleSphere()`：Hero 交互球
- `initRiftSections()`：section 3D 过渡

如果少了任何一个，效果都会像“半成品”。

## 8. 源码参考（本次分析依据）
- 首页：<https://asstar-x.github.io/index.html>
- 背景与时间轴脚本：<https://asstar-x.github.io/js/script.js>
- 时间裂缝滚动脚本：<https://asstar-x.github.io/js/time-rift.js>
- 样式：<https://asstar-x.github.io/css/styles.css>
- 裂缝样式：<https://asstar-x.github.io/css/time-rift.css>
- Three.js 版本来源：<https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js>
- GSAP 版本来源：<https://cdnjs.cloudflare.com/ajax/libs/gsap/3.9.1/gsap.min.js>
