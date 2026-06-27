# 焦点反模式（所有平台）

这些是破坏焦点导航的关键错误。发现任何出现都应立即标记。模式 1-17 是原始 tvOS 模式。模式 18-24 是 macOS 特定的。模式 25-30 是大规模媒体应用开发中发现的生产级 tvOS 模式。

## 阻塞性（发布前必须修复）

### 1. 在 tvOS 上使用 `.disabled()` 切换交互性

`.disabled(true)` 在 tvOS 上会将视图从焦点链中完全移除。焦点不可预测地跳到远处的视图。这是"焦点跳动"的头号原因。

```swift
// 错误——视图从焦点链中消失
Button("Watch") { ... }
    .disabled(isLoading)
```

**没有完美的 SwiftUI 替代方案。** 常被推荐的 `.allowsHitTesting(false)` 在 **tvOS 上不可靠**——生产测试发现它可能在底层映射为 `isUserInteractionEnabled = false`，这正是反模式 #8 所警告的。生产代码库已记录了这一点：`.disabled()` 使按钮即使在重新启用后也无法聚焦，破坏对角线导航。但 `.allowsHitTesting(false)` 在保持视图可聚焦方面结论不确定。

**推荐方法，取决于上下文：**

```swift
// 选项 A：allowsHitTesting——适用于简单情况但需在设备上验证
Button("Watch") { ... }
    .allowsHitTesting(!isLoading)
    .opacity(isLoading ? 0.5 : 1.0)
// ⚠️ 可能不会在所有上下文中保持视图可聚焦。在真实 Apple TV 上测试。

// 选项 B：保持按钮激活，门控操作（最可靠）
Button("Watch") {
    guard !isLoading else { return }
    play()
}
.opacity(isLoading ? 0.5 : 1.0)
// 按钮始终保持可聚焦。操作在闭包内被门控。

// 选项 C：用于侧边栏/列表——使用 .disabled() 配合双重 @FocusState 门控
// 完整模式见反模式 #25。
// .disabled() 在仅约束从外部进入时安全工作，
// 一旦焦点在容器内部，所有项目都是启用的。
```

UIKit 等价物：`UIButton.isEnabled = false` 也会使按钮不可聚焦。参考 UIKit 模式从不禁用单个项目——而是门控容器的 `isUserInteractionEnabled`（参见 layout-patterns.md，UIKit 侧边栏部分）。

**对于具有活动选择状态的侧边栏/列表项**，请参见下面的反模式 #25——同时对多个项目使用 `.disabled()` 是此问题更糟糕的变体。

### 2. 垂直布局中水平 ScrollView 上缺少 `.focusSection()`

没有 `.focusSection()`，从水平行向下滑动会将焦点对角跳到下一行中未对齐的项目。焦点引擎需要这个来将每行视为逻辑组。

```swift
// 错误
VStack {
    ScrollView(.horizontal) { HStack { /* 第 1 行 */ } }
    ScrollView(.horizontal) { HStack { /* 第 2 行 */ } }
}

// 正确
VStack {
    ScrollView(.horizontal) { HStack { /* 第 1 行 */ } }
        .focusSection()
    ScrollView(.horizontal) { HStack { /* 第 2 行 */ } }
        .focusSection()
}
```

### 3. 向 Buttons 或 NavigationLinks 添加 `.focusable()`

Buttons 和 NavigationLinks 已经可聚焦。添加 `.focusable()` 会将它们包装在第二个可聚焦层中，导致双重焦点伪影。

```swift
// 错误
Button("Play") { ... }
    .focusable()

// 正确
Button("Play") { ... }
```

例外：自定义 ButtonStyle 内部视图上的 `.focusable(isEnabled)` 对于条件性可聚焦是可以接受的。

### 4. 在同一层次结构上混合 SwiftUI 和 UIKit 焦点

`@FocusState` 和 UIKit 的焦点引擎（`setNeedsFocusUpdate`）是独立系统。当两者在同一层次结构上同时活跃时（例如 UIKit 中的 UIHostingController），你会得到两个"已聚焦"项目。只有最后操作系统的焦点是真实的。

