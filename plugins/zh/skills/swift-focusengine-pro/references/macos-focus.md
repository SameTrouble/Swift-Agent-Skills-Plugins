# macOS 焦点管理

macOS 使用**键视图循环**模型——焦点通过 Tab/Shift-Tab 在响应者链定义的循环中的视图之间移动。这与 tvOS（几何/空间）和 iOS（硬件键盘激活的焦点组）根本不同。

## 核心概念：键视图循环

每个 `NSWindow` 维护一个可聚焦视图的循环。Tab 向前推进，Shift-Tab 向后。

```
┌─ TextField ──► Button ──► PopUpButton ──► TableView ──┐
└───────────────────────────────────────────────────────┘
```

### NSView 焦点 API

```swift
class MyCustomView: NSView {
    // 必须：声明视图可以接受焦点
    override var acceptsFirstResponder: Bool { true }

    // Tab 键导航必须
    override var canBecomeKeyView: Bool { true }

    // 视图获得焦点时调用
    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    // 视图失去焦点时调用
    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }
}
```

### 窗口第一响应者

```swift
// 使视图聚焦
window.makeFirstResponder(myView)

// 检查当前聚焦
if let focused = window.firstResponder as? NSView {
    print("Focused: \(focused)")
}

// 辞去焦点（焦点到窗口本身）
window.makeFirstResponder(nil)
```

### 键视图循环设置

**Interface Builder：** 按顺序连接 `nextKeyView` outlet，最后一个视图指回第一个。

**编程方式：**
```swift
textField.nextKeyView = button
button.nextKeyView = popUpButton
popUpButton.nextKeyView = textField  // 完成循环
```

**自动重计算：**
```swift
window.recalculatesKeyViewLoop = true  // 系统管理循环
// 系统使用几何位置（从左到右、从上到下）确定顺序
```

常见错误：同时设置 `recalculatesKeyViewLoop = true` 和手动设置 `nextKeyView`。手动链会被覆盖。

## macOS 上的 SwiftUI 焦点

### @FocusState

与 iOS 相同工作方式。在 macOS 上，焦点始终活跃（无 iOS 那样的硬件键盘要求）。

```swift
enum Field: Hashable { case search, name, email }
@FocusState private var focusedField: Field?

VStack {
    TextField("Search", text: $search)
        .focused($focusedField, equals: .search)
    TextField("Name", text: $name)
        .focused($focusedField, equals: .name)
    TextField("Email", text: $email)
        .focused($focusedField, equals: .email)
}
.onAppear { focusedField = .search }  // 出现时自动聚焦
```

与 iOS 的关键区别：在 macOS 上设置 `focusedField = nil` 不会收起键盘（没有虚拟键盘可收起）。它将焦点移到窗口本身。

### macOS 上的 .focusable()

使非交互视图可聚焦以进行键盘导航：

```swift
CardView(item: item)
    .focusable()
    .onKeyPress(.return) {
        openItem(item)
        return .handled
    }
```

在 macOS 上，`.focusable()` 视图自动参与 Tab 循环。

### .focusable(interactions:)（macOS 14+）

```swift
.focusable(interactions: .edit)     // 用于类文本编辑视图
.focusable(interactions: .activate) // 用于类按钮视图
```

在 macOS 上，`.activate` 无需系统开关即可响应 Tab（不像 iOS 需要"键盘导航"启用）。

### defaultFocus(_:_:priority:)（macOS 14+）

```swift
@FocusState var selectedField: Field?

VStack { ... }
    .defaultFocus($selectedField, .search, priority: .userInitiated)
```

### .focusSection()（macOS 14+）

为区域内方向键导航分组可聚焦视图：

```swift
HStack {
    VStack {
        // 侧边栏项目
    }
    .focusSection()

    VStack {
        // 内容项目
    }
    .focusSection()
}
```

方向键在区域内移动；Tab 在区域之间移动。这是 macOS 上焦点区域工作方式的等价物，但使用键盘驱动导航而非遥控器驱动。

## 焦点环（焦点指示器）

macOS 在聚焦视图周围绘制系统焦点环（蓝色光晕）。这是 macOS 等价于 tvOS 焦点缩放/高亮和 iOS 光晕效果。

### NSView 焦点环

