---
name: swiftui-design-principles
description: 构建精致、原生质感的 SwiftUI 应用与小组件的设计原则。在创建或修改 SwiftUI 视图、iOS 小组件（WidgetKit）或任何原生 Apple UI 时使用本技能。确保间距、排版、颜色和小组件实现具有品质感，而不是 AI 生成的劣质货。
license: MIT
metadata:
  author: arjitj2
  version: "1.1.1"
---

本技能编码了设计原则，这些原则源自对精致、生产级 SwiftUI 应用与粗制滥造应用的对比。这里的模式代表了「感觉对」的应用与那些边距、间距和文字大小看起来「不对」的应用之间的差别。

在构建或修改 SwiftUI 界面、WidgetKit 小组件或任何原生 Apple UI 时，请应用这些原则。

## 核心理念

**克制胜于装饰。** 每个像素都必须有其存在的理由。一个精致的应用使用更少的颜色、更少的字号、更少的间距值和更少的文字——但用得一致。过度设计视觉元素（自定义渐变、装饰性边框、定制分隔线）会造成视觉噪音。原生组件和系统色带来和谐感。

**注意力是稀缺资源。** 让界面文案比你认为需要的更短。宁可要一个清晰的标题加一个紧凑的辅助内容块，也不要在标题、副标题、正文和页脚里反复解释。如果某个页面需要说明，把它放在一个有目的的位置，而不是散落在整页。

---

## 1. 间距系统：使用一致的网格

**关键**：使用基于 4/8 的网格间距值。绝不要使用任意值。

### 允许的间距值
```
4, 8, 12, 16, 20, 24, 32, 40, 48
```

### 错误示例（造成视觉不和谐的任意值）
```swift
// 错误 - 这些数字之间没有任何关联
.padding(.bottom, 26)
.padding(.bottom, 34)
.padding(.bottom, 36)
HStack(spacing: 18)
.padding(14)
```

### 正确示例（来自一致网格的值）
```swift
// 正确 - 眼睛能跟随的可预测节奏
.padding(.horizontal, 20)
.padding(.top, 8)
Spacer().frame(height: 32)
HStack(spacing: 4)  // 或 8, 12, 16
.padding(.vertical, 12)
.padding(.horizontal, 16)
```

### 标准内边距分配
- **外层内容内边距**：16-20pt 水平
- **主要区块之间**：24-32pt 垂直
- **分组组件内部**：4-12pt
- **卡片/行内边距**：12-16pt 垂直，16pt 水平

---

## 2. 排版：通过字重而非仅靠字号建立层级

### 原则
使用**更少的字号**搭配**清晰的字重区分**。大字号用更细的字重；小字号用 medium/regular。这带来精致感而非视觉混乱。

### 推荐字号阶梯（面向数据型应用）
| 角色 | 字号 | 字重 | 说明 |
|------|------|--------|-------|
| 主数字 | 36-42pt | `.light` | 大但视觉轻盈——优雅，不沉重 |
| 次级数据 | 20-24pt | `.light` | 与主数字同字重家族，更小 |
| 正文 / 开关标签 | 15pt | `.regular` | 标准 iOS 正文字号 |
| 区块标题（大写） | 11pt | `.medium` | 带字距/字符间距 |
| 说明 / 副标题 | 11-13pt | `.regular` | 次要信息 |

### 错误示例（字号过多，字重不一致）
```swift
// 错误 - 7 个不同字号，没有清晰体系
.font(.system(size: 60, weight: .ultraLight))   // 主数字
.font(.system(size: 44, weight: .regular))        // 数据（与主数字太接近）
.font(.system(size: 31, weight: .ultraLight))     // 百分号（比例奇怪）
.font(.system(size: 18, weight: .regular))        // 标签（对开关来说太大）
.font(.system(size: 14, weight: .regular))        // 标题
.font(.system(size: 13, weight: .regular))        // 另一个标题
.font(.system(size: 12, weight: .regular))        // 按钮（太小难以阅读）
```

### 正确示例（清晰层级，更少字号）
```swift
// 正确 - 5 个字号，每个都有明确用途
.font(.system(size: 42, weight: .light, design: .monospaced))    // 主数字
.font(.system(size: 24, weight: .light, design: .monospaced))    // 数据值
.font(.system(size: 15, weight: .regular, design: .monospaced))  // 正文
.font(.system(size: 14, weight: .regular, design: .monospaced))  // 次级
.font(.system(size: 11, weight: .medium, design: .monospaced))   // 标签
```