规则：每个视图层次结构分支选择一个系统。

### 5. 动画期间调用 `reloadData()`

动画数据源更改导致焦点引擎失去对聚焦项目的跟踪。焦点跳到第一个项目或意外位置。

```swift
// 错误
UIView.animate(withDuration: 0.3) { ... }
collectionView.reloadData()

// 正确——门控焦点更新
var allowsFocusUpdate = true

override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
    return allowsFocusUpdate
}

func safeReload() {
    allowsFocusUpdate = false
    collectionView.reloadData()
    collectionView.layoutIfNeeded()
    allowsFocusUpdate = true
    setNeedsFocusUpdate()
    updateFocusIfNeeded()
}
```

### 6. 在焦点变换计算中使用 `frame.width`

在布局更改期间读取 `frame.width` 会导致抖动，因为 frame 在动画过程中更新。缓存静止宽度。

```swift
// 错误
let scale: CGFloat = 1.13
let scaledWidth = frame.width * scale  // frame.width 在布局过程中变化！

// 正确
private var restingWidth: CGFloat = 0
override func layoutSubviews() {
    super.layoutSubviews()
    if !isFocused { restingWidth = bounds.width }
}
// 在焦点计算中使用 restingWidth
```

### 7. 从错误的环境调用 `setNeedsFocusUpdate()`

`setNeedsFocusUpdate()` 仅在调用焦点环境当前包含聚焦视图时有效。如果不包含，调用会静默地什么都不做。这是最常见的 UIKit 焦点 bug。

```swift
// 错误——从没有焦点的 VC 调用
otherViewController.setNeedsFocusUpdate()

// 正确——从包含当前聚焦视图的 VC 调用
// 或从共同祖先调用
self.setNeedsFocusUpdate()
self.updateFocusIfNeeded()
```

### 8. 在标题/标签上设置 `isUserInteractionEnabled = false`

在 tvOS 上，`isUserInteractionEnabled = false` 会传播到所有后代，并可能永久破坏通过该部分视图层次结构的焦点遍历。

```swift
// 错误
sectionHeader.isUserInteractionEnabled = false

// 正确——只是不使其可聚焦（默认情况下不可聚焦）
// UILabel.canBecomeFocused 已经是 false
```

### 9. `remembersLastFocusedIndexPath` + 离屏 `reloadData()`

当 `remembersLastFocusedIndexPath = true` 且在集合视图不可见时（例如在详情视图后面）调用 `reloadData()`，记住的索引路径可能不匹配之前聚焦的内容。

变通方案：结合通过 `indexPathForPreferredFocusedView(in:)` 的手动跟踪。

### 10. 对 CALayer 属性使用 `UIView.animate`

阴影透明度、阴影半径和其他 CALayer 属性不会在 `UIView.animate` 块内动画。使用 `CABasicAnimation`。

```swift
// 错误
UIView.animate(withDuration: 0.3) {
    self.layer.shadowOpacity = 1.0  // 不会动画
}

// 正确
let anim = CABasicAnimation(keyPath: "shadowOpacity")
anim.fromValue = layer.shadowOpacity
anim.toValue = 1.0
anim.duration = 0.3
layer.add(anim, forKey: "shadowOpacity")
layer.shadowOpacity = 1.0
```

## 警告性（应该修复）

### 11. 非可选 `@FocusState` 与 `focused(_:equals:)`

使用 `focused($binding, equals:)` 重载时，`@FocusState` 必须是 Optional。非可选仅适用于 `focused($bool)`。

```swift
// 错误
@FocusState var field: Field  // 非可选
TextField("Email", text: $email).focused($field, equals: .email)

// 正确
@FocusState var field: Field?  // 可选
TextField("Email", text: $email).focused($field, equals: .email)
```

### 12. 缺少焦点状态的 `prepareForReuse()` 清理

重用的 UIKit 单元格保留之前使用的聚焦视觉状态（缩放、阴影、高亮），导致视觉抖动。

