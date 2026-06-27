# iOS/iPadOS 焦点管理

iOS 焦点是触摸之外的**次要**交互模型，由硬件键盘（Tab 和方向键）驱动。这与 tvOS 有根本不同，tvOS 中焦点是**主要**交互。

## 关键区别：两级导航

- **Tab 键**在**焦点组**之间移动（重要 UI 区域）
- **方向键**在焦点组*内*移动
- **回车**（iPadOS）或**空格**（Mac Catalyst）激活聚焦项目
- 焦点仅在连接硬件键盘时激活——你的应用必须在没有它的情况下工作

这种两级模型在 tvOS 上不存在。

## iOS 专有 API（tvOS 上不可用）

### focusGroupIdentifier（iOS 15+，非 tvOS）

将视图分配到命名焦点组。焦点组定义 Tab 在什么之间导航。

```swift
// UIKit
sidebarContainer.focusGroupIdentifier = "com.myapp.sidebar"
contentContainer.focusGroupIdentifier = "com.myapp.content"
```

规则：
- 设置在**共同祖先**上，而非单个可聚焦项目
- UIKit 自动从视图层次结构推断组——仅在默认分组错误时覆盖
- 相同标识符的元素属于同一组
- Tab 循环顺序从焦点组派生，考虑阅读方向和布局

### UIFocusGroupPriority（iOS 15+，tvOS 15+）

决定焦点组内哪个项目是"主要"的——Tab 进入组时获得焦点的项目。

```swift
// 使此项目成为 Tab 进入组时的首选项目
myButton.focusGroupPriority = .prioritized  // 2000
```

优先级级别：
- `.ignored` (0)——组主选择时跳过
- `.previouslyFocused` (1000)——此前在此组中聚焦过
- `.prioritized` (2000)——显式优先
- `.currentlyFocused` (NSIntegerMax)——当前聚焦

### UIFocusHaloEffect（iOS 15+，非 tvOS）

iPadOS 和 Mac Catalyst 上键盘焦点的系统标准焦点环（光晕）。

```swift
class MyCell: UICollectionViewCell {
    override var focusEffect: UIFocusEffect? {
        // 匹配图像形状的自定义圆角光晕
        let halo = UIFocusHaloEffect(
            roundedRect: imageView.bounds,
            cornerRadius: 8,
            curve: .continuous
        )
        halo.referenceView = imageView   // 在此视图上方渲染
        halo.containerView = contentView // 将光晕放在此视图中
        halo.position = .outside         // .inside、.outside 或 .automatic
        return halo
    }
}
```

禁用默认光晕：
```swift
override var focusEffect: UIFocusEffect? {
    return nil
}
```

常见错误：光晕形状不匹配内容形状（圆形头像上的方形光晕）。

### allowsFocus（UICollectionView/UITableView，iOS 15+）

使所有单元格可键盘聚焦。

```swift
collectionView.allowsFocus = true
collectionView.selectionFollowsFocus = true  // 聚焦时自动选择
```

没有 `selectionFollowsFocus`，用户必须在聚焦单元格后按回车来选择它。

## 共享 API（iOS + tvOS）

### @FocusState（iOS 15+，tvOS 15+）

相同 API，不同上下文。在 iOS 上，主要用于：
- 表单中的键盘焦点管理（在文本字段之间移动）
- 收起键盘（`focusedField = nil`）

```swift
enum Field: Hashable { case username, password }
@FocusState private var focusedField: Field?

VStack {
    TextField("Username", text: $username)
        .focused($focusedField, equals: .username)
    SecureField("Password", text: $password)
        .focused($focusedField, equals: .password)
    Button("Login") { focusedField = nil }  // 收起键盘
}
.onSubmit { focusedField = .password }  // Tab 到下一个字段
```

### .focusSection()（iOS 17+，tvOS 15+）

iOS 从 iOS 17 开始可用。为方向导航分组可聚焦后代——与 tvOS 相同但在 iOS 上较晚到达。

