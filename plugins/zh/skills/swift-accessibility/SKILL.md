---
name: swift-accessibility-skill
description: 将平台无障碍最佳实践应用于 SwiftUI、UIKit 和 AppKit 代码。是任何 SwiftUI、UIKit 或 AppKit 技能的必备伴侣——始终配合使用。在编写、编辑或审查任何 SwiftUI 视图、UIKit 视图控制器、AppKit 视图/窗口控制器或平台 UI 时使用——即使用户没有提及无障碍。当用户提及 VoiceOver、Voice Control、Dynamic Type、Reduce Motion、屏幕阅读器、a11y、WCAG、无障碍审计、Nutrition Labels、accessibilityLabel、UIAccessibility、NSAccessibility、辅助技术或 Switch Control 时也使用。不适用于服务端 Swift、非 UI 包或 CLI 工具。
---

# 平台无障碍

## 概述

为所有支持平台上的 SwiftUI、UIKit 和 AppKit 应用无障碍功能。覆盖全部 9 个 App Store Accessibility Nutrition Label 类别——VoiceOver、Voice Control、Larger Text、Dark Interface、Differentiate Without Color、Sufficient Contrast、Reduced Motion、Captions 和 Audio Descriptions。

本技能优先使用原生平台 API（提供免费的自动支持），并基于事实给出指导，不涉及架构观点。

## 首稿规则

在**首稿**中就包含无障碍——永远不要先写一个裸元素再事后补加。事后补加无障碍更困难、容易被跳过，而且效果不如从一开始就内置。

除非某个模式不明显，否则不加行内注释。用 `// [VERIFY]` 标记推断的标签，因为 SF Symbol 名称并不总是匹配预期的用户可见含义。

| 情形 | 首稿必须做 |
|---|---|
| `Button` / `NavigationLink` — 仅图标 | `.accessibilityLabel("…")` 加 `// [VERIFY]` |
| `Button` / `NavigationLink` — 可见文字 | 无需额外操作——文字自动成为标签 |
| `Image` — 有意义的 | `.accessibilityLabel("…")` |
| `Image` — 装饰性 | `.accessibilityHidden(true)` |
| `withAnimation` / `.transition` / `.animation` | `@Environment(\.accessibilityReduceMotion)` + 控制动画 |
| `.font(.system(size:))` | 替换为 `.font(.body)` 或 `@ScaledMetric` |
| 颜色传达状态/状态 | 在颜色旁添加形状、图标或文字 |
| 在非 `Button` 上使用 `onTapGesture` | `.accessibilityElement(children: .ignore)` + `.accessibilityAddTraits(.isButton)` + `.accessibilityLabel` |
| 自定义滑块/开关/步进器 | `.accessibilityRepresentation { … }` 或 `.accessibilityValue` + `.accessibilityAdjustableAction` |
| 异步内容变化 | 发送带可用性守卫的播报（iOS 17+ 用 `AccessibilityNotification.Announcement`，回退到 `UIAccessibility.post`） |
| 系统 `.sheet` / `.fullScreenCover` | 无需额外操作——SwiftUI 自动捕获焦点（自定义遮罩仍需焦点管理） |
| `AVPlayer` / 视频 | 使用 `AVPlayerViewController`——免费获得字幕和音频描述 |
| 自定义可点击视图 | `.frame(minWidth: 44, minHeight: 44)` |
| 任何新的 SwiftUI 视图 | 用 Xcode Canvas Variants 验证（见无障碍摘要） |
| `NSButton` — 仅图标（AppKit） | `setAccessibilityLabel("…")` 加 `// [VERIFY]` |
| 自定义 `NSView` 交互元素（AppKit） | `setAccessibilityElement(true)` + 角色（`setAccessibilityRole(.button)`）+ 标签 |
| AppKit 模态/弹出 UI | 捕获焦点并确保关闭操作可通过键盘 + VoiceOver 到达 |
| 任何新的 AppKit 视图/控制器 | 用 Accessibility Inspector 和完整键盘导航验证 |