```swift
override func prepareForReuse() {
    super.prepareForReuse()
    transform = .identity
    layer.shadowOpacity = 0
    layer.zPosition = 0
    layer.removeAllAnimations()
}
```

### 13. ScrollView 内的 `prefersDefaultFocus`

`prefersDefaultFocus(_:in:)` 在 tvOS 的 `ScrollView` 内不能可靠工作。这是 Apple 记录的限制。

变通方案：使用 `@FocusState` + `defaultFocus(_:_:priority:)` 或在布局完成后以编程方式设置焦点。

### 14. Apple TV HD 上的 LazyVStack/LazyVGrid 性能

`ScrollView` 内的 `LazyVStack` 和 `LazyVGrid` 在 tvOS 18（Apple TV HD）上有严重延迟。考虑使用 `List` 或基于 List 的自定义网格。

### 15. `LazyVStack` 释放离屏行——焦点逃逸到标签栏

这是 tvOS 上最危险的 `LazyVStack` 问题。当你向下滚动时，`LazyVStack` 从视图层次结构中移除离屏行。当你快速向上滑动时，焦点引擎向上做几何搜索，找不到可聚焦视图（它们已被释放），直接跳到标签栏——跳过所有内容。

```swift
// 错误——快速向上滑动逃逸到标签栏
ScrollView(.vertical) {
    LazyVStack(spacing: 40) {
        ForEach(categories) { category in
            CategoryRow(category: category)  // 离屏时被释放！
        }
    }
}

// 正确——VStack 将所有行保留在层次结构中，LazyHStack 在每行内部保持懒加载
ScrollView(.vertical) {
    VStack(spacing: 40) {
        ForEach(categories) { category in
            CategoryRow(category: category)  // 始终在层次结构中
            // 在每个 CategoryRow 内部，LazyHStack 对重量级卡片内容没问题
        }
    }
    .focusSection()  // 同时添加这个以防止焦点逃逸到标签栏
}
```

当外部行数有界时（配置驱动的首页，约 4-10 行）这有效。行容器本身是轻量级的——昂贵的内容（图像、缩略图）在每行的 `LazyHStack` 内保持懒加载。

对于 `VStack` 太昂贵的无界列表，改用带 `remembersLastFocusedIndexPath` 的 `UICollectionView`。

### 16. 包含目录的垂直 ScrollView 上缺少 `.focusSection()`

反模式 #2 涵盖水平 ScrollView。垂直 ScrollView 也需要 `.focusSection()` 来防止焦点向上逃逸到标签栏或导航栏。

```swift
// 错误——快速向上滑动时焦点可能逃逸到标签栏
ScrollView(.vertical) {
    VStack { /* 目录行 */ }
}

// 正确——焦点包含在目录内
ScrollView(.vertical) {
    VStack { /* 目录行 */ }
}
.focusSection()
```

结合宿主视图控制器上的 `didUpdateFocus(in:with:)` 来检测焦点何时逃逸并触发 UI 状态更改（例如将全屏目录折叠回正常）：

```swift
override func didUpdateFocus(in context: UIFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    guard let tabBar = tabBarController?.tabBar else { return }
    let movedToTabBar = context.nextFocusedView?.isDescendant(of: tabBar) == true
    if movedToTabBar {
        handleTabBarFocused()  // 折叠目录，恢复默认状态
    }
}
```

### 17. 在 `didUpdateFocus` 或 `shouldUpdateFocus` 中分配对象

焦点回调在导航期间频繁触发。在其中分配对象会导致每帧垃圾，并在快速滚动时引起微卡顿。

```swift
// 错误——每次焦点更新都创建一次性 UIView
override func didUpdateFocus(in context: UIFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    let movedToTabBar = context.nextFocusedView?
        .isDescendant(of: tabBarController?.tabBar ?? UIView()) == true  // 每次都分配 UIView()！
}

// 正确——guard let，无分配
override func didUpdateFocus(in context: UIFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    guard let tabBar = tabBarController?.tabBar else { return }
    let movedToTabBar = context.nextFocusedView?.isDescendant(of: tabBar) == true
}
```

