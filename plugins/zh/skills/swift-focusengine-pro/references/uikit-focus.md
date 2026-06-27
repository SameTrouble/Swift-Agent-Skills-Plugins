# tvOS 的 UIKit 焦点 API

## UIFocusEnvironment 协议

遵循的类：`UIView`、`UIViewController`、`UIWindow`、`UIPresentationController`。

### preferredFocusEnvironments

焦点应去往的有序数组。焦点引擎遵循首选焦点链：Window -> Root VC -> 子 VC -> View -> 子视图，每个返回其 `preferredFocusEnvironments`，直到到达可聚焦叶子。

```swift
override var preferredFocusEnvironments: [UIFocusEnvironment] {
    if shouldFocusSearch {
        return [searchButton]
    }
    return [collectionView]
}
```

### 何时重写 `preferredFocusEnvironments`

在其 `view` 包含多个同级可聚焦子视图的任何 tvOS `UIViewController` 上重写。没有重写，焦点引擎选择几何上第一个可聚焦视图，这几乎从不是预期的主 CTA。

需要重写的触发条件：

- 多个 `UIButton` 的垂直或水平 `UIStackView`。
- 同时包含可聚焦列表（`UITableView`、`UICollectionView`）和独立按钮的视图。
- 主 CTA 条件取决于标志、远程配置或异步数据的屏幕——从重写返回条件正确的环境。
- 覆盖在另一个 VC 上的模态/sheet，系统否则会将焦点恢复到展示者。

对于条件 CTA，在重写内分支，并在条件在 VC 屏幕上后更改时与 `setNeedsFocusUpdate()` + `updateFocusIfNeeded()` 配对。从当前包含焦点的 VC 调用——见下面的"程序化焦点更新"和反模式 #7。

```swift
override var preferredFocusEnvironments: [UIFocusEnvironment] {
    if showPrimaryCTA {
        return [primaryCTAButton]
    }
    return [secondaryButton]
}
```

系统沿链读取 `preferredFocusEnvironments`：window -> root VC -> 子 VC -> view -> 子视图。每步返回其首选环境直到到达可聚焦叶子。直接返回可聚焦的 `UIButton`（未包装）是正确的——`UIButton` 已经遵循 `UIFocusEnvironment`。

### shouldUpdateFocus(in:)

验证或取消焦点移动。在包含先前聚焦和下一个聚焦视图的层次结构中的每个焦点环境上调用。如果任何一个返回 false，移动被取消。

```swift
override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
    // 动画期间阻止焦点
    if isAnimating { return false }
    
    // 阻止特定过渡
    if context.nextFocusedView == someViewToBlock {
        return false
    }
    return true
}
```

### didUpdateFocus(in:with:)

响应焦点更改并协调动画。

```swift
override func didUpdateFocus(in context: UIFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    super.didUpdateFocus(in: context, with: coordinator)
    
    if self == context.nextFocusedView {
        coordinator.addCoordinatedFocusingAnimations({ animCtx in
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.layer.zPosition = 1
        }, completion: nil)
    } else if self == context.previouslyFocusedView {
        coordinator.addCoordinatedUnfocusingAnimations({ animCtx in
            self.transform = .identity
            self.layer.zPosition = 0
        }, completion: nil)
    }
}
```

动画定位规则：
- `addCoordinatedFocusingAnimations`——以聚焦时序运行（显著）
- `addCoordinatedUnfocusingAnimations`——以失焦时序运行（细微）
- `UIFocusAnimationContext.duration` 提供同步嵌套动画的时序

### 程序化焦点更新

在 UIKit 中以编程方式移动焦点的唯一正确方法：

```swift
// 1. 存储期望目标
var pendingFocusTarget: UIView?

// 2. 重写 preferredFocusEnvironments
override var preferredFocusEnvironments: [UIFocusEnvironment] {
    if let target = pendingFocusTarget {
        return [target]
    }
    return super.preferredFocusEnvironments
}

// 3. 触发更新
pendingFocusTarget = someButton
setNeedsFocusUpdate()
updateFocusIfNeeded()
```

