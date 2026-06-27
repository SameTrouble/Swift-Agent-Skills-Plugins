---
name: ios-accessibility
description: 'iOS 无障碍最佳实践、模式和实现的专业指南。当开发者提到以下内容时使用：(1) iOS 无障碍、VoiceOver、Dynamic Type 或辅助技术，(2) 无障碍标签、特质、提示或值，(3) 自动化无障碍测试、审计或手动测试，(4) Switch Control、Voice Control 或 Full Keyboard Access，(5) 包容性设计或无障碍文化，(6) 让应用适用于残障用户。'
---

# iOS 无障碍

## 概述

本技能提供 iOS 无障碍方面的专业指导，涵盖 VoiceOver、Dynamic Type、辅助技术、包容性设计实践，以及 UIKit 和 SwiftUI 的实现。使用本技能帮助开发者构建适合所有人的应用。

## 方法论

- **左移** — 无障碍是流程的一部分。即使在原型或 MVP 阶段也需要考虑。
- **以用户为中心** — 无障碍关乎人。清单有帮助，但目标不是清单合规。目标是为残障用户提供出色的体验。
- **进步优于完美** — 随时都是开始的好时机。专注于迭代和增量改进。积少成多。
- **边做边测** — 手动测试是开发的一部分。

## 代理行为契约

1. **无障碍是非确定性的。** 按置信度顺序提出潜在解决方案，并清晰呈现优缺点和权衡。
2. 在提出修复方案之前，先确定平台（UIKit 还是 SwiftUI）以及上下文中的辅助技术、无障碍功能或设计考量。
3. 不要在未考虑用户体验影响的情况下推荐无障碍修复方案。
4. 在代码更改的同时优先提供手动测试指导，并附带任何自动化或半自动化解决方案。
5. 在相关时交叉引用多种辅助技术（VoiceOver、Voice Control、Switch Control、Full Keyboard Access）。

### 需要避免的反模式

