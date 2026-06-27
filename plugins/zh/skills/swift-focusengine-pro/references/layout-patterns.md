# 常见布局模式与焦点（tvOS + macOS）

## Netflix/VOD 模式：水平集合表格

每行是包含水平集合视图的表格单元格。这是最常见的 tvOS 布局。

### SwiftUI

```swift
ScrollView(.vertical) {
    VStack(spacing: 40) {  // VStack，而非 LazyVStack——见下面警告
        ForEach(categories) { category in
            VStack(alignment: .leading) {
                Text(category.title).font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {  // LazyHStack 没问题——重内容保持懒加载
                        ForEach(category.items) { item in
                            Button { select(item) } label: {
                                PosterCard(item: item)
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
                .focusSection()  // 关键——防止跨行跳跃
            }
        }
    }
}
.focusSection()  // 防止焦点向上逃逸到标签栏
```

### 为什么用 VStack，而非 LazyVStack

**`LazyVStack` 释放离屏行。** 在 tvOS 上，滚动是焦点驱动的。当用户快速向上滑动时，焦点引擎向上几何搜索——但离屏行视图已从层次结构中移除。焦点找不到任何东西并跳到标签栏，跳过所有内容。

**`VStack` 将所有行保留在层次结构中。** 行容器是轻量级的（只是标题标签 + ScrollView 包装器）。昂贵的内容（海报图像、缩略图）在每行的 `LazyHStack` 内保持懒加载。这给你两全其美：焦点安全的导航和懒加载的重内容。

以下情况使用 `VStack`：
- 行数有界（配置驱动，通常 4-10 行）
- 行容器轻量级（重内容在懒加载内部容器中）

以下情况使用带 `remembersLastFocusedIndexPath` 的 `UICollectionView`：
- 行数无界（无限滚动、信息流）
- VStack 会急切加载太多内容

### UIKit

```swift
// UITableViewController，每个单元格包含 UICollectionView
class CatalogTableViewCell: UITableViewCell {
    let collectionView: UICollectionView

    override init(style:, reuseIdentifier:) {
        // 设置水平流布局
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.remembersLastFocusedIndexPath = true
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionView]
    }
}
```

表格视图自然隔离行——垂直焦点在表格单元格之间移动，水平在集合视图内移动。

## 侧边栏 + 内容模式

### SwiftUI（基本侧边栏模式）

```swift
struct SidebarContentView: View {
    @FocusState var focusedSection: Section?
    @State var isExpanded = false

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            VStack {
                ForEach(sections) { section in
                    Button(section.title) { selectedSection = section }
                        .focused($focusedSection, equals: section)
                }
            }
            .frame(width: isExpanded ? 300 : 80)
            .focusSection()
            .onChange(of: focusedSection) { old, new in
                if old != nil && new == nil { isExpanded = false }
                if old == nil && new != nil { isExpanded = true }
            }

            // 内容
            ContentView(section: selectedSection)
                .focusSection()
        }
        .onExitCommand {
            if !isExpanded { isExpanded = true }
        }
    }
}
```

关键模式：
- 每个窗格获得 `.focusSection()`
- 侧边栏展开/折叠由焦点进入/离开驱动
- `.onExitCommand` 将焦点返回侧边栏而非退出应用
- `isInitialLoad` 守卫防止首次出现时侧边栏展开

### SwiftUI（生产模式——双重 @FocusState 配合 .disabled() 门控）

上面的基本侧边栏模式有一个关键缺陷：当焦点离开（到网格、导航栏）并返回时，`@FocusState` 不保证落在正确项目上。此生产模式通过结合三种技术解决：

```swift
struct TopicsSidebarView: View {
    @FocusState private var isContainerFocused: Bool   // 容器级
    @FocusState private var focusedIndex: Int?         // 每项
    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    
    let items: [Topic]
    let selectedIndex: Int
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button(item.title) { onSelect(index) }
                        .focused($focusedIndex, equals: index)
                        // 关键：焦点在外部时只有选中项目可聚焦。
                        // 焦点在内部时所有项目都可聚焦。
                        .disabled(!isContainerFocused && selectedIndex != index)
                }
            }
        }
        .focused($isContainerFocused)
        .scrollPosition($scrollPosition)  // 声明式——无 ScrollViewReader
        .focusSection()
        .onChange(of: focusedIndex) { old, new in
            // 仅对侧边栏内导航操作（两者都非 nil）
            guard let _ = old, let newIndex = new else { return }
            onFocusChanged(newIndex)
        }
    }
}
```

