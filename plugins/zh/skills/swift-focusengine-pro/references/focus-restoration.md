# 数据更新后的焦点恢复

## 问题

当数据重新加载（API 响应、状态更改）时，先前聚焦的项目可能更改身份或消失。焦点跳到第一个项目或意外位置。

## SwiftUI 模式

### 保存和恢复 @FocusState

```swift
@FocusState var focusedID: String?
@State private var savedFocusID: String?

func loadData() async {
    savedFocusID = focusedID
    await viewModel.refresh()
    // 在下一个运行循环恢复
    Task { @MainActor in
        focusedID = savedFocusID
    }
}
```

### 使用可标识项目与 @FocusState

如果列表项目有稳定 ID，只要 ID 持续存在，焦点恢复就是自动的：

```swift
ForEach(items) { item in
    Button(item.title) { ... }
        .focused($focusedItem, equals: item.id)
}
```

当数据更新但相同 ID 存在时，`@FocusState` 保持焦点。当聚焦项目的 ID 消失时，焦点落到下一个几何候选。

### 导航返回后自动聚焦

从详情视图返回时，使用 AutoFocusManager 模式恢复焦点到先前选中的项目：

```swift
.onAppear {
    if let savedID = viewModel.lastViewedItemID {
        focusedItem = savedID
    }
}
```

### 使用 ZStack `if/else` 展示的模态/覆盖层不会自动恢复

`.sheet()` 和 `.fullScreenCover()` 在关闭时自动恢复焦点到展示视图。手动实现的覆盖层——在 `ZStack` 内用 `if showingOverlay { overlay } else { screen }` 切换视图——则**不会**。当你将标志翻回时，SwiftUI 从头重建底层屏幕，焦点落到几何上第一个可聚焦视图（通常是最左边的按钮），而非用户所在位置。

恢复它有一个时序陷阱：在关闭覆盖层的同一状态更新中**同步**设置 `@FocusState` 会被丢弃，因为目标按钮尚不在层次结构中——它只在屏幕重建时创建。将赋值延迟到下一个运行循环 tick，使重建的视图（及其目标）先存在：

```swift
Button("Close") {
    showingOverlay = false          // 触发屏幕重建
    // 此处同步 `focusedAction = .readFullStory` 会被丢弃——
    // 目标按钮尚不在层次结构中。延迟一个 tick。
    Task { @MainActor in
        focusedAction = .readFullStory
    }
}
```

## UIKit 模式

### 手动跟踪 + preferredFocusEnvironments

```swift
var lastFocusedIndexPath: IndexPath?

// 在代理中跟踪
func collectionView(_ collectionView: UICollectionView,
    didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
    with coordinator: UIFocusAnimationCoordinator) {
    lastFocusedIndexPath = context.nextFocusedIndexPath
}

// 通过首选焦点恢复
override var preferredFocusEnvironments: [UIFocusEnvironment] {
    if let indexPath = lastFocusedIndexPath,
       let cell = collectionView.cellForItem(at: indexPath) {
        return [cell]
    }
    return super.preferredFocusEnvironments
}

// 重载后
func reloadAndRestore() {
    collectionView.reloadData()
    collectionView.layoutIfNeeded()
    setNeedsFocusUpdate()
    updateFocusIfNeeded()
}
```

### 安全重载模式——重载期间门控焦点

```swift
private var allowsFocusUpdate = true

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

### 尽可能使用 reloadItems(at:) 而非 reloadData()

`reloadData()` 在集合视图离屏时破坏 `remembersLastFocusedIndexPath` 状态。优先使用粒度更新：

```swift
// 错误——离屏时破坏焦点记忆
collectionView.reloadData()

// 正确——保持焦点记忆
collectionView.reloadItems(at: changedIndexPaths)

// 或使用 performBatchUpdates 进行插入/删除/移动
collectionView.performBatchUpdates({
    collectionView.insertItems(at: newIndexPaths)
    collectionView.deleteItems(at: removedIndexPaths)
}, completion: nil)
```

## 行偏移跟踪（集合表格模式）

当表格视图每行包含集合视图时，保存每行的滚动偏移以便返回行时恢复位置：

```swift
private var rowContentOffsets: [Int: CGPoint] = [:]

// 离开行时保存
func didUpdateFocus(in context: UIFocusUpdateContext, ...) {
    if let previousRow = previousRowIndex,
       let collectionView = collectionViewForRow(previousRow) {
        rowContentOffsets[previousRow] = collectionView.contentOffset
    }
}

// 进入行时恢复
func willDisplay(cell:, forRowAt indexPath:) {
    if let offset = rowContentOffsets[indexPath.row] {
        cell.collectionView.contentOffset = offset
    }
}
```

## macOS 焦点恢复

### 窗口第一响应者持久化

macOS 自动为每个窗口保持第一响应者。在窗口之间切换会恢复每个窗口的焦点。但是，重建视图层次结构（例如 SwiftUI 重新渲染视图）可能重置第一响应者。

### 围绕 Sheets 和 Alerts 保存/恢复（AppKit）

```swift
// 显示 sheet 前保存
let savedResponder = window.firstResponder

window.beginSheet(sheetWindow) { response in
    // sheet 关闭后恢复
    self.window.makeFirstResponder(savedResponder)
}
```

SwiftUI `.sheet()` 自动处理——关闭时焦点返回展示视图。

### NSDocument 保存/恢复后的焦点

当文档恢复（`revert(toContentsOf:ofType:)`）时，视图层次结构可能重新加载。跟踪并恢复聚焦字段：

```swift
override func revert(toContentsOf url: URL, ofType typeName: String) throws {
    let savedResponder = windowForSheet?.firstResponder
    try super.revert(toContentsOf: url, ofType: typeName)
    // 延迟到下一个运行循环——视图需要时间重建
    DispatchQueue.main.async {
        self.windowForSheet?.makeFirstResponder(savedResponder)
    }
}
```

## 异步过渡期间处理焦点

在状态之间过渡时（加载 -> 已加载、折叠 -> 展开）：

```swift
// 过渡期间阻止焦点
isAnimatingTransition = true

UIView.animate(withDuration: 0.3, animations: {
    // 布局更改
}) { _ in
    self.isAnimatingTransition = false
    self.setNeedsFocusUpdate()
    self.updateFocusIfNeeded()
}

override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
    return !isAnimatingTransition
}
```