优先使用原生控件（`Button`、`Toggle`、`Stepper`、`Slider`、`Picker`、`TextField`）——它们自动获得完整无障碍支持。自定义交互视图需要显式处理。
对于 AppKit，优先使用原生控件（`NSButton`、`NSPopUpButton`、`NSSlider`、`NSSegmentedControl`、`NSTextField`），再做自定义 `NSView` 交互。

**示例——仅图标按钮：**
```swift
Button {
    shareAction()
} label: {
    Image(systemName: "square.and.arrow.up")
}
.accessibilityLabel("Share") // [VERIFY] confirm label matches intent
```

**示例——基于 Reduce Motion 控制动画：**
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

withAnimation(reduceMotion ? nil : .spring()) {
    isExpanded.toggle()
}
```

完整测试和验证流程 → `references/testing-auditing.md`

## 工作流程

### 参考路由规则
在回答之前，选择一个最匹配用户意图的**主要**参考文件并先加载它。
仅当请求明确涉及多个领域（例如 VoiceOver + Dynamic Type + WCAG 映射）或主要文件未覆盖某个必要标准时，才加载额外的参考文件。

### 1) 实现新代码
应用**首稿规则**——首稿即包含无障碍，不加注释。
对于 iOS 15 之后引入的 API，始终添加 `#available` 守卫并提供旧版 OS 的回退行为。
写完后，对照首稿规则表验证——在输出前修复所有缺口。
代码之后，附加**无障碍摘要**（见下文）。

### 2) 改进或修复现有代码
静默应用修复，不加注释。
对于 iOS 15 之后引入的 API，始终添加 `#available` 守卫并提供旧版 OS 的回退行为。
修复后，对照首稿规则表验证——在输出前修复所有缺口。
代码之后，附加**无障碍摘要**。
- 转换模式 → `examples/before-after-swiftui.md`、`examples/before-after-uikit.md` 或 `examples/before-after-appkit.md`
- 平台问题 → `references/platform-specifics.md`

### 3) 审计现有代码
仅当用户明确要求时（"审计"、"无障碍程度如何？"、"审查无障碍"）。

**快速修复模式**——当用户要求仅修复阻断项/仅严重项范围时（例如："只修复阻断项"、"快速修复"、"仅严重项"）：只处理 Blocks Assistive Tech 和 Degrades Experience 问题。跳过 Incomplete Support。

**全面模式**（默认）——处理所有严重级别，包括 Incomplete Support 和 Nutrition Label 缺口。

- 按类别识别问题 → 下方的**分诊手册**
- 用下方的**审计输出格式**格式化
- WCAG 合规映射 → `references/wcag-mapping.md`
- 交接给 QA → `resources/qa-checklist.md`

### 4) 准备 Nutrition Label 建议
→ `references/nutrition-labels.md`——全部 9 个类别及官方通过/失败标准

当用户要求准备或起草 App Store Accessibility Nutrition Label 建议时，输出此格式：

```
**Accessibility Nutrition Label recommendation**

**App version evaluated:** [版本或 "Current build"]
**Scope reviewed:** [评估的常见任务 / 屏幕]

**You could claim:**
- [所有常见任务为 ✅ 或 — 的标签]

**Why you could claim them:**
- [标签]: [基于已完成的常见任务覆盖的简要理由]

**You should not claim:**
- [被任何 ❌ 阻断的标签]
- [不适用的标签]

**Why you should not claim them:**
- [标签]: [被阻断的任务或标签不适用的原因]

**Common-task verification**
| Common Task | VoiceOver | Voice Control | Larger Text | Dark Mode | No Color | Contrast | Motion | Captions | Audio Desc |
|---|---|---|---|---|---|---|---|---|---|
| [任务] | ✅ / ❌ / — | ✅ / ❌ / — | ✅ / ❌ / — | ✅ / ❌ / — | ✅ / ❌ / — | ✅ / ❌ / — | ✅ / ❌ / — | ✅ / ❌ / — | ✅ / ❌ / — |

**Recommendation summary**
- You could claim: [标签]
- You should not claim: [标签]
```