关键：`setNeedsFocusUpdate()` 仅在调用焦点环境当前包含聚焦视图时有效。

## UIFocusGuide

重定向焦点到真实视图的不可见矩形区域。用于弥合不相邻可聚焦区域之间的间隙。

```swift
let focusGuide = UIFocusGuide()
view.addLayoutGuide(focusGuide)

// 用 Auto Layout 定位
NSLayoutConstraint.activate([
    focusGuide.leadingAnchor.constraint(equalTo: menuView.trailingAnchor),
    focusGuide.trailingAnchor.constraint(equalTo: contentView.leadingAnchor),
    focusGuide.topAnchor.constraint(equalTo: view.topAnchor),
    focusGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
])

// 重定向焦点
focusGuide.preferredFocusEnvironments = [contentView]
```

根据上下文动态更新：
```swift
override func didUpdateFocus(in context: UIFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    super.didUpdateFocus(in: context, with: coordinator)
    // 将指南重定向到焦点刚来的地方
    if context.previouslyFocusedView === menuView {
        focusGuide.preferredFocusEnvironments = [contentView]
    } else {
        focusGuide.preferredFocusEnvironments = [menuView]
    }
}
```

属性：
- `preferredFocusEnvironments: [UIFocusEnvironment]`——重定向目标（有序）
- `isEnabled: Bool`——启用/禁用
- 不要使用已弃用的 `preferredFocusedView`

## canBecomeFocused

在自定义 UIView 子类上重写使其可聚焦。

```swift
override var canBecomeFocused: Bool { return true }
```

内置可聚焦：UIButton、UITextField、UITableViewCell、UICollectionViewCell、UITextView、UISegmentedControl、UISearchBar。

默认不可聚焦：UILabel、UIImageView、自定义 UIView。

## isTransparentFocusItem

为 true 时，项目可以接收焦点但其后面的项目也可以聚焦。用于不可见焦点锚点。

```swift
override var isTransparentFocusItem: Bool { return true }
```

## remembersLastFocusedIndexPath

```swift
collectionView.remembersLastFocusedIndexPath = true
```

为 true 时，`indexPathForPreferredFocusedView(in:)` 仅在第一次调用（在任何索引被记忆之前）。结合手动跟踪：

```swift
func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
    return lastFocusedIndexPath
}
```

## UIFocusSystem

```swift
// 获取环境的焦点系统
let focusSystem = UIFocusSystem.focusSystem(for: self)

// 注册自定义焦点声音
UIFocusSystem.register(soundFileURL, forSoundIdentifier: .default)
```

### soundIdentifierForFocusUpdate(in:)

控制每项焦点声音。声音根据移动速度自动调制音量，根据屏幕位置自动调整声相。

```swift
override func soundIdentifierForFocusUpdate(in context: UIFocusUpdateContext) -> UIFocusSoundIdentifier? {
    return .none  // 抑制此项的声音
}
```

## UIFocusMovementDidFail 通知

检测用户尝试移动焦点但无法移动时（滑入墙壁）。

```swift
NotificationCenter.default.addObserver(
    self, selector: #selector(focusMovementFailed),
    name: UIFocusSystem.movementDidFailNotification, object: nil
)
```

## 集合/表格视图焦点代理

```swift
// UICollectionViewDelegate
func collectionView(_ collectionView: UICollectionView,
    canFocusItemAt indexPath: IndexPath) -> Bool

func collectionView(_ collectionView: UICollectionView,
    didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
    with coordinator: UIFocusAnimationCoordinator)

func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath?

// UITableViewDelegate——相同模式
func tableView(_ tableView: UITableView,
    canFocusRowAt indexPath: IndexPath) -> Bool
```
