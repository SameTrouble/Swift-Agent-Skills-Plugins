# VoiceOver — UIKit

VoiceOver 无障碍的 UIKit 实现。

如需核心概念，请参阅 `voiceover.md`。

## 目录

- [标签](#标签)
- [值](#值)
- [提示](#提示)
- [特质](#特质)
- [可调节控件](#可调节控件)
- [分组](#分组)
- [自定义操作](#自定义操作)
- [无障碍自定义内容](#无障碍自定义内容)
- [手势](#手势)
- [通知](#通知)
- [模态视图](#模态视图)
- [高级 API](#accessibility-frame)
- [示例](#示例完整表格单元格)

## 标签

### 基本标签

```swift
closeButton.accessibilityLabel = "Close"
```

### 用于发音的属性标签

在标签中间切换语言：
当我们知道语言时使用。一些用例示例：语言学习应用、不同语言的歌词...

```swift
let label = NSMutableAttributedString(
    string: "¡Hola! ",
    attributes: [.accessibilitySpeechLanguage: "es-ES"]
)
label.append(NSAttributedString(string: "means Hello!"))
view.accessibilityAttributedLabel = label
```

IPA 发音：
作为最后手段使用。用户倾向于习惯屏幕阅读器的怪异发音。用例示例：纠正品牌名称的发音

```swift
let label = NSMutableAttributedString(string: "Watch ")
label.append(NSAttributedString(
    string: "live",
    attributes: [.accessibilitySpeechIPANotation: "laɪv"]
))
view.accessibilityAttributedLabel = label
```

逐字拼读：
用例示例：代码、电话号码... 在逐字宣布内容有意义时使用。一些开发者用空格分隔字符来实现这一点（C O O L E E A R 5 2 3）。这是一种反模式，因为它会给盲文读者造成不必要的冗余。

```swift
let label = NSAttributedString(
    string: "COOLEEAR523",
    attributes: [.accessibilitySpeechSpellOut: true]
)
view.accessibilityAttributedLabel = label
```

朗读标点：
用例示例：宣布一段编程代码的所有字符、语法应用中的示例...

```swift
let label = NSAttributedString(
    string: "let greeting = \"Hello, world!\"; print(greeting)",
    attributes: [.accessibilitySpeechPunctuation: true]
)
view.accessibilityAttributedLabel = label
```

### 标签：关键规则

- **上下文但不冗余**：提供足够的上下文来理解元素，但避免重复 VoiceOver 已说的内容（例如特质）。不要在按钮的标签中添加"button"——VoiceOver 已经说"Button"了。
- **本地化**：使用 `NSLocalizedString` 以便标签在所有支持的语言中工作。
- **状态变化时更新**：如果元素的含义变化（例如关注按钮变为取消关注），立即更新标签。
- **避免同一视图中的冗余**：如果 VoiceOver 会读取标题而下面的按钮已经引用了该上下文，则无需重复。

```swift
// 状态变化：标签必须反映当前状态
followButton.accessibilityLabel = isFollowing
    ? NSLocalizedString("Unfollow", comment: "")
    : NSLocalizedString("Follow", comment: "")

// 上下文敏感的添加按钮 — 通用 vs 特定
addButton.accessibilityLabel = NSLocalizedString("Add song", comment: "")
// 不是在模糊时仅用"Add"

// 在播放器中避免冗余 — 上下文已清楚
playButton.accessibilityLabel = "Play"     // ✅
playButton.accessibilityLabel = "Play song" // ❌ 在音乐播放器中冗余
```

### 用于可读标签的格式化器

缩写时，尽可能使用内置格式化器和样式

```swift
// 时长
let formatter = DateComponentsFormatter()
formatter.unitsStyle = .spellOut
formatter.allowedUnits = [.hour, .minute]
durationLabel.accessibilityLabel = formatter.string(from: 3660)
// "1 hour, 1 minute"

// 度量
let measurement = Measurement<UnitLength>(value: 42, unit: .kilometers)
let measureFormatter = MeasurementFormatter()
measureFormatter.unitStyle = .long
distanceLabel.accessibilityLabel = measureFormatter.string(from: measurement)
// "42 kilometers"
```

### 组合复杂标签

从多条复杂信息组合标签时有用。

```swift
let components: [String?] = [title, verifiedBadge, date, text, altText]
let accessibilityLabel = components
    .compactMap { $0 }
    .filter { !$0.isEmpty }
    .joined(separator: ", ")
cell.accessibilityLabel = accessibilityLabel
```

### 无障碍值模式

当组件有可变状态时，使用值而非标签（见下一节）。示例：徽章显示计数，使用标签 + 值：

```swift
// 之前：徽章标签变化或仅是数字
numberOfItemsLabel.accessibilityLabel = "\(count)"

// 之后：一致标签带动态值
orderButton.accessibilityLabel = "Cart"
orderButton.accessibilityValue = count > 0 ? "\(count) items" : nil
numberOfItemsLabel.isAccessibilityElement = false  // 隐藏徽章
```

## 值

`UISlider` 的默认值是百分比。这对于音量控件可以，但对于价格范围或播放进度条则不行。始终使用对用户最有意义的格式：

```swift
// 音量：百分比有意义
slider.accessibilityValue = "\(Int(slider.value * 100)) percent"

// 价格范围：说实际价格，而非百分比
let formatter = NumberFormatter()
formatter.numberStyle = .currency
priceSlider.accessibilityValue = formatter.string(from: NSNumber(value: priceSlider.value))
// VoiceOver 说"£450,000"而非"50%"

// 播放进度：说分钟和秒
let formatter = DateComponentsFormatter()
formatter.unitsStyle = .full
formatter.allowedUnits = [.minute, .second]
playbackSlider.accessibilityValue = formatter.string(from: TimeInterval(playbackSlider.value))
// VoiceOver 说"2 minutes, 30 seconds"而非"25%"

toggle.accessibilityValue = toggle.isOn ? "On" : "Off"
```

状态变化时更新值：

```swift
var rating: Int = 0 {
    didSet {
        accessibilityValue = "\(rating + 1) thumbs up"
    }
}
```

对于可重用组件，你也可以重写值：

```swift
final class RatingView: UIView {
    var rating: Int = 0

    override var accessibilityValue: String? {
        get { "\(rating + 1) thumbs up" }
        set {}
    }
}
```

## 提示

提示是**可选的**，会在暂停后朗读——在标签、特质和值之后。有经验的用户可以跳过它们，所以提示不会减慢高级用户。当元素的用途或交互不显而易见时使用；当标签已经讲述了完整故事时跳过。

**经验法则：**
- 以动词开头 — 描述*会发生什么*，而非元素*是什么*
- 不要在提示中重复标签或特质
- 像标签一样本地化
- 保持简洁

```swift
// 好：以动词开头，添加上下文
draggableHandle.accessibilityHint = NSLocalizedString(
    "Double tap and hold, wait for the sound, then drag to rearrange.",
    comment: ""
)

// 好：解释非显而易见的交互
miniPlayer.accessibilityHint = NSLocalizedString(
    "Double tap to expand to full screen.",
    comment: ""
)

// 需要上下文的自定义控件
accessibilityHint = "Rates your drink from 1 to 5 thumbs up"

// 带额外上下文的标准控件
deleteButton.accessibilityHint = "Removes the item from your list"
```

避免仅重述显而易见内容的提示：

```swift
// 坏：VoiceOver 已说"Button"
playButton.accessibilityHint = "Tap to play"  // ❌

// 好：添加真正的上下文
playButton.accessibilityHint = "Plays the episode from the beginning" // ✅
```

## 特质

### 标题特质

标记章节标题以用于转子导航：

```swift
sectionHeader.accessibilityTraits.insert(.header)
```

### 选中特质

用于自定义选择器选项、切换状态和分段控件：

```swift
var isToggled: Bool = false {
    didSet {
        if isToggled {
            selectionIconImageView.image = UIImage(systemName: "checkmark.circle.fill")
            accessibilityTraits.insert(.selected)
        } else {
            selectionIconImageView.image = UIImage(systemName: "circle")
            accessibilityTraits.remove(.selected)
        }
    }
}
```

### 常见操作

优先添加/移除特质，而非完全重新分配。

```swift
// 单个特质
sectionTitle.accessibilityTraits = .header

// 多个特质
cell.accessibilityTraits = [.button, .selected]

// 添加特质
button.accessibilityTraits.insert(.notEnabled)

// 移除特质
button.accessibilityTraits.remove(.selected)
```

## 可调节控件

对于自定义滑块、步进器、选择器 — 分组并设为可调节：

```swift
// 之前：难以理解的独立按钮
class ExtraShotsView: UIView {
    @IBOutlet private weak var removeShotButton: UIButton!
    @IBOutlet private weak var addShotButton: UIButton!
    @IBOutlet private weak var numberOfShotsLabel: UILabel!
}

// 之后：单个可调节控件
class ExtraShotsView: UIView {
    private var numberOfShots = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        isAccessibilityElement = true
        accessibilityLabel = "Extra shots"
        accessibilityTraits.insert(.adjustable)
    }

    override func accessibilityIncrement() {
        guard numberOfShots < 4 else { return }
        numberOfShots += 1
        updateAccessibilityValue()
    }

    override func accessibilityDecrement() {
        guard numberOfShots > 0 else { return }
        numberOfShots -= 1
        updateAccessibilityValue()
    }
    
    private func updateAccessibilityValue() {
        accessibilityValue = "\(numberOfShots) shots"
    }
}
```

### 评分控件示例

```swift
class RaterView: UIView {
    private var maxRate: UInt = 5
    
    // 用 Dynamic Type 缩放图标
    private var icon = UIImage(
        systemName: "hand.thumbsup",
        withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
    )
    
    var rating: Int = 0 {
        didSet {
            accessibilityValue = "\(rating + 1) thumbs up"
        }
    }

    private func setUp() {
        // 分组为单个元素
        isAccessibilityElement = true
        accessibilityLabel = "Rating"
        accessibilityTraits = .adjustable
        accessibilityHint = "Rates your drink from 1 to 5 thumbs up"
    }

    override func accessibilityIncrement() {
        guard rating < maxRate - 1 else { return }
        pressButton(at: rating + 1)
    }

    override func accessibilityDecrement() {
        guard rating > 0 else { return }
        pressButton(at: rating - 1)
    }
}
```

## 分组

### 使容器成为无障碍元素

当单元格有多个元素时，分组以便于导航。确保组中的交互元素在其他地方单独可访问，例如详情屏幕。

```swift
// 之前：VoiceOver 分别读取标签、价格、按钮
final class DrinkTableViewCell: UITableViewCell {
    @IBOutlet private weak var drinkNameLabel: UILabel!
    @IBOutlet private weak var priceLabel: UILabel!
    @IBOutlet private weak var buyButton: UIButton!
}

// 之后：单个分组元素
final class DrinkTableViewCell: UITableViewCell {
    override func awakeFromNib() {
        super.awakeFromNib()
        
        isAccessibilityElement = true
        accessibilityTraits.insert(.button)
    }
    
    override var accessibilityLabel: String? {
        get {
            [drinkNameLabel.accessibilityLabel, priceLabel.accessibilityLabel]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
        set {}
    }
}
```

### 不合并的分组遍历

当你希望 VoiceOver 在移动到组外元素之前作为组遍历容器的子元素时使用。这不会将子元素合并为一个元素。

```swift
containerView.shouldGroupAccessibilityChildren = true
```

### 显式元素顺序

```swift
view.accessibilityElements = [playButton, shareButton, moreOptionsButton]
```

### 配对相关标签（列）

当视觉布局使用列时（例如标签 + 值），配对分组以便 VoiceOver 一起读取：

```swift
// 当你有真实子视图/行时优先：
followersRow.isAccessibilityElement = true
followersRow.accessibilityLabel = "Followers"
followersRow.accessibilityValue = "550"

followingRow.isAccessibilityElement = true
followingRow.accessibilityLabel = "Following"
followingRow.accessibilityValue = "340"

postsRow.isAccessibilityElement = true
postsRow.accessibilityLabel = "Posts"
postsRow.accessibilityValue = "750"

statsStackView.shouldGroupAccessibilityChildren = true

// 对于自定义绘制内容，构建显式无障碍元素：
let followersElement = UIAccessibilityElement(accessibilityContainer: statsView)
followersElement.accessibilityLabel = "Followers"
followersElement.accessibilityValue = "550"
followersElement.accessibilityFrameInContainerSpace = followersFrame

let followingElement = UIAccessibilityElement(accessibilityContainer: statsView)
followingElement.accessibilityLabel = "Following"
followingElement.accessibilityValue = "340"
followingElement.accessibilityFrameInContainerSpace = followingFrame

let postsElement = UIAccessibilityElement(accessibilityContainer: statsView)
postsElement.accessibilityLabel = "Posts"
postsElement.accessibilityValue = "750"
postsElement.accessibilityFrameInContainerSpace = postsFrame

statsView.accessibilityElements = [followersElement, followingElement, postsElement]
```

### 从 VoiceOver 隐藏

```swift
// 单个元素
decorativeImage.isAccessibilityElement = false

// 整个子树
backgroundView.accessibilityElementsHidden = true
```

## 自定义操作

暴露隐藏或次要操作：

```swift
// 之前：单元格内的购买按钮在单元格分组时无法直接到达

// 之后：作为自定义操作暴露
override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
    get {
        [
            UIAccessibilityCustomAction(
                name: "Add to cart",
                image: UIImage(systemName: "cart.badge.plus")
            ) { [weak self] _ in
                self?.buyDrink()
                return true
            }
        ]
    }
    set {}
}
```

### 带图像的多个操作

图像出现在 Switch Control 菜单中（iOS 14+），使用 [`UIAccessibilityCustomAction.init(name:image:actionHandler:)`](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction/init(name:image:actionhandler:))：

```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Delete") { _ in
        self.deleteItem()
        return true
    },
    UIAccessibilityCustomAction(
        name: "Share",
        image: UIImage(systemName: "square.and.arrow.up")
    ) { _ in
        self.shareItem()
        return true
    }
]
```

## 无障碍自定义内容

用于数据丰富 UI 中的补充信息（例如图表、金融卡片、高级统计）。

保持此内容可选且简洁：用户可以配置 VoiceOver 详细程度，因此关于额外内容的提示可能被减少或禁用。
尽可能使相同的信息在其他地方也独立可访问（例如在详情屏幕中）。

```swift
let trend = UIAccessibilityCustomContent(
    label: "Trend",
    value: "Upward over last 30 days"
)
trend.importance = .default

let confidence = UIAccessibilityCustomContent(
    label: "Confidence",
    value: "High"
)
confidence.importance = .high

summaryCard.accessibilityCustomContent = [trend, confidence]
```

仅在上下文中必不可少的数据使用 `.high`。

## 手势

### 双击激活

仅在视图尚不支持此功能时需要，例如带有手势识别器的视图内的自定义组件以激活它

```swift
override func accessibilityActivate() -> Bool {
    performMainAction()
    return true
}
```

### 激活点

默认情况下，VoiceOver 激活聚焦元素的中心。对于自定义绘制控件或不规则的点击区域，在屏幕坐标中设置 `accessibilityActivationPoint`：

```swift
let pointInView = CGPoint(x: knobFrame.midX, y: knobFrame.midY)
customControl.accessibilityActivationPoint = customControl.convert(pointInView, to: nil)
```

### Magic Tap

用于屏幕的主要功能。面向高级用户。示例：启动/停止计时器、播放/暂停游戏...

```swift
override func accessibilityPerformMagicTap() -> Bool {
    togglePlayPause()
    return true
}
```

### Escape

面向高级用户的手势，意思是：返回。仅用于自定义模态和覆盖层。

```swift
override func accessibilityPerformEscape() -> Bool {
    dismiss(animated: true)
    return true
}
```

### 实时交互的直接触摸

对于快速、连续的交互（例如音乐应用、绘图画布和某些游戏控件），直接触摸可以减少摩擦：

```swift
joystickView.isAccessibilityElement = true
joystickView.accessibilityTraits.insert(.allowsDirectInteraction)
```

谨慎使用。除非交互真正依赖于实时触摸移动，否则优先使用常规 VoiceOver 导航。

## 检测辅助技术

谨慎使用这些检查。大多数无障碍改进应是无条件的——不要仅为启用了特定技术的用户保留良好体验。也就是说，有合理的用例：

- 将通常是临时的 UI 元素适配为对 VoiceOver 用户持久
- 在防护后优化昂贵的标签/操作构建（例如在大型列表中）
- 协调特定于一种辅助技术的行为

```swift
// 在某个时间点检查状态
if UIAccessibility.isVoiceOverRunning {
    // 例如，保持工具提示可见
}

if UIAccessibility.isSwitchControlRunning {
    // 例如，也为 Switch Control 构建自定义操作
}
```

始终也观察变化——用户可能在使用的应用时启用或禁用辅助技术：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(voiceOverDidChange),
    name: UIAccessibility.voiceOverStatusDidChangeNotification,
    object: nil
)

@objc private func voiceOverDidChange() {
    if UIAccessibility.isVoiceOverRunning {
        // 更新 UI
    }
}
```

> **先问自己：** 我能否让这个元素始终可访问，以便所有用户都受益？自定义操作、适当的标签和持久反馈对每个人都有好处。

## 通知

### 移动焦点

```swift
// 重大屏幕变化（播放声音）
UIAccessibility.post(notification: .screenChanged, argument: newView)

// 内容更新（无声音）
UIAccessibility.post(notification: .layoutChanged, argument: errorLabel)
```

### 公告消息

用于临时反馈。示例：toast

```swift
// 之前：toast 短暂出现，VoiceOver 用户错过它

// 之后：以高优先级公告
func present(inView view: UIView) {
    guard let text = toastTitleLabel.text else { return }
    
    UIView.animate(withDuration: 0.2) { self.alpha = 1.0 } completion: { _ in
        if #available(iOS 17, *) {
            var announcement = AttributedString(text)
            announcement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(announcement).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
        
        UIView.animate(withDuration: 0.2, delay: 3.0) { self.alpha = 0.0 }
    }
}
```

**注意：** Toast 对无障碍有挑战。尽可能考虑行内持久（或可通过用户交互关闭）的反馈替代方案。

### 队列公告

将 `.accessibilitySpeechQueueAnnouncement` 设为 `true` 以排队后续公告。为 false 时，正在进行的公告会被中断。
```swift
let first = NSAttributedString(
    string: "Downloaded file A.jpeg",
    attributes: [.accessibilitySpeechQueueAnnouncement: true]
)
let second = NSAttributedString(
    string: "Downloaded file B.jpeg",
    attributes: [.accessibilitySpeechQueueAnnouncement: true]
)

UIAccessibility.post(notification: .announcement, argument: first)
UIAccessibility.post(notification: .announcement, argument: second)
```

### 页面滚动

如果你代用户滚动，通知 VoiceOver：

```swift
scrollView.setContentOffset(newOffset, animated: true)
UIAccessibility.post(notification: .pageScrolled, argument: scrollView)
```

## 模态视图

仅用于应阻止与下方元素交互的自定义模态或覆盖层。

```swift
alertView.accessibilityViewIsModal = true
UIAccessibility.post(notification: .screenChanged, argument: alertView)
```

## Smart Invert

防止照片和有意义的图片反转：

```swift
drinkImageView.accessibilityIgnoresInvertColors = true
```

## Accessibility Frame

扩大焦点区域：

```swift
let expandedFrame = button.bounds.insetBy(dx: -20, dy: -20)
button.accessibilityFrame = button.convert(expandedFrame, to: nil)
```

## UIAccessibilityElement

用于跨视图层次结构的自定义绘制或分组：

```swift
let element = UIAccessibilityElement(accessibilityContainer: chartView)
element.accessibilityLabel = "Sales chart"
element.accessibilityFrame = chartView.convert(chartRect, to: nil)
element.accessibilityTraits = .image
chartView.accessibilityElements = [element]
```

## 容器类型

```swift
tabBar.accessibilityContainerType = .semanticGroup
tabBar.accessibilityLabel = "Tab bar"
```

## 示例：完整表格单元格

```swift
final class DrinkTableViewCell: UITableViewCell {
    @IBOutlet private weak var outerStackView: UIStackView!
    @IBOutlet private weak var drinkImageView: UIImageView!
    @IBOutlet private weak var drinkNameLabel: UILabel!
    @IBOutlet private weak var priceLabel: UILabel!
    
    private var drink: Drink?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Dynamic Type
        drinkNameLabel.font = .preferredFont(forTextStyle: .body)
        priceLabel.font = .preferredFont(forTextStyle: .body)
        
        // 对比度的语义颜色
        priceLabel.textColor = .secondaryLabel
        
        // 分组单元格
        isAccessibilityElement = true
        accessibilityTraits.insert(.button)
        
        // Smart Invert
        drinkImageView.accessibilityIgnoresInvertColors = true
        
        updateLayout()
    }
    
    override var accessibilityLabel: String? {
        get {
            [drinkNameLabel.accessibilityLabel, priceLabel.accessibilityLabel]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
        set {}
    }
    
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            [UIAccessibilityCustomAction(name: "Add to cart", target: self, selector: #selector(buyDrink))]
        }
        set {}
    }
    
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        if previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateLayout()
        }
    }
    
    private func updateLayout() {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            outerStackView.axis = .vertical
            drinkNameLabel.numberOfLines = 0
        } else {
            outerStackView.axis = .horizontal
            drinkNameLabel.numberOfLines = 1
        }
    }
}
```

## 示例：切换单元格（UISwitch + UITableViewCell）

非常常见的模式：带标题、可选副标题和切换的设置行。经典错误是将单元格和开关都留作独立的可访问元素，因此 VoiceOver 分别读取每一个，用户需要滑动两次才能交互。

使单元格本身成为镜像开关行为的单个可访问元素：

```swift
// 之后：单元格作为单个可访问切换
final class SwitchTableViewCell: UITableViewCell {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var settingSwitch: UISwitch!

    override func awakeFromNib() {
        super.awakeFromNib()
        // 单元格是可访问元素；开关是装饰性的
        isAccessibilityElement = true
        settingSwitch.isAccessibilityElement = false
    }

    // 组合标题 + 副标题作为上下文
    override var accessibilityLabel: String? {
        get {
            [titleLabel.text, subtitleLabel.text]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
        }
        set {}
    }

    // 镜像开关的特质（"switch button"）
    override var accessibilityTraits: UIAccessibilityTraits {
        get { settingSwitch.accessibilityTraits }
        set {}
    }

    // 镜像开关的值（"on" / "off"）
    override var accessibilityValue: String? {
        get { settingSwitch.accessibilityValue }
        set {}
    }

    // 双击切换开关
    override func accessibilityActivate() -> Bool {
        settingSwitch.isOn.toggle()
        settingSwitch.sendActions(for: .valueChanged)
        return true
    }
}
```

VoiceOver 现在读取：*"Enable notifications. On. Switch."* — 一个元素，清晰的状态，立即可操作。

> **常见错误：** 将单元格和开关都留作可访问元素意味着 VoiceOver 读取标签两次，用户需要导航过去冗余元素。

## 示例：表单错误（焦点，而非公告）

当更新与应接收焦点的可见元素（如行内表单错误）绑定时，使用 `.layoutChanged`。

```swift
func showError(_ message: String) {
    errorLabel.text = message
    errorLabel.isHidden = false
    UIAccessibility.post(notification: .layoutChanged, argument: errorLabel)
}
```

## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
- https://github.com/Apress/developing-accessible-iOS-apps
- https://github.com/dadederk/fromZeroToAccessible（Daniel Devesa Derksen-Staats 和 Rob Whitaker）
