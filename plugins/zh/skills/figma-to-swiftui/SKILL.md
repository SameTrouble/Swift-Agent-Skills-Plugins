---
name: figma-to-swiftui
description: 使用 Figma MCP 将 Figma URL、节点、选区或需求文档转换为生产级 SwiftUI（iOS）。用于 Figma 到 SwiftUI 的实现、规划、设计令牌和资源导出；不适用于 Web 或 React。
---

# Figma 到 SwiftUI 实现技能

将 Figma 节点转换为像素级精准的生产级 SwiftUI 视图。结合 MCP 集成规则与结构化的 iOS 项目实现工作流。

## 前置条件

- Figma MCP 服务器必须已连接且可访问
- 用户必须提供 Figma URL，例如：https://www.figma.com/design/:fileKey/:fileName?node-id=3166-70147&m=dev
  - 可能包含 &m=dev 或其他查询参数——只有 node-id 重要
  - :fileKey —— /design/ 之后的路径段
  - node-id 值——要实现的具体组件或画板
- 或者使用 figma-desktop MCP 时：在 Figma 桌面应用中直接选择节点（无需 URL）
- 带有成熟 SwiftUI 代码库的 Xcode 项目（首选）
- 可选的 `.txt` / `.md` / 工单 / 需求文档，描述范围、行为、操作和状态

## MCP 连接

如果任何 MCP 调用因 Figma MCP 未连接而失败，暂停并要求用户配置。排障请参见 references/figma-mcp-setup.md。

---

## 工作流

按顺序执行以下步骤。不要跳过步骤。

**两种模式：** 如果用户想从零构建新屏幕，按顺序执行所有步骤。如果用户想适配/更新现有屏幕以匹配 Figma 设计，执行步骤 1–5，然后在步骤 6 之前执行步骤 5b（适配审计）。步骤 5b 确保现有代码与设计之间的每个差异都被识别和处理——这是适配过程中最容易出错的地方。

### 步骤 0 — 阅读源文档（如果提供）

如果用户在 Figma 工作之外提供了 `.txt`、`.md`、工单、PM 需求文档或内联规格说明，在任何 Figma MCP 调用之前阅读它。提取功能目标、预期屏幕、入口、操作、异步工作、必需状态、约束、范围外项和不明确点。参见 references/source-document.md。

用提取的契约来缩小 Figma 工作范围。如果文档与 Figma 在屏幕数量、范围或主要操作映射上不一致，先询问再获取或实现错误的节点。

### 步骤 1 — 解析 Figma URL

从 URL 中提取 fileKey 和 nodeId。

接受的 URL 模式（带或不带 www.）：
- figma.com/design/:fileKey/:fileName?node-id=...
- figma.com/file/:fileKey/:fileName?node-id=...（旧版，行为相同）

解析规则：
- fileKey：/design/ 或 /file/ 之后的第一个路径段
- nodeId：node-id 查询参数的值。始终将 "-" 替换为 ":"（URL 使用 "3166-70147"，MCP 期望 "3166:70147"）
- 忽略所有其他查询参数（m=dev、t=...、page-id=... 等）
- 拒绝 /proto/ 和 /board/ URL——它们是原型和 FigJam 画板，不是可实现的设计。要求用户提供 /design/ 链接。

使用 figma-desktop MCP 而无 URL 时，工具自动使用当前选中的节点。只需 nodeId；fileKey 会自动推断。

### 步骤 1b — 屏幕发现（必要时先获取元数据）

在调用 `get_design_context` 之前，判断该节点是否明显是一个可实现的屏幕/组件。如果 URL 指向根节点、页面节点、大型容器、流程、多屏幕画板，或源文档提到的屏幕数多于 URL 明显包含的屏幕数，先运行 `get_metadata`。

构建带有置信度的候选屏幕映射，仅在目标节点明确时继续。如果多个候选会实质性地改变实现，在获取设计上下文之前询问用户。参见 references/screen-discovery.md 和 references/fetch-strategy.md。