### .focusable(interactions:)（iOS 17+）

对焦点交互类型的细粒度控制：

```swift
.focusable(interactions: .edit)     // 类文本（滑块、步进器）
.focusable(interactions: .activate) // 类按钮（需启用键盘导航）
```

`.activate` 不会在点击时接收焦点——需要系统"键盘导航"开关开启。

### defaultFocus(_:_:priority:)（iOS 17+，tvOS 16+）

现代跨平台默认焦点 API：

```swift
@FocusState var selectedField: Field?

VStack { ... }
    .defaultFocus($selectedField, .name, priority: .userInitiated)
```

### .focusEffectDisabled()（iOS 17+）

抑制默认系统焦点环：
```swift
MyView()
    .focusable()
    .focusEffectDisabled()
```

### focusedValue / focusedSceneValue

根据焦点在层次结构中的位置传播数据。用于菜单/命令系统：

```swift
.focusedValue(\.selectedItem, item)

// 在 Commands 中：
@FocusedValue(\.selectedItem) var selectedItem
```

`focusedSceneValue` 用于多窗口 iPad 应用。

### UIFocusItemDeferralMode（iOS 15+，tvOS 15+）

控制用户不活跃使用键盘时是否延迟焦点更新：

- `.automatic`——系统决定（默认）
- `.always`——总是延迟（用于不应窃取焦点的加载指示器）
- `.never`——从不延迟（用于程序化更新后需要立即焦点的项目）

### UIFocusItemScrollableContainer（iOS 12+，tvOS 12+）

自定义可滚动容器的协议。UIScrollView 已经遵循。在自定义容器上实现，使焦点系统可以自动滚动以显示聚焦项目。

## iOS vs tvOS 快速参考

| 特性 | tvOS | iOS/iPadOS |
|---------|------|-----------|
| 焦点始终活跃 | 是 | 否（键盘驱动） |
| 焦点组（Tab 导航） | 否 | 是（iOS 15+） |
| focusGroupIdentifier | 否 | 是（iOS 15+） |
| UIFocusHaloEffect | 否 | 是（iOS 15+） |
| UIFocusGuide | tvOS 9+ | iOS 15+ |
| @FocusState | tvOS 15+ | iOS 15+ |
| .focusSection() | tvOS 15+ | iOS 17+ |
| .focusable(interactions:) | 否 | iOS 17+ |
| canBecomeFocused | tvOS 9+ | iOS 15+ |
| 响应者链同步 | 不适用 | 是 |
| .hoverEffect | tvOS 17+ | 不适用（使用指针效果） |
| 视差倾斜 | tvOS | 不适用 |
| Siri Remote | 是 | 不适用 |
| CV/TV 上的 allowsFocus | 不适用 | iOS 15+ |
| selectionFollowsFocus | 不适用 | iOS 15+ |

## 常见 iOS 焦点错误

### 1. 假设焦点像 tvOS 一样工作
在 iOS 上，焦点组约束方向键移动。忘记设置适当的组会导致键盘导航损坏。

### 2. 不在没有键盘时测试
焦点系统仅在连接键盘时激活。你的应用必须仅用触摸完美工作。

### 3. 不小心重写 canBecomeFocused
这影响常规 Tab 导航和完全键盘访问（辅助功能）。两者都测试。

### 4. SwiftUI 中的修饰符顺序
`.focused()` 必须在 `.focusable()` 之后，而非之前：
```swift
// 错误
MyView().focused($field, equals: .name).focusable()

// 正确
MyView().focusable().focused($field, equals: .name)
```

### 5. 忽略 selectionFollowsFocus
没有在集合/表格视图上设置这个，用户必须在聚焦单元格后按回车来选择它——感觉很笨拙。

### 6. 在 tvOS 上使用 focusGroupIdentifier
那里不存在。在 tvOS 上改用 `.focusSection()`（SwiftUI）或 `UIFocusGuide`（UIKit）。