- **不要在标签中添加特质名称** — 说"关闭"，而不是"关闭按钮"（使用按钮特质时，VoiceOver 会自动添加"按钮"）
- **不要对交互元素使用 `.accessibilityHidden(true)`** — 用户将无法访问它们
- **不要使用固定字体大小** — 始终使用文本样式以支持 Dynamic Type
- **不要为文本使用硬编码颜色** — 使用语义颜色（`.label`、`.secondaryLabel`）以支持对比度和深色模式
- **不要在没有明确组合标签的情况下分组 UIKit 元素** — 如果 `isAccessibilityElement = true`，请设置 `accessibilityLabel`（以及所需的值/特质）。
- **不要在没有明确组合标签的情况下分组 SwiftUI 元素** — 如果使用 `.accessibilityElement(children: .ignore)`，请手动提供标签/值/特质。
- **除非需要，否则不要添加提示** — 通过标签/值/特质就应该能清楚表达组件的含义和行为。仅在需要额外清晰度或上下文时配置。
- **不要仅依赖 `onTapGesture`** — 优先使用 `Button` 等语义控件。如果手势处理不可避免，请添加按钮特性和清晰标签。
- **不要用 Dynamic Type 缩放 chrome 控件** — 对于导航栏、工具栏和标签栏，优先使用 Large Content Viewer（iOS 13+），使用 [`.accessibilityShowsLargeContentViewer`](https://developer.apple.com/documentation/swiftui/view/accessibilityshowslargecontentviewer(content:)) / [`UILargeContentViewerItem`](https://developer.apple.com/documentation/uikit/uilargecontentvieweritem)。

### 通用指导

**优先使用原生组件：** 尽可能使用 Apple 的原生组件并根据需求自定义，而不是从零构建自定义组件。

**设计系统优先：** 当项目使用自己的设计系统（颜色、文本样式、组件目录）时，在设计系统本身中提出更改，这样改进就能在使用改进组件的应用各个地方产生滚雪球效应。

**平台一致性：** 相同的无障碍原则适用于 UIKit 和 SwiftUI，但 API 和实现细节有所不同。

## 项目设置评估（提供建议前先评估）

在提供无障碍指导之前，请确定：

### 项目能力
- **项目使用的是 SwiftUI、UIKit 还是两者混合？**
- **iOS 部署目标** — 某些 API 需要特定版本：
  - iOS 13+：[Large Content Viewer (`UILargeContentViewerInteraction`)](https://developer.apple.com/documentation/uikit/uilargecontentviewerinteraction)、[SF Symbols](https://developer.apple.com/sf-symbols/)
  - iOS 14+：[Switch Control 操作图像 (`UIAccessibilityCustomAction.init(name:image:actionHandler:)`)](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction/init(name:image:actionhandler:))
  - iOS 15+：[`AccessibilityFocusState`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate)、[`.accessibilityRotor`](https://developer.apple.com/documentation/swiftui/view/accessibilityrotor(_:entries:entryid:entrylabel:))
  - iOS 16+：[`.accessibilityRepresentation`](https://developer.apple.com/documentation/swiftui/view/accessibilityrepresentation(representation:))、[`.accessibilityActions { }` 语法](https://developer.apple.com/documentation/swiftui/view/accessibilityactions(content:))
  - iOS 17+：[`.sensoryFeedback`](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))
- **检查最低 OS** — 在项目设置中查找 `#available` 检查和部署目标

### 项目约定
- **设计系统** — 项目是否定义了自己的设计系统（颜色、文本样式、UI 组件目录）？在合适时在设计系统中提出更改，而不仅仅是针对单个功能。
- **语义颜色和文本样式** — 项目是否使用语义颜色（`.label`、`.systemBackground`）和文本样式（UIKit 中 `.preferredFont(forTextStyle:)`，SwiftUI 中 `.font(.body)`）而非硬编码值？
- **现有无障碍模式** — 搜索 `.accessibilityLabel`、`.accessibilityTraits` 等以匹配项目风格。
- **本地化** — 无障碍标签、值和提示应进行本地化。匹配项目的本地化约定。
- **UI 构建** — Interface Builder（XIB/Storyboard）还是纯代码？
- **自定义手势** — 确定自定义手势是否需要无障碍替代方案。
- **无障碍测试覆盖** — 现有 UI 测试是否审计无障碍？

### 当设置未知时
如果无法确定上述内容，请在给出版本特定或框架特定的指导之前，请开发者确认。

## 快速决策树

当开发者需要无障碍指导时，遵循此决策树：

1. **VoiceOver 问题？**
   - 核心概念：阅读 `references/voiceover.md`
   - UIKit 实现：阅读 `references/voiceover-uikit.md`
   - SwiftUI 实现：阅读 `references/voiceover-swiftui.md`

2. **Dynamic Type、文本缩放或自适应布局？**
   - 核心概念：阅读 `references/dynamic-type.md`
   - UIKit 实现：阅读 `references/dynamic-type-uikit.md`
   - SwiftUI 实现：阅读 `references/dynamic-type-swiftui.md`

3. **其他辅助技术？**
   - Voice Control：阅读 `references/voice-control.md`
   - Switch Control：阅读 `references/switch-control.md`
   - Full Keyboard Access：阅读 `references/full-keyboard-access.md`

4. **测试无障碍？**
   - 手动测试：阅读 `references/testing-manual.md`
   - 自动化测试：阅读 `references/testing-automated.md`

5. **横切关注点？**
   - 对比度、目标、动效、触觉：阅读 `references/good-practices.md`
   - 文化和心态：阅读 `references/concepts-and-culture.md`

6. **需要快速参考？**
   - 常见错误、模式、清单：阅读 `references/playbook.md`

7. **需要定义或来源？**
   - 术语表：阅读 `references/glossary.md`
   - 来源和延伸阅读：阅读 `references/resources.md`

## 快速手册（从这里开始）

1. 确认**框架**（UIKit 还是 SwiftUI）和 **iOS 目标**。
2. 确定**辅助技术**和**用户体验问题**。
3. 使用**决策树**并跳转到相关参考文件。
4. 在合适时提供 **2-3 个选项**，包含权衡和预期的 UX 影响。
5. 始终在代码更改的同时包含**测试指导**。

如需常见错误、检查器警告、代码模式、版本特定 API 和清单，请使用 `references/playbook.md`。

## 示例提示和预期形式

**示例提示：** "VoiceOver 将我的关闭按钮读作'按钮'。"
**预期响应：**
- 如果未知，确认框架和 iOS 目标。
- 当有多种可行方法时提供选项（例如，添加无障碍标签 vs 使用图标样式带标签的按钮），并说明权衡。
- 包含适合框架的代码片段。
- 添加测试步骤（VoiceOver、Voice Control...）。

**示例提示：** "Dynamic Type 破坏了我的 UIKit 标题布局。"
**预期响应：**
- 确认 `preferredContentSizeCategory` 处理和 iOS 目标。
- 建议布局适应策略（堆栈轴变换 vs 约束）。
- 包含 UIKit 代码片段和 Large Accessibility Sizes 的测试步骤。

## 边缘情况和注意事项

- UIKit/SwiftUI 混合屏幕：按视图层使用正确的 API 集合。
- 自定义控件或手势：始终提供 VoiceOver/Voice Control 替代方案。
- 未知 iOS 目标：在建议版本特定 API 之前先询问。
- 无代码上下文：请求相关视图代码或 Accessibility Inspector 的截图。
- 本地化：所有标签、值和提示（以及任何其他字符串参数，如自定义内容或无障碍公告等）都必须进行本地化。
