# Asstar 网站 Canvas 动效分析与复刻提示词

## 分析对象
- 页面：`https://asstar-x.github.io/index.html`
- 关键脚本：`https://asstar-x.github.io/js/script.js`
- 关键脚本：`https://asstar-x.github.io/js/time-rift.js`
- 分析时间：`2026-03-06`

## 先说结论
这个站首页的“canvas 动效”本质上不是单一效果，而是三层组合：

1. **全屏背景宇宙层**
   - 使用 `Three.js` 创建 `WebGLRenderer`
   - 挂载到 `#canvas-container`
   - 表现为全屏星尘 / 粒子宇宙 / 视差跟随

2. **Hero 区 3D 粒子球层**
   - 同样使用 `Three.js`
   - 挂载到 `#hero-3d-container`
   - 表现为可旋转、会呼吸、可点击“觉醒”的粒子球

3. **页面切换层**
   - 不是 canvas
   - 主要由 `time-rift.js` + CSS 3D transform 完成时空裂隙式分段切换

所以如果你要复刻，重点不是写一个普通 `canvas` 粒子网，而是：
**Three.js 全屏背景 + Three.js Hero 粒子球 + CSS/JS 分段透视滚动。**

## 主页真正启用的是哪套背景
代码里同时存在两套背景方案：

### 方案 A：`AntigravityBackground`
- 2D Canvas 粒子连线
- 使用 `canvas.getContext('2d')`
- 鼠标靠近时粒子被排斥
- 粒子之间画细线
- 目标节点是 `canvas-background`

### 方案 B：`CosmicUniverse`
- `Three.js` WebGL 粒子宇宙
- 目标容器是 `canvas-container`
- 使用两层粒子云 + 视差摄像机 + 缓慢旋转

### 当前首页实际生效的结论
首页 HTML 中存在的是：
- `#canvas-container`
- `#hero-3d-container`

首页没有看到真正用于 2D 背景的 `canvas-background` 主容器，因此：
**首页主背景实际跑的是 `CosmicUniverse`，不是 `AntigravityBackground`。**

也就是说，你看到的主视觉背景是 **Three.js WebGL 粒子宇宙**，不是传统 2D canvas 连线网格。

## 背景宇宙层怎么做的
这个效果在 `script.js` 的 `CosmicUniverse` 类里。

### 实现结构
1. 创建 `THREE.Scene()`
2. 添加指数雾 `FogExp2(0x050505, 0.002)`
3. 创建透视相机 `PerspectiveCamera(75, aspect, 0.1, 1000)`
4. 相机初始 `z = 5`
5. 创建透明 WebGL 渲染器：
   - `antialias: true`
   - `alpha: true`
6. 渲染器挂到 `#canvas-container`
7. 建两层粒子：
   - 第一层白色粒子云
   - 第二层蓝色背景星点
8. 鼠标移动时：
   - 粒子层旋转产生视差
   - 摄像机位置缓动跟随鼠标
9. `requestAnimationFrame` 持续渲染

### 粒子参数
#### 第一层主粒子云
- 数量：`3000`
- 空间分布：`(Math.random() - 0.5) * 25`
- 材质：`PointsMaterial`
- 大小：`0.03`
- 颜色：白色 `0xffffff`
- 透明度：`0.8`
- 混合模式：`AdditiveBlending`

#### 第二层背景星点
- 数量：`5000`
- 空间分布：`(Math.random() - 0.5) * 80`
- 大小：`0.05`
- 颜色：蓝色 `0x88ccff`
- 透明度：`0.6`
- 混合模式：`AdditiveBlending`

### 动起来的原因
它的动效并不复杂，核心只有三件事：

1. **自动旋转**
   - 主粒子层：`rotation.y = elapsed * 0.05`
   - 主粒子层：`rotation.x = elapsed * 0.02`
   - 背景星层：`rotation.y = elapsed * 0.01`

2. **鼠标视差**
   - 鼠标位置被换算成 `mouseX / mouseY`
   - 粒子层的旋转缓慢追向目标值
   - 摄像机位置也缓慢追向目标值

3. **镜头入场**
   - 使用 `gsap.from(camera.position, { z: 10, duration: 3 })`
   - 打开页面时会有轻微推进感

### 为什么它看起来高级
不是因为算法很重，而是因为这几个点叠加得比较对：
- 深色背景 + 雾化
- 双层粒子形成深度差
- 加色混合让粒子发光
- 鼠标缓动不是硬跟随，而是有惯性
- 相机也在动，所以空间感更强

## Hero 粒子球怎么做的
Hero 视觉不是普通球体，而是 **点云球 + 波动噪声 + 几何形态切换**。

### 基础结构
1. 建立 `Scene / Camera / Renderer`
2. 使用 `SphereGeometry(8, 128, 128)`
3. 使用 `PointsMaterial`
4. 把球体几何体按“顶点”渲染成 `THREE.Points`
5. 为每个点单独写入颜色
6. 在动画循环里持续改写顶点坐标

### 材质参数
- 点大小：`0.1`
- 透明：`true`
- 透明度：`0.85`
- `vertexColors: true`
- `AdditiveBlending`