不要不加限定地使用"claim"。将输出表述为基于已审查范围的建议。
如果该列中任何常见任务为 ❌，不要建议该标签。仅当标签确实不适用于该应用或流程时使用 `—`。

## 无障碍摘要

在所有代码生成和修复任务（模式 1、2）之后附加，除非用户明确要求仅输出代码。无需前言。

```
**Accessibility applied:**
- [每个添加的模式一个要点——例如"仅图标的分享按钮添加了 `.accessibilityLabel`"]

**Verify in Xcode:**
- Use Canvas **Dynamic Type Variants** (grid icon → Dynamic Type Variants) to check layout at all text sizes
- Use Canvas **Color Scheme Variants** to check light and dark mode
- Use **Accessibility Inspector** (Xcode → Open Developer Tool) Settings tab to simulate Increase Contrast, Reduce Motion, Bold Text on the Simulator

**If Xcode is unavailable:**
- Run equivalent checks with platform accessibility inspector tools and manual setting toggles (Dynamic Type, Contrast, Reduce Motion, VoiceOver/Voice Control)

**Test on device:**
- [Must Test on Device 清单中的相关项]
```

如果没有添加任何内容（全部为原生控件），则完全省略"Accessibility applied"。
除非用户询问，否则省略"Nutrition Label readiness"。

## 审计输出格式

仅当用户明确要求审计时使用。代码生成或修复期间不使用。

**🔴 Blocks Assistive Tech** —— 完全不可达，立即修复
**🟡 Degrades Experience** —— 可达但摩擦显著
**🟠 Incomplete Support** —— 阻止 Nutrition Label 声明的缺口
**✅ Verified in code** —— 通过静态分析确认正确

结尾附上：
> **Must test on device**: Review Checklist 中的相关项。
> **Nutrition Label readiness**: Achievable / Blocked by [问题] / Not applicable。

## 核心指南

### 原则
- **首先确定框架和平台。** SwiftUI 和 UIKit 有不同的 API；使用错误的 API 会导致静默失败。
- **每个修饰符都需要语义理由。** 给带可见文字的 `Button` 添加 `.accessibilityLabel` 实际上会*有害*——它会覆盖 VoiceOver 本会自动朗读的文字。
- **用 `#available` 守卫 iOS 17+ API。** 版本特定的 API 在旧版 OS 上不加可用性检查会崩溃。
- **用 `[VERIFY]` 标记推断的标签。** SF Symbol 名称（如 `square.and.arrow.up`）很少匹配用户期望听到的内容（"Share"）。推断的标签需要人工审查。
- **不要根据 `UIAccessibility.isVoiceOverRunning` 改变核心 UI 语义或布局。** 通过直接检查相关的无障碍设置来适应用户的实际需求。狭窄的协调例外是可以的，例如避免语音重叠或在辅助技术活动时延长瞬时超时。
- **Nutrition Labels 需要完整的流程覆盖。** 声明"支持 VoiceOver"意味着*每个*用户流程都能工作——登录、引导、购买、设置——而不仅仅是主屏幕。
- **在浅色和深色模式下都测试对比度。** 在浅色模式下通过 WCAG 4.5:1 的颜色对在深色模式下常常因背景值不同而失败。

### VoiceOver
- 每个非装饰性元素都需要简洁的、不依赖上下文的标签
- 仅图标按钮需要 `.accessibilityLabel`——空白永远不可接受
- 装饰性图片：`.accessibilityHidden(true)`
- 状态是特质，不是标签：用 `.accessibilityAddTraits(.isSelected)` 而非 `"Selected photo"`
- 分组相关元素：`.accessibilityElement(children: .combine)`
- 播报动态变化：iOS 17+ `AccessibilityNotification.Announcement("Upload complete").post()`，回退 `UIAccessibility.post(notification: .announcement, argument: "Upload complete")`
- 深度参考 → `references/voiceover-swiftui.md` 或 `references/voiceover-uikit.md`

