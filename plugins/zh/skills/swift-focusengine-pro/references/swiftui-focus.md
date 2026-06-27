# tvOS 的 SwiftUI 焦点 API

## @FocusState

跟踪并以编程方式控制哪个视图拥有焦点。tvOS 15+ 可用。

### 布尔形式——单个可聚焦视图
```swift
@FocusState private var isFieldFocused: Bool

TextField("Search", text: $query)
    .focused($isFieldFocused)

// 移动焦点：
isFieldFocused = true
```

### 枚举形式——多个可聚焦视图
```swift
enum Field: Hashable {
    case email, password
}

@FocusState private var focusedField: Field?  // 必须是 Optional

TextField("Email", text: $email)
    .focused($focusedField, equals: .email)
SecureField("Password", text: $password)
    .focused($focusedField, equals: .password)

// 移动焦点：
focusedField = .password
// 从此作用域移除焦点：
focusedField = nil
```

### 与 ViewModel 同步
```swift
// 用于双向同步的视图扩展
extension View {
    func sync<T: Equatable>(_ binding: Binding<T>, with focusState: FocusState<T>) -> some View {
        onChange(of: binding.wrappedValue) { _, newValue in
            focusState.wrappedValue = newValue
        }
        .onChange(of: focusState.wrappedValue) { _, newValue in
            binding.wrappedValue = newValue
        }
    }
}

// 用法：
@FocusState var focusedSection: SettingsSection?

var body: some View {
    content
        .sync($viewModel.focusedSection, with: _focusedSection)
}
```

## focusSection()

使容器的整个 frame 对焦点引擎表现为一个大的可聚焦区域。这是 `UIFocusGuide` 的 SwiftUI 等价物。

没有它，焦点移动仅在几何上相邻的可聚焦视图之间有效。有了它，焦点引擎将容器的 frame 视为可扫描的。

```swift
HStack {
    VStack {
        Button("A") {}
        Button("B") {}
    }
    .focusSection()  // 左列

    VStack {
        Button("C") {}
        Button("D") {}
    }
    .focusSection()  // 右列
}
```

### 何时使用 focusSection()
- 垂直布局中的每个水平 ScrollView（防止跨行跳跃）
- 侧边栏/内容分割布局（每个窗格有自己的区域）
- 与内容分开的标签栏区域
- 任何应作为单元导航的可聚焦项目组

### 陷阱
`focusSection()` 需要容器有足够的 frame 尺寸。如果按钮没有填满空间，在容器内部添加 `Spacer()` 来扩展其边界。

**无最后焦点记忆。** 与 UIKit 的 `remembersLastFocusedIndexPath` 不同，`focusSection()` 不记忆你从哪个项目离开。每次进入时焦点引擎都**按几何方式**选择——最接近焦点来源位置的项目——而非你上次在区域内聚焦的项目。因此如果重新进入区域落在错误的项目上（例如从网格向上箭头回到一行分区/分类标签时落在最近的标签而非选中的那个），那个几何选择就是原因。修复是门控进入，使只有预期项目从外部可聚焦——见**反模式 #25**（双重 `@FocusState` + `.disabled()` 门控）：容器 `@FocusState` 布尔加上 `.disabled(!isContainerFocused && item != selected)` 恰好留下一个有效进入目标，因此重新进入落在那里，没有几何跳跃。反应式 `onChange` 重定向在这里不起作用——引擎先按几何移动，所以你会看到可见跳跃然后才修正。

**比下方内容更窄的区域会让焦点越过它逃逸。** 与上面的"太小"情况不同：这里区域有可聚焦项目，只是它们不在几何上方。如果 `focusSection()` 比其下方内容更窄（或水平偏移），没有区域直接在上方的列在按上时找不到任何东西——焦点完全越过区域逃逸（例如直接到标签栏）。在应用 `.focusSection()` 之前扩展区域以跨越内容宽度：

```swift
HStack { /* 左对齐标签 */ }
    .frame(maxWidth: .infinity, alignment: .leading)  // 跨越整个网格宽度
    .focusSection()                                    // 使下方每列都有区域覆盖
```

## prefersDefaultFocus(_:in:) + focusScope(_:)

控制哪个视图在命名空间作用域内默认获得焦点。仅限 tvOS 和 watchOS。

```swift
@Namespace private var namespace
@Environment(\.resetFocus) var resetFocus

VStack {
    Button("Search") { }
        .prefersDefaultFocus(shouldFocusSearch, in: namespace)
    Button("Play") { }
        .prefersDefaultFocus(!shouldFocusSearch, in: namespace)
    Button("Reset Focus") {
        resetFocus(in: namespace)
    }
}
.focusScope(namespace)
```

规则：
- `focusScope(namespace)` 必须在使用 `prefersDefaultFocus` 的视图的祖先上
- `resetFocus(in:)` 重新求值偏好并移动焦点
- 在 ScrollView 内不起作用——请改用 `defaultFocus`

## defaultFocus(_:_:priority:)

现代跨平台替代方案。在 ScrollView 内有效。

```swift
@FocusState private var focusedField: Field?

VStack { ... }
    .defaultFocus($focusedField, .email, priority: .userInitiated)
```

优先级级别：
- `.automatic`——默认，系统可能覆盖
- `.userInitiated`——即使系统会选择不同也强制焦点（谨慎使用）

## onMoveCommand

当几何焦点失败时的自定义方向导航。

```swift
.onMoveCommand { direction in
    switch direction {
    case .left: focusedField = .sidebar
    case .right: focusedField = .content
    case .down: focusedField = .row1
    default: break
    }
}
```

## onExitCommand

拦截 Menu/返回按钮按下。对侧边栏模式至关重要。

```swift
.onExitCommand {
    if !sidebarExpanded {
        sidebarExpanded = true  // 展开侧边栏而非退出
    }
}
```

## focusable() 和 focusable(interactions:)

使任何视图能够接收焦点。

```swift
.focusable()                        // 所有交互
.focusable(interactions: .edit)     // 类似文本编辑
.focusable(interactions: .activate) // 类似按钮激活
.focusable(isEnabled)               // 条件性
```

不要应用于 Button、NavigationLink 或 Toggle——它们已经可聚焦。

## isFocused 环境

只读焦点状态。如果最近的可聚焦祖先已聚焦则返回 true。

```swift
@Environment(\.isFocused) var isFocused
```

用于自定义 ButtonStyles 的视觉反馈。参见 `references/focus-styling.md`。

## 悬停效果（tvOS 17+）

```swift
.hoverEffect(.lift)       // Buttons 的默认——抬起视图
.hoverEffect(.highlight)  // 添加透视偏移 + 镜面光泽（适合艺术作品）
.focusEffectDisabled()     // 禁用默认焦点外观
```

## AutoFocus 模式

屏幕加载时的一次性程序化焦点，与布局完成协调：

```swift
class AutoFocusManager: ObservableObject {
    @Published var shouldAutoFocus = true
    private let subject = PassthroughSubject<Void, Never>()
    var publisher: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
    private var hasTriggered = false

    func trigger() {
        guard shouldAutoFocus, !hasTriggered else { return }
        subject.send()
        hasTriggered = true
        shouldAutoFocus = false
    }

    func reset() {
        shouldAutoFocus = true
        hasTriggered = false
    }
}

// 在父视图中——布局完成后触发：
.onPreferenceChange(LayoutCompleteKey.self) { complete in
    if complete { autoFocusManager.trigger() }
}

// 在子视图中——接收并设置焦点：
.onReceive(autoFocusManager.publisher) { _ in
    focusedField = .mainContent
}
```