同样的规则适用于 `shouldUpdateFocus(in:)`——不要 `String` 格式化、不要创建数组、不要分配对象。

### 25. 具有活动选择状态的多个列表/侧边栏项上的 `.disabled()`

这是反模式 #1 最危险的变体。当你在列表中对多个项目使用 `.disabled(!canFocus)`，而 `canFocus` 依赖于 `activeTopicIndex` 时，当活动索引更改时，所有项目同时重新进入或离开焦点链。这会导致"焦点级联"——焦点引擎快速循环遍历每个项目，产生可见闪烁。

```swift
// 错误——批量切换：当 activeSection 更改时，所有行同时
// 进入/离开焦点链，导致快速级联
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    Button(item.title) { select(index) }
        .disabled(activeSection != nil && activeSection != index)
}

// 正确——仅使用 .disabled() 门控从外部进入，而非
// 列表内导航。结合容器级 @FocusState：
@FocusState private var isContainerFocused: Bool
@FocusState private var focusedIndex: Int?

ScrollView {
    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        Button(item.title) { select(index) }
            .focused($focusedIndex, equals: index)
            .disabled(!isContainerFocused && selectedIndex != index)
            // 当焦点在侧边栏内部时，所有项目都启用。
            // 当焦点在外部时，只有选中的项目启用，
            // 因此焦点引擎只能落在正确的那个上。
    }
}
.focused($isContainerFocused)
```

这种"双重 `@FocusState`"模式（容器+每项）在生产级 tvOS 开发中发现。关键洞察：`.disabled()` 门控在仅约束从外部进入时有效，而非在列表内活动导航期间切换时。

### 26. `onChange` 内的 `ScrollViewReader.scrollTo()` 与焦点引擎产生反馈循环

命令式 `scrollTo` 重新定位视口，这会将项目移动到焦点光标下，触发新的焦点计算，再次触发 `onChange`，再次调用 `scrollTo`——级联。

```swift
// 错误——反馈循环：scrollTo → 项目移动 → 焦点更改 → onChange → scrollTo
ScrollViewReader { proxy in
    ScrollView {
        ForEach(items) { item in
            Button(item.title) { }
                .focused($focusedItem, equals: item.id)
        }
    }
    .onChange(of: focusedItem) { _, newValue in
        withAnimation {
            proxy.scrollTo(newValue, anchor: .center)  // 干扰焦点！
        }
    }
}

// 正确——声明式 ScrollPosition（tvOS 17+、iOS 17+）不与焦点引擎对抗
@State private var scrollPosition = ScrollPosition(idType: String.self)

ScrollView {
    ForEach(items) { item in
        Button(item.title) { }
            .focused($focusedItem, equals: item.id)
    }
}
.scrollPosition($scrollPosition)
```

声明式 `ScrollPosition` 方法让 SwiftUI 原子地协调滚动和焦点，避免命令式反馈循环。如果必须使用 `ScrollViewReader`，在焦点过渡期间的程序化滚动中禁用动画。

### 27. `@Observable` 同值变更触发不必要的 body 重新求值

使用 `@Observable`，属性 setter 总是调用 `withMutation()`——即使新值等于旧值。这会触发观察通知，导致 SwiftUI 重新求值 `body`，这可能在操作过程中干扰焦点引擎。

```swift
// 错误——即使值未更改也总是触发观察
@Observable class TopicsViewModel {
    var displayedTopicIndex: Int = 0
    
    func topicFocused(index: Int) {
        displayedTopicIndex = index  // 即使 index == displayedTopicIndex 也触发
    }
}

// 正确——守卫同值赋值
@Observable class TopicsViewModel {
    var displayedTopicIndex: Int = 0
    
    func topicFocused(index: Int) {
        guard displayedTopicIndex != index else { return }
        displayedTopicIndex = index
    }
}
```

这在焦点回调（`onChange(of: focusedItem)`）中尤其关键，快速焦点遍历可能重复设置相同值，每次都触发 body 重新求值，干扰焦点引擎。

### 28. 带 `.userInitiated` 的 `defaultFocus` 仅在初始出现时触发

