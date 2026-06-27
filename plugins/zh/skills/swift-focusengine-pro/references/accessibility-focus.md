# 辅助功能和焦点

UI 焦点（`@FocusState`）和辅助功能焦点（`@AccessibilityFocusState`）是完全独立的系统。两者都正确对 tvOS、iOS、visionOS 和 macOS 应用至关重要。

## @FocusState vs @AccessibilityFocusState

| | @FocusState | @AccessibilityFocusState |
|---|---|---|
| **目的** | UI 导航（遥控器、键盘、手柄） | VoiceOver/辅助技术光标 |
| **触发** | Siri Remote 滑动、Tab 键、方向键 | VoiceOver 滑动、Switch Control |
| **视觉** | 焦点环、缩放、高亮 | VoiceOver 光标（黑色矩形） |
| **系统** | UIFocusSystem / SwiftUI 焦点引擎 | UIAccessibility / SwiftUI 辅助功能 |
| **共存** | 是——两者可以同时在不同元素上活跃 |

### SwiftUI

```swift
struct FormView: View {
    @FocusState private var uiFocus: Field?
    @AccessibilityFocusState private var voFocus: Field?
    
    enum Field { case name, email, submit }
    
    var body: some View {
        VStack {
            TextField("Name", text: $name)
                .focused($uiFocus, equals: .name)
                .accessibilityFocused($voFocus, equals: .name)
            
            TextField("Email", text: $email)
                .focused($uiFocus, equals: .email)
                .accessibilityFocused($voFocus, equals: .email)
            
            Button("Submit") { validate() }
                .focused($uiFocus, equals: .submit)
                .accessibilityFocused($voFocus, equals: .submit)
        }
    }
    
    func showError(on field: Field) {
        uiFocus = field       // 移动键盘/遥控器焦点
        voFocus = field       // 移动 VoiceOver 光标
    }
}
```

设置两者确保视力正常用户和 VoiceOver 用户都落在错误字段上。

## VoiceOver + 焦点协调

### tvOS

在 tvOS 上，VoiceOver 更改 Siri Remote 的工作方式：
- 左/右滑动移动 VoiceOver 光标（非 UI 焦点）
- 双击激活 VoiceOver 聚焦的元素
- UI 焦点和 VoiceOver 焦点默认一起移动，但如果你以编程方式设置其中一个而不设置另一个可能不同步

**规则：** 在 tvOS 上以编程方式移动焦点时，如果 VoiceOver 可能活跃，也要移动辅助功能焦点。

### iOS

在 iOS 上，VoiceOver 焦点独立于键盘焦点：
- VoiceOver 用户滑动以顺序导航
- 键盘用户 Tab/方向键按焦点组导航
- 两者可以同时活跃（外部键盘 + VoiceOver）

### visionOS

在 visionOS 上，VoiceOver 替代注视作为定位机制：
- 不同手势用于导航（手指捏合）
- 悬停效果仍渲染但不是主要反馈
- RealityKit 实体上的辅助功能标签至关重要

```swift
entity.accessibilityLabel = "3D Trophy Model"
entity.isAccessibilityElement = true
```

## 完全键盘访问（iOS/iPadOS）

完全键盘访问（设置 > 辅助功能 > 键盘）为所有用户启用 Tab/方向键导航，不仅是连接硬件键盘的用户。它激活完整的焦点系统。

### 完全键盘访问的焦点组

```swift
VStack {
    // 组 1：导航
    HStack {
        Button("Home") { }
        Button("Search") { }
        Button("Settings") { }
    }
    .focusSection()
    
    // 组 2：内容
    LazyVGrid(columns: columns) {
        ForEach(items) { item in
            CardView(item: item)
        }
    }
    .focusSection()
}
```

Tab 在组之间移动。方向键在组内移动。没有 `.focusSection()`，Tab 遍历每个单独元素。

### UIFocusGroupPriority（UIKit）

控制多个组存在时哪个焦点组接收初始焦点：

```swift
// 更高优先级 = 优先获得焦点
navigationBar.focusGroupPriority = .prioritized  // .prioritized > .default > .ignored
contentArea.focusGroupPriority = .default
```

## Switch Control

Switch Control 让用户使用外部开关（按钮、头部动作、支持设备上的眼睛追踪）导航。

### tvOS
- 自动扫描模式循环遍历可聚焦元素
- 元素必须在焦点链中才能到达
- `.disabled()` 反模式也破坏 Switch Control 导航

### iOS
- 点扫描和项扫描模式
- 尊重辅助功能元素分组
- `.accessibilityElement(children: .combine)` 将子项组合为一个开关目标

### visionOS
- 使用注视控制变体——注视元素设定时长
- RealityKit 实体需要辅助功能属性

