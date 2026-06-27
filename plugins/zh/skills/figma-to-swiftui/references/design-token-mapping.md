# Figma 设计令牌到 SwiftUI 映射

如何将 Figma 变量（来自 get_variable_defs）翻译为 SwiftUI 设计系统。

## 目录

- [颜色令牌](#颜色令牌)
- [间距令牌](#间距令牌)
- [排版令牌](#排版令牌)
- [圆角令牌](#圆角令牌)
- [阴影令牌](#阴影令牌)
- [渐变](#渐变)
- [不透明度](#不透明度)
- [通用规则](#通用规则)

## 颜色令牌

Figma 颜色变量映射到 SwiftUI Color 扩展或 Asset Catalog 命名颜色。

### 策略

1. 检查项目是否已有颜色系统（Color+Extensions.swift、Theme.swift 或 Asset Catalog 命名颜色）
2. 如果有：通过匹配值将 Figma 变量名映射到现有项目颜色
3. 如果没有：从 Figma 变量创建 Color 扩展或 Asset Catalog 条目
4. 在引入新令牌之前，优先使用相邻屏幕已使用的语义颜色和命名资源

### 映射规则

Figma 变量 "primary/500" -> Color.primary500 或 Color("primary500")
Figma 变量 "text/primary" -> Color.textPrimary
Figma 变量 "surface/default" -> Color.surfaceDefault
Figma 变量 "border/subtle" -> Color.borderSubtle

### 自适应颜色（浅色/深色）

带模式变体（浅色/深色）的 Figma 变量：
- Asset Catalog：创建带 Any Appearance + Dark Appearance 的颜色集
- 代码：仅当 Asset Catalog 不可选时使用 @Environment(\.colorScheme)

```swift
// Asset Catalog 方式（首选）
Color("textPrimary") // 自动适配

// 代码方式（需要时）
extension Color {
    static var textPrimary: Color {
        Color("textPrimary")
    }
}
```

## 间距令牌

Figma 间距变量映射到 CGFloat 常量。

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
```

如果项目已有间距系统则使用。不要创建并行系统。

## 排版令牌

Figma 排版变量映射到 Font 定义。排版是 SwiftUI 中视觉漂移的常见来源——携带每个字段，而不仅仅是字号和字重。

### 每种文本样式的必需字段

| Figma | SwiftUI |
|---|---|
| font-family | `Font.custom("Family", size:)` 或 `.system(size:)` |
| font-size | `size:` 参数 |
| font-weight | `weight:` 参数 |
| font-width（Expanded/Condensed）| `.fontWidth(.expanded)` / `.fontWidth(.condensed)`（iOS 16+）|
| line-height | `.lineSpacing(lineHeight - fontSize)` ——见下方陷阱 |
| letter-spacing | `.tracking(X)` 首选，`.kerning(X)` 仅当项目使用时 |
| text-align | `.multilineTextAlignment(.leading / .center / .trailing)` |
| text-transform: uppercase | `.textCase(.uppercase)` 或大写本地化文案 |

### 行高陷阱

Figma `line-height: 22px` 用于 `16px` 字体意味着 22pt 总行框。SwiftUI `Text` 有自己的默认行高，因此仅 size + weight 不够。

```swift
Text("...")
    .font(.system(size: 16, weight: .semibold))
    .lineSpacing(22 - 16)
```

如果结果块在垂直方向过度填充，在容器中补偿，而非默默丢弃行高。当 Figma 指定行高时绝不跳过。

### 字间距陷阱

Figma `letter-spacing: -0.32px` 映射到 `.tracking(-0.32)`。Figma tracking 优先使用 `.tracking()`，因为它尊重字体连字；`.kerning()` 在字符间应用原始间距。

### 示例——完整样式携带

```swift
extension Font {
    static let headingLarge = Font.system(size: 28, weight: .bold)
}

Text("Title")
    .font(.headingLarge)
    .fontWidth(.expanded)
    .tracking(-0.56)
    .lineSpacing(34 - 28)
    .foregroundStyle(Color("textPrimary"))
    .multilineTextAlignment(.leading)
```

### 自定义字体

如果 Figma 使用自定义字体（例如 Inter、SF Pro Rounded）：
1. 检查字体是否已添加到 Xcode 项目（Info.plist UIAppFonts）
2. 如果没有，下载并添加字体文件
3. 使用 Font.custom("FontName", size:) 替代 .system()

如果项目已提供排版辅助或包装器，优先使用它们，而非引入原始字体声明或并行排版层。

### 动态字号支持

始终考虑动态字号。当 Figma 排版与 iOS 文本样式密切映射时，优先使用 .font(.headline) 或 .font(.body)。对于自定义尺寸，使用 @ScaledMetric：

```swift
@ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 16
```

## 圆角令牌

Figma 圆角变量映射到用于 RoundedRectangle 的 CGFloat 常量：

```swift
enum CornerRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let full: CGFloat = 9999 // 药丸形状 -> Capsule()
}
```

当圆角等于 9999 或 "full" 时，使用 Capsule() 替代 RoundedRectangle。

## 阴影令牌

Figma 阴影变量（高度级别）：

```swift
extension View {
    func shadowSm() -> some View {
        shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    func shadowMd() -> some View {
        shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    func shadowLg() -> some View {
        shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
    }
}
```

## 渐变

Figma 渐变映射到 SwiftUI 渐变类型。精确匹配色标和方向。

```swift
// Figma：从上到下的线性渐变
LinearGradient(
    colors: [Color("gradientStart"), Color("gradientEnd")],
    startPoint: .top,
    endPoint: .bottom
)

// Figma：特定色标位置
LinearGradient(
    stops: [
        .init(color: Color("gradientStart"), location: 0.0),
        .init(color: Color("gradientMid"), location: 0.6),
        .init(color: Color("gradientEnd"), location: 1.0)
    ],
    startPoint: .leading,
    endPoint: .trailing
)
```

径向渐变 -> `RadialGradient`。角度/圆锥渐变 -> `AngularGradient`。在设计上下文提供时匹配 Figma 的中心、半径、角度和色标。

## 不透明度

- Figma 填充不透明度 50% -> 填充/背景上的 `Color(...).opacity(0.5)`
- Figma 图层不透明度 50% -> 整个视图（包括子元素）上的 `.opacity(0.5)`
- 这些不同：填充不透明度仅影响填充颜色；图层不透明度影响内部所有内容
- Tailwind `bg-black/50` = 填充不透明度；`opacity-50` = 图层不透明度

## 通用规则

1. 创建新令牌之前始终检查项目是否有现有设计系统
2. 先按值匹配（hex 颜色、px 值），再按语义名匹配
3. 如果项目令牌存在但名称与 Figma 不同，使用项目名称
4. 不要重复：每个令牌一个真实来源
5. 优先使用已表达相同意图的现有共享模块和辅助器、主题包装器和 Asset Catalog 颜色
6. 按逻辑分组令牌（Color、Spacing、Typography、Radius、Shadow）