### 步骤 2 — 获取设计上下文

get_design_context(fileKey=":fileKey", nodeId="1-2", prompt="generate for iOS using SwiftUI")

`prompt` 参数将默认代码输出引导至 SwiftUI。你也可以传入项目特定的提示：`"use components from Components/"`、`"generate using my design system tokens"`。

返回结构化设计数据：布局、排版、颜色、间距和代码表示。即使使用 iOS 提示，也要将输出视为设计规范，而非可直接移植的代码。

对于大型/复杂设计：如果响应被截断或超时，不要重试同一节点。运行 `get_metadata`，识别更小的区块和子节点 ID，然后逐个获取每个区块。参见 references/fetch-strategy.md。

对于多设备设计：如果 Figma 包含不同屏幕尺寸的画板（iPhone + iPad），获取所有设备特定的画板，而非仅一个。关于将它们合并为自适应 SwiftUI 视图，参见 references/responsive-layout.md。

### 步骤 3 — 获取截图

get_screenshot(fileKey=":fileKey", nodeId="1-2")

此截图是整个实现过程中视觉验证的真实依据。

### 步骤 4 — 获取设计令牌（如果有）

get_variable_defs(fileKey=":fileKey", nodeId="1-2")

返回颜色、间距、排版令牌。映射到项目的 SwiftUI 设计系统。参见 references/design-token-mapping.md。

### 步骤 5 — 构建资源清单并下载资源

在编写 SwiftUI 之前，根据截图和设计上下文构建视觉资源清单。完整决策流程参见 references/asset-handling.md。

1. 打开步骤 3 的截图，列出每个可见的非文本元素：图标、Logo、照片、插画、装饰图形和图像填充
2. 将每一行与 `get_design_context` 和 `get_metadata` 交叉核对，查找 localhost URL、图像填充、矢量节点和节点 ID
3. 将每一行分类为 `download`、`code` 或 `remote`
4. 在活跃的 MCP 会话期间下载 Figma 拥有的资源：
   - 图标、Logo、插画和图形节点默认使用 `get_screenshot(fileKey, nodeId)`
   - 仅当 localhost URL 验证为 PNG 时才使用 `get_design_context` 中的 localhost URL
5. 用 `file <asset>` 验证下载的文件：可见的 Figma 资源必须是真正的 PNG 文件，然后添加到 Asset Catalog，包含 @1x/@2x/@3x 变体和正确的渲染模式

资源规则：
- Figma 资源优先：不要用 SF Symbols 或手绘 SwiftUI 形状替换 Figma 图标、Logo 或插画
- 可见的 Figma 拥有资源默认应导出为 Figma 渲染的 PNG；SVG/文本/XML 响应是导出失败，不是最终资源
- SF Symbols 仅允许用于 iOS 系统组件或用户明确批准替换的情况
- 不要用 `Text`、`Rectangle`、`Circle` 或自定义 `Shape` 创建占位图像或假 Logo
- 如果可见资源没有下载 URL 且无可识别的节点 ID，停止并询问用户，而非即兴处理
- 除非项目已使用，否则不要导入新的图标包
- 远程内容图像（头像、信息流、CDN 照片）应使用项目现有的图像加载路径，而非打包资源

### 步骤 5b — 适配审计（修改现有屏幕时）

当用户要求适配/更新现有屏幕以匹配 Figma 设计时，在编写任何代码之前执行完整的逐元素审计。完整流程参见 **references/adaptation-workflow.md**。

关键步骤：
1. 阅读现有代码及其所有子组件
2. 构建分类差异清单（ADD / UPDATE / REMOVE），包含精确的旧 → 新值
3. 特别注意间距——这是最常被遗漏的差异
4. 在实现之前向用户展示清单并澄清未知项
5. 应用所有更改——不要跳过看似次要的项