```swift
class MyView: NSView {
    // 控制焦点环可见性
    override var focusRingType: NSFocusRingType {
        return .exterior  // .exterior（默认）、.interior、.none
    }

    // 自定义焦点环形状（默认：bounds）
    override var focusRingMaskBounds: NSRect {
        return bounds.insetBy(dx: 4, dy: 4)
    }

    override func drawFocusRingMask() {
        // 绘制圆角矩形焦点环
        NSBezierPath(roundedRect: focusRingMaskBounds,
                     xRadius: 8, yRadius: 8).fill()
    }

    // 焦点环遮罩更改时通知 AppKit
    override func noteFocusRingChanged() {
        // 环需要重绘时调用
    }
}
```

### SwiftUI 焦点环

```swift
// 系统焦点环（macOS 默认）
TextField("Name", text: $name)
    .focusable()

// 抑制系统焦点环
TextField("Name", text: $name)
    .focusable()
    .focusEffectDisabled()  // 不绘制环

// 自定义焦点指示器
@FocusState var isFocused: Bool

TextField("Name", text: $name)
    .focused($isFocused)
    .focusEffectDisabled()
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(isFocused ? .blue : .clear, lineWidth: 2)
    )
```

常见错误：禁用焦点环而不提供替代视觉指示器。用户需要看到什么被聚焦。

### NSFocusRingPlacement

绘制包含焦点环的视图时：

```swift
// 在 draw(_:) 中
NSGraphicsContext.saveGraphicsState()
NSFocusRingPlacement.only.set()
path.fill()   // 只绘制焦点环，不绘制填充
NSGraphicsContext.restoreGraphicsState()
```

## focusedValue / focusedSceneValue（菜单命令）

在 macOS 上，`focusedValue` 对于使菜单栏命令响应当前聚焦内容至关重要。这是主要用例——菜单根据焦点启用/禁用并更改行为。

### 菜单栏集成

```swift
// 定义键
struct SelectedDocumentKey: FocusedValueKey {
    typealias Value = Document
}

extension FocusedValues {
    var selectedDocument: Document? {
        get { self[SelectedDocumentKey.self] }
        set { self[SelectedDocumentKey.self] = newValue }
    }
}

// 从视图设置
DocumentView(document: document)
    .focusedValue(\.selectedDocument, document)

// 在 Commands 中读取
struct AppCommands: Commands {
    @FocusedValue(\.selectedDocument) var document

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Export PDF") { document?.exportPDF() }
                .disabled(document == nil)
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}
```

### 使用 focusedSceneValue 的多窗口

macOS 应用通常有多个窗口。`focusedSceneValue` 从关键窗口传播：

```swift
WindowGroup {
    EditorView()
        .focusedSceneValue(\.activeDocument, document)
}

// 菜单命令自动针对关键窗口的文档
@FocusedValue(\.activeDocument) var activeDocument
```

### @FocusedObject（macOS 12+）

通过焦点传递整个 ObservableObject：

```swift
.focusedObject(editorModel)

// 在 Commands 中：
@FocusedObject var editor: EditorModel?
```

## NSTableView / NSOutlineView / NSCollectionView 焦点

### 表格视图

```swift
// 键盘导航默认启用
// 方向键移动选择，Tab 移到下一个键视图
tableView.allowsEmptySelection = false  // 确保始终有选择

// 响应选择更改（跟随焦点）
func tableViewSelectionDidChange(_ notification: Notification) {
    // 通过键盘或鼠标更改选择
}
```

### 集合视图

```swift
// macOS 10.13+：键盘焦点导航
collectionView.isSelectable = true
collectionView.allowsEmptySelection = false

// selectionIndexPaths 跟踪聚焦/选中项目
```

### 类型选择

NSTableView 和 NSOutlineView 默认支持类型选择——输入字符跳到匹配行。这与焦点/选择分开。

```swift
// 如果与搜索字段冲突则禁用
tableView.allowsTypeSelect = false
```

## NSResponder 链和焦点

macOS 焦点建立在 NSResponder 链上。理解此链对调试焦点问题至关重要。

### 链

```
NSView（你的视图） → NSView（父视图） → ... → NSWindow → NSWindowController → NSApplication → NSApplication.delegate
```

当按键事件发生时，它从第一响应者（聚焦视图）沿响应者链向上传播。如果没有视图处理它，事件到达应用级别。

### 第一响应者 vs 键视图

- **第一响应者**（`window.firstResponder`）：当前接收按键事件的视图。可以是任何 NSResponder。
- **键视图**（`canBecomeKeyView == true`）：Tab 导航可以聚焦的视图。是 `acceptsFirstResponder == true` 视图的子集。