### 字体设计一致性
选定一种字体设计并到处使用——应用和小组件都用：
```swift
// 如果使用 monospaced，就到处都用
design: .monospaced  // 应用视图、小组件、锁屏——全部

// 绝不在应用和小组件之间混用设计
// 错误：应用用 .monospaced，锁屏小组件用 .rounded
```

### 字符间距（tracking）
最多用 2 个值，且只用于大写标签：
```swift
.tracking(1.5)  // 区块标签："NOTIFICATIONS"、"DAY"、"LEFT"
.tracking(3)    // 导航/工具栏标题
```

**绝不要使用 3 个以上不同的 tracking 值**，比如 `kerning(4)`、`kerning(4.5)`、`kerning(5)`——差异难以察觉，但不一致会被潜意识感知到。

### 标识符的数字格式
年份和其他固定标识符不应按区域分组。
```swift
// 正确 - 稳定、不分组的标识符文本
Text(String(year))                  // "2026"
Text(year, format: .number.grouping(.never))

// 错误 - 区域分组可能渲染成 "2,026"
Text("\(year)")
```

---

## 3. 颜色：系统语义色优先于硬编码值

### 原则
使用 SwiftUI 的语义色系统。它会自动处理浅色/深色模式、无障碍，并呈现原生感。硬编码颜色加上手动透明度值会造成维护噩梦，并显得不自然。

### 错误示例（硬编码白色加十几个透明度值）
```swift
// 错误 - 无法维护，不适配浅色模式
Color.black.ignoresSafeArea()           // 强制深色
Color.white.opacity(0.08)               // 环形背景
Color.white.opacity(0.09)               // 分隔线
Color.white.opacity(0.3)                // 年份文本
Color.white.opacity(0.32)               // 数据标签
Color.white.opacity(0.42)               // 百分号
Color.white.opacity(0.44)               // 开关色调
Color.white.opacity(0.72)               // 按钮文本
Color.white.opacity(0.88)               // 开关标签
Color.white.opacity(0.9)                // 数据值
Color.white.opacity(0.94)               // 环形填充
```

### 正确示例（语义系统色）
```swift
// 正确 - 自动适配，原生质感，易于维护
Color(.systemBackground)                 // 主背景
Color(.secondarySystemBackground)        // 卡片/分组背景
Color(.separator)                        // 分隔线（可选透明度）
Color.primary                            // 主文本和 UI 元素
.foregroundStyle(.secondary)              // 次级文本
.foregroundStyle(.tertiary)               // 标签、说明
```

### 确实需要透明度时
限制在 2-3 个有明确用途的值：
```swift
.opacity(0.15)  // 细微的背景描边
.opacity(0.3)   // 分隔线
// 就这些。如果还需要更多，你可能在硬编码语义色已经处理好的东西。
```

---

## 4. 组件尺寸：成比例，不要过大

### 进度环 / 圆形指示器
```swift
// 应用主视图：200x200，细描边
.frame(width: 200, height: 200)
Circle().stroke(..., lineWidth: 3)

// 小组件（systemSmall）：90x90，同样描边
.frame(width: 90, height: 90)
Circle().stroke(..., lineWidth: 3)

// 错误：过大的环加上粗细不一致的描边
.frame(width: 260, height: 260)    // 太大，主导整个屏幕
Circle().stroke(..., lineWidth: 9)  // 背景
Circle().stroke(..., lineWidth: 8)  // 填充——为什么和背景不一样？
```

### 描边宽度一致性
**同一元素的背景和前景描边始终使用相同的 lineWidth：**
```swift
// 正确
Circle().stroke(background, lineWidth: 3)
Circle().trim(from: 0, to: fraction).stroke(fill, lineWidth: 3)

// 错误 - 造成视觉错位
Circle().stroke(background, lineWidth: 9)
Circle().trim(from: 0, to: fraction).stroke(fill, lineWidth: 8)
```