**为什么有效：**
1. **`.disabled()` 门控**——焦点在侧边栏外部时，只有选中项目启用。焦点引擎只能落在它上面——无可见跳过错误项目。
2. **容器 `@FocusState`**——`isContainerFocused` 提供侧边栏是否有焦点的稳定跟踪，没有每项 nil 检查的不稳定性。
3. **`ScrollPosition`**——声明式滚动绑定避免 `ScrollViewReader.scrollTo()` 反馈循环（见反模式 #26）。
4. **`onChange` 守卫**——过滤穿透过渡期间的瞬态焦点接触（见反模式 #29）。

### UIKit 侧边栏（生产模式）

参考 UIKit 代码库使用根本不同的方法，避免 SwiftUI 的焦点链问题：

```swift
class TopicsSidebarViewController: UITableViewController {
    // 关键：从不禁用单个行——使用容器级门控
    // 和 remembersLastFocusedIndexPath 进行恢复
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.remembersLastFocusedIndexPath = true
    }
    
    // 门控容器，而非单个项目
    func setInteractionEnabled(_ enabled: Bool) {
        // 用 0.5s 定时器防抖快速状态变化
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.tableView.isUserInteractionEnabled = enabled
        }
    }
}
```

**与 SwiftUI 的关键区别：**
- **从不禁用单个行**——避免批量切换级联
- **`remembersLastFocusedIndexPath = true`**——内置焦点恢复（无 SwiftUI 等价物）
- **容器级 `isUserInteractionEnabled`**——切换整个表格，非单个单元格
- **0.5s 防抖**——防止导航过渡期间的快速状态变化
- **内置滚动淡出**——`UITableView` 有原生渐变边缘淡出（SwiftUI 需要手动遮罩）

### UIKit

使用 `UIFocusGuide` 弥合侧边栏和内容之间的间隙：

```swift
let sidebarContentGuide = UIFocusGuide()
view.addLayoutGuide(sidebarContentGuide)
// 在侧边栏和内容之间定位
sidebarContentGuide.preferredFocusEnvironments = [contentView]

// 根据焦点来源更新方向
override func didUpdateFocus(in context: UIFocusUpdateContext, ...) {
    if context.previouslyFocusedView?.isDescendant(of: sidebarView) == true {
        sidebarContentGuide.preferredFocusEnvironments = [contentView]
    } else {
        sidebarContentGuide.preferredFocusEnvironments = [sidebarView]
    }
}
```

## 标签栏模式

### SwiftUI

```swift
TabView(selection: $selectedTab) {
    HomeView().tabItem { Label("Home", systemImage: "house") }.tag(Tab.home)
    ShowsView().tabItem { Label("Shows", systemImage: "tv") }.tag(Tab.shows)
}
```

对于自定义标签栏（可折叠侧边标签栏模式）：
- 将标签按钮包装在 `.focusSection()` 中
- 使用 `@FocusState` 跟踪哪个标签聚焦
- 焦点进入/离开时展开/折叠
- 使用 `.onExitCommand` 将焦点带回标签

### 标签栏焦点逃逸检测（UIKit）

在 UIKit 标签栏控制器内托管 SwiftUI 视图时，检测焦点从内容逃逸到标签栏。这对需要在用户导航回标签时折叠的全屏目录视图至关重要：

```swift
class SwiftUIHomeViewController: UIHostingController<HomeView> {
    override func didUpdateFocus(in context: UIFocusUpdateContext,
                                 with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        guard let tabBar = tabBarController?.tabBar else { return }
        let movedToTabBar = context.nextFocusedView?.isDescendant(of: tabBar) == true
        if movedToTabBar {
            // 折叠全屏目录，恢复默认英雄状态
            viewModel.handleTabBarFocused()
        }
    }
}
```

关键规则：
- 使用 `guard let`——从不在焦点回调中分配回退对象（见反模式 #17）
- 检查 `isDescendant(of:)`——不要直接比较视图身份，标签栏项目是嵌套的
- 先调用 `super` 以保持默认行为

### UIKit

占位标签（尚未实现）应将焦点重定向回标签栏：

```swift
class PlaceholderTabViewController: UIViewController {
    private let focusGuide = UIFocusGuide()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addLayoutGuide(focusGuide)
        // 约束以填充视图
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let tabBar = tabBarController?.tabBar {
            focusGuide.preferredFocusEnvironments = [tabBar]
        }
    }
}
```

## 英雄 + 目录模式

顶部大英雄图像，下方目录行。目录获得焦点时英雄折叠。