`.defaultFocus($focusedItem, firstItem, priority: .userInitiated)` 仅在焦点分支首次出现时求值——而非每次重新进入。如果焦点离开（例如到导航栏）并返回，`defaultFocus` 不会将焦点重定向到期望的项目。

```swift
// 错误——期望 defaultFocus 每次重新进入都重定向
VStack {
    SidebarView()
        .focusSection()
    GridView()
        .focusSection()
}
.defaultFocus($focusedSidebarIndex, selectedTopic, priority: .userInitiated)
// 首次出现时有效，从网格/导航返回时无效

// 正确——使用双重 @FocusState + .disabled() 门控（见反模式 #25）
// 或使用容器级 onChange 重定向：
.focused($isContainerFocused)
.onChange(of: isContainerFocused) { _, isFocused in
    if isFocused {
        focusedItem = selectedItem  // 每次重新进入时重定向
    }
}
```

### 29. 导航过渡期间的瞬态焦点弹跳

当焦点在网格→导航栏过渡期间穿过侧边栏（例如用户从网格按上，焦点短暂进入侧边栏，然后继续到导航栏），焦点快速连续进入和退出侧边栏：`nil→10→nil→10→nil→10`。如果侧边栏状态依赖焦点（例如 `onChange` 触发数据加载或 UI 状态更改），这会导致可见闪烁。

```swift
// 错误——每次瞬态焦点接触都触发状态更改
.onChange(of: focusedSidebarIndex) { old, new in
    if let index = new {
        viewModel.topicFocused(index: index)  // 过渡期间触发 3 次
    }
}

// 正确——仅在"稳定"焦点上触发（old 和 new 都非 nil = 侧边栏内导航）
.onChange(of: focusedSidebarIndex) { old, new in
    guard let oldIndex = old, let newIndex = new else { return }
    // 两者都非 nil 意味着焦点在侧边栏内移动，而非穿过
    viewModel.topicFocused(index: newIndex)
}
```

或者，使用短防抖（`Task.sleep(for: .milliseconds(100))`）来过滤瞬态焦点接触。但 guard 方法更简单且更可靠。

### 30. 具有多个可聚焦子视图的 tvOS UIViewController 上缺少 `preferredFocusEnvironments`

当 tvOS `UIViewController`（或其 `view`）包含多个同级可聚焦子视图——`UIStackView` 的按钮、一行 `UIButton`、多个 `UITableView`/`UICollectionView` 等——且没有 `preferredFocusEnvironments` 重写时，焦点引擎会选择它几何上找到的第一个可聚焦视图。这很少是预期的初始焦点。

这是一个**缺失检查发现**：需要重写的屏幕上缺少重写本身就是问题。在添加或修改具有多个可聚焦子视图的 tvOS 视图控制器的 PR 上标记它，即使 diff 中没有焦点 API 符号。

```swift
// 错误——垂直堆叠中的三个按钮，无重写。
// 首次启动焦点落在引擎几何上首先找到的按钮上，
// 不一定是主要 CTA。
final class PaywallViewController: UIViewController {
    private let buttonStack = UIStackView()
    private lazy var subscribeButton = makeSubscribeButton()
    private let signInButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    // 无 preferredFocusEnvironments 重写
}

// 正确——显式主要 CTA，条件取决于可见性
final class PaywallViewController: UIViewController {
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if showSubscribeOption {
            return [subscribeButton]
        }
        return [signInButton]
    }
}
```

如何在 diff 中发现：

- 新的 `UIViewController`（或修改的）带有 `UIStackView` / `UIView` 排列多个 `UIButton`、`UITableView`、`UICollectionView`、可聚焦自定义视图。
- 屏幕的条件形状变化（例如标志下出现新按钮）且没有重写或 `setNeedsFocusUpdate` 来重定向。
- 规范参考代码库有类似屏幕的显式 `preferredFocusEnvironments` 重写，而新代码没有。

当条件在启动后更改（标志翻转，内容异步到达），将重写与 `setNeedsFocusUpdate()` + `updateFocusIfNeeded()` 配对，从包含聚焦视图的 VC 调用。不要从当前不包含焦点的同级/父级调用——见反模式 #7。