### 列表行和开关行
```swift
// 正确 - 自然尺寸加合适内边距
Toggle(isOn: $value) {
    Text(title)
        .font(.system(size: 15, weight: .regular, design: .monospaced))
}
.padding(.horizontal, 16)
.padding(.vertical, 12)

// 错误 - 固定的过大高度
HStack {
    Text(label)
        .font(.system(size: 18))   // 对开关标签来说太大
    Spacer()
    Toggle("", isOn: $isOn)
        .labelsHidden()             // 为什么要隐藏标签？正确使用 Toggle
}
.frame(height: 70)                  // 太高
```

---

## 5. 分组内容与卡片：使用系统模式

### 错误示例（过度设计的自定义卡片）
```swift
// 错误 - 自定义渐变、覆盖边框、超大圆角
VStack { ... }
    .padding(.vertical, 4)              // 太紧
    .background(
        RoundedRectangle(cornerRadius: 22)   // 太圆
            .fill(LinearGradient(            // 不必要的渐变
                colors: [Color(white: 0.10), Color(white: 0.085)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 22)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)  // 装饰性边框
    )
```

### 正确示例（原生分组样式）
```swift
// 正确 - 简洁、原生、在浅色和深色模式都能工作
VStack(spacing: 0) {
    row1
    Divider().padding(.leading, 16)
    row2
    Divider().padding(.leading, 16)
    row3
}
.background(Color(.secondarySystemBackground))
.clipShape(.rect(cornerRadius: 10))
```

### 分组内容的关键规则
- **圆角**：卡片/分组用 10pt（匹配 iOS 系统样式）。绝不要 22pt 以上。
- **分隔线**：使用系统 `Divider()` 配合 `.padding(.leading, 16)` 实现 iOS 标准缩进。绝不要构建自定义分隔线结构体。
- **卡片内边距**：12-16pt 垂直，16pt 水平。绝不要 4pt 垂直。
- **背景**：`Color(.secondarySystemBackground)`——标准卡片绝不要用自定义渐变。

---

## 6. 导航：使用 NavigationStack

```swift
// 正确 - 正确的导航加极简工具栏
NavigationStack {
    ScrollView {
        content
    }
    .toolbar {
        ToolbarItem(placement: .principal) {
            Text("Title")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.tertiary)
        }
    }
    .navigationBarTitleDisplayMode(.inline)
}

// 错误 - 没有导航结构，只有一个 ZStack
ZStack {
    Color.black.ignoresSafeArea()
    ScrollView {
        VStack {
            Text("2026").font(...) // 手动放置的"标题"
            content
        }
    }
}
```

---

## 7. WidgetKit：使用原生组件

### 圆形锁屏小组件
```swift
// 正确 - 使用 Gauge，它是为此专门构建的
Gauge(value: entry.fraction) {
    Text("")
} currentValueLabel: {
    Text("\(Int(entry.percentage))%")
        .font(.system(size: 12, weight: .medium, design: .monospaced))
}
.gaugeStyle(.accessoryCircular)
.containerBackground(.fill.tertiary, for: .widget)

// 错误 - 为锁屏手动绘制圆形
ZStack {
    Circle().stroke(Color.primary.opacity(0.18), lineWidth: 4)
    Circle().trim(from: 0, to: progress).stroke(...)
    Text(percentText)
        .font(.system(size: 14, weight: .bold, design: .rounded)) // 字体设计错误！
}
```

### 矩形锁屏小组件
```swift
// 正确 - 使用 Gauge 加 linearCapacity
VStack(alignment: .leading, spacing: 4) {
    HStack {
        Text(year).font(.system(size: 13, weight: .semibold, design: .monospaced))
        Spacer()
        Text(percentage).font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
    }
    Gauge(value: fraction) { Text("") }
        .gaugeStyle(.linearCapacity)
        .tint(.primary)
    HStack {
        Spacer()
        Text("\(dayOfYear)/\(totalDays)")
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}
.containerBackground(.fill.tertiary, for: .widget)

// 错误 - 自定义 GeometryReader 进度条
GeometryReader { proxy in
    ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.16))
        RoundedRectangle(cornerRadius: 2).fill(Color.primary)
            .frame(width: max(2, proxy.size.width * progress))
    }
}
.frame(height: 6)
```

### 小组件背景
```swift
// 正确
.containerBackground(.fill.tertiary, for: .widget)

// 错误 - 硬编码颜色
.containerBackground(.black, for: .widget)
```

