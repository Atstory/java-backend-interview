# Dirac 声波动画 - 1:1 复刻版

完整复刻 Dirac.com 官网的滚动驱动声波动画效果。

## 📁 文件说明

- `index.html` - 完整的单文件实现，包含 HTML + CSS + JavaScript
- 无需任何依赖，直接用浏览器打开即可运行

## ✨ 功能特性

### 🎬 四阶段动画

1. **阶段1 (0-25%)** - 单侧横向波形（青色）
   - 代表原始失真的声音
   - 正弦波动画

2. **阶段2 (25-50%)** - 对称双波形（青色+红色）
   - 代表识别声音缺陷
   - 左右镜像波动

3. **阶段3 (50-75%)** - 3D网格形成（白色）
   - 代表算法处理过程
   - 2D到3D的平滑过渡

4. **阶段4 (75-100%)** - 完整3D波形（白色+光晕）
   - 代表完美校正后的效果
   - 复杂的三维波形

### 🎯 技术亮点

- ✅ **Sticky定位** - Canvas固定在视口，文字正常滚动
- ✅ **滚动驱动** - 根据滚动位置实时计算动画进度
- ✅ **Canvas绘制** - 高性能实时渲染
- ✅ **高DPI适配** - 支持Retina等高分辨率屏幕
- ✅ **RAF优化** - requestAnimationFrame确保60fps流畅动画
- ✅ **响应式设计** - 完美适配移动端和桌面端

### 🐛 调试模式

按键盘 **D 键**开启/关闭调试面板，显示：
- 当前滚动进度百分比
- 当前动画阶段
- 实时帧率（FPS）

## 🚀 使用方法

### 方法1：直接打开
```bash
# Windows
start index.html

# 或者双击 index.html 文件
```

### 方法2：本地服务器（推荐）
```bash
# 使用 Python
python -m http.server 8000

# 使用 Node.js
npx serve

# 然后访问 http://localhost:8000
```

## 📐 核心技术原理

### 1. 滚动进度计算
```javascript
// 容器高度 = 400vh (4倍屏高)
// 可滚动距离 = 容器高度 - 视口高度
// 滚动进度 = 已滚动距离 / 可滚动距离
scrollProgress = Math.max(0, Math.min(1, scrolled / scrollableHeight))
```

### 2. 波形数学公式

**简单正弦波（阶段1）**
```javascript
offset = A * sin(f * i + φ)
// A = 振幅, f = 频率, φ = 相位（时间）
```

**复合波形（阶段2）**
```javascript
offset = sin(i * 0.2 + phase) * 100 + sin(i * 0.15 + phase * 1.5) * 60
```

**3D波形（阶段3、4）**
```javascript
wave = sin(x * 0.1 + phase) * cos(z * 0.1 + phase) * 15
```

### 3. 3D到2D投影
```javascript
screenX = centerX + x * scale
screenY = centerY + z * perspective * 3 + wave * 10
```

## 🎨 设计系统

### 颜色
- 背景：`#000000` (纯黑)
- 文字：`#ffffff` (纯白)
- 青色波形：`#00ffff`
- 红色波形：`#ff6464`

### 字体
- 字重：300 (Light)
- 行高：1.2
- 大小：响应式 clamp()

### 间距
- 容器高度：400vh
- 每屏：100vh
- 左右边距：2-4rem

## 🔧 自定义配置

修改 `config` 对象可调整动画参数：

```javascript
const config = {
  lineCount: 80,       // 线条数量（越多越密集）
  lineSpacing: 8,      // 线条间距
  lineWidth: 2,        // 线条粗细
  animationSpeed: 0.0008, // 动画速度
  
  colors: {
    cyan: '#00ffff',   // 自定义颜色
    red: '#ff6464',
    white: '#ffffff'
  }
};
```

## ⚡ 性能优化

1. **requestAnimationFrame节流** - 滚动事件最多60fps触发
2. **高DPI适配** - 自动根据设备像素比调整Canvas分辨率
3. **被动事件监听** - `{ passive: true }` 避免阻塞滚动
4. **清空画布优化** - 每帧前清空，避免残影

## 📱 浏览器兼容性

- ✅ Chrome 60+
- ✅ Firefox 55+
- ✅ Safari 11+
- ✅ Edge 79+
- ✅ 移动端浏览器

## 🎓 学习要点

### 核心概念
1. **Sticky定位** - `position: sticky` 实现固定效果
2. **Canvas API** - 2D绘图上下文的使用
3. **滚动监听** - `scroll` 事件 + RAF优化
4. **数学应用** - 三角函数创建波形
5. **3D投影** - 简化的透视投影算法

### 进阶技巧
- 多频率波形叠加
- 透明度渐变模拟深度
- 径向渐变创建光晕
- 响应式设计模式

## 📚 扩展方向

### 可以添加的功能
- [ ] 音频播放器集成
- [ ] 鼠标交互效果
- [ ] 更多动画阶段
- [ ] WebGL版本（Three.js）
- [ ] 触摸手势支持
- [ ] 性能监控面板

### Three.js 版本
如需更强大的3D效果，可以使用 Three.js：
- 真实的3D几何体
- 光照和阴影
- 后期处理效果
- 更复杂的动画

## 🐛 已知问题

- 在低端设备上可能出现掉帧（可降低 lineCount）
- Safari 旧版本可能需要添加 `-webkit-` 前缀

## 💡 提示

1. **流畅滚动** - 确保浏览器硬件加速已开启
2. **调试** - 按 D 键查看实时参数
3. **性能** - 如果卡顿，减小 lineCount 或 gridSize
4. **修改** - 所有代码都在 index.html 中，方便编辑

## 📞 技术支持

如有问题或建议，欢迎反馈！

---

**Made with ❤️ - 1:1 复刻 Dirac.com 声波动画**
