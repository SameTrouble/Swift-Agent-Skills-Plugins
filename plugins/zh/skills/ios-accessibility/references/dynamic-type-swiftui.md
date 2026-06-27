# Dynamic Type — SwiftUI

Dynamic Type 和可缩放布局的 SwiftUI 实现。

如需核心概念，请参阅 `dynamic-type.md`。

## 目录

- [文本样式](#文本样式)
- [布局适应](#布局适应)
- [缩放非文本元素](#缩放非文本元素)
- [Large Content Viewer](#large-content-viewer)
- [受限 Dynamic Type](#受限-dynamic-type)
- [测试](#测试)
- [示例](#示例自适应卡片)

## 文本样式

SwiftUI 自动用文本样式缩放文本：

```swift
Text("Hello")
    .font(.body)
```

无需额外配置——文本自动缩放。
如需按文本样式和内容大小类别的精确点大小，请参阅 Apple HIG：[iOS/iPadOS Dynamic Type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-Dynamic-Type-sizes)。

## 所有文本样式

```swift
Text("Large Title").font(.largeTitle)
Text("Title").font(.title)
Text("Title 2").font(.title2)
Text("Title 3").font(.title3)
Text("Headline").font(.headline)
Text("Subheadline").font(.subheadline)
Text("Body").font(.body)
Text("Callout").font(.callout)
Text("Footnote").font(.footnote)
Text("Caption").font(.caption)
Text("Caption 2").font(.caption2)
```

## 自定义字体

相对于文本样式缩放自定义字体：

```swift
Text("Custom")
    .font(.custom("PressStart2P-Regular", size: 17, relativeTo: .body))
```

## 检测无障碍尺寸

如需更大的无障碍类别及其参考大小，请参阅 Apple HIG：[iOS/iPadOS larger accessibility type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-larger-accessibility-type-sizes)。

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    if dynamicTypeSize.isAccessibilitySize {
        // 无障碍尺寸（5 个最大尺寸之一）
    }
}
```

### 比较尺寸

```swift
if dynamicTypeSize >= .accessibility1 {
    // 第一个无障碍尺寸或更大
}
```

## 布局适应

在更大文本尺寸时，从水平布局切换到垂直布局，以便文本可以跨全屏宽度流动。

### 翻转堆栈轴

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    let layout = dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout())
        : AnyLayout(HStackLayout())
    
    layout {
        Image(systemName: "star")
        Text("Favorite")
    }
}
```

### 使用 Group 的方法

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    Group {
        if dynamicTypeSize.isAccessibilitySize {
            VStack { content }
        } else {
            HStack { content }
        }
    }
}

@ViewBuilder
var content: some View {
    Image(systemName: "star")
    Text("Favorite")
}
```

### ViewThatFits

让 SwiftUI 自动选择最佳布局：

```swift
ViewThatFits {
    HStack { content } // 先尝试水平
    VStack { content } // 回退到垂直
}
```

当布局应根据可用空间和实际内容适配，而不仅仅是特定 `dynamicTypeSize` 或尺寸类别阈值时使用。
当回退比简单切换 `HStack` 到 `VStack` 更复杂时（例如重新分组内容、更改层级或删除非必要装饰元素），它也是一个强有力的选择。

非常适合在屏幕上出现一次（或仅几次）的局部 UI 块。
对于列表/网格中的重复行，优先使用确定性规则（例如动态类型阈值），这样项目不会在不同行之间不一致地切换布局。

### 超大内容的 ScrollView

无论屏幕复杂度如何，考虑将屏幕包裹在滚动视图中，这样即使是无障碍尺寸也总有空间容纳内容：

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    Group {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { content }
        } else {
            content
        }
    }
}
```

### 可重用的 AdaptiveStack 组件

创建一个同时考虑尺寸类别和 Dynamic Type 的可重用组件：

```swift
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    private let horizontalAlignment: HorizontalAlignment
    private let verticalAlignment: VerticalAlignment
    private let spacing: CGFloat?
    private let content: Content
    
    public init(
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: horizontalAlignment, spacing: spacing) { content }
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing) { content }
        }
    }
}
```

用法：

```swift
AdaptiveStack(horizontalAlignment: .leading, spacing: 12) {
    Image(systemName: "info.circle")
        .font(.title2)
    VStack(alignment: .leading) {
        Text("About")
        Text("App information")
            .font(.caption)
    }
}
```

扩展额外条件，如紧凑尺寸类别：

```swift
public enum AdaptiveCondition {
    case accessible           // 无障碍文本尺寸
    case compact              // 紧凑宽度
    case compactAccessible    // 两者都是
}
```

来源：[SwiftUI Adaptive Stack Views - Use Your Loaf](https://useyourloaf.com/blog/swiftui-adaptive-stack-views/)

### 示例：列表行

```swift
struct DrinkTableRow: View {
    let drink: Drink
    @Environment(\.dynamicTypeSize.isAccessibilitySize) var accessibilitySize

    var body: some View {
        NavigationLink {
            DrinkDetail(drink: drink)
        } label: {
            // 为大文本适配布局
            if accessibilitySize {
                VStack(alignment: .leading) {
                    DrinkTableRowContent(drink: drink)
                }
            } else {
                HStack {
                    DrinkTableRowContent(drink: drink)
                }
            }
        }
    }
}
```

### 示例：步进器控件

```swift
struct ExtraShotsView: View {
    @State private var shots = 0

    var body: some View {
        ViewThatFits {
            HStack {
                Image(systemName: "minus.circle")
                Text("\(shots) shots")
                Image(systemName: "plus.circle")
                Text("+ £\(shots * 0.50, format: .currency(code: "GBP"))")
            }
            VStack {
                HStack {
                    Image(systemName: "minus.circle")
                    Text("\(shots) shots")
                    Image(systemName: "plus.circle")
                }
                Text("+ £\(shots * 0.50, format: .currency(code: "GBP"))")
            }
        }
    }
}
```

## 多行文本

SwiftUI `Text` 默认换行。对于 `TextField`：

```swift
TextField("Notes", text: $notes, axis: .vertical)
    .lineLimit(3...10)
```

如果出于产品原因必须限制行数，在更大尺寸时放宽限制（例如，无障碍尺寸加倍或三倍）：

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

private var titleLineLimit: Int {
    if dynamicTypeSize >= .accessibility3 { return 6 } // 从 2 三倍
    if dynamicTypeSize.isAccessibilitySize { return 4 } // 从 2 加倍
    return 2
}

Text(title)
    .lineLimit(titleLineLimit)
```

## 缩放非文本元素

使用 `ScaledMetric` 缩放图标、间距和边框：

```swift
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24

Image(systemName: "star")
    .frame(width: iconSize, height: iconSize)
```

### 将缩放与文本样式匹配

使用 `relativeTo:` 将缩放绑定到特定文本样式：

```swift
@ScaledMetric(relativeTo: .title3) private var borderWidth: CGFloat = 3.0
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24
@ScaledMetric(relativeTo: .largeTitle) private var headerSpacing: CGFloat = 16
```

这确保视觉元素与关联文本成比例缩放。

### 示例：缩放边框

```swift
struct TranscriptLineView: View {
    @ScaledMetric(relativeTo: .title3) private var baseBorderWidth: CGFloat = 3.0
    @Environment(\.legibilityWeight) private var legibilityWeight
    
    private var borderWidth: CGFloat {
        // 启用粗体文本时加倍边框宽度
        legibilityWeight == .bold ? baseBorderWidth * 2 : baseBorderWidth
    }
    
    var body: some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.tint, lineWidth: borderWidth)
            )
    }
}
```

## 相对框架

使用容器相对尺寸：

```swift
Text("Content")
    .containerRelativeFrame(.horizontal) { length, _ in
        length * 0.8
    }
```

## 示例：自适应卡片

```swift
struct CardView: View {
    let title: String
    let subtitle: String
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) var imageSize: CGFloat = 60
    
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading) { content }
            } else {
                HStack { content }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    var content: some View {
        Image(systemName: "photo")
            .frame(width: imageSize, height: imageSize)
        
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
```

## 示例：自适应网格

```swift
struct AdaptiveGridView: View {
    let items: [Item]
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible()), count: count)
    }
    
    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(items) { item in
                ItemView(item: item)
            }
        }
    }
}
```

## 预览不同尺寸

预览所有 Dynamic Type 尺寸：

```swift
#Preview {
    ContentView()
}
```

使用 Xcode 预览工具栏，转到"Variants"和"Dynamic Type Variants"以预览所有尺寸的布局。

### 预览中的显式尺寸

```swift
#Preview {
    ContentView()
        .dynamicTypeSize(.accessibility3)
}
```

## Large Content Viewer

对于栏项和其他不可缩放的元素，提供 Large Content Viewer：

```swift
Button { showBasket.toggle() } label: {
    ZStack(alignment: .topTrailing) {
        Image(systemName: "cart.fill")
        if basket.orderCount > 0 {
            Text("\(basket.orderCount)")
                .padding(5)
                .background(.red)
                .clipShape(Capsule())
        }
    }
}
.accessibilityShowsLargeContentViewer {
    Image(systemName: "cart.fill")
    Text("Cart, \(basket.orderCount) items")
}
```

使用更大无障碍字号的用户可以点击并按住以在屏幕中央看到放大的内容。
使用高质量矢量资源（例如 SF Symbols 或矢量 PDF），以便放大的预览保持清晰。

## 条件修饰符模式

一种基于无障碍设置条件应用修饰符的可重用模式：

```swift
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
```

用于无障碍修饰符：

```swift
@Environment(\.verticalSizeClass) private var verticalSizeClass