视图可以是第一响应者（接收事件）而不是键视图（不可通过 Tab 到达）。例如：处理按键事件但不在 Tab 循环中的自定义绘图画布。

### becomeFirstResponder vs makeFirstResponder

```swift
// 不要直接调用——使用 window.makeFirstResponder
view.becomeFirstResponder()  // 仅由系统调用

// 设置焦点的正确方式
window.makeFirstResponder(view)  // 返回 Bool——视图拒绝时为 false
```

`window.makeFirstResponder(view)` 在当前第一响应者上调用 `resignFirstResponder()`，然后在目标上调用 `becomeFirstResponder()`。如果任何一个返回 `false`，焦点更改被取消。

### 防止焦点丢失

```swift
override func resignFirstResponder() -> Bool {
    if hasUnsavedChanges {
        return false  // 拒绝失去焦点——强制用户先保存
    }
    return super.resignFirstResponder()
}
```

## 关键窗口 vs 主窗口

macOS 区分**关键窗口**（接收按键事件、有焦点环）和**主窗口**（面板后面的文档窗口）。

```swift
// 关键窗口——有活动焦点的窗口
NSApplication.shared.keyWindow

// 主窗口——主文档窗口（可能与关键窗口不同）
NSApplication.shared.mainWindow
```

当面板（NSPanel）或弹出框可见时，它成为关键窗口。它后面的文档窗口成为主窗口。`focusedValue` 从关键窗口的层次结构读取。

### 面板和焦点

```swift
// NSPanel 窃取关键窗口状态
let panel = NSPanel(contentRect: rect, styleMask: [.titled, .closable],
                    backing: .buffered, defer: false)
panel.becomesKeyOnlyIfNeeded = true  // 仅在面板有可聚焦内容时窃取焦点

// 非激活面板——不从主窗口窃取焦点
panel.styleMask.insert(.nonactivatingPanel)
```

对仅在用户点击其中文本字段时才应获取焦点的检查器面板使用 `becomesKeyOnlyIfNeeded = true`。

## NSPopover、Sheets 和模态焦点

### NSPopover

弹出框创建自己的焦点作用域。Tab 在弹出框内循环。

```swift
let popover = NSPopover()
popover.behavior = .transient  // 点击外部时关闭

// 焦点自动移到弹出框中第一个可聚焦视图
// 关闭时，焦点返回展示弹出框的视图
```

常见错误：未在弹出框内容中设置初始第一响应者。用户必须 Tab 或点击才能聚焦任何东西。

```swift
// 在弹出框内容视图控制器中
override func viewDidAppear() {
    super.viewDidAppear()
    view.window?.makeFirstResponder(searchField)  // 自动聚焦搜索
}
```

### Sheets

Sheet 创建模态焦点作用域——Tab 无法逃出 sheet。

```swift
// SwiftUI
.sheet(isPresented: $showSettings) {
    SettingsView()
}
// 焦点自动限定在 sheet 内容
// Cmd+W 或 Esc 关闭 sheet 并恢复焦点到父级
```

### NSAlert 焦点

NSAlert 的默认按钮获得初始焦点。自定义附件视图需要显式第一响应者设置。

## NSToolbar 和焦点

NSToolbar 项目默认不在键视图循环中。用户通过以下方式到达它们：
- 鼠标点击
- 键盘快捷键（如果定义）
- 完全键盘访问：`Ctrl+F5` 将焦点移到工具栏，然后方向键

### 使工具栏项目可聚焦

在 SwiftUI 中：
```swift
.toolbar {
    ToolbarItem(placement: .automatic) {
        TextField("Search", text: $search)
            // TextField 自动可聚焦
    }
    ToolbarItem(placement: .automatic) {
        Button("Filter") { }
            // 按钮仅在 FKA 启用时可聚焦
    }
}
```

### NSSearchToolbarItem

系统搜索工具栏项目自动处理焦点——Cmd+F 聚焦它，Esc 将焦点返回内容区域。

```swift
let searchItem = NSSearchToolbarItem(itemIdentifier: .search)
searchItem.searchField.delegate = self
// Cmd+F → 聚焦搜索，Esc → 聚焦内容
```

## 多窗口和多屏幕焦点

### 窗口激活和焦点

