# 异步焦点模式

焦点更新必须在主线程上发生。将焦点与异步数据加载、导航和动画协调需要仔细的顺序控制。

## @MainActor 和焦点更新

所有焦点状态更改必须在 `@MainActor` 上发生。SwiftUI 的 `@FocusState` 已经是主 actor 隔离的，但从异步上下文调用的 UIKit 焦点更新可能静默失败。

### SwiftUI

```swift
@MainActor
struct ContentView: View {
    @FocusState private var focusedItem: String?
    @State private var items: [String] = []
    
    var body: some View {
        VStack {
            ForEach(items, id: \.self) { item in
                Button(item) { }
                    .focused($focusedItem, equals: item)
            }
        }
        .task {
            items = await loadItems()
            // 安全——.task 在 SwiftUI 视图上运行于 @MainActor
            focusedItem = items.first
        }
    }
}
```

### UIKit

```swift
func loadAndFocus() {
    Task {
        let data = await fetchData()
        
        // 错误——可能不在主 actor 上
        // self.setNeedsFocusUpdate()
        
        // 正确——显式分派到主线程
        await MainActor.run {
            self.dataSource.apply(data)
            self.collectionView.layoutIfNeeded()
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
        }
    }
}
```

## 数据加载后焦点

最常见的异步焦点 bug：数据加载、视图更新，但焦点要么重置到顶部要么指向陈旧索引。

### 模式：延迟焦点恢复

```swift
struct CatalogView: View {
    @FocusState private var focusedID: String?
    @State private var items: [Item] = []
    @State private var pendingFocusID: String?
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) { item in
                    CardView(item: item)
                        .focused($focusedID, equals: item.id)
                }
            }
        }
        .onChange(of: items) { _, newItems in
            // 数据更新后恢复焦点
            if let pending = pendingFocusID, newItems.contains(where: { $0.id == pending }) {
                focusedID = pending
                pendingFocusID = nil
            }
        }
    }
    
    func refresh() async {
        pendingFocusID = focusedID  // 重载前保存
        items = await fetchItems()
        // 焦点恢复在 onChange 中发生
    }
}
```

### 模式：带焦点锁的 UIKit 安全重载

```swift
class CatalogViewController: UIViewController {
    private var allowsFocusUpdate = true
    private var savedIndexPath: IndexPath?
    
    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        return allowsFocusUpdate
    }
    
    func reloadPreservingFocus() async {
        // 保存当前焦点位置
        savedIndexPath = collectionView.indexPathsForVisibleItems
            .first { collectionView.cellForItem(at: $0)?.isFocused == true }
        
        // 重载期间锁定焦点
        allowsFocusUpdate = false
        
        let newData = await fetchData()
        
        await MainActor.run {
            dataSource.apply(newData, animatingDifferences: false)
            collectionView.layoutIfNeeded()
            
            // 解锁并恢复
            allowsFocusUpdate = true
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        }
    }
    
    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        return savedIndexPath
    }
}
```

## 导航后焦点

### NavigationStack 返回（SwiftUI）

在 `NavigationStack` 中返回时，SwiftUI 不会自动恢复焦点到触发推送的项目。你必须手动跟踪和恢复。

```swift
struct ListView: View {
    @FocusState private var focusedID: String?
    @State private var lastSelectedID: String?
    
    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink(value: item) {
                    Text(item.title)
                }
                .focused($focusedID, equals: item.id)
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(item: item)
            }
            .onAppear {
                // 返回时恢复焦点
                if let lastID = lastSelectedID {
                    focusedID = lastID
                }
            }
        }
    }
}
```

### 标签切换（tvOS）

焦点状态是每个标签的。切换标签并切回应恢复该标签中先前聚焦的项目。使用 `@FocusState` 配合 `onAppear`/`onDisappear` 保存和恢复。

```swift
struct TabContentView: View {
    @FocusState private var focusedItem: String?
    @State private var savedFocusItem: String?
    
    var body: some View {
        content
            .onDisappear {
                savedFocusItem = focusedItem
            }
            .onAppear {
                if let saved = savedFocusItem {
                    focusedItem = saved
                }
            }
    }
}
```

## withAnimation 和焦点

### SwiftUI

在 `withAnimation` 内设置 `@FocusState` 会动画化焦点更改：

```swift
withAnimation(.easeInOut(duration: 0.3)) {
    focusedItem = "newItem"
}
```

但在 `withAnimation` 完成后在 `Task` 中设置焦点可能导致视觉故障：

```swift
// 错误——动画上下文结束后设置焦点
withAnimation {
    showNewSection = true
}
Task {
    focusedItem = "firstItemInNewSection"  // 可能闪烁或不动画
}

// 正确——在相同动画事务中设置焦点
withAnimation {
    showNewSection = true
    focusedItem = "firstItemInNewSection"
}
```

### UIKit

`setNeedsFocusUpdate()` 在 `addCoordinatedFocusingAnimations` 内调用时与 `UIView.animate` 协调：

```swift
func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
    coordinator.addCoordinatedFocusingAnimations({ animContext in
        // 这些与焦点更改同步动画
        self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
    }, completion: nil)
}
```

## 并发数据加载

当多个数据源同时加载时，协调哪个可以设置焦点。