## 可聚焦元素的辅助功能标签

没有辅助功能标签的可聚焦元素仅按类型播报（"按钮"、"链接"），这对 VoiceOver 用户无用。

```swift
// 错误
Button(action: play) {
    Image(systemName: "play.fill")
}

// 正确
Button(action: play) {
    Image(systemName: "play.fill")
}
.accessibilityLabel("Play video")
```

### tvOS 聚焦状态播报

当焦点在 tvOS 上移动到新元素时，VoiceOver 播报元素。自定义视图必须提供有意义的标签：

```swift
CardView(show: show)
    .focusable()
    .accessibilityLabel("\(show.title), \(show.genre)")
    .accessibilityHint("Press select to play")
    .accessibilityAddTraits(.isButton)
```

### 在可聚焦卡片上组合 VoiceOver 标签

具有多个文本元素（眉题、标题、时长、直播徽章）的卡片在 tvOS 上作为单个单元可聚焦。没有组合标签，VoiceOver 会单独读取每个子视图——混乱且缓慢。

```swift
// 错误——VoiceOver 分别读取"News"、"Breaking Story Title"、"LIVE"、"2:34"
CardView(clip: clip)
    .focusable()

// 正确——单个组合播报
CardView(clip: clip)
    .focusable()
    .accessibilityElement(children: .ignore)  // 从 VoiceOver 隐藏子视图
    .accessibilityLabel(composeLabel(for: clip))
    .accessibilityAddTraits(clip.isLive ? [.isButton, .updatesFrequently] : .isButton)
    .accessibilityHint("Press select to play")

func composeLabel(for clip: Clip) -> String {
    var parts = [clip.eyebrow, clip.title]
    if clip.isLive { parts.append("Live") }
    if let duration = clip.formattedDuration { parts.append(duration) }
    if clip.isLocked { parts.append("Locked") }
    return parts.compactMap { $0 }.joined(separator: ", ")
}
```

此模式对卡片包含 3-5 个文本元素加状态徽章的媒体应用至关重要。

## 自定义操作和焦点

VoiceOver 自定义操作让用户执行次要操作而无需离开聚焦元素。

```swift
CardView(show: show)
    .accessibilityAction(named: "Add to favorites") {
        addToFavorites(show)
    }
    .accessibilityAction(named: "More info") {
        showDetails(show)
    }
```

在 tvOS 上，这些出现在 VoiceOver 转子中。在 iOS 上，上/下滑动循环操作。

## 焦点顺序和辅助功能顺序

SwiftUI 辅助功能顺序默认遵循视图层次结构。焦点顺序（键盘/遥控器）是几何的。这些可能冲突。

### 当它们冲突时

```swift
// 视觉布局：[B] [A] [C]（A 视觉居中但声明为第二个）
HStack {
    ButtonB()  // VoiceOver 先读取，焦点引擎可能先聚焦
    ButtonA()  // VoiceOver 第二读取
    ButtonC()  // VoiceOver 第三读取
}
```

要覆盖辅助功能读取顺序而不更改焦点几何：

```swift
HStack {
    ButtonB()
        .accessibilitySortPriority(1)
    ButtonA()
        .accessibilitySortPriority(3)  // VoiceOver 先读取
    ButtonC()
        .accessibilitySortPriority(2)
}
```

`accessibilitySortPriority` 不影响键盘/遥控器焦点顺序。

## 动态类型和焦点

大文本尺寸会更改视图尺寸，这影响 tvOS 上焦点引擎的几何计算。

- 更大文本 = 更大焦点目标（好）
- 但可能将元素推到屏幕外或垂直未对齐（对焦点几何不好）
- 始终用最大动态类型尺寸测试焦点导航

## 减弱动态效果和焦点动画

启用减弱动态效果时（设置 > 辅助功能 > 动态效果），焦点动画应简化：

```swift
struct CardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isFocused)
    }
}
```

在 UIKit 中：

```swift
override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
    if UIAccessibility.isReduceMotionEnabled {
        // 立即应用状态更改，无动画
        self.transform = isFocused ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
    } else {
        coordinator.addCoordinatedFocusingAnimations({ _ in
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: nil)
    }
}
```

## VoiceOver 动画滚动守卫（tvOS）

在侧边栏或列表中使用 `withAnimation` 进行程序化滚动时，VoiceOver 用户可能因意外滚动动画而迷失方向。检查 `UIAccessibility.isVoiceOverRunning` 并跳过动画：