### 7. 不处理响应者链
在 iOS 上，聚焦项目必须在第一响应者链内。分离的视图无法接收焦点。

## focusedValue / focusedSceneValue（深入探讨）

这些通过焦点层次结构向上传播数据，使菜单和命令能够对当前聚焦的内容做出反应。对 iPad 多窗口应用至关重要。

### @FocusedValue——单值

定义键并扩展 FocusedValues：

```swift
struct SelectedItemKey: FocusedValueKey {
    typealias Value = Item
}

extension FocusedValues {
    var selectedItem: Item? {
        get { self[SelectedItemKey.self] }
        set { self[SelectedItemKey.self] = newValue }
    }
}
```

从视图设置值：
```swift
List(items, selection: $selectedItem) { item in
    ItemRow(item: item)
}
.focusedValue(\.selectedItem, selectedItem)
```

在 Commands 中读取：
```swift
struct MyCommands: Commands {
    @FocusedValue(\.selectedItem) var selectedItem
    
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Duplicate") { duplicate(selectedItem!) }
                .disabled(selectedItem == nil)  // 无焦点时自动禁用
        }
    }
}
```

### @FocusedBinding——双向绑定

当命令需要修改聚焦值，而非仅读取时：

```swift
struct SelectedItemBindingKey: FocusedValueKey {
    typealias Value = Binding<Item?>
}

// 在视图中：
.focusedValue(\.selectedItemBinding, $selectedItem)

// 在命令中：
@FocusedBinding(\.selectedItemBinding) var selectedItem
// 现在 selectedItem 是 Binding——可以写回
```

### @FocusedObject——可观察对象

通过焦点传递可观察对象：

```swift
class DocumentModel: ObservableObject {
    @Published var title: String = ""
    @Published var content: String = ""
}

// 在视图中：
.focusedObject(documentModel)

// 在命令中：
@FocusedObject var document: DocumentModel?
```

### focusedSceneValue——多窗口 iPad

`focusedValue` 仅在单个视图层次结构内传播。`focusedSceneValue` 跨整个场景传播，因此菜单命令知道哪个窗口活跃：

```swift
// 在每个窗口的内容视图中：
.focusedSceneValue(\.activeDocument, document)

// 在命令中——从聚焦的任何场景读取：
@FocusedValue(\.activeDocument) var activeDocument
```

**已知问题：** 在基于 UIKit 的平台上，`focusedSceneValue` 即使文档打开也可能随 `DocumentGroup` 返回 nil。在 macOS 上正确工作。变通方案：使用 `focusedValue` 配合手动场景跟踪。

### 何时使用哪个

| API | 作用域 | 用例 |
|-----|-------|----------|
| `focusedValue` | 视图层次结构 | 单窗口应用、场景内数据 |
| `focusedSceneValue` | 场景范围 | 多窗口 iPad、菜单命令 |
| `@FocusedBinding` | 视图层次结构 | 修改聚焦数据的命令 |
| `@FocusedObject` | 视图层次结构 | 向命令传递可观察模型 |

## 游戏手柄焦点

当游戏手柄（MFi、Xbox、PlayStation 等）通过蓝牙连接时，其方向键驱动与键盘方向键相同的 `UIFocusSystem`。

### 工作原理

- 方向键方向触发焦点移动事件
- A/X 按钮作为选择（相当于回车键）
- 焦点引擎处理路由——基本导航不需要 GameController 框架代码
- `shouldUpdateFocus(in:)` 和 `didUpdateFocus(in:with:)` 正常触发

### 启用手柄支持

UIKit 应用自动支持游戏手柄焦点导航。对于 SwiftUI，确保视图正确可聚焦：

```swift
// 这些自动响应手柄方向键
Button("Play") { }
NavigationLink("Settings") { SettingsView() }

// 自定义视图需要 .focusable()
CardView()
    .focusable()
```

### 手柄 + 键盘共存