```swift
struct HomeView: View {
    @FocusState private var focusedSection: SectionID?
    @State private var heroLoaded = false
    @State private var catalogLoaded = false
    
    var body: some View {
        VStack {
            HeroSection()
                .focused($focusedSection, equals: .hero)
                .task {
                    await loadHero()
                    heroLoaded = true
                }
            
            CatalogSection()
                .focused($focusedSection, equals: .catalog)
                .task {
                    await loadCatalog()
                    catalogLoaded = true
                }
        }
        .onChange(of: heroLoaded) { _, loaded in
            if loaded && focusedSection == nil {
                focusedSection = .hero  // 英雄优先
            }
        }
    }
}
```

### 优先级规则
当多个区域在不同时间加载时建立清晰的焦点优先级。没有它，最后加载的区域获得焦点，导致可见焦点跳跃。

## Task 取消和焦点

当 `Task` 被取消（视图消失、用户导航离开），该任务中任何挂起的焦点更新应被跳过。

```swift
.task {
    let items = await loadItems()
    
    // 设置焦点前检查取消
    guard !Task.isCancelled else { return }
    
    self.items = items
    focusedItem = items.first?.id
}
```

在 UIKit 中，在 `viewWillDisappear` 中取消任务以防止在离屏视图控制器上进行焦点更新：

```swift
private var loadTask: Task<Void, Never>?

override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    loadTask = Task { await loadAndFocus() }
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    loadTask?.cancel()
}
```

## 防抖焦点更新

快速状态更改（搜索结果、过滤器更新）可能在每次按键时触发焦点更新。防抖以防止焦点闪烁。

```swift
struct SearchView: View {
    @FocusState private var focusedResult: String?
    @State private var results: [String] = []
    @State private var searchTask: Task<Void, Never>?
    
    func search(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            
            results = await performSearch(query)
            focusedResult = results.first
        }
    }
}
```

## @Observable 和焦点

### 同值变更守卫

使用 `@Observable`（iOS 17+、tvOS 17+），属性 setter 总是调用 `withMutation()` 即使值未更改。这会触发观察通知，导致 SwiftUI 重新求值 `body`，这可能在导航过程中干扰焦点引擎。

```swift
// 错误——每次调用都触发观察，即使无操作
@Observable class ViewModel {
    var selectedIndex: Int = 0
    
    func indexFocused(_ index: Int) {
        selectedIndex = index  // 即使 index == selectedIndex 也触发
    }
}

// 正确——守卫同值
func indexFocused(_ index: Int) {
    guard selectedIndex != index else { return }
    selectedIndex = index
}
```

这在焦点回调中尤其关键，快速遍历可能重复设置相同值。

### 非	UI 状态的 @ObservationIgnored

驱动焦点逻辑但不应触发视图更新的属性应使用 `@ObservationIgnored`：

```swift
@Observable class ViewModel {
    @ObservationIgnored private var paginationTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    
    var clips: [Clip] = []  // 这应触发 UI 更新
}
```

## ScrollTo 反馈循环

`onChange(of: focusedItem)` 内的命令式 `ScrollViewReader.scrollTo()` 创建级联焦点更新：

1. 焦点移动 → `onChange` 触发 → `scrollTo()` 动画化视口
2. 视口动画重新定位焦点光标下的项目
3. 焦点引擎重新计算 → 找到新的最近项目 → 焦点移动
4. 回到 1

**修复：** 用声明式 `ScrollPosition`（tvOS 17+）替换 `ScrollViewReader`：

```swift
// 错误——命令式 scrollTo 与焦点引擎对抗
ScrollViewReader { proxy in
    ScrollView {
        ForEach(items) { item in
            Button(item.title) { }
                .focused($focusedItem, equals: item.id)
        }
    }
    .onChange(of: focusedItem) { _, new in
        proxy.scrollTo(new, anchor: .center)  // 触发级联！
    }
}

// 正确——声明式 ScrollPosition 原子地与焦点协调
@State private var scrollPosition = ScrollPosition(idType: String.self)

ScrollView {
    ForEach(items) { item in
        Button(item.title) { }
            .focused($focusedItem, equals: item.id)
    }
}
.scrollPosition($scrollPosition)
```

如果必须使用 `ScrollViewReader`（例如 tvOS 16 支持），禁用程序化滚动的动画并使用防抖：

```swift
.onChange(of: focusedItem) { _, new in
    guard let id = new else { return }
    // 无 withAnimation——防止干扰焦点引擎
    proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.7))
}
```

## 常见错误

### 1. 视图在层次结构中之前设置焦点
在目标视图出现在层次结构中之前设置 `@FocusState` 什么也不做。使用 `onAppear` 或 `task` 延迟。

### 2. 分离 Task 中的焦点更新
分离的 `Task` 不继承主 actor 上下文。`Task.detached` 内的焦点更新没有显式 `@MainActor` 分派将不起作用。

### 3. 多个 .task 修饰符之间的竞态条件
同级视图上的多个 `.task` 修饰符可以以任何顺序完成。每个可能尝试获取焦点，导致可见焦点跳跃。

### 4. 未检查 Task.isCancelled 就更新焦点
在已消失的视图上设置焦点（任务未取消）不会崩溃但浪费周期并可能导致短暂视觉伪影。

### 5. 从后台线程调用 setNeedsFocusUpdate
后台线程的 UIKit 焦点更新静默失败。始终使用 `await MainActor.run { }` 或 `DispatchQueue.main.async { }`。