### Voice Control
- 标签必须精确匹配可见文字——不匹配会静默破坏"Tap [name]"
- 仅图标元素用 `.accessibilityInputLabels(["Compose", "New Message"])`
- 每个交互元素都必须出现在"Show numbers"和"Show names"覆盖层中
- 滑动显示的 UI 需要语音可访问的替代方案（`.accessibilityAction`）
- 深度参考 → `references/voice-control.md`

### Dynamic Type
- 只用文字样式：`.font(.body)` 而非 `.font(.system(size: 16))`
- 缩放自定义值：`@ScaledMetric(relativeTo: .body) var spacing: CGFloat = 8`
- 固定大小 UI chrome：`.accessibilityShowsLargeContentViewer()`
- 自适应布局：优先使用 `ViewThatFits`（iOS 16+）而非手动 `dynamicTypeSize` 检查——它会自动选择合适的布局
- 深度参考 → `references/dynamic-type.md`

### 显示设置
- Reduce Motion：用淡入淡出/溶解替换有意义的动画；移除装饰性动画
- Contrast：语义颜色（`Color(.label)`）；WCAG 4.5:1 文字，3:1 非文字
- Differentiate Without Color：在颜色旁添加形状/图标/文字
- Reduce Transparency：启用时用不透明背景替换 `.ultraThinMaterial`
- 深度参考 → `references/display-settings.md`

### 语义结构
- 阅读顺序：`.accessibilitySortPriority(_:)`（值越高 = 先读）
- 新屏幕聚焦：发送 `.screenChanged` 通知
- 模态焦点：`accessibilityViewIsModal = true`
- 自定义导航：`accessibilityRotor(_:entries:)`
- 深度参考 → `references/semantic-structure.md`

### 运动/输入
- 触摸目标：最小 44×44pt
- 键盘：每个元素通过 Tab 到达，每个模态通过 Escape 关闭
- Switch Control：`UIAccessibilityCustomAction` 用于仅滑动手势
- 深度参考 → `references/motor-input.md`

## 快速参考

### SwiftUI 修饰符

| 修饰符 | 用途 |
|---|---|
| `.accessibilityLabel(_:)` | 非文字元素的 VoiceOver 文字 |
| `.accessibilityHint(_:)` | 简要结果描述 |
| `.accessibilityValue(_:)` | 当前值（滑块、进度） |
| `.accessibilityHidden(true)` | 隐藏装饰性元素 |
| `.accessibilityAddTraits(_:)` | 语义角色或状态 |
| `.accessibilityRemoveTraits(_:)` | 移除继承的特质 |
| `.accessibilityElement(children:)` | `.combine` / `.contain` / `.ignore` |
| `.accessibilitySortPriority(_:)` | 阅读顺序（值越高 = 越早） |
| `.accessibilityAction(_:_:)` | 命名的自定义操作 |
| `.accessibilityAdjustableAction(_:)` | 递增/递减 |
| `.accessibilityInputLabels(_:)` | Voice Control 备选名称 |
| `.accessibilityFocused(_:)` | 编程聚焦 |
| `.accessibilityRotor(_:entries:)` | 自定义 VoiceOver 转子 |
| `.accessibilityRepresentation(_:)` | 替换自定义控件的无障碍树 |
| `.accessibilityIgnoresInvertColors(true)` | 在 Smart Invert 中保护图片 |
| `.accessibilityShowsLargeContentViewer()` | 固定大小 UI 的 Large Content Viewer |

### @Environment 值

| 值 | 用途 |
|---|---|
| `\.accessibilityReduceMotion` | 控制动画 |
| `\.accessibilityReduceTransparency` | 替换模糊效果 |
| `\.accessibilityDifferentiateWithoutColor` | 添加非颜色指示器 |
| `\.colorSchemeContrast` | `.standard` / `.increased` |
| `\.dynamicTypeSize` | 当前文字大小 |

### Nutrition Labels → APIs

