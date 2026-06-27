# 触感反馈

## 意图

节制使用触感反馈来强化用户操作（标签选择、刷新、成功/错误），并尊重用户偏好。

## 核心模式

- 在 `HapticManager` 或类似工具中集中触感反馈触发。
- 用用户偏好和硬件支持对触感反馈加门控。
- 为不同 UX 时刻使用不同类型（选择 vs 通知 vs 刷新）。

## 示例：简单触感反馈管理器

```swift
@MainActor
final class HapticManager {
  static let shared = HapticManager()

  enum HapticType {
    case buttonPress
    case tabSelection
    case dataRefresh(intensity: CGFloat)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
  }

  private let selectionGenerator = UISelectionFeedbackGenerator()
  private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
  private let notificationGenerator = UINotificationFeedbackGenerator()

  private init() { selectionGenerator.prepare() }

  func fire(_ type: HapticType, isEnabled: Bool) {
    guard isEnabled else { return }
    switch type {
    case .buttonPress:
      impactGenerator.impactOccurred()
    case .tabSelection:
      selectionGenerator.selectionChanged()
    case let .dataRefresh(intensity):
      impactGenerator.impactOccurred(intensity: intensity)
    case let .notification(style):
      notificationGenerator.notificationOccurred(style)
    }
  }
}
```

## 示例：用法

```swift
Button("Save") {
  HapticManager.shared.fire(.notification(.success), isEnabled: preferences.hapticsEnabled)
}

TabView(selection: $selectedTab) { /* tabs */ }
  .onChange(of: selectedTab) { _, _ in
    HapticManager.shared.fire(.tabSelection, isEnabled: preferences.hapticTabSelectionEnabled)
  }
```

## 应保留的设计选择

- 触感反馈应微妙，不应在每次细小交互时触发。
- 尊重用户偏好（可切换禁用）。
- 保持触感反馈触发靠近用户操作，而非深藏在数据层中。

## 陷阱

- 避免快速连续触发多个触感反馈。
- 不要假设触感反馈可用；检查支持。