### 颜色设计
颜色不是单色，而是按比例随机混色：
- 靛蓝 `0x0a0a2a`
- 紫色 `0x8a2be2`
- 青色 `0x00d2ff`
- 白色 `0xffffff`

这让球体在静止时就有“赛博能量体”的质感。

### 球体为什么会“呼吸”
动画循环里，代码不是直接旋转球，而是每帧重新计算点位置：

1. 读取原始球面坐标
2. 用三角函数组合出伪噪声：
   - `sin(px * 0.5 + t)`
   - `cos(py * 0.3 + t)`
   - `sin(pz * 0.5 + t)`
3. 生成位移系数 `displacement`
4. 将点沿原方向轻微放大 / 缩小

因此最终效果是：
**球体表面像在轻微脉冲、流动、呼吸。**

### 点击“觉醒”是怎么做的
这部分是整页最有意思的地方。

作者并不是切换贴图，而是准备了第二套目标顶点位置：`awakePositions`。

#### `awakePositions` 的本质
它不是球，而是一个接近“钟形 / 高斯山丘”的点云形态：
- 在圆盘范围内随机取样
- 根据二维高斯函数算出高度 `y`
- 得到一组新的目标坐标

也就是说，点击后粒子球会从：
- **混沌脉冲球体**
逐渐变成：
- **秩序化的高斯钟形结构**

#### 过渡方法
借助 GSAP 动画一个进度值：
- `pulseObj.progress: 0 -> 1`

在每帧中按这个进度做插值：
- `chaosPosition` 和 `awakePosition` 之间线性混合

所以你看到的不是“切换”，而是“形态演化”。

### 交互手感怎么做的
Hero 粒子球的手感来自三种缓动：

1. **位置磁吸**
   - 球体位置朝鼠标方向慢慢靠近
   - 不是瞬移，是插值追随

2. **缩放弹性**
   - 鼠标离中心越远，球体缩放越大
   - 点击时额外做一次短促脉冲放大

3. **旋转追随**
   - 基础自转一直存在
   - `x / z` 旋转再缓慢朝鼠标方向偏转

所以它看起来像“会回应你的能量体”。

## `time-rift.js` 的作用
这个文件主要负责页面 section 切换，不是 canvas 本体。

它的做法是：
- 维护一个当前进度 `currentProgress`
- 维护一个目标进度 `targetProgress`
- 在渲染循环里做插值
- 按 section 与当前焦点的距离，动态设置：
  - `translate3d`
  - `scale`
  - `opacity`
  - `z-index`
  - `pointer-events`

本质上是：
**用 DOM + CSS 3D transform，伪装出穿越式时空滚动。**

所以如果你想复刻首页整体味道，不能只做 canvas，还要把 section 的纵深切换一并做出来。

## 如果你要复刻，建议怎么拆
推荐技术栈：
- `Vite`
- `Three.js`
- `GSAP`
- 原生 CSS 或 `Tailwind` 都可

推荐拆成 3 个模块：

### 模块 1：全屏宇宙背景
职责：只负责全屏背景粒子宇宙

需要实现：
- 全屏固定定位容器
- `Three.Scene + Camera + WebGLRenderer`
- 两层点云
- 自动旋转
- 鼠标视差
- Resize 自适应
- `devicePixelRatio` 上限控制

### 模块 2：Hero 粒子球
职责：只负责页面首屏视觉主体

需要实现：
- `SphereGeometry + PointsMaterial`
- 顶点颜色渐变
- 每帧顶点扰动
- 备用目标几何 `awakePositions`
- 点击切换形态
- 鼠标磁吸 / 缩放 / 旋转反馈
- 文案提示 `[ CLICK TO AWAKE ]`

### 模块 3：Section 时空切换
职责：负责首页多个 section 的透视滚动

需要实现：
- section 分段绝对定位
- `targetProgress / currentProgress`
- 统一 render loop
- `translate3d + scale + opacity`
- 键盘 / 鼠标滚轮 / 点击导航切换

## 复刻时最容易踩的坑
### 1. 把所有效果堆进一个类
不建议。

原因：
- 背景层、Hero 层、Section 切换的职责不同
- 后续调性能和调交互会很痛苦

### 2. 粒子数量过大
这个站的视觉靠的是：
- 层次
- 颜色
- 缓动
- 深度感

不是单纯靠“海量粒子”。

建议初版：
- 背景主粒子：`1200 ~ 2000`
- 背景星点：`2000 ~ 3500`
- Hero 粒子球：先控制在中等细分即可

如果直接拉太高：
- 手机会掉帧
- 高分屏笔记本会发热

### 3. 不限制像素比
建议：
- `renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))`

否则 3K / 4K 屏下代价很高。

### 4. 鼠标跟随太硬
一定要用插值：
- 位置插值
- 旋转插值
- 缩放插值

否则会像“普通跟手动画”，没有高级感。

### 5. 忽略移动端降级
建议移动端：
- 降低粒子数量
- 减少实时形变频率
- 关闭过重的点击形态切换
- 降低雾和发光强度