两者可以同时连接。焦点系统处理用户交互的任何设备的输入——无需冲突解决。

### GCController 通知

```swift
NotificationCenter.default.addObserver(
    forName: .GCControllerDidConnect,
    object: nil, queue: .main
) { notification in
    // 手柄已连接——焦点系统自动激活
    // 可选显示焦点友好的 UI 提示
}
```

## Stage Manager / 多窗口焦点

iPad Stage Manager（iPadOS 16+）允许多个窗口并排。焦点影响：

### 窗口激活

- 点击窗口使其成为关键窗口并激活其焦点系统
- 一次只有关键窗口的焦点系统活跃
- 切换窗口默认不保留前一个窗口的焦点位置

### 跨场景焦点

每个 `WindowGroup` 场景有自己的焦点状态。使用 `focusedSceneValue` 让菜单命令针对活动场景：

```swift
WindowGroup {
    ContentView()
        .focusedSceneValue(\.activeEditor, editorModel)
}
```

### 外接显示器

镜像或扩展到外接显示器时：
- 焦点系统跟随关键窗口，而非显示器
- 外接显示器内容可以在关键窗口的层次结构中时被聚焦
- 独立的 `UIScreen` 窗口需要自己的焦点管理

## .onKeyPress 和焦点

`.onKeyPress`（iOS 17+）仅在当前聚焦的视图或其祖先上触发。如果没有视图有焦点，按键不会被传递。

```swift
TextField("Search", text: $query)
    .focused($isSearchFocused)
    .onKeyPress(.escape) {
        isSearchFocused = false  // 收起键盘
        return .handled
    }
    .onKeyPress(characters: .alphanumerics) { press in
        // 仅在此 TextField 有焦点时触发
        return .ignored  // 让 TextField 正常处理
    }
```

### 按键路由顺序
1. 聚焦视图的 `.onKeyPress` 处理器（最具体）
2. 父视图的 `.onKeyPress` 处理器（冒泡向上）
3. 键命令 / 键盘快捷键
4. 系统快捷键

## iPad 上的指针悬停效果

iPad 触控板/鼠标指针效果与键盘焦点分开但相关：

```swift
// 悬停效果（指针/触控板）——非键盘焦点
Button("Tap me") { }
    .hoverEffect(.lift)      // 指针悬停时抬起
    .hoverEffect(.highlight) // 指针悬停时高亮

// 这些是独立的——一个按钮可以同时有：
// - 指针悬停高亮（触控板附近）
// - 键盘焦点环（Tab 导航到它）
// - 两者同时
```

iOS 上的 `.hoverEffect()` 仅响应触控板/鼠标（非触摸）。这与 visionOS 不同，那里 `.hoverEffect()` 响应注视。

## VoiceOver 焦点 vs UI 焦点

这些是**完全独立的系统**：
- **UI 焦点**（`UIFocusSystem`）：键盘驱动，仅硬件键盘活跃时活跃
- **VoiceOver 焦点**（`UIAccessibilityFocus`）：辅助技术，`isAccessibilityElement` + `accessibilityElements` 排序
- **完全键盘访问**：使用与 Tab 导航相同的焦点系统，因此 `canBecomeFocused` 影响两者
- SwiftUI：`@AccessibilityFocusState` 独立于 `@FocusState` 控制 VoiceOver 焦点

## WWDC 会议

| 会议 | 年份 | 关键内容 |
|---------|------|-------------|
| iPad 键盘导航焦点 | WWDC21 | 主要 iOS 焦点会议：焦点组、Tab 循环、光晕、allowsFocus |
| SwiftUI 中的直接和反射焦点 | WWDC21 | @FocusState、.focused、focusSection |
| 支持完全键盘访问 | WWDC21 | FKA 使用与 Tab 导航相同的焦点系统 |
| SwiftUI 焦点手册 | WWDC23 | .focusable(interactions:)、iOS 17 上的焦点区域 |
