# 运动和替代输入

覆盖通过直接触摸以外方式与设备交互的用户的无障碍：Switch Control、Full Keyboard Access、AssistiveTouch 和 Guided Access。

## 目录
- [触摸目标大小](#触摸目标大小)
- [Switch Control](#switch-control)
- [Full Keyboard Access (iOS / iPadOS)](#full-keyboard-access-ios--ipados)
- [tvOS 焦点引擎](#tvos-焦点引擎)
- [AssistiveTouch](#assistivetouch)
- [Guided Access](#guided-access)
- [常见模式清单](#常见模式清单)

---

## 触摸目标大小

所有交互元素的触摸目标必须至少为 **44×44 点**。小目标是 Nutrition Label 失败和常见的无障碍审计发现。

### SwiftUI

```swift
// ✅ contentShape 扩展点击区域而不改变视觉大小
Image(systemName: "heart")
    .font(.system(size: 20))
    .contentShape(Rectangle())
    .frame(minWidth: 44, minHeight: 44)

// ✅ 或者，使用 padding 扩展点击区域
Button { toggleFavorite() } label: {
    Image(systemName: "heart").font(.system(size: 20))
}
.padding(12)   // 扩展点击区域到约 44pt

// ❌ 视觉和点击区域都是 20×20
Image(systemName: "heart")
    .font(.system(size: 20))
    .onTapGesture { toggleFavorite() }
```

### UIKit

```swift
// 重写 pointInside 扩展点击区域
class LargeHitButton: UIButton {
    var hitAreaInsets = UIEdgeInsets(top: -12, left: -12, bottom: -12, right: -12)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitArea = bounds.inset(by: hitAreaInsets)
        return hitArea.contains(point)
    }
}

// 或重写 accessibilityFrame 报告更大区域
override var accessibilityFrame: CGRect {
    let frame = convert(bounds, to: nil)
    let minSize: CGFloat = 44
    let dX = max(0, (minSize - frame.width) / 2)
    let dY = max(0, (minSize - frame.height) / 2)
    return frame.insetBy(dx: -dX, dy: -dY)
}
```

---

## Switch Control

Switch Control 允许用户用一个或多个自适应开关导航（物理按钮、吸吹控制、声音输入）。项目按顺序高亮；用户激活开关选择高亮的元素。

### 导航工作原理

1. **项目扫描** —— 元素逐个高亮
2. **组扫描** —— 先高亮组，然后组内的单个项目
3. **点扫描** —— 十字线在屏幕上移动

开发者主要需要确保：
- 所有交互元素可达
- 操作不超时
- 复杂手势有开关可访问的替代方案

### 手势的自定义操作

任何滑动、长按或多点触控手势都必须有自定义操作替代方案。

```swift
// SwiftUI
FeedCard(post: post)
    .accessibilityAction(named: "Like") { like(post) }
    .accessibilityAction(named: "Comment") { showComment(post) }
    .accessibilityAction(named: "Share") { share(post) }
    .accessibilityAction(named: "Save") { save(post) }

// UIKit
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Like") { _ in self.like(post); return true },
    UIAccessibilityCustomAction(name: "Share") { _ in self.share(post); return true }
]
```

### 为高效扫描分组

使用 `shouldGroupAccessibilityChildren = true`（UIKit）或 `.accessibilityElement(children: .contain)`（SwiftUI）创建组。如果不相关，用户可以一次开关点击跳过整个组。

```swift
// SwiftUI —— 将侧边栏分组为一个单元
SidebarView()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Sidebar")

// UIKit
sidebarView.shouldGroupAccessibilityChildren = true
sidebarView.accessibilityLabel = "Sidebar"
```

### 检测 Switch Control

仅用于 UI 优化，永远不要用于分支核心逻辑。

```swift
if UIAccessibility.isSwitchControlRunning {
    // 简化动画，增加点击目标反馈
}
```

### 限时交互

永远不要要求交互在固定时间窗口内完成。Switch Control 用户的操作速度明显慢于直接触摸。

```swift
// ❌ 3 秒后自动前进——不可访问
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    self.advanceToNextStep()
}

// ✅ 要求显式用户操作
Button("Next Step") { advanceToNextStep() }
```

---

## Full Keyboard Access (iOS / iPadOS)

Full Keyboard Access（Settings → Accessibility → Keyboards → Full Keyboard Access）允许使用硬件键盘完整导航。对 iPad 用户和 Mac Catalyst 应用必不可少。

### 工作原理

- **Tab** —— 向前移动焦点
- **Shift+Tab** —— 向后移动焦点
- **Space / Return** —— 激活聚焦元素
- **Escape** —— 关闭模态/取消
- **方向键** —— 在组件内导航（选择器、滑块）

### 所有元素必须可键盘聚焦

原生 SwiftUI 和 UIKit 控件默认可键盘访问。自定义交互视图需要显式启用。

```swift
// SwiftUI —— 自定义可点击视图需要是 Button 或使用 .accessibilityAddTraits(.isButton)
// 使用 onTapGesture 的非 Button 视图可能无法接收键盘焦点

// ✅ Button 自动接收键盘焦点
Button("Open Settings") { openSettings() }

// ⚠️ 自定义视图——显式测试键盘导航
CustomTileView()
    .accessibilityAddTraits(.isButton)
    .onTapGesture { handleTap() }
    // 可能无法接收键盘焦点——优先使用 Button
```

### 检测 Full Keyboard Access

```swift
if UIAccessibility.isFullKeyboardAccessEnabled {
    // 在 UI 中显示键盘快捷键提示
}
```

### 通过 Escape 关闭模态

每个模态、sheet、popover 和 alert 都必须能用 Escape 键关闭。

```swift
// SwiftUI —— 使用 .sheet() 时 sheet 通过 Escape 自动关闭
.sheet(isPresented: $showSettings) {
    SettingsView()
}

// UIKit 自定义模态——实现 accessibilityPerformEscape
class CustomModalViewController: UIViewController {
    override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }
}
```

### 焦点引导 —— 桥接焦点间隙

当键盘焦点无法自然到达屏幕某个区域时（例如浮动按钮与其他内容重叠），使用 `UIFocusGuide` 重定向焦点。

```swift
// UIKit
let focusGuide = UIFocusGuide()
view.addLayoutGuide(focusGuide)
focusGuide.preferredFocusEnvironments = [floatingButton]

// 将引导约束为填充间隙区域
NSLayoutConstraint.activate([
    focusGuide.topAnchor.constraint(equalTo: gapArea.topAnchor),
    focusGuide.leadingAnchor.constraint(equalTo: gapArea.leadingAnchor),
    focusGuide.trailingAnchor.constraint(equalTo: gapArea.trailingAnchor),
    focusGuide.bottomAnchor.constraint(equalTo: gapArea.bottomAnchor)
])
```

### `accessibilityRespondsToUserInteraction(_:)`（SwiftUI, iOS 17+）

将视图标记为可交互以用于键盘焦点。

```swift
CustomInteractiveView()
    .accessibilityRespondsToUserInteraction(true)
```

---

## tvOS 焦点引擎

在 tvOS 上，Siri Remote 完全通过**焦点引擎**导航。没有指针；UI 元素在接收焦点时高亮。

### 焦点基础

- 每个可聚焦视图必须实现 `canBecomeFocused` 或使用原生可聚焦控件
- 焦点使用 Siri Remote 方向键在元素之间移动
- Menu 按钮 = 返回/退出
- Select 上长按 = 上下文菜单

### 使自定义视图可聚焦

```swift
// UIKit (tvOS)
class FocusableCardView: UIView {
    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if context.nextFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.layer.shadowOpacity = 0.5
            })
        } else if context.previouslyFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.layer.shadowOpacity = 0
            })
        }
    }
}
```

### 设置默认焦点

```swift
// UIKit —— preferredFocusEnvironments 从上到下评估
override var preferredFocusEnvironments: [UIFocusEnvironment] {
    return [primaryButton]
}

// 已弃用——使用上面的 preferredFocusEnvironments
override weak var preferredFocusedView: UIView? { primaryButton }
```

### UIFocusGuide —— 重定向焦点

```swift
let guide = UIFocusGuide()
view.addLayoutGuide(guide)
guide.preferredFocusEnvironments = [targetButton]

// 引导占据两个按钮之间的空白
NSLayoutConstraint.activate([
    guide.leadingAnchor.constraint(equalTo: leftButton.trailingAnchor),
    guide.trailingAnchor.constraint(equalTo: rightButton.leadingAnchor),
    guide.topAnchor.constraint(equalTo: leftButton.topAnchor),
    guide.bottomAnchor.constraint(equalTo: leftButton.bottomAnchor)
])
```

### 调试焦点

在带 tvOS target 的 iOS Simulator 中：Debug → View → Show Focus for Focus Engine Debug。

---

## AssistiveTouch

AssistiveTouch 显示浮动虚拟按钮，提供对手势、硬件按钮和自定义序列的访问。如果实现了 VoiceOver 和基本无障碍，大部分 AssistiveTouch 支持是自动的。

### 检测 AssistiveTouch

```swift
if UIAccessibility.isAssistiveTouchRunning {
    // 可选：简化复杂手势，显示替代控件
}

// 观察变化
NotificationCenter.default.addObserver(
    forName: UIAccessibility.assistiveTouchStatusDidChangeNotification,
    object: nil, queue: .main
) { _ in
    // 更新 UI
}
```

### AssistiveTouch + 自定义手势

自定义多点触控手势对 AssistiveTouch 不可访问。始终提供单点击或按钮替代方案。

---

## Guided Access

Guided Access 将设备锁定到单个应用，带有可选的功能限制。用于信息亭、教育应用和专注模式场景。

### 检查 Guided Access 状态

```swift
if UIAccessibility.isGuidedAccessEnabled {
    // 锁定导航，隐藏敏感控件
}

// 观察变化
NotificationCenter.default.addObserver(
    forName: UIAccessibility.guidedAccessStatusDidChangeNotification,
    object: nil, queue: .main
) { _ in
    updateForGuidedAccess()
}
```

### GuidedAccessRestrictions —— 按功能限制

实现 `UIGuidedAccessRestrictionDelegate` 以提供教育者或护理人员可切换的细粒度限制。

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, UIGuidedAccessRestrictionDelegate {

    var guidedAccessRestrictionIdentifiers: [String] {
        ["com.myapp.restriction.settings",
         "com.myapp.restriction.purchases"]
    }

    func textForGuidedAccessRestriction(withIdentifier restrictionIdentifier: String) -> String? {
        switch restrictionIdentifier {
        case "com.myapp.restriction.settings": return "Settings"
        case "com.myapp.restriction.purchases": return "In-App Purchases"
        default: return nil
        }
    }

    func guidedAccessRestriction(withIdentifier restrictionIdentifier: String,
                                  didChange newRestrictionState: UIAccessibility.GuidedAccessRestrictionState) {
        switch restrictionIdentifier {
        case "com.myapp.restriction.settings":
            settingsButton.isHidden = (newRestrictionState == .deny)
        default: break
        }
    }
}
```

### 编程式 Guided Access 控制

```swift
// 编程式进入/退出单应用模式（用于信息亭应用）
// 注意：需要受监管设备或 MDM 注册
UIAccessibility.requestGuidedAccessSession(enabled: true) { success in
    if success { print("Guided Access session started") }
}
```

---

## 常见模式清单

- [ ] 所有交互元素 ≥ 44×44pt 触摸目标
- [ ] 仅滑动手势有 `accessibilityCustomAction` 替代方案
- [ ] 无交互在无用户控制下超时
- [ ] 每个模态可用 Escape 键关闭
- [ ] 自定义视图使用 `Button` 或有 `.accessibilityTraits(.button)` 以可键盘到达
- [ ] tvOS：自定义视图重写 `canBecomeFocused` 并为焦点变化添加动画
- [ ] 如果应用有可锁定功能则定义 Guided Access 限制
