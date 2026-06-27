# 之前/之后：UIKit 无障碍

带优先级层级注释的具体 UIKit 代码转换。

优先级层级：
- **Blocks Assistive Tech** —— 元素完全不可达或不可用
- **Degrades Experience** —— 可达但摩擦显著
- **Incomplete Support** —— 阻止 Nutrition Label 声明的缺口

## 目录

### Blocks Assistive Tech
- 自定义视图不在无障碍树中
- 容器同时暴露元素和子元素
- 模态不捕获 VoiceOver 焦点

### Degrades Experience
- 滑动显示操作不可访问
- 自定义可调视图缺少递增/递减
- 自定义 frame 不在屏幕坐标中

### Incomplete Support
- 异步内容加载后无播报
- 缓存的 accessibilityElements 未失效

---

## [Blocks Assistive Tech] 自定义视图不在无障碍树中

**问题：** 可点击卡片的自定义 UIView 子类未暴露给 VoiceOver 或 Voice Control，因为 UIView 的 `isAccessibilityElement` 默认为 `false`。

```swift
// ❌ 之前
class ProductCardView: UIView {
    // 无无障碍属性设置
    // 通过 UITapGestureRecognizer 添加 onTap 手势
}
```

```swift
// ✅ 之后
class ProductCardView: UIView {
    var product: Product? {
        didSet { updateAccessibility() }
    }

    override var isAccessibilityElement: Bool {
        get { true }
        set { }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { .button }
        set { }
    }

    override var accessibilityLabel: String? {
        get { product?.name }  // [VERIFY] confirm this label matches intent
        set { }
    }

    override var accessibilityHint: String? {
        get { "Opens product details" }
        set { }
    }

    private func updateAccessibility() {
        UIAccessibility.post(notification: .layoutChanged, argument: self)
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 设置 `isAccessibilityElement = true` | 将视图纳入无障碍树 |
| 设置 `accessibilityTraits = .button` | VoiceOver 朗读"button"；Voice Control 显示元素 |
| 添加 `accessibilityLabel` | VoiceOver 朗读产品名 |
| 添加 `accessibilityHint` | VoiceOver 朗读激活的结果 |
| 数据变化时发送 `.layoutChanged` | VoiceOver 更新缓存信息 |

---

## [Blocks Assistive Tech] 容器同时暴露元素和子元素

**问题：** 容器有 `isAccessibilityElement = true` 且设置了 `accessibilityElements`。VoiceOver 朗读容器及其子元素——内容翻倍。

```swift
// ❌ 之前
class RatingView: UIView {
    let starsLabel = UILabel()
    let countLabel = UILabel()

    override var isAccessibilityElement: Bool {
        get { true }  // ❌ 与下方 accessibilityElements 冲突
        set { }
    }

    override var accessibilityElements: [Any]? {
        get { [starsLabel, countLabel] }
        set { }
    }
}
```

```swift
// ✅ 之后
class RatingView: UIView {
    let starsLabel = UILabel()
    let countLabel = UILabel()

    // 容器不是元素——它暴露子元素
    override var isAccessibilityElement: Bool {
        get { false }
        set { }
    }

    override var accessibilityElements: [Any]? {
        get { [starsLabel, countLabel] }
        set { }
    }
}

// 配置标签
starsLabel.accessibilityLabel = "4.5 stars"
starsLabel.accessibilityTraits = .staticText
countLabel.accessibilityLabel = "2,304 ratings"
countLabel.accessibilityTraits = .staticText
```

**更改：**
| 更改 | 原因 |
|---|---|
| 容器上 `isAccessibilityElement = false` | 容器通过 `accessibilityElements` 暴露子元素——它不能同时也是元素 |
| 配置子元素标签 | 每个子元素需要自己的标签 |

---

## [Blocks Assistive Tech] 模态不捕获 VoiceOver 焦点

**问题：** 自定义模态出现时，VoiceOver 仍可通过滑动导航到后面的元素。

```swift
// ❌ 之前
class AlertModalView: UIView {
    // 通过 addSubview 出现的自定义 alert
    // 无焦点捕获
}
```

```swift
// ✅ 之后
class AlertModalView: UIView {
    // 在此模态内捕获焦点
    override var accessibilityViewIsModal: Bool {
        get { true }  // VoiceOver 忽略此视图后面的所有内容
        set { }
    }
}