### 焦点协调

```swift
// 跟踪目录焦点以驱动英雄折叠
override func didUpdateFocus(in context: UIFocusUpdateContext, ...) {
    let focusInCatalog = context.nextFocusedView?.isDescendant(of: catalogView) == true
    let focusWasInCatalog = context.previouslyFocusedView?.isDescendant(of: catalogView) == true

    if focusInCatalog && !focusWasInCatalog {
        collapseHero(animated: true)
    } else if !focusInCatalog && focusWasInCatalog {
        expandHero(animated: true)
    }
}
```

英雄动画期间阻止焦点：

```swift
override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
    return !isAnimatingHeroTransition
}
```

## 滚动 + 箭头按钮模式

带左右箭头按钮的水平货架：

```swift
@FocusState private var buttonFocus: ScrollDirection?

HStack {
    VStack {
        button(.reverse, isDisabled: atStart)
        button(.forward, isDisabled: atEnd)
    }
    .focusSection()  // 按钮获得自己的区域

    ScrollView(.horizontal) {
        LazyHStack { /* 项目 */ }
    }
    .focusSection()  // 滚动内容获得自己的区域
}

func button(_ direction: ScrollDirection, isDisabled: Bool) -> some View {
    Button {
        guard !isDisabled else { return }  // 门控操作，而非视图
        scroll(direction)
    } label: { Image(systemName: "chevron.\(direction)") }
        .focused($buttonFocus, equals: direction)
        .opacity(isDisabled ? 0.5 : 1.0)
}
```

当按钮滚动到末尾变为禁用时，自动移动焦点到另一个按钮：

```swift
if viewModel.isFullyScrolled(direction: direction) {
    buttonFocus = direction.opposite
}
```

## 分割详情模式

左侧主列表，右侧详情。tvOS NavigationSplitView 或手动分割：

```swift
NavigationSplitView {
    List(items, selection: $selectedItem) { item in
        Text(item.title)
    }
    .focusSection()
} detail: {
    DetailView(item: selectedItem)
        .focusSection()
}
```

对于自定义实现，使用两个 `.focusSection()` 窗格并处理 `.onExitCommand` 返回主列表。

## macOS 布局模式

### 侧边栏 + 内容（NavigationSplitView）

标准 macOS 文档/导航模式。焦点通过 Tab 或鼠标点击在侧边栏和内容之间移动。

```swift
NavigationSplitView {
    List(items, selection: $selectedItem) { item in
        Text(item.title)
    }
    .focusSection()  // macOS 14+——Tab 在侧边栏和内容之间切换
} detail: {
    if let item = selectedItem {
        DetailView(item: item)
            .focusSection()
    }
}
```

AppKit 等价物使用 `NSSplitViewController`：

```swift
class MainSplitViewController: NSSplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Tab 自动在分割窗格之间移动
        // 方向键在每个窗格内导航
    }

    // Cmd+1 聚焦侧边栏第一个项目
    @IBAction func focusSidebar(_ sender: Any?) {
        let sidebarVC = splitViewItems[0].viewController
        view.window?.makeFirstResponder(sidebarVC.view)
    }
}
```

### 工具栏 + 内容

主内容区域上方有工具栏项目的 macOS 应用。工具栏焦点需要完全键盘访问或 Ctrl+F5。

```swift
struct ContentView: View {
    @FocusState private var isContentFocused: Bool

    var body: some View {
        VStack {
            // 内容区域默认获得焦点
            DocumentEditor()
                .focusable()
                .focused($isContentFocused)
        }
        .toolbar {
            ToolbarItem {
                TextField("Search", text: $search)
                // 搜索字段默认可 Tab 聚焦
            }
        }
        .onAppear { isContentFocused = true }
    }
}
```

### 多窗口文档应用

每个窗口有独立焦点状态。菜单命令针对关键窗口。

```swift
@main
struct MyApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MyDocument()) { file in
            DocumentView(document: file.$document)
                .focusedSceneValue(\.activeDocument, file.document)
                // 每个窗口发布其文档供菜单命令使用
        }

        Settings {
            SettingsView()
            // 设置有自己的焦点作用域——独立于文档
        }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.activeDocument) var document

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Format Selection") {
                document?.formatSelection()
            }
            .disabled(document == nil)
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }
}
```

### 偏好设置 / 设置窗口