```swift
// 将窗口带到前面并使其成为关键（聚焦）
window.makeKeyAndOrderFront(nil)

// 成为关键但不改变 z-order
window.makeKey()

// 监听焦点更改
NotificationCenter.default.addObserver(
    forName: NSWindow.didBecomeKeyNotification,
    object: window, queue: .main
) { _ in
    // 窗口获得焦点——更新 UI 状态
}

NotificationCenter.default.addObserver(
    forName: NSWindow.didResignKeyNotification,
    object: window, queue: .main
) { _ in
    // 窗口失去焦点——暗化选择、暂停动画
}
```

### 每窗口焦点恢复

每个 NSWindow 维护自己的第一响应者。在窗口之间切换会自动恢复每个窗口的聚焦视图。

```swift
// 窗口 A 有 TextField 聚焦
// 用户点击窗口 B（有 TableView 聚焦）
// 用户点击回窗口 A——TextField 自动恢复焦点
```

这是自动的——无需手动保存/恢复。但是，如果窗口内容被重建（例如 SwiftUI 重新渲染），第一响应者可能重置。

### 外接显示器

macOS 应用可以跨越多个屏幕。焦点跟随关键窗口，而非屏幕。

- 外接显示器上的 NSWindow 可以是关键的（活动焦点）
- 在屏幕之间移动窗口不影响焦点状态
- 不同屏幕上的全屏窗口各自维护自己的焦点
- Mission Control / Spaces 切换保持每窗口焦点

## SwiftUI 设置窗口

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        Settings { SettingsView() }
    }
}
```

设置窗口（Cmd+,）有自己的焦点作用域。`focusedValue` 不会从设置窗口传播到主窗口的 Commands——设置使用直接绑定。

## .onKeyPress 和 macOS

macOS 14+ 在 SwiftUI 中支持 `.onKeyPress`：

```swift
ContentView()
    .focusable()
    .onKeyPress(.escape) {
        dismiss()
        return .handled
    }
    .onKeyPress(characters: .alphanumerics) { press in
        handleTypeAhead(press.characters)
        return .handled
    }
    .onKeyPress(phases: .down) { press in
        // 仅在按下时触发（非重复或释放）
        return .handled
    }
```

按键路由遵循焦点链——未聚焦的视图不接收按键事件。在 macOS 上，`.onKeyPress` 也适用于没有修饰键的键盘快捷键。

## macOS 上的完全键盘访问

在系统设置 > 键盘 > 键盘导航中启用后，所有控件都可通过 Tab 聚焦——不仅是文本字段和列表。

```swift
// 检查完全键盘访问是否开启
NSApplication.shared.isFullKeyboardAccessEnabled

