# 视觉保真度手册

使 SwiftUI 输出匹配 Figma 设计的流程和清单。这是"让它看起来像 Figma"的权威参考。

## 目录

- [1. 解析 `design-context.md`](#1-解析-design-contextmd)
- [2. 真实依据优先级](#2-真实依据优先级)
- [3. 视觉清单模板](#3-视觉清单模板)
- [4. 破坏保真度的 SwiftUI 默认值](#4-破坏保真度的-swiftui-默认值)
- [5. 截图交叉核对](#5-截图交叉核对)
- [6. 常见预检](#6-常见预检)
- [7. 硬性规则](#7-硬性规则)

此文件涵盖：
1. 如何将 `design-context.md`（MCP 响应）解析为精确值
2. 多个缓存不一致时的真实依据规则
3. 视觉清单模板（严格）
4. 默默破坏保真度的 SwiftUI 默认值
5. 截图交叉核对流程

---

## 1. 解析 `design-context.md`

`get_design_context` 返回 React + Tailwind 风格的代码加内联 `style` 对象。它是**规范载体**，不是要移植的代码。从中提取精确值。

### Tailwind class → 精确值

默认 Tailwind 比例（Figma MCP 使用此比例，除非值不匹配，此时使用 `[arbitrary]` 语法）：

| Class | 值 |
|---|---|
| `p-1`、`p-2`、`p-3`、`p-4`、`p-6`、`p-8` | 4、8、12、16、24、32pt |
| `gap-1`、`gap-2`、`gap-3`、`gap-4`、`gap-6` | 4、8、12、16、24pt |
| `text-xs` / `text-sm` / `text-base` / `text-lg` / `text-xl` / `text-2xl` / `text-3xl` | 12 / 14 / 16 / 18 / 20 / 24 / 30pt |
| `font-normal` / `medium` / `semibold` / `bold` | .regular / .medium / .semibold / .bold |
| `rounded` / `-md` / `-lg` / `-xl` / `-2xl` / `-3xl` / `-full` | 4 / 6 / 8 / 12 / 16 / 24 / Capsule |
| `leading-none` / `-tight` / `-snug` / `-normal` / `-relaxed` / `-loose` | 1.0 / 1.25 / 1.375 / 1.5 / 1.625 / 2.0 × fontSize |
| `tracking-tight` / `-normal` / `-wide` | -0.025em / 0 / 0.025em |

### 任意值——按字面取

当 Figma 值不匹配默认比例时，MCP 发出 `[arbitrary]`：
- `p-[17px]` → 17pt padding（不是 16）
- `text-[15px]` → 15pt 字体（不是 14 或 16）
- `rounded-[10px]` → 10pt 圆角
- `leading-[22px]` → 22pt 行高（绝对值，不是乘数）
- `tracking-[-0.32px]` → -0.32pt 字间距

**规则：任意值是权威的。绝不将它们四舍五入到最近的 Tailwind 默认值。**

### 颜色 class

- `bg-white`、`bg-black` → `Color.white`、`Color.black`
- `bg-[#F5F5F5]` → `Color(hex: "F5F5F5")` 或匹配的项目颜色
- `bg-white/50` → `.white.opacity(0.5)`
- `bg-[#000000]/80` → `Color(hex: "000000").opacity(0.8)`
- Tailwind 调色板（`bg-gray-500` 等）→ 如果项目映射了则通过 tokens.json 转换；否则从 MCP 通常同时发出的内联样式中取 hex。

### 内联样式块

MCP 经常发出覆盖 Tailwind 的显式样式对象。信任这些而非 class 名：

```jsx
style={{
  fontFamily: 'SF Pro Display',
  fontWeight: '600',
  fontSize: '17px',
  lineHeight: '22px',
  letterSpacing: '-0.32px',
  color: '#1C1C1E'
}}
```

这里的每个字段都是要携带到 SwiftUI 的值。**不要丢弃字段**，因为"Font.system 默认处理它"——它不会。

### Figma 特定注释

MCP 有时注入注释，如 `// Auto layout: vertical, gap 12, padding 16` 或 `// Fill: linear gradient from #FF0080 to #7928CA`。存在时这些是权威的。

---

## 2. 真实依据优先级

当多个缓存对某个值不一致时：

```
tokens.json  >  design-context.md 中的内联样式  >  design-context.md 中的 Tailwind class  >  screenshot.png（估计）
```

规则：
- **tokens.json** 对任何有设计令牌的内容（颜色、间距令牌、排版）胜出。如果定义了变量，使用它——而非碰巧在此画板上的字面 hex。
- **内联样式** 在两者都存在时胜过 Tailwind class（因为内联是字面的，class 可能被四舍五入）。
- **截图** 是上下文模糊或截断时的决胜者，也是最终验证面。绝不从截图提取精确值（从 PNG 读取像素不可靠）——用它确认，而非测量。
- **Code Connect map**（`code-connect.json`）对于有现有映射的组件覆盖一切——使用映射的组件并让它处理内部值。

---

## 3. 视觉清单模板

对于每个屏幕或组件，在编写 SwiftUI 之前产生此清单。保留在草稿上下文中，除非用户要求实现计划或审计产物。

```
─────────── 容器 ───────────
尺寸：           W x H （fixed / fill-width / fill-height / hug）
背景：           <hex 或令牌>   [来源：tokens | inline | class]
圆角：           Xpt              [来源]
边框：           Xpt, <hex>       [来源]
阴影：           color=<rgba>, radius=X, offsetX=X, offsetY=X   [来源]
padding：        top=X, leading=X, bottom=X, trailing=X

─────────── 布局 ───────────
类型：           VStack | HStack | ZStack | ScrollView + stack | LazyVGrid | GeometryReader
间距：           Xpt
对齐：           leading | center | trailing（+ 交叉轴）

─────────── 元素 ───────────（每个可见元素一行）
[n] <种类> "<标签或资源名>"
    位置：          栈中索引 | offset (x,y) 用于 ZStack
    尺寸：          WxH（fixed / hug / fill）
    — 如果是 Text：
    字体：          family=<名称>, size=X, weight=<w>, width=<std|expanded>
    行高：          Xpt 绝对  或  Xx 乘数     [关键——绝不跳过]
    字间距：        X pt
    颜色：          <hex 或令牌>
    对齐：          leading/center/trailing
    lineLimit：     N
    — 如果是 Image/Icon：
    资源：          <名称>
    尺寸：          WxH
    渲染模式：      original | template（+ 着色）
    — 如果是 Button/Control：
    样式：          <变体>
    尺寸变体：      small|medium|large
    背景：          <hex>
    前景：          <hex>
    圆角：          Xpt
    padding：       X x X
    — 如果是 Shape：
    形状：          RoundedRectangle | Capsule | Circle | Custom
    填充：          <hex 或渐变规格>
    描边：          Xpt <hex>
```

**规则：**
- 截图中的每个可见元素必须有条目。
- 每个值必须有来源标签 `[tokens | inline | class | screenshot]`。
- 如果某字段确实未知，写 `[estimate]`——绝不默默省略。
- `lineHeight`、`letterSpacing`、`shadow`、`border` 最常被跳过。如果 design-context 提到它们，绝不跳过。
- 如果 Figma 使用 `Expanded` 或 `Condensed` 宽度，记录它——SwiftUI 需要 `.fontWidth(.expanded)`，而不仅仅是字重。

---

## 4. 破坏保真度的 SwiftUI 默认值

这些是隐形杀手。注意每一个：

### Text
- `.font(.system(size: X))` 有自己的默认行高（约 1.17×）。Figma `line-height: Xpx` 很少匹配。使用 `.lineSpacing(Y)`，其中 `Y = lineHeight - fontSize`，如果过度填充则用 `.padding(.vertical, -((Y)/2))` 取消 SwiftUI 的默认值。替代：用显式 frame + `.lineSpacing` 包裹 `Text`。
- 默认字间距 ≠ 0。Figma `letter-spacing: -0.32px` 必须通过 `.tracking(-0.32)` 或 `.kerning(-0.32)` 应用。它们不同——`.kerning` 在所有字符间应用，`.tracking` 尊重字体连字。优先使用 `.tracking`。
- `Text` 忽略前导空格 / 在窄宽度下截断方式不同于 Figma——用真实内容长度测试。

### Button
- 普通 `Button("Label") { }` 应用系统按钮样式（蓝色前景、按下动画、某些上下文中的隐式 padding）。当 Figma 按钮是自定义样式时用 `.buttonStyle(.plain)` 包裹。
- `.plain` 移除所有样式——你必须手动重新添加背景、padding、前景。

### Image
- 资源默认 `.renderingMode(.original)`，除非 asset catalog 设为 template。当图标应随前景色着色时，设置 `.renderingMode(.template)` + `.foregroundStyle(...)`。
- `.resizable()` 对于任何你想要调整尺寸的非 SF Symbol 图像是必需的。没有它，尺寸是固有的。
- `.aspectRatio(contentMode: .fit)` vs `.fill` ——`.fit` 留白，`.fill` 裁剪。匹配 Figma 裁剪行为。

### Padding & Spacing
- 不带参数的 `.padding()` 使用系统默认（约 16pt）。始终指定：`.padding(16)`。
- SwiftUI `VStack` spacing 默认约 8pt。如果无间距，始终指定：`VStack(spacing: 0)`。
- 在 `.background` 之后 vs 之前应用 `.padding` 改变结果。Figma 内 padding = 先 `.padding`，再 `.background`。

### Shape / Background
- `.background(Color.X)` 延伸到整个 frame 后面。要用圆角裁剪：`.background(Color.X, in: RoundedRectangle(cornerRadius: R))` 或 `.background(Color.X).clipShape(.rect(cornerRadius: R))`。
- `.cornerRadius(R)` 已弃用——使用 `.clipShape(.rect(cornerRadius: R))`。
- `Rectangle().fill(...)` 不包含描边——为边框添加 `.overlay { RoundedRectangle(...).stroke(...) }`。

### Shadow
- `.shadow(radius: R)` 默认黑色 33% 不透明度。Figma 阴影很少是这样。使用完整形式：`.shadow(color: .black.opacity(0.1), radius: R, x: X, y: Y)`。
- Figma 中的阴影模糊半径 ≠ SwiftUI radius 1:1——Figma 模糊是高斯 σ，SwiftUI `radius` 类似但可能需要调优。从精确匹配开始；如果阴影太硬/太软则调整。

### Lists & Forms
- `List` 添加分区缩进、行分隔符和表单式背景。对于匹配 Figma 的普通行堆栈，使用 `ScrollView { LazyVStack { ... } }` 替代 `List`。
- `.listStyle(.plain)` 移除部分样式但非全部。当 Figma 显示扁平列表时，优先使用 `LazyVStack`。

### NavigationStack
- 默认添加大标题 padding。当 Figma 头部紧凑时使用 `.navigationBarTitleDisplayMode(.inline)`，或完全自定义头部时使用 `.toolbar(.hidden, for: .navigationBar)`。
- 自动添加返回按钮和安全区域缩进。将这些纳入布局。

### 字体宽度 / tracking（iOS 16+）
- Figma "Expanded Semibold" = `.fontWeight(.semibold).fontWidth(.expanded)`。仅使用 `.semibold` 会丢失展开宽度。
- Figma "Condensed" = `.fontWidth(.condensed)`。

### 动态字号
- `.font(.body)` 随用户设置缩放。对于 Figma 的精确 pt 尺寸，使用 `.font(.system(size: X))`——但这会丢失动态字号。对于像素匹配 + 动态字号，使用 `@ScaledMetric`。
- 如果用户的目标是严格保真度，优先使用固定尺寸。记录权衡。

---

## 5. 截图交叉核对

截图是最终仲裁者。主动使用它：

### 实现区块之前
1. 查看 `screenshot.png`。
2. 先识别并剥离 iOS 系统组件。画板通常包含状态栏模型图（时间"9:41"、灵动岛、信号/wifi/电量）和主指示条（底部约 134×5pt 的条）。这些不是内容——iOS 渲染它们。不要清点它们，不要编码它们。
3. 在脑中放大到你要实现的区块。
4. 注意 design-context 未提及的任何内容（细微渐变、模糊、内阴影、重叠元素、不透明度层）。
5. 将遗漏项添加到视觉清单。

### 实现之后
1. 在脑中重新打开 `screenshot.png`。
2. 自顶向下遍历已实现的代码。
3. 对每个 `.padding`、`.spacing`、`.font`、`.foregroundStyle`、`.background`、`.frame`、`.shadow`——问："这匹配我看到的吗？"
4. 特别殊扫描常被遗漏的项：
   - [ ] 行高（如果 Text 有多行内容）
   - [ ] 字间距 / tracking
   - [ ] 内阴影 / 外阴影
   - [ ] 边框 + 圆角组合
   - [ ] 子元素上的不透明度
   - [ ] 图标渲染模式（着色 vs original）
   - [ ] 图标精确像素尺寸（不仅是"小"）
   - [ ] 分隔符颜色 / 不透明度 / 高度
   - [ ] 文本后的背景材质（模糊）
   - [ ] 文本截断 / 行限制
   - [ ] 渐变方向（上→下 vs 对角）
   - [ ] 安全区域行为（背景是否延伸到状态栏下？）
   - [ ] **无系统组件被绘制**——无"9:41"，无 wifi/电量 SF Symbols，无假装是主指示条的 `Capsule`/`RoundedRectangle`（约 134×5）。iOS 渲染这些。

### 不一致处理
当代码正确反映清单但与截图对比看起来不对时：
- 清单是错的。重新解析 design-context。
- 或截图显示了 design-context 未指定的内容。添加它。
- 绝不"微调直到看起来对"而不追踪来源。

---

## 6. 常见预检

在编写引用令牌/API 的 SwiftUI 之前，确认项目支持它们。

### `Color(hex:)` 非内置

SwiftUI 没有 `Color(hex: "FF0080")` 初始化器。每个使用它的项目都定义了扩展。在生成代码之前：

1. 在项目中搜索 `extension Color` 或 `Color(hex:` ——确认扩展存在。
2. 如果存在，原样使用（匹配签名——有些接受 `String`，有些接受 `UInt`，有些支持 alpha 作为单独参数）。
3. 如果不存在，使用以下之一：
   - Asset Catalog 命名颜色：`Color("accentPrimary")` ——首选，支持深色模式
   - RGB 初始化器：`Color(red: 1.0, green: 0.0, blue: 0.5)` ——十进制 0-1 值
   - 系统颜色：`.accentColor`、`.primary`、`.secondary`（语义化时）

如果扩展未定义，绝不在代码中留下 `Color(hex:)` ——它不会编译。

### iOS 部署目标

在使用以下任何修饰符之前，检查项目的部署目标（`.xcodeproj` 中的 `IPHONEOS_DEPLOYMENT_TARGET`，或 `Package.swift` 中的 `platforms:`）：

| API | 最低 iOS |
|---|---|
| `.scrollTargetBehavior`、`.scrollTransition`、`containerRelativeFrame`、`@Observable`、`Grid` | iOS 17 |
| `.onScrollGeometryChange`、`.scrollPosition`、`@Entry` | iOS 18 |
| `.glassEffect`、Liquid Glass | iOS 26 |
| `NavigationStack`、`NavigationPath` | iOS 16 |
| `ViewThatFits`、`AnyLayout`、`Grid` | iOS 16 |
| `.fontWidth(.expanded/.condensed)`、`.tracking` | iOS 16 |

如果项目目标更低，使用较旧的等价物（例如 iOS 16 用 `LazyVGrid` 替代 `Grid`，仅当目标 <16 时用 `NavigationView`）。

### 本地化

Figma 字符串 → 使用 `LocalizedStringKey` 的 `Text("localizable_key")`，而非硬编码字符串，除非项目明确是单语言。

- 默认 `Text("...")` 参数是 `LocalizedStringKey` ——字符串字面量通过 `Localizable.strings` / `.xcstrings` 自动本地化。
- 当字符串是动态数据（用户内容、API 响应）时，使用 `Text(verbatim:)` 跳过本地化查找。
- 检查项目中现有的 `.strings` / `.xcstrings` 文件。如果存在，在那里添加新键。如果不存在且项目有多个功能文件夹，询问用户关于本地化策略。

### 深色模式

- **如果 Figma 为画板提供浅色 + 深色变体**：获取两者（在每个变体节点上调用 `get_screenshot`），将两者添加到缓存，并为颜色和图像使用 Asset Catalog "Any / Dark" 外观。
- **如果 Figma 仅提供浅色：** 询问用户深色模式是否在范围内。如果是，使用自动适配的 Asset Catalog 语义颜色（iOS 系统灰色，或带两种外观的命名颜色）——不要硬编码在深色中看起来错误的 hex。如果深色不在范围内，仍使用 Asset Catalog 颜色，使深色模式不会完全渲染崩溃。
- 对于带深色变体的图像：在 PNG imageset 中使用 Asset Catalog `appearances`。
- 对于模板图标：用语义颜色着色（`.foregroundStyle(Color.textPrimary)`）——它免费适配。

### 占位符 / 模型图文本

Figma 经常包含占位文案：`Lorem ipsum...`、`Body text`、`Title`、`Placeholder`、`Sample text`、`Username`、`example@email.com`、`$0.00`。如果你将其作为 `Text("Lorem ipsum")` 复制到 SwiftUI 中，占位内容就会上线。

规则：
- 在视觉清单中检测这些模式。用 `[PLACEHOLDER]` 标记每个。
- 在代码中，要么：(a) 询问用户真实文案，(b) 绑定到模型属性（`Text(viewModel.title)`）并加 TODO，(c) 使用简短的语义本地化键（`Text("profile.title")`）。
- 绝不上线 `Text("Lorem ipsum dolor sit amet")` 字面量。

---

## 7. 硬性规则

1. SwiftUI 代码中的每个魔法数字都必须可追溯到来源（令牌、内联样式、class 或 design-context 注释）。如果无法追溯，你就是在猜测。
2. 绝不使用 `.font(.body)` / `.title` 等，除非 design-context 明确映射到 iOS 文本样式。Figma 尺寸是绝对的。
3. 绝不近似。17pt 不是 16pt。#F5F5F7 不是 #F5F5F5。
4. 当 design-context 指定 `lineHeight`、`letterSpacing`、`shadow`、`border` 时绝不跳过。
5. 始终在自定义样式按钮上设置 `.buttonStyle(.plain)` 以禁用系统样式。
6. 始终在 `Image` 上显式设置 `.renderingMode` ——不要依赖 asset catalog 默认值。
7. 始终用显式值指定 `VStack(spacing:)` 和 `.padding(X)` ——绝不依赖 SwiftUI 默认值。
8. 在说"完成"之前，执行第 5 节的截图交叉核对。