private var isLandscape: Bool {
    verticalSizeClass == .compact
}

var body: some View {
    Slider(value: $progress)
        .if(!isLandscape) { view in
            view.accessibilityShowsLargeContentViewer()
        }
}
```

这避免了重复视图并保持条件逻辑可读。

## 受限 Dynamic Type

对于不应超出特定尺寸缩放的元素（这应避免，你应该有非常好的理由或替代方案才这样做），约束 Dynamic Type 尺寸：

```swift
Slider(value: $progress)
    .dynamicTypeSize(.large)  // 限制在 Large 尺寸
    .accessibilityShowsLargeContentViewer()  // 为更大尺寸提供替代
```

### 示例：进度滑块

```swift
Slider(value: $sliderValue, in: 0...duration)
    .accessibilityLabel("Progress")
    .accessibilityValue(currentLineText)
    .if(!isLandscape) { view in
        view.dynamicTypeSize(.large)
            .accessibilityShowsLargeContentViewer()
    }
```

始终将受限元素与 Large Content Viewer 配对，以便使用无障碍尺寸的用户仍能访问信息。

## 最小缩放因子

允许文本在换行前稍微缩小（谨慎使用）：

```swift
Text("Long title that might not fit")
    .minimumScaleFactor(0.8)
```

## 测试

### 环境覆盖

在 Xcode 的调试区域工具栏中，点击环境覆盖以更改 Dynamic Type 尺寸。

### 模拟器快捷键

`Option + Command + +/-` 增大/减小文本尺寸。


## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
- https://accessibilityupto11.com/blog/
- https://github.com/dadederk/fromZeroToAccessible（Daniel Devesa Derksen-Staats 和 Rob Whitaker）