// 视图可以在运行时检查
override var canBecomeKeyView: Bool {
    // 总是返回 true，或仅在 FKA 启用时
    return NSApplication.shared.isFullKeyboardAccessEnabled || alwaysFocusable
}
```

重要：即使没有完全键盘访问，用户也可以在文本字段和列表之间 Tab。FKA 添加按钮、复选框、滑块、弹出等。

## Mac Catalyst 焦点

Mac Catalyst 应用在 macOS 上运行 iOS UIKit 代码。焦点行为桥接两个世界：

### 自动工作的内容
- `UIFocusSystem` 活跃（与带键盘的 iPad 相同）
- `UIFocusHaloEffect` 渲染为 macOS 焦点环
- `focusGroupIdentifier` 映射到 Tab 导航组
- Tab/Shift-Tab 导航有效

### 不同之处
- `canBecomeFocused` 对自定义视图必须返回 `true`
- macOS 菜单栏集成需要 `UIMenuBuilder` 或 SwiftUI Commands
- 焦点环外观遵循 macOS 系统设置，而非 iOS 光晕样式
- `UIFocusSystem.focusSystem(for:)`——使用前检查是否存在，如果焦点不可用则为 nil

### 常见 Catalyst 错误
忘记 Mac Catalyst 继承 iPad 焦点行为。如果你的 iPad 应用不支持键盘焦点（无 `UIFocusHaloEffect`、集合视图上无 `allowsFocus`），你的 Mac Catalyst 应用也不会支持。

## macOS vs 其他平台

| 特性 | macOS | tvOS | iOS/iPadOS |
|---------|-------|------|-----------|
| 焦点模型 | 键视图循环 | 几何/空间 | 焦点组（键盘） |
| 始终活跃 | 是 | 是 | 否（需要键盘） |
| Tab 行为 | 下一个键视图 | 不适用 | 下一个焦点组 |
| 方向键 | 控件内 | 方向焦点 | 焦点组内 |
| 焦点指示器 | 蓝色环 | 缩放/高亮 | 光晕 |
| 主要输入 | 鼠标 + 键盘 | Siri Remote | 触摸 |
| focusedValue | 菜单命令 | 不适用 | 菜单命令 |
| .focusSection() | macOS 14+ | tvOS 15+ | iOS 17+ |
| @FocusState | macOS 12+ | tvOS 15+ | iOS 15+ |
| FKA 开关 | 系统设置 | 不适用 | 设置 > 辅助功能 |

## 常见 macOS 焦点错误

### 1. 未完成键视图循环
如果最后一个视图的 `nextKeyView` 不指回第一个，Tab 在到达末尾后停止工作。

### 2. 忘记 acceptsFirstResponder
自定义 NSView 子类默认返回 `false`。不重写为 `true`，视图对 Tab 导航不可见。

### 3. 自定义绘制视图上的焦点环
如果你用自定义内边距或形状绘制内容，默认矩形焦点环看起来不对。重写 `drawFocusRingMask()` 和 `focusRingMaskBounds`。

### 4. recalculatesKeyViewLoop 与手动 nextKeyView 冲突
设置 `recalculatesKeyViewLoop = true` 覆盖所有手动 `nextKeyView` 连接。选择一种方式。

### 5. 假设完全键盘访问始终开启
大多数用户不启用它。你的依赖 Tab 聚焦非文本字段控件的自定义视图可能对大多数用户不接收焦点。始终提供鼠标/触控板交互作为主要方式。

### 6. 菜单命令不使用 focusedValue
不使用 `focusedValue` 的菜单栏项目无法响应当前选择。菜单项无论上下文如何都保持启用/禁用。

### 7. SwiftUI 焦点环重复
在已有系统焦点支持的视图（如 TextField）上使用 `.focusable()` 可能导致双重焦点环。

## macOS 上不可用（或不同）

| API / 概念 | 为什么不可用 / 差异 |
|---------------|---------------------|
| 几何焦点移动 | macOS 使用键视图循环，非空间几何 |
| Siri Remote / 方向键导航 | 无遥控输入设备 |
| `.hoverEffect()`（visionOS 风格） | macOS 使用 `NSTrackingArea` 或 `.onHover` 进行指针跟踪 |
| Digital Crown | 仅 watchOS |
| `UIFocusGuide` | UIKit 概念——在 AppKit 中使用 `nextKeyView` 链 |
| `UIFocusHaloEffect` | iOS/Catalyst——macOS 使用系统焦点环 |
| `preferredFocusEnvironments` | UIKit——macOS 在 NSWindow 上使用 `initialFirstResponder` |
| `shouldUpdateFocus(in:)` | UIKit 代理——macOS 使用 `resignFirstResponder()` 返回 false |
| 视差倾斜效果 | 仅 tvOS |
| `remembersLastFocusedIndexPath` | UIKit 集合/表格视图——NSTableView 原生保持选择 |

### macOS 专有焦点 API（iOS/tvOS 上无）

| API | 用途 |
|-----|---------|
| `acceptsFirstResponder` | NSView 是否可以接收焦点 |
| `canBecomeKeyView` | NSView 是否参与 Tab 循环 |
| `nextKeyView` / `previousKeyView` | 手动键视图循环构建 |
| `recalculatesKeyViewLoop` | 从几何自动计算 Tab 顺序 |
| `NSWindow.initialFirstResponder` | 窗口打开时获得焦点的视图 |
| `NSFocusRingType` | 控制每个视图的焦点环外观 |
| `drawFocusRingMask()` | 自定义焦点环形状 |
| `NSWindow.makeFirstResponder(_:)` | 程序化焦点——macOS 等价于 UIKit 的 `setNeedsFocusUpdate` |
| `becomesKeyOnlyIfNeeded`（NSPanel） | 除非需要否则不窃取焦点的面板 |

## WWDC 会议

| 会议 | 年份 | 关键内容 |
|---------|------|-------------|
| 支持 macOS 中的键盘导航 | WWDC21 | 键视图循环、焦点环自定义 |
| SwiftUI 中的直接和反射焦点 | WWDC21 | macOS 上的 @FocusState、focusedValue |
| 将 iOS 应用带到 Mac | WWDC19 | Mac Catalyst 焦点行为 |
| SwiftUI 焦点手册 | WWDC23 | .focusable(interactions:)、跨平台焦点 |
| AppKit 新功能 | WWDC24 | 焦点环改进、NSFocusRingPlacement 更新 |
