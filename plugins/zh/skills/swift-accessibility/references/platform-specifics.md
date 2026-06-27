# 平台特定无障碍

无障碍 API 和行为在支持平台间有所不同。本参考覆盖 macOS、watchOS、tvOS 和 visionOS——行为偏离 iOS 模式的地方。

## 目录
- [macOS](#macos)
- [watchOS](#watchos)
- [tvOS](#tvos)
- [visionOS](#visionos)
- [跨平台条件代码](#跨平台条件代码)
- [常见跨平台错误](#常见跨平台错误)

---

## macOS

### NSAccessibility vs UIAccessibility

macOS 使用 `NSAccessibility`（AppKit）而非 `UIAccessibility`。SwiftUI 自动处理大多数情况，但 AppKit 代码需要显式 NSAccessibility 工作。

### NSAccessibility 协议

```swift
import AppKit

class CustomControl: NSView {
    // 必需：声明此元素是什么
    override func accessibilityRole() -> NSAccessibility.Role? {
        return .button
    }

    override func accessibilityLabel() -> String? {
        return "Share Document"
    }

    override func accessibilityHelp() -> String? {
        return "Shares the current document with other users."
    }

    override func isAccessibilityEnabled() -> Bool {
        return isEnabled
    }

    override func isAccessibilityElement() -> Bool {
        return true
    }

    override func accessibilityPerformPress() -> Bool {
        // 处理 VoiceOver 激活（Space/Return 键）
        performAction()
        return true
    }
}
```

### NSAccessibility 角色参考

| 角色 | `NSAccessibility.Role` | 使用时机 |
|---|---|---|
| Button | `.button` | 可点击控件 |
| Checkbox | `.checkBox` | 双态开关 |
| Radio button | `.radioButton` | 互斥选项 |
| Text field | `.textField` | 可编辑文字 |
| Static text | `.staticText` | 非交互标签 |
| Slider | `.slider` | 范围控件 |
| Progress indicator | `.progressIndicator` | 加载/进度 |
| Table | `.table` | 表格数据 |
| List | `.list` | 项目列表 |
| Group | `.group` | 容器 |
| Toolbar | `.toolbar` | 工具栏 |
| Menu | `.menu` | 菜单 |
| Window | `.window` | 窗口 |

### macOS 上的自定义操作

```swift
class InteractiveRow: NSView {
    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        return [
            NSAccessibilityCustomAction(name: "Reply", target: self, selector: #selector(reply)),
            NSAccessibilityCustomAction(name: "Archive", target: self, selector: #selector(archive)),
            NSAccessibilityCustomAction(name: "Delete") { [weak self] in
                self?.delete()
                return true
            }
        ]
    }
}
```

### NSAccessibilityElement（自定义元素）

用于自定义绘制内容（Core Graphics、Metal）：

```swift
class ChartView: NSView {
    var bars: [BarData] = []

    override func isAccessibilityElement() -> Bool { false }

    override func accessibilityChildren() -> [Any]? {
        return bars.enumerated().map { index, bar in
            let element = NSAccessibilityElement()
            element.setAccessibilityRole(.staticText)
            element.setAccessibilityFrame(convert(frameForBar(at: index), to: nil))
            element.setAccessibilityLabel(bar.label)
            element.setAccessibilityValue(bar.value)
            element.setAccessibilityParent(self)
            return element
        }
    }
}
```

### macOS 上的自定义转子

```swift
class DocumentViewController: NSViewController, NSAccessibilityCustomRotorItemSearchDelegate {
    var headingViews: [NSView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        let rotor = NSAccessibilityCustomRotor(label: "Headings", itemSearchDelegate: self)
        view.setAccessibilityCustomRotors([rotor])
    }

    func rotor(_ rotor: NSAccessibilityCustomRotor, resultFor searchParameters: NSAccessibilityCustomRotor.SearchParameters) -> NSAccessibilityCustomRotor.ItemResult? {
        // 根据 searchParameters.searchDirection 在 headingViews 中导航
        // 该方向无更多标题时返回 nil
        return nil
    }
}
```

### macOS 上的 VoiceOver 差异

在 macOS 上，VoiceOver 使用**光标**模型（而非滑动模型）：
- VoiceOver 光标通过 Tab、方向键和 VO+方向键在元素间移动
- 键盘快捷键与 iOS 滑动手势不同
- QuickNav 模式（VO+Q）让用户无需按住 VO 键即可导航
- Web 内容使用与 Safari 相同的 VoiceOver 手势

**键盘导航在 macOS 上是一等公民。** 每个交互元素必须可通过 Tab 到达并通过 Space/Return 激活。

### 焦点环

macOS 在当前聚焦元素周围显示焦点环。NSView 为标准控件默认提供此功能。

```swift
// 自定义视图——手动绘制焦点环
class FocusableView: NSView {
    override var focusRingType: NSFocusRingType {
        get { .default }
        set { }
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }
}
```

### Mac Catalyst

Mac Catalyst 应用使用 UIKit API 但在 macOS 上运行。大多数 UIAccessibility API 直接工作。显著差异：
- `UIFocusSystem` 在 Catalyst 中自动启用键盘导航
- Mac 上 Full Keyboard Access 始终活跃
- 指针/悬停事件与触摸不同——测试悬停状态
- 自定义视图的 `NSCursor` 管理

---

## watchOS

### watchOS 上的 VoiceOver

watchOS VoiceOver 交互模型：
- **点击**元素选择
- **双击**激活
- **上下滑动**导航（不像 iOS 的左右滑动）
- **Digital Crown** 旋转改变可调元素的值

```swift
// watchOS VoiceOver 使用标准 SwiftUI 修饰符
// accessibilityLabel, accessibilityHint, accessibilityValue 等
Button("Start Workout") { startWorkout() }
    .accessibilityLabel("Start running workout")
    .accessibilityHint("Begins tracking your run")
```

### Digital Crown 无障碍

```swift
// ✅ 支持可调控件的 Digital Crown
struct VolumeControl: View {
    @State private var volume = 0.5

    var body: some View {
        Slider(value: $volume, in: 0...1)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int(volume * 100)) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: volume = min(1, volume + 0.1)
                case .decrement: volume = max(0, volume - 0.1)
                @unknown default: break
                }
            }
            .focusable()
            .digitalCrownRotation($volume, from: 0, through: 1, sensitivity: .medium)
    }
}
```

### Reduce Motion（watchOS）

```swift
import WatchKit

// isReduceMotionEnabled 的 watchOS 等价
if WKAccessibilityIsReduceMotionEnabled() {
    // 禁用动画
}

// 观察变化
NotificationCenter.default.addObserver(
    forName: NSNotification.Name(rawValue: WKAccessibilityReduceMotionStatusDidChange),
    object: nil,
    queue: .main
) { _ in
    updateAnimationPreferences()
}
```

### 小屏幕注意事项

watchOS 屏幕小——测试 Dynamic Type 尤为重要：

```swift
// watchOS 最低：支持 140% 缩放（不像 iOS 的 200%）
// 始终测试：
#Preview {
    MyWatchView()
        .environment(\.dynamicTypeSize, .xxLarge)  // watchOS 常用最大值
}
```

### 复杂功能和应用快捷方式

复杂功能应有描述性标签。watchOS 复杂功能无障碍使用系统无障碍：

```swift
// 复杂功能由 VoiceOver 使用其 accessibilityLabel 朗读
// 确保 widget/复杂功能文字在无视觉上下文时有意义
```

---

## tvOS

### 焦点引擎

tvOS **没有指针和触摸**——所有导航使用 Siri Remote 方向键和焦点引擎。

每个交互元素必须：
1. 可聚焦（`canBecomeFocused` 返回 `true`）
2. 显示清晰的视觉焦点状态
3. 响应 Select 按钮（Return 键等价）
4. 处理 Menu 按钮（= 返回/退出）

### 使自定义视图可聚焦

```swift
// UIKit (tvOS)
class FocusableCardView: UIView {
    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(
        in context: UIFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator
    ) {
        if context.nextFocusedView === self {
            coordinator.addCoordinatedAnimations {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.layer.shadowOpacity = 0.5
                self.layer.shadowRadius = 12
            }
        } else if context.previouslyFocusedView === self {
            coordinator.addCoordinatedAnimations {
                self.transform = .identity
                self.layer.shadowOpacity = 0
            }
        }
    }
}
```

### 设置默认焦点

```swift
// UIKit —— 返回应首先接收焦点的元素
override var preferredFocusEnvironments: [UIFocusEnvironment] {
    return [primaryContentButton]
}

// 已弃用——使用上面的 preferredFocusEnvironments
override weak var preferredFocusedView: UIView? { primaryContentButton }
```

### UIFocusGuide —— 桥接焦点间隙

当方向导航留下间隙（两行按钮之间的空白）时，使用 `UIFocusGuide` 重定向焦点：

```swift
let focusGuide = UIFocusGuide()
view.addLayoutGuide(focusGuide)

// 从左按钮导航时引导将焦点重定向到右按钮
focusGuide.preferredFocusEnvironments = [rightButton]

NSLayoutConstraint.activate([
    focusGuide.leadingAnchor.constraint(equalTo: leftButton.trailingAnchor),
    focusGuide.trailingAnchor.constraint(equalTo: rightButton.leadingAnchor),
    focusGuide.topAnchor.constraint(equalTo: leftButton.topAnchor),
    focusGuide.bottomAnchor.constraint(equalTo: leftButton.bottomAnchor)
])
```

### tvOS 上的 SwiftUI

```swift
// SwiftUI Button 在 tvOS 上默认可聚焦
Button("Play") { play() }
    .buttonStyle(.card)  // tvOS 卡片样式带抬起动画

// 对非按钮交互视图使用 focusable()
CustomCardView()
    .focusable()
    .onMoveCommand { direction in
        // 处理视图内的方向键导航
        switch direction {
        case .up: navigateUp()
        case .down: navigateDown()
        case .left: navigateLeft()
        case .right: navigateRight()
        }
    }
```

### tvOS 上的 VoiceOver

tvOS VoiceOver 与 iOS 类似但使用 Siri Remote 手势：
- 在触摸面上滑动导航
- 点击激活聚焦元素
- 所有标准 `accessibilityLabel`、`accessibilityHint`、`accessibilityAction` API 适用

### Menu 按钮 = Escape

Siri Remote Menu 按钮是返回/退出操作。在自定义视图控制器上实现 `accessibilityPerformEscape()`：

```swift
override func accessibilityPerformEscape() -> Bool {
    navigationController?.popViewController(animated: true)
    return true
}
```

### 调试焦点

```
Simulator: Debug 菜单 → View → Show Focus for Focus Engine Debug
```

---

## visionOS

### 空间计算中的无障碍

visionOS 混合使用眼动追踪、手势和语音输入。visionOS 上的 VoiceOver 使用注视 + 捏合导航。

### SwiftUI —— 标准修饰符工作

标准 SwiftUI 无障碍修饰符（`.accessibilityLabel`、`.accessibilityHint`、特质、操作）直接适用于 visionOS：

```swift
// ✅ 在 visionOS 上工作
RealityView { content in
    // 3D 内容
}
.accessibilityLabel("3D Model: Red Cube")
.accessibilityHint("Pinch to interact")
.accessibilityAddTraits(.isButton)
```

### RealityKit —— AccessibilityComponent

对于 RealityKit 中的 3D 实体，使用 `AccessibilityComponent`：

```swift
import RealityKit

// 为 3D 实体添加无障碍信息
var accessibilityComponent = AccessibilityComponent()
accessibilityComponent.label = "Spinning Globe"
accessibilityComponent.value = "Currently rotating"
accessibilityComponent.isAccessibilityElement = true
accessibilityComponent.traits = [.isButton]
accessibilityComponent.customActions = [
    AccessibilityCustomAction(name: "Stop rotation") { entity in
        entity.components.remove(RotationComponent.self)
        return true
    }
]
myGlobeEntity.components.set(accessibilityComponent)
```

### 悬停效果

visionOS 元素在用户注视时高亮。对于自定义交互视图：

```swift
// ✅ 标准悬停效果——交互元素必需
MyView()
    .hoverEffect(.lift)  // 或 .highlight

// 确保为基于注视的交互存在 VoiceOver 替代方案
MyView()
    .hoverEffect(.highlight)
    .accessibilityLabel("Interactive Panel")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { performAction() }
```

### visionOS 上的 Voice Control

visionOS 上的 Voice Control 工作方式与 iOS 类似。元素必须出现在"Show numbers"中并有匹配的"Show names"标签。`accessibilityInputLabels` 适用。

### visionOS 上的 VoiceOver 导航

- **注视**元素 → VoiceOver 朗读它
- **捏合**（食指 + 拇指）→ 激活聚焦元素
- **双捏合**→ 向后导航
- **滑动手势**→ 移到下一个/上一个元素（如 iOS）

所有标准无障碍修饰符适用。确保通过 `AccessibilityComponent` 的 3D 内容完整。

### 空间音频和无障碍

```swift
// 为空间音频应用使用 AVAudioSession
// .spokenAudio 模式在 visionOS 上支持
try? AVAudioSession.sharedInstance().setCategory(
    .playback,
    mode: .spokenAudio
)
```

---

## 跨平台条件代码

```swift
// 平台条件无障碍代码
var body: some View {
    MyView()
        .accessibilityLabel("Chart")
#if os(macOS)
        // macOS：附加键盘快捷键提示
        .accessibilityHint("Press Space to toggle data view")
#elseif os(tvOS)
        // tvOS：焦点反馈说明
        .accessibilityHint("Press Select to expand")
#else
        // iOS/iPadOS/visionOS：滑动提示
        .accessibilityHint("Double-tap to expand")
#endif
}
```

### 共享无障碍逻辑

```swift
// 协议抽象平台差异
protocol AccessibilityProvider {
    var accessibilityName: String { get }
    var accessibilityDescription: String? { get }
}

// 在所有平台上工作的共享扩展
extension View {
    func applyAccessibility(from provider: AccessibilityProvider) -> some View {
        self
            .accessibilityLabel(provider.accessibilityName)
            .accessibilityHint(provider.accessibilityDescription ?? "")
    }
}
```

---

## 常见跨平台错误

| 错误 | 平台 | 修复 |
|---|---|---|
| 在 macOS/AppKit target 中使用 `UIAccessibility` | macOS | 改用 `NSAccessibility` 协议 |
| tvOS 自定义视图无焦点动画 | tvOS | 用 `coordinator.addCoordinatedAnimations` 实现 `didUpdateFocus` |
| tvOS 自定义视图无 `canBecomeFocused` 重写 | tvOS | 重写 `canBecomeFocused` 返回 `true` |
| 假设 iOS 滑动手势在 watchOS 上工作 | watchOS | watchOS 使用点击/双击/Crown，而非 VoiceOver 的滑动 |
| RealityKit 实体缺少 `AccessibilityComponent` | visionOS | 添加带标签、特质和操作的 `AccessibilityComponent` |
| Mac Catalyst 模态中焦点捕获不工作 | macOS (Catalyst) | 设置 `accessibilityViewIsModal = true`——与 UIKit 相同 |
| 未检查 WKAccessibilityIsReduceMotionEnabled | watchOS | 使用 WatchKit 函数，而非 `UIAccessibility.isReduceMotionEnabled` |
| 悬停效果无无障碍替代方案 | visionOS | 添加 `accessibilityLabel` + `accessibilityAddTraits(.isButton)` |
