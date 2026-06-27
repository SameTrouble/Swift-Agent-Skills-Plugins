# VoiceOver — SwiftUI

VoiceOver 无障碍的 SwiftUI 实现。

如需核心概念，请参阅 `voiceover.md`。

## 目录

- [标签](#标签)
- [值](#值)
- [提示](#提示)
- [特质](#特质)
- [分组](#分组)
- [导航顺序](#导航顺序)
- [图片](#图片)
- [自定义操作](#自定义操作)
- [无障碍自定义内容](#无障碍自定义内容)
- [可调节控件](#可调节控件)
- [无障碍表示](#无障碍表示)
- [手势](#手势)
- [焦点管理](#焦点管理)
- [公告](#公告)
- [模态对话框](#模态对话框)
- [自定义转子](#自定义转子)
- [示例：带操作的分组卡片](#示例带操作的分组卡片)

## 标签

### 基本标签

```swift
Button(action: play) {
    Image(systemName: "play.fill")
}
.accessibilityLabel("Play")
```

### 带标签的仅图标按钮

```swift
Button(action: play) {
    Label("Play", systemImage: "play.fill")
}
.labelStyle(.iconOnly)
```

这在渲染仅图标控件的同时保留语义文本标签。

### 文本自动用作标签

```swift
Button("Submit", action: submit)
// accessibilityLabel 自动为"Submit"
```

### 状态驱动标签

当控件含义随状态变化时，更新标签以反映当前操作：

```swift
struct PlayButton: View {
    @Binding var isPlaying: Bool
    
    var body: some View {
        Button(action: { isPlaying.toggle() }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        }
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}
```

### 组合多个视图的文本

使用 `.combine` 自动合并。如果需要严格控制措辞（例如避免标点停顿），使用 `.ignore` 并设置手动标签。

```swift
// 自动合并
HStack {
    Text("Price")
    Text("$42.00")
}
.accessibilityElement(children: .combine)
// VoiceOver 读取："Price, $42.00"

// 手动表达
HStack {
    Text("Price of")
    Text("$42.00")
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Price of $42.00")
```

### 带值模式的徽章

当视觉徽章显示计数时，保持稳定标签并将变化部分放入值：

```swift
// 之前：令人困惑的标签变化
Button { showBasket.toggle() } label: {
    ZStack(alignment: .topTrailing) {
        Image(systemName: "cart.fill")
        if basket.orderCount > 0 {
            Text("\(basket.orderCount)")
                .background(.red)
                .clipShape(Capsule())
        }
    }
}
// VoiceOver 读取："cart.fill" 或 "3" 取决于状态 — 令人困惑

// 之后：一致标签带动态值
Button { showBasket.toggle() } label: {
    ZStack(alignment: .topTrailing) {
        Image(systemName: "cart.fill")
        if basket.orderCount > 0 {
            Text("\(basket.orderCount)")
                .background(.red)
                .clipShape(Capsule())
        }
    }
}
.accessibilityLabel("Cart")
.accessibilityValue("\(basket.orderCount) items")
// VoiceOver 读取："Cart, 3 items, button"
```

## 值

```swift
Slider(value: $volume, in: 0...10000)
    .accessibilityValue("\(Int(volume)) steps")
```

值随绑定自动更新。

## 提示

```swift
Button("Delete", action: delete)
    .accessibilityHint("Removes the item from your list")
```

提示是可选的，但有助于描述不寻常的控件：
优先使用描述操作结果的提示措辞（例如"Removes the item from your list"）。

```swift
HStack {
    ForEach(1..<6) { value in
        Button { rating = value } label: {
            Image(systemName: value <= rating ? "hand.thumbsup.fill" : "hand.thumbsup")
        }
    }
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Rating")
.accessibilityValue("\(rating) thumbs up")
.accessibilityHint("Rates your drink from 1 to 5 thumbs up")
```

## 特质

### 标题特质

标记章节标题以用于转子导航：

```swift
Text("Settings")
    .font(.headline)
    .accessibilityAddTraits(.isHeader)
```

### 标题级别

对于具有层次结构的文档，使用语义标题级别进行屏幕阅读器导航（iOS 17+），使用 [`.accessibilityHeading(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityheading(_:))：

```swift
Text("Main Title")
    .font(.largeTitle)
    .accessibilityAddTraits(.isHeader)
    .accessibilityHeading(.h1)

Text("Section")
    .font(.title2)
    .accessibilityAddTraits(.isHeader)
    .accessibilityHeading(.h2)

Text("Subsection")
    .font(.title3)
    .accessibilityAddTraits(.isHeader)
    .accessibilityHeading(.h3)
```

可用级别：`.h1` 到 `.h6`，以及 `.unspecified`（iOS 17+，参见 [`.accessibilityHeading(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityheading(_:))）。

### 频繁更新特质

对于快速变化的值（计时器、进度、实时数据），添加 `.updatesFrequently` 以便 VoiceOver 可以批量更新：

```swift
Slider(value: $progress, in: 0...100)
    .accessibilityLabel("Progress")
    .accessibilityValue("Line \(currentLine) of \(totalLines)")
    .accessibilityAddTraits(.updatesFrequently)
```

这防止 VoiceOver 在播放或动画期间值快速变化时中断自身。

### 选中特质

用于选择器选项、切换状态和分段控件：

```swift
ForEach(MilkOptions.allCases, id: \.self) { milk in
    Button {
        selectedMilk = milk
    } label: {
        HStack {
            Text(milk.rawValue)
            Spacer()
            Image(systemName: selectedMilk == milk ? "checkmark.circle" : "circle")
                .accessibilityHidden(true)  // 仅视觉
        }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selectedMilk == milk ? .isSelected : [])
}
```

### 常见特质

| 特质 | 用途 |
|-------|-----|
| `.isButton` | 可点击控件 |
| `.isHeader` | 章节标题（转子导航） |
| `.isSelected` | 当前选中选项 |
| `.isLink` | 打开 URL |
| `.isImage` | 图片内容 |
| `.isStaticText` | 非交互文本 |
| `.isModal` | 模态对话框 |
| `.updatesFrequently` | 快速变化的值 |

### 使用 `.disabled()` 而非 `.notEnabled`

在 UIKit 中，`.notEnabled` 是显式特质。在 SwiftUI 中，使用 `.disabled(...)` 并让框架暴露禁用的无障碍状态和交互行为。

```swift
Button("Submit", action: submit)
    .disabled(!isValid)
```

## 分组

### accessibilityElement(children:)

| 选项 | 行为 |
|--------|----------|
| `.ignore` | 单个元素；手动设置标签和其他属性 |
| `.combine` | 自动合并子元素标签和其他属性 |
| `.contain` | 语义分组；子元素仍单独可访问 |

优先使用 `.combine` — 它会在内容变化时自动更新。

### 分组自定义控件

UIKit 通常需要显式添加 `.adjustable`。在 SwiftUI 中，`.accessibilityAdjustableAction` 隐式暴露可调节行为。

当现有标准控件能很好地映射到你的自定义控件时，优先使用 `.accessibilityRepresentation { }`，以保持交互模式熟悉。

当多个按钮形成一个逻辑控件时，将它们分组：

```swift
// 之前：VoiceOver 读取 5 个独立按钮
HStack {
    ForEach(1..<6) { value in
        Button { rating = value } label: {
            Image(systemName: value <= rating ? "hand.thumbsup.fill" : "hand.thumbsup")
        }
    }
}

// 之后：单个可调节控件
HStack {
    ForEach(1..<6) { value in
        Button { rating = value } label: {
            Image(systemName: value <= rating ? "hand.thumbsup.fill" : "hand.thumbsup")
        }
    }
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Rating")
.accessibilityValue("\(rating) thumbs up")
.accessibilityAdjustableAction { direction in
    switch direction {
    case .increment:
        guard rating < 5 else { return }
        rating += 1
    case .decrement:
        guard rating > 1 else { return }
        rating -= 1
    @unknown default:
        break
    }
}
```

### 分组列表行

将所有内容放入 NavigationLink 的标签中以自动分组：

```swift
// 之前：隐藏的 NavigationLink，独立按钮
ZStack {
    HStack {
        Text(drink.name)
        Button("Add to cart") { basket.add(Order(drink: drink)) }
    }
    NavigationLink { DrinkDetail(drink: drink) } label: { EmptyView() }
        .opacity(0)
}

// 之后：带自定义操作的正确分组
NavigationLink {
    DrinkDetail(drink: drink)
} label: {
    HStack {
        Text(drink.name)
        Text(CurrencyFormatter.format(drink.basePrice))
    }
}
.accessibilityAction(named: "Add to cart") {
    basket.add(Order(drink: drink))
}
```

## 导航顺序

### 排序优先级

用优先级更改读取顺序（数字越大越先读取）：

```swift
VStack {
    Text("Read second").accessibilitySortPriority(1)
    Text("Read first").accessibilitySortPriority(2)
}
```

默认优先级为 0。对应更早读取的元素使用正数。

## 图片

### 装饰性图片

```swift
Image(decorative: "background-pattern")

// 或：
Image("background")
    .accessibilityHidden(true)
```

### Smart Invert 支持

防止照片和有意义的图片反转：

```swift
Image(imageName)
    .resizable()
    .accessibilityHidden(true)  // 装饰性
    .accessibilityIgnoresInvertColors()  // 不随 Smart Invert 反转
```

### 有意义的图片

```swift
Image("profile-photo")
    .accessibilityLabel("Profile photo of Johnny Appleseed")
```

## 自定义操作

暴露隐藏或次要操作：

```swift
// 之前：单元格内的按钮难以到达
HStack {
    Text(drink.name)
    Button("Add to cart") { basket.add(Order(drink: drink)) }
}

// 之后：通过 VoiceOver 可访问的操作
NavigationLink { DrinkDetail(drink: drink) } label: {
    Text(drink.name)
}
.accessibilityAction(named: "Add to cart") {
    basket.add(Order(drink: drink))
}
```

### 多个操作

```swift
.accessibilityAction(named: "Delete") { delete() }
.accessibilityAction(named: "Share") { share() }
```

### iOS 16+ 语法

```swift
.accessibilityActions {
    Button("Delete", action: delete)
    Button("Share", action: share)
}
```

此语法需要 iOS 16+（[Apple 文档](https://developer.apple.com/documentation/swiftui/view/accessibilityactions(content:))）。

## 无障碍自定义内容

用于数据丰富 UI 中的补充细节而不重载主标签/值：
尽可能使相同的信息在其他地方也独立可访问（例如在详情屏幕中）。

```swift
VStack(alignment: .leading) {
    Text("AAPL")
    Text("$182.34")
}
.accessibilityLabel("Apple stock")
.accessibilityValue("$182.34")
.accessibilityCustomContent("Daily change", value: "+1.8 percent")
.accessibilityCustomContent("52-week range", value: "124 to 199")
.accessibilityCustomContent("Risk", value: "Moderate", importance: .high)
```

将自定义内容用于次要上下文。将主要操作/状态保留在标签、值、特质和操作中。

## 可调节控件

用单个可调节控件替换多个按钮：

```swift
struct RatingView: View {
    @Binding var rating: Int

    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) of 5")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(rating + 1, 5)
            case .decrement:
                rating = max(rating - 1, 1)
            @unknown default:
                break
            }
        }
    }
}
```

## 无障碍表示

用标准的可访问等效控件替换复杂自定义控件：

```swift
// 之前：带点击手势的自定义加/减图标
HStack {
    Image(systemName: "minus.circle")
        .onTapGesture { shots = max(0, shots - 1) }
    Text("\(shots) shots")
    Image(systemName: "plus.circle")
        .onTapGesture { shots = min(4, shots + 1) }
}

// 之后：辅助技术看到滑块
HStack {
    Image(systemName: "minus.circle")
        .onTapGesture { shots = max(0, shots - 1) }
    Text("\(shots) shots")
    Image(systemName: "plus.circle")
        .onTapGesture { shots = min(4, shots + 1) }
}
.accessibilityRepresentation {
    Slider(value: $shots, in: 0...4, step: 1)
        .accessibilityLabel("Extra shots")
        .accessibilityValue("\(Int(shots)) shots")
}
```

用户看到你的自定义 UI；VoiceOver 与 Slider 交互。

## 手势

### Magic Tap

双指双击触发主要操作。非常适合媒体应用中的播放/暂停：

```swift
struct PlayerView: View {
    @State private var isPlaying = false
    
    var body: some View {
        VStack {
            // 播放器 UI...
        }
        .accessibilityAction(.magicTap) {
            isPlaying.toggle()
        }
    }
}
```

应用于最外层视图以使 Magic Tap 在屏幕任何位置工作：

```swift
NavigationStack {
    TranscriptView()
}
.accessibilityAction(.magicTap) {
    audioManager.isPlaying ? audioManager.pause() : audioManager.play()
}
```

### Escape

```swift
.accessibilityAction(.escape) {
    dismiss()
}
```

### 实时交互的直接触摸

对于快速、连续的交互（例如音乐应用、绘图画布和某些游戏控件），直接触摸可以减少摩擦：

```swift
JoystickView()
    .accessibilityDirectTouch(true, options: [.silentOnTouch])
```

谨慎使用。除非交互真正依赖于实时触摸移动，否则优先使用常规 VoiceOver 导航。

## 焦点管理

### 编程移动焦点

```swift
@AccessibilityFocusState private var isFocused: Bool

var body: some View {
    VStack {
        TextField("Name", text: $name)
            .accessibilityFocused($isFocused)
        Button("Focus Field") {
            isFocused = true
        }
    }
}
```

### 错误时聚焦

```swift
struct FormView: View {
    @State private var email = ""
    @State private var showError = false
    @AccessibilityFocusState private var isErrorFocused: Bool
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
            
            if showError {
                Text("Email is required")
                    .foregroundStyle(.red)
                    .accessibilityFocused($isErrorFocused)
            }
            
            Button("Submit") {
                if email.isEmpty {
                    showError = true
                    isErrorFocused = true  // 将 VoiceOver 移至错误
                }
            }
        }
    }
}
```

## 公告

对于像 toast 这样的临时反馈，向 VoiceOver 公告：

```swift
// 之前：toast 短暂出现，VoiceOver 用户错过它
Text(message ?? "")
    .opacity(opacity)

// 之后：公告消息
func showToast(_ message: String) {
    if #available(iOS 17, *) {
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    } else {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
```

**注意：** Toast 对无障碍有挑战。尽可能考虑持久的和/或行内的反馈替代方案。

## 模态对话框

```swift
.accessibilityAddTraits(.isModal)
```

## 从 VoiceOver 隐藏

```swift
Image(decorative: "divider")

// 或：
Image("divider")
    .accessibilityHidden(true)
```

## 自定义转子

```swift
.accessibilityRotor("Headings") {
    ForEach(headings, id: \.id) { heading in
        AccessibilityRotorEntry(heading.title, id: heading.id)
    }
}
```

## 示例：带操作的分组卡片

此示例在一个卡片组件中组合了分组、特质和自定义操作：

```swift
struct CardView: View {
    let item: Item
    @Binding var isFavorite: Bool
    var onDelete: () -> Void
    
    var body: some View {
        VStack {
            Image(item.imageName)
                .accessibilityIgnoresInvertColors()
            Text(item.title)
            Text(item.subtitle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: isFavorite ? "Remove from favorites" : "Add to favorites") {
            isFavorite.toggle()
        }
        .accessibilityAction(named: "Delete") {
            onDelete()
        }
    }
}
```

## 来源

- [Accessibility Up To 11 — #365DaysIOSAccessibility](https://accessibilityupto11.com/365-days-ios-accessibility/)
- [Accessibility Up To 11 — Blog](https://accessibilityupto11.com/blog/)
- [From Zero to Accessible](https://github.com/dadederk/fromZeroToAccessible)（Rob Whitaker 和 Daniel Devesa Derksen-Staats）
