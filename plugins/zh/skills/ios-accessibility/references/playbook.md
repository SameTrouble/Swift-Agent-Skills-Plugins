# 无障碍手册

使用本手册查找常见错误、Accessibility Inspector 警告、核心模式、版本特定 API 和验证清单。将此与框架特定的参考（VoiceOver、Dynamic Type 等）配合使用以获得更深入的指导。

## 目录

- [常见错误手册](#常见错误手册)
- [常见 Accessibility Inspector 警告](#常见-accessibility-inspector-警告)
- [核心模式参考](#核心模式参考)
- [测试工作流](#测试工作流)
- [iOS 版本特定 API](#ios-版本特定-apis)
- [常见场景 → 快速导航](#常见场景--快速导航)
- [最佳实践摘要](#最佳实践摘要)
- [验证清单（修改后）](#验证清单修改后)
- [审查清单（快速检查）](#审查清单快速检查)
- [来源](#来源)

## 常见错误手册

当你看到这些模式（以用户体验问题表述）时，建议修复。示例在适用时同时展示 UIKit 和 SwiftUI。

### VoiceOver 不读取任何内容或读取"button"
**原因：** 元素没有标签或标签为空。在仅图标按钮中非常常见。
**修复：** 添加带有简洁描述的 `accessibilityLabel`。
```swift
// UIKit — 没有标签的图标按钮：VoiceOver 读取"button"
let closeButton = UIButton(type: .system)
closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
// 正确：
closeButton.accessibilityLabel = "Close"

// SwiftUI — 错误：VoiceOver 读取"button"
Button(action: close) { Image(systemName: "xmark") }

// SwiftUI — 正确：VoiceOver 读取"Close, button"
Button(action: close) { Image(systemName: "xmark") }
    .accessibilityLabel("Close")
```

### VoiceOver 分别读取单元格中的每个元素，导航繁琐
**原因：** 元素未分组；用户需要滑过每个标签和按钮。
**修复：** 将单元格分组为单个元素，按钮使用自定义操作。
```swift
// UIKit
cell.isAccessibilityElement = true
cell.accessibilityLabel = "\(title), \(subtitle)"
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Add to cart") { _ in self.addToCart(); return true }
]

// SwiftUI — 单次滑动；组合子元素以便标签从内部视图的无障碍属性构建
HStack {
    AsyncImage(url: imageURL)
    VStack(alignment: .leading) { Text(title); Text(subtitle) }
}
.accessibilityElement(children: .combine)
// 内部视图的标签/值贡献于组公告

// SwiftUI — 或单次滑动带自定义操作
NavigationLink { ... } label: { content }
    .accessibilityAction(named: "Add to cart") { addToCart() }
```

### VoiceOver 将自定义控件读取为许多独立元素或按钮
**原因：** 每个部分（星星、缩略图、递增/递减）都是独立的可聚焦元素。
**修复：** **当存在类似的原生控件时，优先使用 [`.accessibilityRepresentation`](https://developer.apple.com/documentation/swiftui/view/accessibilityrepresentation(representation:))（iOS 16+）。** 否则分组为一个元素：当控件有递增/递减语义时使用 **adjustable**（评分、步进器）；当没有时使用 **自定义操作** 或单个 **按钮**（例如具有离散选项的自定义选择器）。
```swift
// SwiftUI — 最佳：如果原生控件适合则使用表示（例如 Stepper）
CustomRatingView(rating: $rating)
    .accessibilityRepresentation {
        Stepper("Rating", value: $rating, in: 1...5)
    }

// SwiftUI — 如果需要自定义实现：单个元素，adjustable
customControl
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Rating")
    .accessibilityValue("\(rating) of 5")
    .accessibilityAdjustableAction { direction in ... }

// UIKit — 同样思路：一个元素，自定义操作或 adjustable
view.isAccessibilityElement = true
view.accessibilityLabel = "Rating"
view.accessibilityValue = "\(rating) of 5"
view.accessibilityTraits = .adjustable
// 实现 accessibilityIncrement() / accessibilityDecrement()
```

### 文本不随 Dynamic Type 缩放
**原因：** 使用了固定字体大小。
**修复：** 使用文本样式。
```swift
// UIKit
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true

// SwiftUI
Text("Content")
    .font(.body)  // 自动缩放
```

### 布局在大文本尺寸时破坏
**原因：** 水平布局无法容纳更大的文本。
**修复：** 当你需要跨重复项目确定性行为时，使用基于 `dynamicTypeSize`（或 `preferredContentSizeCategory`）的自适应布局。当你想要基于布局特定部分实际适配的局部回退，或当回退比简单翻转堆栈轴更复杂时，使用 `ViewThatFits`。
```swift
// SwiftUI — 自适应堆栈：在无障碍尺寸时翻转轴（iOS 16+ [AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)）
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

var body: some View {
    let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
    layout { content }
}

// SwiftUI — 同样思路，条件堆栈（所有 iOS 版本）
@Environment(\.dynamicTypeSize) var dynamicTypeSize
var body: some View {
    if dynamicTypeSize.isAccessibilitySize { VStack { content } } else { HStack { content } }
}

// SwiftUI — 基于适配的局部布局块回退
ViewThatFits {
    HStack { content } // 偏好的紧凑布局
    VStack { content } // 水平不适配时的回退
}

// UIKit
if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
    stackView.axis = .vertical
} else {
    stackView.axis = .horizontal
}
```

对于重复的列表/网格项，优先使用确定性规则；否则不同行可能根据内容长度解析为不同布局。

### Toast/snackbar 在 VoiceOver 到达前消失
**原因：** 临时反馈没有公告。
**修复：** 发布公告并考虑持久替代方案。
```swift
// UIKit
UIAccessibility.post(notification: .announcement, argument: message)

// SwiftUI
var announcement = AttributedString(message)
announcement.accessibilitySpeechAnnouncementPriority = .high
AccessibilityNotification.Announcement(announcement).post()
```

### Voice Control 找不到或无法激活按钮
**原因：** 标签与可见文本不同，或 Voice Control 需要直观的名称。
**修复：** Voice Control 默认使用 `accessibilityLabel` 进行识别。当你需要同义词或更短的命令时（例如，用"Remove"、"Delete"代替"Remove User"），使用 `accessibilityInputLabels` 提供额外替代方案。
```swift
// SwiftUI
Button("Remove User") { remove() }
    .accessibilityInputLabels(["Remove User", "Remove", "Delete"])

// UIKit
button.accessibilityLabel = "Remove User"
button.accessibilityUserInputLabels = ["Remove User", "Remove", "Delete"]
```

### 使用点击手势的自定义交互控件未作为按钮暴露给辅助技术
**原因：** 视图使用 `onTapGesture`（SwiftUI）或 `UITapGestureRecognizer`（UIKit）但未作为按钮暴露给 VoiceOver。
**修复：** **优先使用原生 `Button`（SwiftUI）或 `UIButton`（UIKit）** 以获得更好的开箱即用无障碍。如果必须使用带手势的自定义视图，使其成为无障碍元素并添加按钮特质。
```swift
// SwiftUI — 最佳：使用原生 Button
Button { select() } label: { HStack { Text("Option") } }

// SwiftUI — 如果需要自定义视图：手动添加特质和标签
HStack { Text("Option") }
    .onTapGesture { select() }
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("Option")

// UIKit — 最佳：使用 UIButton
// 如果需要自定义视图：使其可访问
customView.isAccessibilityElement = true
customView.accessibilityTraits.insert(.button)
customView.accessibilityLabel = "Option name"
customView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
```

### 选中状态未传达
**原因：** 选中指示器（勾选、高亮、单选按钮、复选框）仅是视觉的；VoiceOver 不知道它被选中了。
**修复：** 添加 `.selected` 特质。
```swift
// SwiftUI
.accessibilityAddTraits(isSelected ? .isSelected : [])

// UIKit
accessibilityTraits = isSelected ? accessibilityTraits.union(.selected) : accessibilityTraits.subtracting(.selected)
```

### VoiceOver 用户无法按标题导航
**原因：** 章节标题未标记标题特质；标题转子不列出它们。
**修复：** 为章节标题添加 `.header` 特质。
```swift
// SwiftUI
Text("Section Title")
    .accessibilityAddTraits(.isHeader)

// UIKit
sectionTitleLabel.accessibilityTraits.insert(.header)
```

### 装饰性图片可被 VoiceOver 到达
**原因：** 不传达有意义信息的图片仍在无障碍树中；VoiceOver 用户必须滑过它。
**修复：** 从辅助技术中隐藏装饰性图片。
```swift
// SwiftUI
Image("decoration")
    .accessibilityHidden(true)

// UIKit
decorativeImageView.isAccessibilityElement = false
```

## 常见 Accessibility Inspector 警告

当 Accessibility Inspector（Xcode > 窗口 > Accessibility Inspector > 审计）报告问题时，它提供修复建议。最常见的警告与上面的常见错误手册重叠。将此部分用作检查器特定指导的快速参考。

### "元素没有标签"
→ 参见上方的 **VoiceOver 不读取任何内容或读取"button"**。

### "文本不支持 Dynamic Type"
→ 参见上方的 **文本不随 Dynamic Type 缩放**。

### "对比度低于 4.5:1"（或大文本 3:1）
**修复：** 使用语义颜色或增加对比度。
```swift
// UIKit
label.textColor = .label  // 适应浅色/深色 + 增强对比度

// SwiftUI
Text("Content")
    .foregroundStyle(.primary)
```
→ 参见 `good-practices.md#color-contrast`

### "触摸目标低于 44x44 点"
**修复：** 确保最小 44×44 点；Dynamic Type 时允许更大。
```swift
// UIKit
button.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
])

// SwiftUI
Button(action: action) {
    Image(systemName: "info")
        .padding(12)
}
.contentShape(Rectangle())
```
→ 参见 `good-practices.md#touch-target-size`

### "元素有标签但没有特质"
→ 参见上方的 **使用点击手势的自定义交互控件未作为按钮暴露给辅助技术**。

### "元素不可访问"
**修复：** 使其成为无障碍元素。
```swift
// UIKit
customView.isAccessibilityElement = true
customView.accessibilityLabel = "Description"

// SwiftUI — 通常自动，但检查：
customView
    .accessibilityLabel("Description")
```

## 核心模式参考

**重要：** 始终为无障碍标签、值和提示使用**本地化字符串**。匹配项目的本地化模式（例如，UIKit 中的 `NSLocalizedString("close_button", comment: "")`，或 SwiftUI 中的 `Text("close_button")` 配合 `.xcstrings`）。

### 何时使用每个属性

**accessibilityLabel** — 元素名称
```swift
// UIKit
closeButton.accessibilityLabel = "Close"

// SwiftUI
Button("") { close() }
    .accessibilityLabel("Close")
```

**accessibilityValue** — 当前状态
```swift
// UIKit
slider.accessibilityValue = "50 percent"

// SwiftUI
Slider(value: $value, in: 0...100)
    .accessibilityValue("\(Int(value)) percent")
```

**accessibilityHint** — 额外上下文（谨慎使用；仅用于非显而易见的操作）
```swift
// UIKit
deleteButton.accessibilityHint = "Removes the item from your list"

// SwiftUI
Button("Delete") { delete() }
    .accessibilityHint("Removes the item from your list")
```

**accessibilityTraits** — 角色和状态
```swift
// UIKit
sectionTitle.accessibilityTraits.insert(.header)

// SwiftUI
Text("Section Title")
    .accessibilityAddTraits(.isHeader)
```

### 常见模式（UIKit）

**分组元素：**
```swift
cardView.isAccessibilityElement = true
cardView.accessibilityLabel = "\(title), \(subtitle)"
cardView.accessibilityTraits = .button
```

**自定义操作：**
```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Delete") { _ in
        self.delete()
        return true
    }
]
```

**可调节控件：**
```swift
// 对于有递增/递减的控件（滑块、步进器等）
customControl.accessibilityTraits = .adjustable
customControl.accessibilityLabel = "Volume"
customControl.accessibilityValue = "\(volume)%"

// 重写这些方法
override func accessibilityIncrement() {
    volume = min(volume + 10, 100)
    accessibilityValue = "\(volume)%"
}

override func accessibilityDecrement() {
    volume = max(volume - 10, 0)
    accessibilityValue = "\(volume)%"
}
```

**移动焦点：**
```swift
UIAccessibility.post(notification: .layoutChanged, argument: errorLabel)
```

### 常见模式（SwiftUI）

**分组元素：**
```swift
HStack {
    Image(systemName: "star.fill")
    Text("Favorite")
}
.accessibilityElement(children: .combine)
```

**自定义操作：**
```swift
.accessibilityAction(named: "Delete") {
    deleteItem()
}
```

**可调节控件：**
```swift
.accessibilityAdjustableAction { direction in
    switch direction {
    case .increment: value += 1
    case .decrement: value -= 1
    @unknown default: break
    }
}
```

**移动焦点（iOS 15+ 使用 [`AccessibilityFocusState`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate)）：**
```swift
@AccessibilityFocusState private var isFocused: Bool

// 将焦点移动到元素
Button("Submit") { submit() }
    .accessibilityFocused($isFocused)

// 触发焦点
isFocused = true
```

## 测试工作流

标准测试指导位于：
- `testing-manual.md` — 辅助技术和设置工作流
- `testing-automated.md` — 审计、UI 测试和 CI 护栏

在日常开发中使用以下快速序列：
1. **开发期间：** 运行 Accessibility Inspector 检查。
2. **PR 前：** 在关键流程上端到端验证 VoiceOver 和 Dynamic Type。
3. **回归防护：** 在能提供信号的地方添加或更新自动化检查。
4. **发布前：** 运行完整的手动测试清单。
5. **持续改进：** 尽可能包含残障用户的反馈。

## iOS 版本特定 API

一些无障碍功能需要特定 iOS 版本。在推荐这些 API 之前检查部署目标；尽可能提供回退。

### iOS 13+
- [Large Content Viewer (`UILargeContentViewerItem`)](https://developer.apple.com/documentation/uikit/uilargecontentvieweritem)、[`UILargeContentViewerInteraction`](https://developer.apple.com/documentation/uikit/uilargecontentviewerinteraction)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [`preferredContentSizeCategory.isAccessibilityCategory`](https://developer.apple.com/documentation/uikit/uicontentsizecategory/2897384-isaccessibilitycategory)

### iOS 14+
- [Switch Control 自定义操作图像 (`UIAccessibilityCustomAction.init(name:image:actionHandler:)`)](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction/init(name:image:actionhandler:))

### iOS 15+
- [`AccessibilityFocusState`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate) 用于编程焦点管理（SwiftUI）
- [`.accessibilityRotor`](https://developer.apple.com/documentation/swiftui/view/accessibilityrotor(_:entries:entryid:entrylabel:)) 用于自定义转子（SwiftUI）

### iOS 16+
- [`.accessibilityRepresentation`](https://developer.apple.com/documentation/swiftui/view/accessibilityrepresentation(representation:)) 用于自定义控件替代（SwiftUI）
- [`.accessibilityActions { }` 语法](https://developer.apple.com/documentation/swiftui/view/accessibilityactions(content:))

### iOS 17+
- [`.sensoryFeedback()`](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)) 用于触觉响应

## 常见场景 → 快速导航

使用此表快速找到特定问题的解决方案（以用户体验问题表述）：

| 场景 | 常见错误章节 | 参考文件 |
|----------|------------------------|----------------|
| 按钮在 VoiceOver 中不工作 | VoiceOver 不读取任何内容或"button" | `voiceover-*.md` |
| 单元格需要多次滑动 | VoiceOver 分别读取每个元素 | `voiceover-*.md`（分组） |
| 自定义控件读取多个"button" | VoiceOver 将自定义控件读取为许多独立元素 | `voiceover-*.md`（Adjustable） |
| 文本在大尺寸时截断 | 文本不随 Dynamic Type 缩放 | `dynamic-type-*.md` |
| 布局在大文本时破坏 | 布局在大文本尺寸时破坏 | `dynamic-type-*.md`（适应） |
| Toast 消失太快 | Toast/snackbar 在 VoiceOver 前消失 | `voiceover-*.md`（公告） |
| Voice Control 找不到按钮 | Voice Control 找不到或无法激活按钮 | `voice-control.md` |
| 图片在 Smart Invert 下异常 | 图片在 Smart Invert 下看起来异常 | `good-practices.md` |
| 自定义视图/按钮无法激活 | VoiceOver 无法激活自定义视图 | `voiceover-*.md`（特质） |
| 选中状态未传达 | 选中状态未传达 | `voiceover-*.md`（Selected 特质） |
| VoiceOver 无法按标题导航 | VoiceOver 用户无法按标题导航 | `voiceover-*.md`（Headers） |
| 装饰性图片在 VoiceOver 顺序中 | 装饰性图片可被 VoiceOver 到达 | `voiceover-*.md`（Hidden） |

## 最佳实践摘要

**目标：** 应用应支持辅助技术而不丢失任何内容或功能。将常见错误手册和反模式部分与此列表一起使用。

1. **为所有交互元素添加标签** — 每个按钮、控件和图片都需要标签或必须被隐藏
2. **正确使用特质** — 特质传达角色；不要仅依赖标签
3. **分组相关内容** — 减少滑动次数和认知负荷
4. **支持 Dynamic Type** — 使用文本样式，而非固定大小
5. **用辅助技术测试** — 自动化捕获基础；手动测试发现真实问题
6. **适当移动焦点** — 导航或错误后移动 VoiceOver 焦点
7. **提供替代方案** — 自定义手势需要无障碍回退
8. **遵循用户设置** — 尊重减弱动效、增强对比度、粗体文本
9. **多模态思考** — 不要仅依赖颜色；使用图标、文本、触觉
10. **与用户迭代** — 用真实反馈验证并持续改进

## 验证清单（修改后）

### 对于代理（自动化检查）

在建议或应用无障碍更改时使用这些检查：

- [ ] 构建成功且无新警告
- [ ] 运行现有单元测试；无新失败
- [ ] 对项目部署目标无破坏性 API 更改
- [ ] 使用的 API 与项目的 iOS 版本匹配（参见项目能力）
- [ ] 模式一致性：UIKit vs SwiftUI 与被编辑的文件匹配；标签/特质遵循现有项目风格
- [ ] Linter / 静态分析显示无新错误

### 对于开发者（手动测试）

在 PR 或发布前验证更改时使用此清单。代理可以建议这些步骤；开发者执行它们。

- [ ] **Accessibility Inspector**（Xcode > 窗口 > Accessibility Inspector > 审计）
  - 颜色对比度比例（文本 ≥4.5:1，UI 元素 ≥3:1）
  - 触摸目标大小（≥44×44 点）
  - 所有交互元素都有标签

- [ ] **VoiceOver**：启用 VoiceOver 端到端测试（尽可能在设备上；考虑屏幕变暗）
  - 浏览更改的视图
  - 验证标签、值、特质正确
  - 通过操作转子测试自定义操作
  - 通过标题转子测试标题导航
  - 确认状态变化后焦点适当移动

- [ ] **Dynamic Type**：用最大无障碍尺寸（无障碍 5）测试
  - 文本不截断
  - 布局适应（如需从水平到垂直）
  - 无内容或功能丢失

- [ ] **Voice Control**：用 Voice Control 测试关键流程
  - 说"Show names"并验证标签出现
  - 对主要交互元素说"Tap [元素名称]"

- [ ] **Full Keyboard Access**（如适用）：测试键盘导航
  - Tab 浏览所有交互元素
  - 所有交互元素都可到达
  - 焦点顺序合理

- [ ] **用户设置**：减弱动效、增强对比度、粗体文本、按钮形状、深色模式 — 测试应用适应且对比度保持足够

- [ ] **文档**：如更改则更新无障碍标识符（用于 UI 测试）；为 QA 注明手动测试要求；为变通方法或妥协添加代码注释

## 审查清单（快速检查）

### 标签和特质
- [ ] 所有交互元素都有标签
- [ ] 标签简洁且不包含控件类型
- [ ] 特质与角色匹配
- [ ] 状态变化更新值（并在相关时更新特质，例如 selected）

### 结构
- [ ] 相关元素已分组
- [ ] 装饰性元素已隐藏
- [ ] 导航顺序合理
- [ ] 状态变化后焦点移动

### Dynamic Type
- [ ] 文本随系统尺寸缩放
- [ ] 布局为大尺寸适应
- [ ] 无截断（除非有意的）

### 测试
- [ ] VoiceOver 端到端测试
- [ ] Dynamic Type 在无障碍尺寸测试
- [ ] Voice Control 可激活所有按钮
- [ ] 键盘导航工作正常

## 来源

- [Accessibility Up To 11](https://accessibilityupto11.com)
- [Developing Accessible iOS Apps](https://link.springer.com/book/10.1007/978-1-4842-5308-3)