参考：`references/uikit-focus.md` "何时重写 `preferredFocusEnvironments`"。

## macOS 特定反模式

### 18. 自定义 NSView 上未重写 `acceptsFirstResponder`

自定义 NSView 子类默认 `acceptsFirstResponder = false`。视图静默忽略 Tab 导航和 `makeFirstResponder` 调用。这是 macOS 头号焦点 bug。

```swift
// 错误——视图永远不会接收焦点
class MyCustomView: NSView {
    // acceptsFirstResponder 默认为 false
}

// 正确
class MyCustomView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
}
```

### 19. 不完整的键视图循环

如果最后一个视图的 `nextKeyView` 不循环回第一个视图，Tab 导航在到达末尾后停止工作。从第一个视图 Shift-Tab 也会失败。

```swift
// 错误——Tab 到达 buttonC 后停止
textField.nextKeyView = buttonA
buttonA.nextKeyView = buttonB
buttonB.nextKeyView = buttonC
// 没有循环回去！

// 正确——完成循环
buttonC.nextKeyView = textField
```

替代方案：设置 `window.recalculatesKeyViewLoop = true` 让系统按几何方式管理循环。但永远不要将手动 `nextKeyView` 与 `recalculatesKeyViewLoop` 混用。

### 20. 直接调用 `becomeFirstResponder()`

永远不要直接在视图上调用 `becomeFirstResponder()`。它应该在 `makeFirstResponder(_:)` 期间由系统调用。

```swift
// 错误——绕过辞职/成为握手
myTextField.becomeFirstResponder()

// 正确——通过窗口的正确焦点握手
view.window?.makeFirstResponder(myTextField)
```

直接调用会跳过当前第一响应者的 `resignFirstResponder()`，可能使前一个视图处于不良状态（例如文本编辑仍然活跃）。

### 21. NSPanel 从主窗口窃取焦点

面板（检查器、工具窗口）默认成为关键窗口，从文档窃取焦点。用户失去文本编辑器中的光标位置。

```swift
// 错误——检查器面板每次显示都窃取焦点
let panel = NSPanel(...)
panel.makeKeyAndOrderFront(nil)

// 正确——面板仅在用户显式点击内部时获取焦点
panel.becomesKeyOnlyIfNeeded = true
panel.orderFront(nil)  // 显示但不窃取焦点
```

### 22. sheet 关闭后未恢复焦点

当 NSAlert 或 sheet 关闭时，焦点应返回到 sheet 出现前聚焦的视图。SwiftUI 自动处理，但 AppKit 需要手动跟踪。

```swift
// 错误——焦点到窗口，非原始视图
alert.runModal()

// 正确——保存和恢复
let savedFirstResponder = window.firstResponder
alert.beginSheetModal(for: window) { _ in
    self.window.makeFirstResponder(savedFirstResponder)
}
```

### 23. 在 NSViewRepresentable 上使用 `.focusable()` 而未桥接

在通过 `NSViewRepresentable` 包装 AppKit 的 SwiftUI 视图上添加 `.focusable()` 会创建一个不与 AppKit 第一响应者协调的 SwiftUI 焦点层。AppKit 视图处理自己的焦点。

```swift
// 错误——双重焦点，SwiftUI 环 + AppKit 环
struct MyAppKitView: NSViewRepresentable { ... }
MyAppKitView()
    .focusable()  // 不要添加这个

// 正确——让 AppKit 原生处理焦点
struct MyAppKitView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = MyNSView()
        // NSView 处理自己的 acceptsFirstResponder
        return view
    }
}
```

### 24. 没有文档聚焦时未禁用菜单项

依赖 `focusedValue` 但不检查 nil 的菜单项在没有窗口为关键窗口时（例如所有窗口最小化）仍然启用，导致崩溃或无效操作。

```swift
// 错误——document 为 nil 时崩溃
Button("Save") { document!.save() }

// 正确——没有聚焦文档时禁用
Button("Save") { document?.save() }
    .disabled(document == nil)
```