```swift
.onChange(of: focusedIndex) { _, newIndex in
    guard let index = newIndex else { return }
    if UIAccessibility.isVoiceOverRunning {
        scrollPosition.scrollTo(id: index)  // 无动画
    } else {
        withAnimation(.easeInOut(duration: 0.2)) {
            scrollPosition.scrollTo(id: index)
        }
    }
}
```

这防止 VoiceOver 在视口意外移动时失去位置。

## 常见错误

### 1. 设置 @FocusState 但未设置 @AccessibilityFocusState
视力正常用户看到焦点移到错误字段。VoiceOver 用户什么也听不到，因为 VoiceOver 光标没有移动。

### 2. 使用 .disabled() 同时从 VoiceOver 移除
`.disabled(true)` 使元素对焦点和 VoiceOver 都不可访问。在 tvOS 上，在按钮闭包内门控操作而非禁用视图（见反模式 #1）。注意：`.allowsHitTesting(false)` 在 tvOS 上不可靠，也可能从 VoiceOver 移除视图。无论哪种方式，始终设置 `.accessibilityLabel` 包含禁用状态信息。

### 3. 可聚焦自定义视图缺少辅助功能标签
VoiceOver 播报"按钮"无上下文。每个可聚焦元素都需要描述性标签。

### 4. 忽略焦点动画的减弱动态效果
焦点更改时的缩放和阴影动画可能引起不适。检查 `accessibilityReduceMotion` 或 `UIAccessibility.isReduceMotionEnabled`。

### 5. 未在 tvOS 上用 VoiceOver 测试
tvOS 上的 VoiceOver 与 iOS 工作方式非常不同。Siri Remote 交互模型完全改变。用实际 Apple TV + VoiceOver 启用测试。

### 6. 辅助功能顺序与焦点顺序冲突
VoiceOver 按视图树顺序读取，焦点引擎按几何导航。当两个顺序显著偏离时用户可能困惑。

## macOS 辅助功能和焦点

### macOS 上的 VoiceOver

macOS VoiceOver 使用 `VO+方向键`（Control+Option+方向键）导航，与 Tab 焦点分开：

- **Tab 焦点**：`@FocusState` / 第一响应者（键盘导航）
- **VoiceOver 光标**：由 VO 键命令控制，遵循辅助功能元素顺序
- VoiceOver 开启时两个系统同时活跃

```swift
// SwiftUI——相同 API，在 macOS 上有效
@AccessibilityFocusState private var voFocus: Field?

TextField("Name", text: $name)
    .accessibilityFocused($voFocus, equals: .name)
```

### NSAccessibility 协议（AppKit）

AppKit 视图遵循 `NSAccessibilityProtocol`。焦点相关属性：

```swift
class MyView: NSView {
    override func accessibilityFocusedUIElement() -> Any? {
        // 返回 VoiceOver 应聚焦的子元素
        return self
    }

    override var isAccessibilityFocused: Bool {
        // VoiceOver 光标是否在此元素上
        return window?.firstResponder === self
    }

    override func accessibilityPerformPress() -> Bool {
        // VoiceOver 激活此元素时调用（VO+Space）
        performAction()
        return true
    }
}
```

### macOS 上的完全键盘访问

macOS 完全键盘访问（系统设置 > 键盘 > 键盘导航）影响：
- 所有控件变为可 Tab 聚焦（按钮、复选框、滑块、弹出）
- 焦点环出现在所有聚焦控件上
- 与常规 Tab 导航相同的焦点系统——`canBecomeKeyView` 决定可达性

```swift
// 运行时检查
if NSApplication.shared.isFullKeyboardAccessEnabled {
    // FKA 开启——所有控件获得焦点
} else {
    // 默认只有文本字段和列表接收 Tab 焦点
}
```

### macOS 上的语音控制

语音控制（macOS 10.15+）在所有交互元素上显示编号标签。缺少辅助功能标签的可聚焦元素只获得通用编号，使它们难以通过语音定位。

```swift
// 错误——语音控制显示"Button 7"无上下文
Button(action: save) {
    Image(systemName: "square.and.arrow.down")
}

// 正确——语音控制显示"Save"标签
Button(action: save) {
    Image(systemName: "square.and.arrow.down")
}
.accessibilityLabel("Save")
```

### macOS 辅助功能焦点错误

**7. 未在工具栏项目上设置辅助功能标签。** NSToolbarItem 按钮通常仅图标。VoiceOver 播报"按钮"无上下文。

**8. 菜单项缺少适当辅助功能。** 自定义菜单项如果包含非文本内容（图标、自定义视图）应有辅助功能标签。

**9. 忽略 NSPanel 的 VoiceOver。** 浮动面板和弹出框可能混淆 VoiceOver 的导航顺序。在模态面板上设置 `accessibilityModal = true` 使 VoiceOver 不读取后面的内容。
