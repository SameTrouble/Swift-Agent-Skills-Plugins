---
name: swift-focusengine-pro
description: 审查、编写和修复所有 Apple 平台（tvOS、iOS/iPadOS、watchOS、visionOS、macOS）的焦点管理代码，涵盖 SwiftUI、UIKit、AppKit 和 RealityKit。在读取、编写或审查处理焦点、悬停、键视图循环或 Digital Crown 导航的应用时使用。
version: 1.7.1
author: Michael Haviv
tags:
  - swift
  - swiftui
  - uikit
  - tvos
  - ios
  - ipados
  - visionos
  - watchos
  - macos
  - focus-engine
  - focus-management
  - realitykit
  - accessibility
  - apple
  - agent-skill
---

审查焦点管理代码的正确性、现代 API 使用情况，以及对 Apple 焦点引擎规则的遵守程度。涵盖所有 Apple 平台。只报告真正的问题——不要吹毛求疵或凭空捏造问题。

审查流程：

1. 使用 `references/anti-patterns.md` 检查关键反模式。
2. 确定目标平台并加载相应的参考文档：
   - **tvOS**：`references/swiftui-focus.md` 和 `references/uikit-focus.md`。
   - **iOS/iPadOS**：`references/ios-focus.md`（焦点组、光晕、键盘导航）。
   - **watchOS**：`references/watchos-focus.md`（Digital Crown、顺序焦点）。
   - **visionOS**：`references/visionos-focus.md`（注视、悬停效果）和 `references/realitykit-focus.md`（RealityKit 实体、手势、立体空间）。
   - **macOS**：`references/macos-focus.md`（键视图循环、焦点环、NSView 焦点、菜单的 focusedValue、Mac Catalyst）。
   - 跨平台：加载所有相关参考文档。
3. 使用 `references/focus-styling.md` 检查焦点样式和视觉反馈。
4. 使用 `references/focus-restoration.md` 验证焦点恢复和数据重新加载处理。
5. 使用 `references/layout-patterns.md` 审查布局模式以检查焦点区域隔离。
6. 使用 `references/async-focus.md` 检查 async/await 和数据加载焦点模式。
7. 使用 `references/accessibility-focus.md` 验证辅助功能集成。
8. 使用 `references/debugging.md` 检查调试和测试实践。

如果进行部分审查，只加载相关的参考文件。


## 核心指令

### tvOS
- tvOS 使用基于焦点的导航模型——每个可交互元素都必须可通过 Siri Remote 的方向键到达。
- 焦点移动纯粹是几何性的——焦点引擎从当前聚焦的视图沿滑动方向画一个矩形，并选择该矩形中最近的可聚焦视图。
- 如果几何路径上没有任何内容，焦点不会移动。就这样。使用 `.focusSection()`（SwiftUI）或 `UIFocusGuide`（UIKit）来弥合间隙。
- 在 tvOS 上不要使用 `.disabled()` 来切换交互性——它会将视图从焦点链中完全移除。`.allowsHitTesting(false)` 在 tvOS 上**不可靠**（可能映射为 `isUserInteractionEnabled = false`）。推荐做法：在按钮闭包内部对操作进行门控，或者对列表使用双重 `@FocusState` + `.disabled()` 门控模式（反模式 #25）。
- `prefersDefaultFocus(_:in:)` 在 tvOS 的 `ScrollView` 内不起作用——请改用 `defaultFocus(_:_:priority:)`。注意：带 `.userInitiated` 的 `defaultFocus` 仅在初始出现时触发，而非每次重新进入时触发。
- 优先使用 `ScrollPosition` 而非 `ScrollViewReader.scrollTo()`——命令式 scrollTo 会与焦点引擎产生反馈循环（反模式 #26）。
- 始终在真实的 Apple TV 硬件上测试——模拟器的焦点行为有所不同。

### iOS/iPadOS
- 焦点是次要交互模型——仅在连接硬件键盘时激活。
- Tab 在焦点组之间移动；方向键在组内移动。这种两级模型在 tvOS 上不存在。
- 使用 `focusGroupIdentifier`（iOS 15+，UIKit）定义自定义焦点组——此 API 在 tvOS 上不可用。
- 使用 `UIFocusHaloEffect` 自定义系统焦点环——tvOS 上不可用。
- 在集合/表格视图上设置 `allowsFocus = true` 和 `selectionFollowsFocus = true` 以支持键盘导航。
- 你的应用必须在没有键盘焦点的情况下完美工作——始终仅用触摸测试。

### watchOS
- 焦点将 **Digital Crown 输入**路由到正确的视图——由绿色边框指示。
- 焦点是顺序的（布局顺序），而非空间/方向性的。
- `.focusSection()` 在 watchOS 上不可用。
- `.focusable()` 必须在 `.digitalCrownRotation()` 之前——顺序反转会静默破坏 Crown 输入。
- 不要向系统控件（Picker、Stepper、Toggle）添加 `.focusable()`——它们已经处理了焦点。

### visionOS
- 眼睛注视 = 悬停定位，而非焦点。`onHover(perform:)` 不会从注视触发——仅从指针设备触发。
- 使用 `.hoverEffect()` 获取注视视觉反馈。系统控件自动获得；自定义视图需要显式添加。
- `@FocusState` 仅通过键盘（Magic Keyboard）、VoiceOver 或 Switch Control 激活。
- RealityKit 实体需要 `InputTargetComponent` + `CollisionComponent` + `HoverEffectComponent` 才能进行注视交互。
- `.focusEffectDisabled()` 隐藏键盘焦点环；`.hoverEffectDisabled()` 禁用注视悬停——它们是不同的。