### 步骤 6 — 用 SwiftUI 实现

在编写任何代码之前：

1. 运行 `get_code_connect_map(fileKey, nodeId)` 检查设计中的 Figma 组件是否已有映射的代码组件。如果映射存在——直接使用该代码，而非从零构建。
2. 检查项目的依赖（Package.swift、Podfile、.xcodeproj）和现有代码库中的 UI 相关库和模式。项目可能使用第三方方案来实现你本会用原生 SwiftUI 实现的功能。例如：
- 图像加载：Kingfisher、SDWebImage、Nuke 替代 AsyncImage
- 动画：Lottie 替代 SwiftUI 动画
- UI 组件：自定义设计系统、SnapKit 布局等
- 网络 + 图像缓存：Alamofire、自定义图像缓存
- 图表：Charts 库替代 Swift Charts

使用项目已有的方案。如果项目已有用于某目的的库，不要引入原生 SwiftUI 替代方案。如果设计需要项目没有依赖的功能，在选择方案前询问用户。

关键规则：MCP 输出（React + Tailwind）是设计意图的表示。不要将 React 移植为 SwiftUI。读取设计属性并从零构建原生 SwiftUI 视图。

在实现非简单屏幕之前阅读 references/visual-fidelity.md。将其用于精确值提取、真实依据优先级、视觉清单、SwiftUI 默认陷阱和截图交叉核对。

编码前的资源自检：
- 每个 `Image(...)` 必须引用已下载的 Figma 资源、通过项目图像管道加载的远程图像，或明确允许的系统符号
- 视觉清单中每个 Figma 图标/Logo/插画必须有对应的 Asset Catalog 条目或批准的远程源
- 除非用户批准了该替换，否则 Figma 设计的资源不允许使用 `Image(systemName:)`
- `Text("G")`、彩色形状、自定义 `Shape` 或近似矢量绘图不得充当 Logo、应用图标、社交图标或插画资源

不要实现 Figma 模型图中出现的系统提供的元素。设计师通常为了上下文而包含它们，但它们由 iOS 自动渲染。跳过以下内容：
- 键盘（系统键盘、表情选择器）
- 状态栏（时间、电量、信号）
- 主指示条
- 导航栏返回按钮（由 NavigationStack 提供）
- 使用原生 TabView 时的标签栏（仅实现自定义标签栏）
- 系统提醒和操作表（使用 .alert() / .confirmationDialog()）
- 分享面板（使用 ShareLink 或 UIActivityViewController）
- 系统搜索栏（使用 .searchable()）
- 下拉刷新指示器（使用 .refreshable()）
- 原生 TabView 使用 .page 样式时的页面指示点

如果不确定某个元素是系统提供还是自定义的，询问用户。

#### 6.1 — 布局翻译

完整映射参见 references/layout-translation.md。关键规则：

Figma Auto Layout（垂直）-> VStack(spacing:)，匹配对齐方式
Figma Auto Layout（水平）-> HStack(spacing:)，匹配对齐方式
Figma Auto Layout 带换行 -> LazyVGrid 或自定义 FlowLayout
Figma Frame 带绝对子元素 -> ZStack + .offset()（尽量避免）
Figma padding -> .padding(.horizontal, 16)，按边指定
Figma gap -> 栈初始化器中的 spacing 参数
Figma fill container -> .frame(maxWidth: .infinity)
Figma hug contents -> 无 frame 修饰符（固有尺寸，SwiftUI 默认）
Figma fixed size -> .frame(width:, height:)
Figma aspect ratio -> .aspectRatio(ratio, contentMode:)
Figma scroll -> ScrollView(.vertical) 或 .horizontal
Figma constraints（固定到边缘）-> 父视图中的 .frame() + alignment
Figma 针对特定设备尺寸的画板 -> 检查项目是否支持多设备，用尺寸类别适配。参见 references/responsive-layout.md

