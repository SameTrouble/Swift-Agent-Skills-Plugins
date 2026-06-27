# VoiceOver —— UIKit

## 目录
- [核心 UIAccessibility 属性](#核心-uiaccessibility-属性)
- [UIAccessibilityTraits 参考](#uiaccessibilitytraits-参考)
- [UIAccessibilityElement - 自定义元素](#uiaccessibilityelement---自定义元素)
- [UIAccessibilityContainer - 元素排序](#uiaccessibilitycontainer---元素排序)
- [UIAccessibilityCustomAction - 自定义操作](#uiaccessibilitycustomaction---自定义操作)
- [UIAccessibilityCustomRotor - 自定义导航](#uiaccessibilitycustomrotor---自定义导航)
- [通知 - 播报和焦点](#通知---播报和焦点)
- [UIAccessibilityReadingContent](#uiaccessibilityreadingcontent)
- [模态视图](#模态视图)
- [自定义控件模式](#自定义控件模式)
- [NSAttributedString 无障碍属性](#nsattributedstring-无障碍属性)
- [常见错误](#常见错误)

---

## 核心 UIAccessibility 属性

每个 `UIView` 子类都暴露这些属性。重写它们以提供无障碍信息。

```swift
class RatingView: UIView {
    var rating: Int = 0 {
        didSet {
            // 通知 VoiceOver 值已变化
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }
    }

    // 必需：将此视图纳入无障碍树
    override var isAccessibilityElement: Bool {
        get { true }
        set { }
    }

    override var accessibilityLabel: String? {
        get { "Rating" }
        set { }
    }

    override var accessibilityValue: String? {
        get { "\(rating) out of 5 stars" }
        set { }
    }

    override var accessibilityHint: String? {
        get { "Double-tap and hold, then swipe up or down to change" }
        set { }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { .adjustable }
        set { }
    }

    // 支持递增/递减手势（VoiceOver 上下滑动）
    override func accessibilityIncrement() {
        rating = min(5, rating + 1)
    }

    override func accessibilityDecrement() {
        rating = max(0, rating - 1)
    }
}
```

### 关键属性

| 属性 | 类型 | 用途 |
|---|---|---|
| `isAccessibilityElement` | `Bool` | 将视图纳入无障碍树 |
| `accessibilityLabel` | `String?` | 朗读的名称（非文字元素必需） |
| `accessibilityHint` | `String?` | 描述激活的结果 |
| `accessibilityValue` | `String?` | 当前值（滑块、进度） |
| `accessibilityTraits` | `UIAccessibilityTraits` | 语义角色和状态 |
| `accessibilityFrame` | `CGRect` | 无障碍点击区域（屏幕坐标） |
| `accessibilityPath` | `UIBezierPath?` | 自定义非矩形点击区域 |
| `accessibilityActivationPoint` | `CGPoint` | 精确点击点 |
| `accessibilityViewIsModal` | `Bool` | 将 VoiceOver 焦点限制在此视图 |
| `shouldGroupAccessibilityChildren` | `Bool` | 分组子元素以便扫描 |
| `accessibilityNavigationStyle` | `UIAccessibilityNavigationStyle` | `.automatic` / `.combined` / `.separate` |
| `accessibilityCustomActions` | `[UIAccessibilityCustomAction]?` | 自定义操作列表 |
| `accessibilityCustomRotors` | `[UIAccessibilityCustomRotor]?` | 自定义转子导航 |
| `accessibilityContainerType` | `UIAccessibilityContainerType` | `.none` / `.list` / `.landmark` / `.semanticGroup` / `.table` / `.dataTable` |

### `accessibilityFrame` —— 自定义点击区域

默认情况下，`accessibilityFrame` 匹配视图在屏幕坐标中的 frame。当视觉区域和无障碍区域不同时重写。

```swift
override var accessibilityFrame: CGRect {
    // 转换为屏幕坐标
    return UIAccessibility.convertToScreenCoordinates(bounds, in: self)
}

// 将点击区域扩展到 44pt 最小值
override var accessibilityFrame: CGRect {
    let frame = convert(bounds, to: nil)
    let minSize: CGFloat = 44
    let expandX = max(0, (minSize - frame.width) / 2)
    let expandY = max(0, (minSize - frame.height) / 2)
    return frame.insetBy(dx: -expandX, dy: -expandY)
}
```

---

## UIAccessibilityTraits 参考

特质可用 `|`（并集）组合。

```swift
accessibilityTraits = [.button, .selected]
```

| 特质 | 使用时机 |
|---|---|
| `.button` | 任何非 `UIButton` 的可点击元素 |
| `.link` | 打开 URL 或导航到应用外 |
| `.header` | 分区或页面标题 |
| `.selected` | 当前选中的项 |
| `.image` | 图片视图（装饰性或信息性） |
| `.searchField` | 搜索文字字段 |
| `.playsSound` | 激活播放音频 |
| `.keyboardKey` | 自定义键盘按键 |
| `.staticText` | 非交互显示文字 |
| `.summaryElement` | 应用首次启动时朗读 |
| `.notEnabled` | 禁用/不可用控件 |
| `.updatesFrequently` | 实时区域——值变化时重新朗读 |
| `.startsMediaSession` | 开始音频/视频播放 |
| `.adjustable` | 支持递增/递减 |
| `.allowsDirectInteraction` | 传递原始触摸（钢琴键、绘图） |
| `.causesPageTurn` | 在阅读应用中触发翻页 |
| `.tabBar` | 标签栏（系统处理） |

### 通过特质表达状态

```swift
// ✅ 选中状态作为特质
cell.accessibilityTraits = isSelected ? [.button, .selected] : .button

// ❌ 状态嵌入标签（破坏自动化且冗长）
cell.accessibilityLabel = isSelected ? "Photos, selected" : "Photos"
```

---

## UIAccessibilityElement - 自定义元素

当内容绘制在自定义视图中（`drawRect`、Core Graphics、Metal）且无原生子视图时使用。`UIAccessibilityElement` 在自定义绘制内容上创建虚拟元素。

```swift
class GraphView: UIView {
    var bars: [BarData] = []

    // 缓存元素——数据变化时重建
    private var _accessibilityElements: [UIAccessibilityElement]?

    override var isAccessibilityElement: Bool {
        get { false }   // 容器本身不是元素
        set { }
    }

    override var accessibilityElements: [Any]? {
        get {
            if _accessibilityElements == nil {
                _accessibilityElements = bars.enumerated().map { index, bar in
                    let element = UIAccessibilityElement(accessibilityContainer: self)
                    element.accessibilityLabel = bar.label
                    element.accessibilityValue = "\(bar.value) units"
                    element.accessibilityTraits = .staticText
                    // 将 bar 的 CGRect 转换为屏幕坐标
                    let barFrame = frameForBar(at: index)
                    element.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(barFrame, in: self)
                    return element
                }
            }
            return _accessibilityElements
        }
        set { _accessibilityElements = newValue as? [UIAccessibilityElement] }
    }

    func dataDidChange() {
        _accessibilityElements = nil
        // 告诉 VoiceOver 布局已变化
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}
```

---

## UIAccessibilityContainer - 元素排序

当视图包含多个应以特定顺序导航的子视图时，通过提供 `accessibilityElements` 实现 `UIAccessibilityContainer`。

```swift
class DashboardView: UIView {
    @IBOutlet var headerView: UIView!
    @IBOutlet var chartView: UIView!
    @IBOutlet var summaryLabel: UILabel!
    @IBOutlet var actionButton: UIButton!

    // 按期望的阅读顺序返回元素
    override var accessibilityElements: [Any]? {
        get { [headerView!, summaryLabel!, chartView!, actionButton!] }
        set { }
    }
}
```

### `accessibilityContainerType`

为容器提供语义含义。VoiceOver 播报容器类型变化。

```swift
tableContainerView.accessibilityContainerType = .dataTable
listView.accessibilityContainerType = .list
navContainerView.accessibilityContainerType = .landmark
```

### `shouldGroupAccessibilityChildren`

将所有子元素分组为单个节点供 Switch Control 扫描。不会为 VoiceOver 导融合元素。

```swift
groupView.shouldGroupAccessibilityChildren = true
```

---

## UIAccessibilityCustomAction - 自定义操作

向 VoiceOver 的 Actions 转子添加条目（双击并按住 → 上下滑动）。对于滑动显示和长按菜单必不可少。

```swift
class MessageCell: UITableViewCell {
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            [
                UIAccessibilityCustomAction(name: "Reply", target: self, selector: #selector(reply)),
                UIAccessibilityCustomAction(name: "Forward", target: self, selector: #selector(forward)),
                UIAccessibilityCustomAction(name: "Delete", image: UIImage(systemName: "trash")) { [weak self] _ in
                    self?.deleteMessage()
                    return true
                }
            ]
        }
        set { }
    }

    @objc private func reply() -> Bool {
        replyToMessage()
        return true  // 返回 true = 操作成功
    }

    @objc private func forward() -> Bool {
        forwardMessage()
        return true
    }
}
```

**返回值：** 操作已执行返回 `true`，不适用返回 `false`。

---

## UIAccessibilityCustomRotor - 自定义导航

在 VoiceOver 的转子中创建新项用于应用特定的导航（例如在标题、未读项、错误之间跳转）。

```swift
class ArticleViewController: UIViewController {
    var headings: [Heading] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        accessibilityCustomRotors = [makeHeadingRotor(), makeBookmarkRotor()]
    }

    private func makeHeadingRotor() -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(name: "Headings") { [weak self] predicate in
            guard let self = self else { return nil }

            let currentIndex = self.headings.firstIndex { $0.view == predicate.currentItem.targetElement as? UIView }
            let nextIndex: Int

            switch predicate.searchDirection {
            case .next:
                nextIndex = (currentIndex.map { $0 + 1 }) ?? 0
            case .previous:
                nextIndex = currentIndex.map { $0 - 1 } ?? self.headings.count - 1
            @unknown default:
                return nil
            }

            guard nextIndex >= 0, nextIndex < self.headings.count else { return nil }
            let heading = self.headings[nextIndex]
            return UIAccessibilityCustomRotorItemResult(targetElement: heading.view, targetRange: nil)
        }
    }
}
```

---

## 通知 - 播报和焦点

### 发送播报

```swift
// 简单字符串播报
UIAccessibility.post(notification: .announcement, argument: "Message sent")

// 带优先级控制的属性字符串（iOS 17+）
let announcement = NSAttributedString(
    string: "Emergency alert",
    attributes: [.accessibilitySpeechQueueAnnouncement: true]
)
UIAccessibility.post(notification: .announcement, argument: announcement)
```

### 屏幕变化 —— 完整焦点重置

当整个屏幕内容变化时发送（例如模态出现、标签页切换）。

```swift
// 焦点移到第一个元素
UIAccessibility.post(notification: .screenChanged, argument: nil)

// 焦点移到特定视图
UIAccessibility.post(notification: .screenChanged, argument: confirmButton)
```

### 布局变化 —— 部分更新

当部分布局变化时发送（分区展开、项目加载、错误出现）。

```swift
UIAccessibility.post(notification: .layoutChanged, argument: errorLabel)
```

### 页面滚动

```swift
UIAccessibility.post(notification: .pageScrolled, argument: "Page 3 of 10")
```

### 观察状态变化

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(voiceOverStatusChanged),
    name: UIAccessibility.voiceOverStatusDidChangeNotification,
    object: nil
)

@objc func voiceOverStatusChanged() {
    // 如需更新 UI——但避免根据 VoiceOver 状态分支核心逻辑
}
```

---

## UIAccessibilityReadingContent

用于显示长篇文字的视图（电子书阅读器、文档查看器）。启用 VoiceOver 的"Read All"和逐行导航。

```swift
class BookPageView: UIView, UIAccessibilityReadingContent {
    var lines: [String] = []

    func accessibilityLineNumber(for point: CGPoint) -> Int {
        return lineIndex(for: point)
    }

    func accessibilityContent(forLineNumber lineNumber: Int) -> String? {
        guard lineNumber < lines.count else { return nil }
        return lines[lineNumber]
    }

    func accessibilityFrame(forLineNumber lineNumber: Int) -> CGRect {
        return UIAccessibility.convertToScreenCoordinates(
            frameForLine(lineNumber), in: self
        )
    }

    func accessibilityPageContent() -> String? {
        return lines.joined(separator: " ")
    }
}
```

---

## 模态视图

当模态或 alert 出现时，必须阻止 VoiceOver 到达背景内容。

```swift
class ModalView: UIView {
    override var accessibilityViewIsModal: Bool {
        get { true }
        set { }
    }
}

// 出现时：
func presentModal() {
    let modal = ModalView()
    view.addSubview(modal)
    // VoiceOver 现在忽略模态后面的所有内容
    UIAccessibility.post(notification: .screenChanged, argument: modal.firstInteractiveElement)
}

// 支持 Escape 关闭（VO 双指 Z）
override func accessibilityPerformEscape() -> Bool {
    dismiss()
    return true
}
```

---

## 自定义控件模式

### 开关/复选框

```swift
class AccessibleCheckbox: UIControl {
    var isChecked: Bool = false {
        didSet { accessibilityValue = isChecked ? "On" : "Off" }
    }

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityLabel: String? { get { title } set {} }
    override var accessibilityTraits: UIAccessibilityTraits {
        get { isChecked ? [.button, .selected] : .button }
        set {}
    }

    // 或使用 .toggleButton 特质（iOS 17+）
}
```

### 自定义滑块

```swift
class CustomSlider: UIView {
    var value: Float = 0.5
    var minValue: Float = 0
    var maxValue: Float = 1

    override var accessibilityTraits: UIAccessibilityTraits { get { .adjustable } set {} }
    override var accessibilityValue: String? {
        get { "\(Int(value * 100)) percent" }
        set {}
    }

    override func accessibilityIncrement() {
        value = min(maxValue, value + 0.05)
        UIAccessibility.post(notification: .layoutChanged, argument: self)
    }

    override func accessibilityDecrement() {
        value = max(minValue, value - 0.05)
        UIAccessibility.post(notification: .layoutChanged, argument: self)
    }
}
```

### `accessibilityActivate()` —— 自定义激活

VoiceOver 用户双击时调用。当正常点击行为与无障碍操作不同时有用。

```swift
override func accessibilityActivate() -> Bool {
    // 显示展开的详情视图而非仅切换
    showDetailPanel()
    return true  // true = 已处理，false = 传递给正常点击处理
}
```

---

## NSAttributedString 无障碍属性

为富文本应用逐字符无障碍属性。

```swift
let string = NSMutableAttributedString(string: "Error: Invalid password")
string.addAttributes([
    .accessibilitySpeechPitch: 0.5,               // 更低音调
    .accessibilitySpeechQueueAnnouncement: true,   // 排队，不打断
    .accessibilitySpeechSpellOut: false,
    .accessibilitySpeechLanguage: "en-US"
], range: NSRange(location: 0, length: string.length))

label.attributedText = string
```

---

## 常见错误

| 错误 | 修复 |
|---|---|
| 容器 `isAccessibilityElement = true` 同时设置 `accessibilityElements` | 在暴露子元素的容器上设置 `isAccessibilityElement = false` |
| `accessibilityFrame` 使用本地坐标 | 始终转换：`UIAccessibility.convertToScreenCoordinates(rect, in: view)` |
| 忘记使缓存的 `accessibilityElements` 失效 | 数据变化时清空缓存并发送 `.layoutChanged` |
| `.adjustable` 特质缺少 `accessibilityIncrement`/`Decrement` | `.adjustable` 特质需要两个方法 |
| 自定义模态无 `accessibilityPerformEscape()` | 实现以支持双指 Z 手势和 Escape 键 |
| 部分更新使用 `notification: .screenChanged` | 部分更新用 `.layoutChanged`；整屏替换用 `.screenChanged` |
| `accessibilityViewIsModal` 设置在错误视图上 | 设置在最外层模态视图上，而非子视图 |
| 异步状态变化后无播报 | 网络/异步操作完成后发送 `.layoutChanged` 或 `.announcement` |
| 布局变化后 `UIAccessibilityElement` 中的标签未更新 | 边界变化时重建元素数组并清空缓存 |