### macOS
- macOS 使用键视图循环——Tab/Shift-Tab 按定义的序列在视图之间移动。这与 tvOS 的空间模型不同。
- 自定义 NSView 子类必须重写 `acceptsFirstResponder` 返回 `true`——默认为 `false`，使视图对 Tab 导航不可见。
- NSWindow 上的 `recalculatesKeyViewLoop = true` 会覆盖所有手动 `nextKeyView` 连接。选择一种方式。
- 焦点环自定义：在 NSView 上重写 `focusRingType`、`focusRingMaskBounds` 和 `drawFocusRingMask()`。
- `focusedValue` / `focusedSceneValue` 在 macOS 上对于使菜单栏命令响应当前选择至关重要。
- Mac Catalyst：继承 iPad 的 `UIFocusSystem`。如果 iPad 应用不支持键盘焦点，Catalyst 应用也不会支持。
- 完全键盘访问默认关闭——大多数用户只在文本字段和列表之间 Tab，而非所有控件。

### 所有平台
- 不要向 Buttons 或 NavigationLinks 添加 `.focusable()`——它们已经可聚焦。添加它会创建双重焦点包装。
- 不要在同一视图层次结构分支上混合使用 `@FocusState`（SwiftUI）和 UIKit 焦点 API（`setNeedsFocusUpdate`）。
- VoiceOver 焦点（`@AccessibilityFocusState`）与 UI 焦点（`@FocusState`）完全分开。


## 输出格式

按文件组织发现的问题。对于每个问题：

1. 说明文件和相关行号。
2. 指出违反的规则（例如"使用 `.allowsHitTesting(false)` 而非 `.disabled()`"）。
3. 展示简短的前后代码修复对比。

跳过没有问题的文件。以优先级排序的总结结尾，列出最有影响力的更改。

示例输出：

### TopicsView.swift

**第 49 行：`.disabled()` 将视图从 tvOS 焦点链中移除（反模式 #1）。**

```swift
// 修改前
TopicClipsGridView(...)
    .disabled(!wrapper.isGridFocusable)

// 修改后——门控操作，而非视图
TopicClipsGridView(...)
    .opacity(wrapper.isGridFocusable ? 1.0 : 0.5)
// 将守卫移到按钮/操作闭包内部
```

**第 72 行：垂直布局中的水平 ScrollView 缺少 `.focusSection()`。**

```swift
// 修改前
ScrollView(.horizontal) {
    HStack { /* 行项目 */ }
}

// 修改后
ScrollView(.horizontal) {
    HStack { /* 行项目 */ }
}
.focusSection()
```

### 总结

1. **焦点断裂（严重）：** 第 49 行的 `.disabled()` 将网格从焦点链中完全移除。
2. **焦点跳跃（高）：** 缺少 `.focusSection()` 导致跨行焦点跳跃。

示例结束。


## 参考文档

- `references/anti-patterns.md` — 破坏焦点导航的关键错误：14 个 tvOS + 7 个 macOS 特定反模式。
- `references/swiftui-focus.md` — SwiftUI 焦点 API：@FocusState、focusSection、prefersDefaultFocus、focused、defaultFocus、onMoveCommand。
- `references/uikit-focus.md` — UIKit 焦点 API：UIFocusEnvironment、UIFocusGuide、shouldUpdateFocus、didUpdateFocus、preferredFocusEnvironments、UIFocusDebugger。
- `references/focus-styling.md` — 焦点视觉反馈：带 isFocused 的 ButtonStyle、FocusBorder、悬停效果、缩放/阴影动画、macOS 焦点环样式。
- `references/focus-restoration.md` — 数据重新加载、导航和异步更新后的焦点处理。
- `references/layout-patterns.md` — 常见 tvOS 布局：集合表格、侧边栏+内容、标签栏、水平货架。
- `references/ios-focus.md` — iOS/iPadOS 特定：焦点组、focusGroupIdentifier、UIFocusHaloEffect、键盘导航、allowsFocus、selectionFollowsFocus。
- `references/watchos-focus.md` — watchOS 特定：Digital Crown 路由、顺序焦点、digitalCrownRotation、focusable 顺序。
- `references/visionos-focus.md` — visionOS 特定：注视 vs 焦点 vs 悬停、HoverEffect、HoverEffectGroup、RealityKit HoverEffectComponent、空间输入。
- `references/macos-focus.md` — macOS 特定：键视图循环、NSView 焦点（acceptsFirstResponder、canBecomeKeyView）、焦点环自定义、菜单的 focusedValue、Mac Catalyst、完全键盘访问。
- `references/realitykit-focus.md` — RealityKit 实体悬停：HoverEffectComponent、碰撞形状、手势、着色器效果、混合 SwiftUI+RealityKit 层次结构。
- `references/async-focus.md` — 异步焦点模式：@MainActor 协调、数据加载后焦点、NavigationStack 返回、Task 取消、防抖。
- `references/accessibility-focus.md` — 辅助功能集成：@AccessibilityFocusState、VoiceOver + 焦点、完全键盘访问、Switch Control、减弱动态效果。
- `references/debugging.md` — UIFocusDebugger、_whyIsThisViewNotFocusable、启动参数、Quick Look、macOS 第一响应者调试。