### 小组件系列覆盖
支持所有相关系列——不要跳过常见的：
```swift
.supportedFamilies([
    .accessoryCircular,      // 锁屏圆形
    .accessoryRectangular,   // 锁屏矩形
    .accessoryInline,        // 锁屏内联文本
    .systemSmall,            // 主屏小
    .systemMedium,           // 主屏中
    .systemLarge,            // 主屏大
])
```

### 跨系列视觉一致性
中和大号主屏小组件应共享相同的结构布局：
- 头部：左侧年份，右侧百分比
- 中部：进度条
- 底部：`day/total` 右对齐

除非有硬性尺寸限制，否则不要为每个系列重新发明层级。

主屏小组件务必显式设置内部内边距，避免在圆角边缘附近被裁切：
```swift
.padding(.horizontal, 12)
.padding(.vertical, 12)
```

### 小组件内存预算（硬性限制）
小组件扩展有严格的内存预算（通常约 30 MB）。如果由过多嵌套视图构建，密集可视化可能被 `EXC_RESOURCE` 杀掉。

```swift
// 正确 - 在一次绘制中画出密集点阵
Canvas { context, size in
    // 在这里画 365/366 个点
}

// 错误 - 数百个嵌套子视图（高内存开销）
LazyVGrid(columns: columns) {
    ForEach(1...366, id: \.self) { day in
        ZStack { Circle(); partialFillLayer }
    }
}
```

### 时间线刷新（匹配数据粒度）
```swift
// 正确 - 天级数据在午夜刷新
let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
Timeline(entries: [entry], policy: .after(tomorrow))

// 正确 - 依赖时段的百分比/部分填充定期刷新
let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
Timeline(entries: [entry], policy: .after(refresh))

// 错误 - 静态每日数据用分钟级刷新
let tooFrequent = Calendar.current.date(byAdding: .minute, value: 1, to: now)!
Timeline(entries: [entry], policy: .after(tooFrequent))
```

---

## 8. 交互元素

### 开关
```swift
// 正确 - 使用 Toggle 的内置标签，用单一强调色着色
Toggle(isOn: $value) {
    Text(title)
        .font(.system(size: 15, weight: .regular, design: .monospaced))
}
.tint(.green)

// 错误 - 隐藏标签加手动 HStack 布局
HStack {
    Text(label).font(.system(size: 18))
    Spacer()
    Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(Color.white.opacity(0.44))  // 低对比度色调
}
```

### 互斥选项
当选项互斥时（例如每日/每周/每月频率），使用一个选中值，而不是三个独立开关。

```swift
// 正确 - 单一数据源
enum Cadence: String, CaseIterable { case daily, weekly, monthly }
@State private var cadence: Cadence = .daily

ForEach(Cadence.allCases, id: \.rawValue) { option in
    Button {
        cadence = option
    } label: {
        HStack {
            Image(systemName: cadence == option ? "checkmark.circle.fill" : "circle")
            Text(option.rawValue.capitalized)
        }
    }
}

// 正确 - 内容共享时用一个预览操作
Button("Preview") { sendPreview() }

// 错误 - 独立开关允许矛盾状态
Toggle("Daily", isOn: $daily)
Toggle("Weekly", isOn: $weekly)
Toggle("Monthly", isOn: $monthly)
```

### 数字变化的动画过渡
```swift
// 加到任何显示变化数值的 Text 上
Text(String(format: "%.2f", percentage))
    .contentTransition(.numericText())
```

---

## 9. 交互式编辑器：集中几何与状态

交互式编辑器（拼贴、裁剪、画布、媒体取景工具、布局选择器）需要比普通表单更严格的状态和布局纪律。

### 展示状态
从负载状态展示编辑器流程，而不是从一个单独的 `Bool` 加独立管理的数据。

```swift
// 正确 - 只有负载存在时才会展示
@State private var activeCropRequest: CropRequest?

.sheet(item: $activeCropRequest) { request in
    CropEditor(request: request)
}

// 错误 - 底层数据未就绪时 sheet 也可能打开
@State private var showCropEditor = false
@State private var selectedImage: UIImage?

.sheet(isPresented: $showCropEditor) {
    if let selectedImage { CropEditor(image: selectedImage) }
}
```

### 共享几何模型
如果应用实时预览平移/缩放/裁剪/布局，之后导出结果，预览和渲染应使用同一个共享几何模型。