| 标签 | 关键 APIs | 参考 |
|---|---|---|
| VoiceOver | `accessibilityLabel`, traits, actions, rotors | `voiceover-swiftui.md`, `voiceover-uikit.md` |
| Voice Control | `accessibilityInputLabels`, 可见文字匹配 | `voice-control.md` |
| Larger Text | `@ScaledMetric`, 文字样式, Large Content Viewer | `dynamic-type.md` |
| Dark Interface | `colorScheme`, 语义颜色 | `display-settings.md` |
| Differentiate Without Color | 形状 + 颜色 | `display-settings.md` |
| Sufficient Contrast | WCAG 4.5:1 文字 / 3:1 非文字 | `display-settings.md` |
| Reduced Motion | `accessibilityReduceMotion`, 动画控制 | `display-settings.md` |
| Captions | `AVPlayerViewController` | `media-accessibility.md` |
| Audio Descriptions | `AVMediaCharacteristic.describesVideoForAccessibility` | `media-accessibility.md` |

## 审查清单

### 代码中可验证
- [ ] 仅图标按钮有 `.accessibilityLabel`
- [ ] 装饰性图片有 `.accessibilityHidden(true)`
- [ ] 状态以特质表达，而非标签
- [ ] 无硬编码字体大小——使用文字样式或 `@ScaledMetric`
- [ ] 动画基于 `accessibilityReduceMotion` 控制
- [ ] 使用语义颜色（非硬编码 hex）
- [ ] 仅图标元素有 `.accessibilityInputLabels`
- [ ] 触摸目标 ≥ 44×44pt
- [ ] 模态使用 `.sheet()` 或 `accessibilityViewIsModal`
- [ ] 仅滑动操作有 `.accessibilityAction` 替代方案
- [ ] 视频使用 `AVPlayerViewController`
- [ ] 照片/地图/视频有 `.accessibilityIgnoresInvertColors()`
- [ ] XCUITest 包含 `performAccessibilityAudit()` 并带 `#available` 守卫（iOS 17+ / macOS 14+），加上旧版 OS 的回退断言

### 必须在设备上测试
- VoiceOver：导航顺序、阅读流程、push/模态后聚焦
- Voice Control："Show numbers"覆盖、"Tap [name]"激活
- Switch Control：扫描路径、自定义操作可达
- Full Keyboard Access：Tab 顺序、Escape 关闭
- Dynamic Type：最大尺寸下布局——无裁剪或重叠
- Reduce Motion：所有动画已验证
- 灰度滤镜：不依赖颜色即可理解信息
- 深色 + Increase Contrast：两种模式下的对比度
- 字幕和音频描述：自动启用

完整测试流程 → `references/testing-auditing.md`

## 分诊手册

### Blocks Assistive Tech —— 立即修复
- 仅图标按钮无标签 → `references/voiceover-swiftui.md`
- 图片缺少替代文字 → `references/voiceover-swiftui.md`
- 自定义视图不在无障碍树中 → `references/voiceover-uikit.md`
- VoiceOver 循环或无法退出元素 → `references/semantic-structure.md`

### Degrades Experience —— 摩擦显著
- Voice Control 遗漏某元素 → `references/voice-control.md`
- 语音标签与可见文字不匹配 → `references/voice-control.md`
- 触摸目标 < 44×44pt → `references/motor-input.md`
- 颜色是唯一区分手段 → `references/display-settings.md`
- 阅读顺序错误 → `references/semantic-structure.md`
- 模态未捕获焦点 → `references/semantic-structure.md`

### Incomplete Support —— 阻止 Nutrition Label 声明
- 文字不随 Dynamic Type 缩放 → `references/dynamic-type.md`
- 动画忽略 Reduce Motion → `references/display-settings.md`
- 深色模式下对比度低 → `references/display-settings.md`
- 无字幕或音频描述 → `references/media-accessibility.md`
- 平台不可访问 → `references/platform-specifics.md`
- Nutrition Label 准备 → `references/nutrition-labels.md`

## 故障排查