// 出现：
func showAlert() {
    let modal = AlertModalView()
    view.addSubview(modal)

    // 焦点移入模态
    UIAccessibility.post(notification: .screenChanged, argument: modal)
}

// 在模态的视图控制器中：
override func accessibilityPerformEscape() -> Bool {
    dismissAlert()
    return true
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| `accessibilityViewIsModal = true` | VoiceOver 忽略模态后面的所有视图 |
| 用模态发送 `.screenChanged` | 出现时焦点移入模态 |
| 实现 `accessibilityPerformEscape()` | 双指 Z 手势 + Escape 键关闭模态 |

---

## [Degrades Experience] 滑动显示操作不可访问

**问题：** 删除和归档仅通过滑动手势可访问。VoiceOver 和 Voice Control 用户无法到达它们。

```swift
// ❌ 之前
class MessageCell: UITableViewCell {
    // 在 tableView(_:trailingSwipeActionsConfigurationForRowAt:) 中配置滑动操作
    // 无无障碍等价物
}
```

```swift
// ✅ 之后
class MessageCell: UITableViewCell {
    var message: Message?

    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            guard let message = message else { return nil }
            return [
                UIAccessibilityCustomAction(
                    name: "Reply",
                    target: self,
                    selector: #selector(handleReply)
                ),
                UIAccessibilityCustomAction(
                    name: "Archive"
                ) { [weak self] _ in
                    self?.archiveMessage()
                    return true
                },
                UIAccessibilityCustomAction(
                    name: "Delete",
                    image: UIImage(systemName: "trash")
                ) { [weak self] _ in
                    self?.deleteMessage()
                    return true
                }
            ]
        }
        set { }
    }

    @objc private func handleReply() -> Bool {
        replyToMessage()
        return true  // true = 操作已执行
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `accessibilityCustomActions` | VoiceOver Actions 转子；Voice Control">>"指示器 |
| 从操作处理返回 `true` | 向 VoiceOver 信号操作成功 |
| 为 Delete 操作添加图片 | 在 VoiceOver 操作菜单中显示图标（可选） |
| 在委托中保留滑动操作 | 视力用户保留手势 |

---

## [Degrades Experience] 自定义可调视图缺少递增/递减

**问题：** 星级评分视图有 `.adjustable` 特质但未实现递增/递减方法。VoiceOver 播放"adjustable"声音但什么也没发生。

```swift
// ❌ 之前
class StarRatingView: UIView {
    var rating: Int = 0

    override var accessibilityTraits: UIAccessibilityTraits {
        get { .adjustable }
        set { }
    }

    override var accessibilityValue: String? {
        get { "\(rating) stars" }
        set { }
    }
    // 缺少：accessibilityIncrement 和 accessibilityDecrement
}
```

```swift
// ✅ 之后
class StarRatingView: UIView {
    var rating: Int = 0 {
        didSet {
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }
    }

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityLabel: String? { get { "Rating" } set {} }
    override var accessibilityTraits: UIAccessibilityTraits { get { .adjustable } set {} }
    override var accessibilityValue: String? {
        get { "\(rating) out of 5 stars" }
        set {}
    }
    override var accessibilityHint: String? {
        get { "Swipe up or down to change rating" }
        set {}
    }

    override func accessibilityIncrement() {
        rating = min(5, rating + 1)
    }

    override func accessibilityDecrement() {
        rating = max(0, rating - 1)
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `accessibilityIncrement()` | `.adjustable` 特质必需——上滑递增 |
| 添加 `accessibilityDecrement()` | `.adjustable` 特质必需——下滑递减 |
| 评分变化时发送 `.layoutChanged` | VoiceOver 重新朗读更新值 |
| 添加 `accessibilityHint` | 告诉用户如何与可调元素交互 |
| 更好的 `accessibilityValue` 措辞 | "out of 5 stars"比仅"3 stars"更具描述性 |

---

## [Degrades Experience] 自定义 frame 不在屏幕坐标中

**问题：** `accessibilityFrame` 返回本地视图坐标。VoiceOver 在错误位置绘制焦点环。

```swift
// ❌ 之前
class BadgeView: UIView {
    override var accessibilityFrame: CGRect {
        get { bounds }  // ❌ 本地坐标，非屏幕坐标
        set { }
    }
}
```

```swift
// ✅ 之后
class BadgeView: UIView {
    override var accessibilityFrame: CGRect {
        get {
            // 转换为屏幕坐标
            UIAccessibility.convertToScreenCoordinates(bounds, in: self)
        }
        set { }
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 使用 `UIAccessibility.convertToScreenCoordinates(bounds, in: self)` | `accessibilityFrame` 必须是屏幕坐标；本地 bounds 是错误的 |

---

## [Incomplete Support] 异步内容加载后无播报

**问题：** 网络请求完成且新内容出现时，VoiceOver 用户不知道内容已变化。他们必须手动探索才能发现。

```swift
// ❌ 之前
func loadMessages() {
    Task {
        messages = try await api.fetchMessages()
        tableView.reloadData()
        // VoiceOver 不知道内容已变化
    }
}
```

```swift
// ✅ 之后
func loadMessages() {
    Task {
        messages = try await api.fetchMessages()
        tableView.reloadData()

        // 播报更新并将焦点移到相关内容
        if messages.isEmpty {
            UIAccessibility.post(
                notification: .announcement,
                argument: "No messages"
            )
        } else {
            // 焦点移到第一条新消息
            let firstCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0))
            UIAccessibility.post(notification: .layoutChanged, argument: firstCell)
        }
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 用第一个单元格发送 `.layoutChanged` | VoiceOver 焦点移到新内容 |
| 为空状态发送 `.announcement` | 播报未找到内容 |
| 选择 `.layoutChanged` 而非 `.screenChanged` | 部分更新（新行，非新屏幕） |

---

## [Incomplete Support] 缓存的 accessibilityElements 未失效

**问题：** 自定义图表视图缓存其无障碍元素但在数据变化时不刷新。VoiceOver 朗读过时数据。

```swift
// ❌ 之前
class ChartView: UIView {
    var data: [ChartPoint] = [] {
        didSet {
            setNeedsDisplay()
            // ❌ 缓存元素未失效
        }
    }

    private var cachedElements: [UIAccessibilityElement]?

    override var accessibilityElements: [Any]? {
        get {
            if cachedElements == nil {
                cachedElements = buildElements()
            }
            return cachedElements
        }
        set { cachedElements = newValue as? [UIAccessibilityElement] }
    }
}
```

```swift
// ✅ 之后
class ChartView: UIView {
    var data: [ChartPoint] = [] {
        didSet {
            setNeedsDisplay()
            cachedElements = nil  // ✅ 使缓存失效
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    private var cachedElements: [UIAccessibilityElement]?

    override var isAccessibilityElement: Bool {
        get { false }  // 容器暴露子元素
        set { }
    }

    override var accessibilityElements: [Any]? {
        get {
            if cachedElements == nil {
                cachedElements = data.enumerated().map { index, point in
                    let element = UIAccessibilityElement(accessibilityContainer: self)
                    element.accessibilityLabel = point.label
                    element.accessibilityValue = "\(point.value) units"
                    element.accessibilityTraits = .staticText
                    element.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(
                        frameForPoint(at: index), in: self
                    )
                    return element
                }
            }
            return cachedElements
        }
        set { cachedElements = newValue as? [UIAccessibilityElement] }
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| `didSet` 中 `cachedElements = nil` | 强制下次 VoiceOver 访问时重建 |
| 数据变化后发送 `.layoutChanged` | 告诉 VoiceOver 布局已变化；触发刷新 |
| 容器上设置 `isAccessibilityElement = false` | 容器暴露子元素——不能本身是元素 |
| 将 frame 转换为屏幕坐标 | `accessibilityFrame` 需要屏幕坐标 |