```swift
// 正确 - 边界和变换的单一数据源
let normalized = EditorGeometry.normalizedAdjustment(adjustment, imageSize: image.size, slotSize: slotSize)
let drawRect = EditorGeometry.drawRect(for: image.size, in: slotRect, adjustment: adjustment)

// 错误 - 预览和导出各自发明自己的数学
let previewOffset = ...
let exportOffset = ...
```

如果用户可以缩小到足以露出背景，那必须是共享几何模型的有意设计，而不是编辑器专属的例外。

### 手势协调
点按、长按拖拽和捏合不是独立功能。在 SwiftUI 中，除非你显式建模它们的关系，否则它们会相互竞争。

- 为活动的瓦片/卡片/画布项使用单一交互状态。
- 决定哪个手势有优先级，哪些应同时运行。
- 选中项变化时，有意地重置临时手势状态。
- 优先使用一个连贯的状态机，而不是绑定到各个手势的零散布尔值。

### 固定编辑器布局
如果页面不能滚动，用几个命名区域自上而下分配垂直空间：
- 头部
- 画布舞台
- 设置区
- 底部工具栏

把尺寸计算集中在一处。不要让每个子视图各自发明自己的高度。

### 自定义头部和安全区域
如果你用自定义头部替换系统导航栏：
- 明确父视图是否已经遵循安全区域。
- 不要反射性地添加 `safeAreaInsets.top`；重复计算会造成明显的空白。
- 保持自定义头部紧凑。它们应感觉像导航栏装饰，而不是完整的内容区。

### 设置面板
当编辑器有多种配置模式（`Layout`、`Border`、`Ratio`、`Background` 等），一次只显示一个活动设置面板，而不是把所有控件堆在屏幕上。

这样能让画布在视觉上占主导，并使每组控件更易理解。

---

## 10. 数据模型：应用与小组件共享

```swift
// 正确 - 一个模型到处用
struct YearProgress {
    // 共享计算逻辑
    static func current() -> YearProgress { ... }
}
// ContentView 和 widget TimelineProvider 都使用

// 如果百分比作为实时进度显示，共享数学中应包含时段
let dayProgress = elapsedInCurrentDay / totalSecondsInDay
let elapsedDays = Double(dayOfYear - 1) + dayProgress
let fraction = elapsedDays / Double(totalDays)

// 错误 - 分离的快照结构体带重复的日期数学
struct YearProgressSnapshot { ... }            // 在应用中
struct YearProgressWidgetSnapshot { ... }      // 在小组件扩展中（重复！）
```

---

## 11. 快速清单

发布任何 SwiftUI 视图前，验证：

- [ ] 所有间距值来自网格（4、8、12、16、20、24、32）
- [ ] 字号限制在 5 个或更少不同值
- [ ] 一致使用一种字体设计（包括小组件）
- [ ] 颜色使用语义系统色，而非带透明度的硬编码值
- [ ] 背景和前景描边使用相同 lineWidth
- [ ] 卡片使用 `Color(.secondarySystemBackground)` 加 10pt 圆角
- [ ] 分隔线使用系统 `Divider()` 加前导内边距
- [ ] 开关行使用 Toggle 的内置标签（而非 `.labelsHidden()`）
- [ ] 锁屏小组件使用 `Gauge`（而非手动绘制圆形）
- [ ] 小组件背景使用 `.containerBackground(.fill.tertiary, for: .widget)`
- [ ] 年份/标识符文本在不希望分组时避免区域分组
- [ ] tracking/kerning 限制在最多 2 个值
- [ ] 使用 NavigationStack（而非裸 ZStack）
- [ ] 时间线刷新频率匹配数据粒度（午夜 vs 定期）
- [ ] 大型/密集小组件视觉使用 `Canvas` 或类似的轻量渲染
- [ ] 中和大号小组件系列共享一致的层级和内部内边距
- [ ] 互斥选择使用单一选中值（而非多个开关）
- [ ] 当 UI 暗示实时进度时百分比包含时段
- [ ] 没有 `minimumScaleFactor` 取巧——去修复布局
- [ ] 交互式编辑器从负载状态展示，而非 `Bool` 加独立数据
- [ ] 预览和导出共享同一几何模型用于平移/缩放/裁剪/布局
- [ ] 自定义头部不重复计算顶部安全区域缩进
- [ ] 不滚动编辑器页面通过集中式布局模型分配高度
- [ ] 多模式编辑器一次显示一个聚焦设置面板，而非所有控件同时显示