#### 6.2 — 排版翻译

Figma font family -> 最接近的 iOS 系统字体或项目自定义字体
Figma font weight -> Font.Weight（.regular、.medium、.semibold、.bold）
Figma font size -> .font(.system(size:, weight:, design:)) 或自定义 Font 扩展
Figma line height -> .lineSpacing(lineHeight - fontSize)
Figma letter spacing -> .tracking()（Figma px = SwiftUI points，iOS 上 1:1）

如果项目有排版系统（Typography.headline），优先使用项目令牌而非原始值。

#### 6.3 — 颜色翻译

Figma hex 颜色 -> 来自 Asset Catalog 的 Color 或 Color(hex:) 扩展
Figma 颜色 + 不透明度 -> .opacity() 修饰符或带 alpha 的颜色
Figma 线性渐变 -> LinearGradient(colors:, startPoint:, endPoint:)
Figma 径向渐变 -> RadialGradient(colors:, center:, startRadius:, endRadius:)
Figma 颜色变量 -> 映射到项目令牌（Color.primaryText、Color.surface）
Figma 深色模式变体 -> Asset Catalog 中的自适应颜色或 @Environment(\.colorScheme)

当项目令牌与 Figma 规格冲突时，优先使用项目令牌，但做最小调整以匹配视觉效果。

#### 6.4 — 组件翻译

Figma 组件实例 -> 检查项目中是否有现有视图。优先复用而非新建。
Figma button -> Button + 项目 .buttonStyle()
Figma text input -> TextField 或 TextEditor
Figma toggle -> Toggle，如设计与系统不同则使用自定义样式
Figma image -> 本地用 Asset Catalog 中的 Image。远程 URL 用项目的图像加载库；如果没有，询问用户。
Figma list/collection -> List 或 LazyVStack / LazyVGrid
Figma tab bar -> TabView，非标准时用自定义标签栏
Figma navigation bar -> .navigationTitle() + .toolbar {} 或自定义头部
Figma sheet/modal -> .sheet() / .fullScreenCover()——sheet 自行管理关闭
Figma card -> 自定义视图 + .background() + .clipShape(.rect(cornerRadius:)) + .shadow()
Figma 带变体的组件 -> 检查变体属性，总结检测到的变体，询问用户使用哪种样式方案，然后实现。关于将 Figma 变体属性（状态、尺寸、样式、内容开关）翻译为 SwiftUI，参见 references/component-variants.md。在编写变体代码之前，始终询问用户偏好哪种实现方案。

#### 6.5 — 效果与装饰

Figma drop shadow -> .shadow(color:, radius:, x:, y:)
Figma inner shadow -> .overlay() 带阴影或自定义形状描边
Figma blur（图层）-> .blur(radius:)
Figma blur（背景）-> .background(.ultraThinMaterial) 或 .regularMaterial
Figma corner radius -> .clipShape(.rect(cornerRadius:))
Figma individual corners -> UnevenRoundedRectangle(topLeadingRadius:, ...)
Figma border/stroke -> .overlay(RoundedRectangle(...).stroke(...))
Figma clip content -> .clipped() 或 .clipShape()
Figma mask -> .mask { ... }
Figma blend mode -> .blendMode()
Figma Liquid Glass（iOS 26+）-> .glassEffect() 配合适当的形状

#### 6.6 — 动画与过渡

Figma 原型连接定义画板之间的过渡。将它们理解为导航或状态变更动画——而非字面上的动画规格。

Figma dissolve -> .opacity() + withAnimation(.easeInOut)
Figma move in / slide in -> .transition(.move(edge:)) 或 .offset()
Figma push -> NavigationStack 推送（系统过渡）
Figma smart animate -> 状态变更时 withAnimation { }，匹配属性差异（位置、尺寸、不透明度）
Figma scroll animate -> ScrollView 配合 .scrollTransition() 或 .animation() 作用于 offset