### 应用了错误的框架 API
**症状：** 在 UIKit/AppKit 代码中使用 SwiftUI 修饰符，或跨框架混用平台 API。
**修复：** 在应用 API 之前从导入语句确定框架（`import SwiftUI`、`import UIKit`、`import AppKit`）。SwiftUI 使用修饰符，UIKit 使用 `UIAccessibility` 属性，AppKit 使用 `NSAccessibility` API。

### 过度标记原生控件
**症状：** 给已有可见文字的 `Button("Save")` 或 `Toggle("Dark Mode")` 添加 `.accessibilityLabel`。
**修复：** 控件有可见文字时不要添加 `.accessibilityLabel`——它会覆盖自动标签，并可能与屏幕上的内容不同步。只给仅图标或非文字元素添加标签。

### API 需要的 OS 版本高于项目目标
**症状：** 代码使用平台版本特定的 API（iOS/macOS/tvOS/watchOS/visionOS）而未做可用性检查。
**修复：** 为每个支持的目标 OS 用 `#available` 守卫，并在需要时使用旧版等效 API。常见替换：
- `AccessibilityNotification.Announcement("…").post()` → `UIAccessibility.post(notification: .announcement, argument: "…")`
- `performAccessibilityAudit()` → 手动 XCTest 断言
- `ViewThatFits`（iOS 16+）→ `@Environment(\.dynamicTypeSize)` 手动布局切换
- 共享代码时优先使用多平台守卫：
  `if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) { ... }`

### 缺少无障碍摘要
**症状：** 生成的代码没有"Accessibility applied"/"Test on device"摘要块。
**修复：** 在代码生成和修复任务（工作流程模式 1 和 2）后始终附加无障碍摘要。仅当未添加任何无障碍模式时省略（全部为带可见文字的原生控件）。

### 推断标签缺少 [VERIFY] 注释
**症状：** 从 SF Symbol 名称或方法名推导的 `.accessibilityLabel` 没有 `// [VERIFY]` 注释。
**修复：** 任何推断的（非用户提供的）标签都必须包含 `// [VERIFY] confirm label matches intent`。像 `square.and.arrow.up` 这样的 SF Symbol 名称很少匹配用户期望听到的内容。

## 参考

- `references/voiceover-swiftui.md` —— SwiftUI 无障碍修饰符、特质、操作、转子、播报
- `references/voiceover-uikit.md` —— UIAccessibility 协议、自定义元素、容器、通知
- `references/voice-control.md` —— 输入标签、"Show numbers/names"、语音可访问替代方案
- `references/motor-input.md` —— Switch Control、Full Keyboard Access、AssistiveTouch、tvOS 焦点
- `references/dynamic-type.md` —— Dynamic Type、@ScaledMetric、Large Content Viewer、自适应布局
- `references/display-settings.md` —— Reduce Motion、Contrast、Dark Mode、Color、Transparency、Invert
- `references/semantic-structure.md` —— 分组、阅读顺序、焦点管理、转子、模态焦点
- `references/media-accessibility.md` —— Captions、Audio Descriptions、Speech synthesis、Charts
- `references/testing-auditing.md` —— Accessibility Inspector、Xcode Canvas Variants、XCTest、`performAccessibilityAudit()`、手动测试
- `references/nutrition-labels.md` —— 全部 9 个 Nutrition Labels 及通过/失败标准
- `references/wcag-mapping.md` —— WCAG 2.2 Level A/AA 成功标准映射到 SwiftUI/UIKit/AppKit APIs
- `references/assistive-access.md` —— Assistive Access（iOS 17+）、设计原则、测试
- `references/platform-specifics.md` —— macOS、watchOS、tvOS、visionOS 特定内容
- `examples/before-after-swiftui.md` —— SwiftUI 之前/之后转换
- `examples/before-after-uikit.md` —— UIKit 之前/之后转换
- `examples/before-after-appkit.md` —— AppKit（macOS）之前/之后转换
- `resources/audit-template.swift` —— 用于自动化无障碍审计的可直接使用的 XCUITest 文件（iOS 17+）
- `resources/qa-checklist.md` —— 用于手动测试的独立 QA 清单（交给测试人员）