## 我建议你的复刻策略
如果你的目标是“像它”，不是“逐行抄它”，建议按下面顺序做：

1. 先复刻全屏宇宙背景
2. 再复刻 Hero 粒子球
3. 最后再补 section 时空切换

原因很简单：
- 背景层最稳
- Hero 粒子球最出效果
- section 切换最容易牵连布局结构

## 可直接使用的提示词
下面给你几套可直接喂给 Codex / ChatGPT / Cursor / Claude 的提示词。

### 提示词 1：高保真复刻版
```text
请帮我用 Vite + Three.js + GSAP 实现一个高保真首页动效，视觉风格参考 https://asstar-x.github.io/index.html ，但不要直接复制原站文案与资源。

要求：
1. 页面为深色科幻风，背景接近宇宙星尘。
2. 背景必须是全屏固定的 Three.js WebGL 粒子宇宙，而不是普通 CSS 背景。
3. 背景至少两层粒子：
   - 前层白色粒子云，带轻微旋转
   - 后层蓝色星点，分布更大更稀疏
4. 鼠标移动时要有高级感的视差：
   - 粒子层旋转缓动跟随
   - 相机位置轻微缓动跟随
   - 不要生硬直接跟随
5. Hero 区域实现一个 Three.js 粒子球：
   - 使用 SphereGeometry + PointsMaterial
   - 支持 vertexColors
   - 颜色从靛蓝、紫色、青色、白色之间混合
   - 球体表面每帧做轻微噪声形变，产生呼吸感和流动感
6. Hero 粒子球支持交互：
   - 鼠标移动时，球体有磁吸式位置偏移
   - 球体旋转和缩放都要有缓动
   - 点击后，球体从混沌球状渐变为秩序化的高斯钟形点云
   - 使用 GSAP 控制 morph 进度和脉冲放大
7. 页面 section 切换要有时空穿越感：
   - 使用 translate3d、scale、opacity、z-index 做纵深切换
   - 使用 requestAnimationFrame 驱动 currentProgress 向 targetProgress 缓动
8. 必须考虑性能：
   - 限制 renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
   - 移动端自动降低粒子数量
   - 结构拆分清晰，背景层、Hero 层、Section 切换分别封装
9. 输出完整项目代码，包含：
   - 目录结构
   - 依赖安装命令
   - 关键组件代码
   - 每段关键代码都加详细注释
10. 不要只给思路，直接给可运行代码。
```

### 提示词 2：工程化复刻版
```text
请你作为资深前端图形工程师，帮我设计并实现一个可维护的首页动效系统，技术栈使用 Vite + Three.js + GSAP。

目标效果：类似高端科幻网站首页，包含全屏宇宙背景、首屏粒子球、带纵深感的 section 切换。

请按下面要求输出：
1. 先给出模块划分方案：BackgroundUniverse、HeroParticleSphere、RiftSections。
2. 每个模块说明职责、输入参数、生命周期、性能风险。
3. 然后直接给出完整代码。
4. 背景层要用 WebGL 粒子系统，不要用 2D canvas 连线网格。
5. Hero 粒子球要支持 morph：sphere -> gaussian hill。
6. 鼠标交互必须使用 lerp / easing，不允许硬跟随。
7. 代码要适合后续接入 React。
8. 需要提供移动端降级策略和性能优化点。
```

### 提示词 3：低成本近似版
```text
请帮我实现一个低成本但观感接近高端科幻首页的动效方案。

技术要求：
- 仍使用 Three.js
- 优先保证 60fps
- 降低粒子数量
- 减少复杂 morph 计算
- 保留以下核心观感：深空背景、双层粒子、鼠标视差、首屏能量球、轻微呼吸感

请直接给出一套更适合中低配设备的实现代码，并解释相比高保真版做了哪些取舍。
```

## 如果你想让 AI 生成得更像，提示词还要补哪些信息
你可以继续补这几类约束：

### 视觉约束
- 主色：深黑、靛蓝、紫、青
- 氛围词：未来感、静谧、深空、克制、神秘、非游戏化
- 不要：炫彩过度、霓虹太杂、廉价赛博朋克

### 交互约束
- 鼠标反馈必须有惯性
- 动画要慢，不要抖动
- 点击反馈要有“能量脉冲”感
- 页面整体偏高级品牌站，不是作品集模板站

### 工程约束
- 模块解耦
- 支持移动端降级
- 支持后续替换文案与图片
- 不依赖大型 UI 框架

### 性能约束
- 目标桌面端 60fps
- 移动端优先流畅而非完全一致
- 控制 GPU 压力
- 页面隐藏时暂停渲染

## 最后给你的实话建议
如果你只是想“做出这个味道”，最值钱的不是逐行抄源码，而是抓住下面 5 个核心：

1. 深色宇宙背景
2. 双层粒子制造空间深度
3. Hero 能量球用点云而不是实体网格
4. 鼠标交互全部走缓动
5. section 切换要有纵深透视感

只要这 5 个点到位，最终效果就会很接近。

如果只复刻一个普通粒子背景，味道会差很多。