```swift
Settings {
    TabView {
        GeneralSettingsView()
            .tabItem { Label("General", systemImage: "gear") }
        AdvancedSettingsView()
            .tabItem { Label("Advanced", systemImage: "gearshape.2") }
    }
    .frame(width: 450, height: 300)
}
// Tab 键在活动设置标签页的控件间循环
// Cmd+1/Cmd+2 在标签页之间切换
```

### 检查器面板模式

不从主窗口窃取焦点的浮动面板：

```swift
// AppKit
let panel = NSPanel(contentRect: rect,
                    styleMask: [.titled, .closable, .utilityWindow],
                    backing: .buffered, defer: false)
panel.becomesKeyOnlyIfNeeded = true  // 不窃取焦点
panel.isFloatingPanel = true          // 浮在文档窗口上方
panel.orderFront(nil)                 // 显示但不成为关键

// SwiftUI——使用 Window 场景
Window("Inspector", id: "inspector") {
    InspectorView()
}
.defaultSize(width: 250, height: 400)
```

### 源列表 + 编辑器 + 检查器（三列）

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    // 源列表（侧边栏）
    List(projects, selection: $selectedProject) { project in
        Label(project.name, systemImage: "folder")
    }
    .focusSection()
} content: {
    // 文件列表（中间）
    List(files, selection: $selectedFile) { file in
        Text(file.name)
    }
    .focusSection()
} detail: {
    // 编辑器（右侧）
    EditorView(file: selectedFile)
        .focusSection()
}
```

Tab 在三列之间移动。方向键在每列内导航。每列独立维护自己的选择/焦点。

## 滚动边缘淡出（tvOS）

UIKit 的 `UITableView` 提供内置渐变边缘淡出。SwiftUI 没有等价物——你必须手动构建。

### `.scrollEdgeEffectStyle(.soft)`（tvOS 26+）

```swift
ScrollView(.vertical) {
    VStack { /* 内容 */ }
}
.scrollEdgeEffectStyle(.soft, for: .all)
```

**警告：** tvOS 26 液态玻璃效果使这非常微妙——对于深色背景的媒体应用通常太微妙。仔细测试，必要时回退到手动遮罩。

### 手动渐变遮罩（所有 tvOS 版本）

使用 `.mask()` 配合匹配 UIKit `CAGradientLayer` 停止距离的静态渐变停止点：

```swift
struct StaticEdgeFadeMask: View {
    let fadeHeight: CGFloat = 40  // 匹配 UIKit 参考的 CAGradientLayer 停止距离
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部淡出
            LinearGradient(colors: [.clear, .black],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: fadeHeight)
            
            // 完全可见内容区域
            Color.black
            
            // 底部淡出
            LinearGradient(colors: [.black, .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: fadeHeight)
        }
    }
}

// 应用到 ScrollView
ScrollView(.vertical) {
    VStack { /* 侧边栏项目 */ }
}
.mask { StaticEdgeFadeMask() }
```

**重要：** 使用 `.mask()`，而非 `.overlay()`。带纯色的覆盖层在径向渐变背景上显示可见方块。`.mask()` 适用于任何背景，因为它只影响 alpha。

### 动态滚动位置跟踪（tvOS 17+）

对于响应滚动位置的淡出（例如在顶部时隐藏顶部淡出）：

```swift
.onGeometryChange(for: CGFloat.self) { proxy in
    proxy.frame(in: .scrollView).minY
} action: { offset in
    isScrolledFromTop = offset < -10
}
```

### ScrollViewReader 自定义锚点用于温和滚动

需要程序化滚动时，使用自定义锚点避免激进居中：

```swift
proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.7))
// y: 0.7 将项目保持在下三分之一——比 .center 更温和
```

## 焦点缩放匹配（tvOS）

UIKit 应用通常使用 `adjustsImageWhenAncestorFocused`，它应用约 1.13x 缩放加视差。SwiftUI `scaleEffect` 应匹配：

| 元素 | UIKit（旗舰） | SwiftUI（推荐） |
|---------|-----------------|----------------------|
| 剪辑卡片 | 系统焦点（约 1.13 + 视差） | `scaleEffect(1.13)` |
| 节目海报 | 系统焦点（约 1.13 + 视差） | `scaleEffect(1.13)` |
| 侧边栏行 | 无缩放——仅颜色/标签 | 无缩放——仅颜色/标签 |
| 阴影（聚焦） | 系统视差阴影 | opacity 0.5, radius 24, y 18 |

使用 1.13 缩放时，增加行周围垂直内边距以适应增长：`card_height * 0.13 / 2 ≈ 26pt` 每侧（向上取整到 40pt 以保证安全）。