常见 SwiftUI 模式：
- 状态驱动：`withAnimation(.spring) { showDetail = true }` + `.transition(.move(edge: .trailing))`
- 匹配几何：`matchedGeometryEffect(id:in:)` 用于视图之间的共享元素过渡
- 隐式：在动画视图上使用 `.animation(.default, value: someState)`

规则：
- 检查项目依赖中的 Lottie 或其他动画库——如果有则使用
- 不要过度动画。如果 Figma 仅在屏幕之间显示过渡（原型链接），将其实现为导航，而非自定义动画
- 如果设计包含复杂的编排动画（多元素、序列时序），询问用户是完全实现还是简化
- Figma 原型延迟和持续时间是提示，不是精确规格——除非用户另有说明，使用标准 iOS 时序（.default、.spring）

### 步骤 7 — 验证（仅在用户要求时）

不要自动验证。在开始实现之前（步骤 5 之后），询问用户想如何验证结果。例如：
- 在 Xcode 预览中并排比较截图
- 在模拟器上运行并手动比较
- 使用快照测试
- 不需要验证，信任实现

按用户选择的方法进行。如果用户未指定，完全跳过验证。

参考清单（如果用户问要检查什么，可与之分享）：
- 布局：间距、对齐、尺寸
- 排版：字体、字号、字重、行高
- 颜色：填充、描边、背景、文本
- 资源：所有图标/图像存在，无占位符
- 交互状态：按下、聚焦、禁用
- 深色模式（如果 Figma 提供变体）
- 动态字号：文本适当缩放
- 安全区域：内容不在刘海/主指示条后面
- 如果设计暗示可滚动内容，滚动行为正确

更深入的视觉 QA，使用 references/visual-fidelity.md 作为清单。

如果偏离 Figma（无障碍、平台约定、技术约束），在注释中记录原因。

### 步骤 8 — 注册 Code Connect 映射

创建对应 Figma 组件的可复用 SwiftUI 组件后，注册它们：

add_code_connect_map(fileKey, nodeId, componentPath, componentName)

这会将 Figma 组件链接到你的代码，使未来使用相同组件的设计引用现有实现，而非生成新代码。

仅注册以下组件：
- 可复用（在多处使用或可能被复用）
- 稳定（非一次性的屏幕特定视图）

---

## 处理复杂设计

1. get_metadata 获取节点树
2. 识别主要区块和子节点 ID
3. 自顶向下实现：先容器，再区块
4. 每个区块 get_design_context + get_screenshot
5. 如果用户要求验证，逐区块验证，然后整体组合验证

## MCP 工具参考

get_design_context：设计数据 + 默认代码 + 资源下载 URL。始终使用，主要来源。
get_metadata：稀疏节点树。用于大型设计，先看结构。
get_screenshot：视觉参考 PNG。始终使用，验证真实依据。
get_variable_defs：设计令牌。当项目有设计系统令牌时使用。
get_code_connect_map：现有代码映射。在创建组件之前使用。
add_code_connect_map：注册新映射。在创建可复用组件之后使用。

## 关键原则

1. 绝不凭假设实现。始终先获取上下文 + 截图。
2. MCP 输出是规范，不是代码。读取属性，构建原生 SwiftUI。
3. 使用项目已有的方案。在实现任何东西之前检查依赖和现有模式。如果项目已有用于某目的的库，不要引入原生替代方案。
4. 项目令牌优先。优先使用项目令牌，做最小调整以匹配视觉效果。
5. 仅在被要求时验证。在实现之前询问用户如何验证。
6. Figma 资源优先。SF Symbols 仅用于 iOS 系统组件或用户批准的替换；默认绝不替换 Figma 设计的图标、Logo 或插画。
7. 平台约定很重要。iOS 导航、安全区域、动态字号、无障碍比像素级精确的 Figma 复制更重要。
