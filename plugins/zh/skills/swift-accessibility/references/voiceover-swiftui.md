# VoiceOver —— SwiftUI

## 目录
- [标签、提示、值](#标签提示值)
- [特质](#特质)
- [操作](#操作)
- [分组和结构](#分组和结构)
- [焦点管理](#焦点管理)
- [自定义转子](#自定义转子)
- [播报和实时区域](#播报和实时区域)
- [语音修饰符](#语音修饰符)
- [高级修饰符](#高级修饰符)
- [常见错误](#常见错误)

---

## 标签、提示、值

### `.accessibilityLabel(_:)`
VoiceOver 为任何非文字元素朗读的文字。仅图标按钮和图片必需。

```swift
// ✅ 好——简洁、不依赖上下文
Button(action: share) {
    Image(systemName: "square.and.arrow.up")
}
.accessibilityLabel("Share")

// ❌ 坏——包含控件类型（VoiceOver 自动添加"button"）
.accessibilityLabel("Share button")

// ❌ 坏——依赖上下文，单独无法理解
.accessibilityLabel("More")

// ❌ 坏——操作描述属于提示
.accessibilityLabel("Tap to share this post")
```

**`[VERIFY]` 规则：** 从 SF Symbol 名称或操作方法推断标签时，添加注释：
```swift
Button { deleteItem() } label: { Image(systemName: "trash") }
    .accessibilityLabel("Delete item") // [VERIFY] confirm label matches intent
```

### `.accessibilityHint(_:)`
简要描述激活元素的**结果**（而非操作本身）。VoiceOver 在短暂停顿后朗读。

```swift
Button("Save") { save() }
    .accessibilityHint("Saves your changes and closes the editor")

// ❌ 坏——描述操作而非结果
.accessibilityHint("Tap to save")

// ❌ 坏——与标签冗余
Button("Delete") { delete() }
    .accessibilityHint("Deletes") // 无意义
```

当结果从标签即可明显看出时，省略提示。

### `.accessibilityValue(_:)`
随时间变化的控件的当前值：滑块、步进器、进度指示器、非标准状态的开关。

```swift
Slider(value: $volume, in: 0...1)
    .accessibilityLabel("Volume")
    .accessibilityValue("\(Int(volume * 100)) percent")

// 自定义进度指示器
Circle()
    .trim(from: 0, to: progress)
    .accessibilityLabel("Upload progress")
    .accessibilityValue("\(Int(progress * 100)) percent complete")
```

不要用 `.accessibilityValue` 重复标签或附加静态文字。

### `.accessibilityIdentifier(_:)`
用于 UI 测试的稳定字符串。**VoiceOver 不会朗读。** 用于 `XCUITest` 元素查询。

```swift
TextField("Search", text: $query)
    .accessibilityIdentifier("searchField")
```

### `.accessibilityLabeledPair(role:id:in:)`
将标签与其对应控件配对（例如 `TextField` 旁边的 `Text` 标签）。

```swift
@Namespace var formNamespace

Text("Full name")
    .accessibilityLabeledPair(role: .label, id: "fullName", in: formNamespace)

TextField("", text: $name)
    .accessibilityLabeledPair(role: .content, id: "fullName", in: formNamespace)
```

---

## 特质

特质描述元素的**语义角色**和**状态**。VoiceOver 自动朗读它们（如"button"、"selected"、"header"）。

### 添加和移除特质

```swift
.accessibilityAddTraits(.isButton)
.accessibilityAddTraits([.isButton, .isSelected])
.accessibilityRemoveTraits(.isButton)
```

### 完整特质参考

| 特质 | 使用时机 |
|---|---|
| `.isButton` | 任何非原生 `Button` 的可点击元素 |
| `.isLink` | 打开 URL 或导航到应用外 |
| `.isHeader` | 分区标题（相当于 h1–h6） |
| `.isSelected` | 列表或标签页中当前选中的项 |
| `.isToggle` | 布尔开/关控件 |
| `.isImage` | 装饰性或信息性图片 |
| `.isSearchField` | 搜索输入框 |
| `.isStaticText` | 非交互文字 |
| `.playsSound` | 激活此元素会播放声音 |
| `.isKeyboardKey` | 自定义键盘按键 |
| `.updatesFrequently` | 作为实时区域播报更新 |
| `.causesPageTurn` | 触发翻页（例如在阅读器中） |
| `.allowsDirectInteraction` | 将原始触摸事件传递给视图 |
| `.isSummaryElement` | 应用启动时朗读（系统摘要） |

### 通过特质表达状态——而非标签

```swift
// ✅ 好——状态作为特质
Image(systemName: item.isStarred ? "star.fill" : "star")
    .accessibilityLabel("Favorite")
    .accessibilityAddTraits(item.isStarred ? .isSelected : [])

// ❌ 坏——状态嵌入标签（变化时需要重新朗读整个标签）
.accessibilityLabel(item.isStarred ? "Favorited" : "Not favorited")
```

---

## 操作

### `.accessibilityAction(_:_:)` —— 命名自定义操作

向 VoiceOver 的 Actions 转子添加条目。用于通过长按、滑动或上下文菜单可用的操作。

```swift
MessageRow(message: message)
    .accessibilityAction(named: "Reply") { replyTo(message) }
    .accessibilityAction(named: "Forward") { forward(message) }
    .accessibilityAction(named: "Delete") { delete(message) }
```

### `.accessibilityActions(_:)` —— 通过 ViewBuilder 添加多个操作

```swift
.accessibilityActions {
    Button("Archive") { archive(item) }
    Button("Share") { share(item) }
}
```

### `.accessibilityAdjustableAction(_:)` —— 递增/递减

用于自定义滑块、步进器或任何增减的值。

```swift
CustomRatingView(rating: $rating)
    .accessibilityLabel("Rating")
    .accessibilityValue("\(rating) out of 5 stars")
    .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: rating = min(5, rating + 1)
        case .decrement: rating = max(0, rating - 1)
        @unknown default: break
        }
    }
```

### `.accessibilityScrollAction(_:)` —— 滚动方向

用于不使用原生 `ScrollView` 的自定义可滚动内容。

```swift
.accessibilityScrollAction { edge in
    switch edge {
    case .top: scrollToTop()
    case .bottom: scrollToBottom()
    case .leading: scrollLeft()
    case .trailing: scrollRight()
    @unknown default: break
    }
}
```

### `.accessibilityZoomAction(_:)` —— 缩放手势

用于自定义地图、图片查看器或可缩放内容。

```swift
.accessibilityZoomAction { action in
    switch action.direction {
    case .zoomIn: scale *= 1.2
    case .zoomOut: scale /= 1.2
    @unknown default: break
    }
}
```

### `.accessibilityActivationPoint(_:)` —— 自定义点击目标

当无障碍点击点与视觉中心不同时使用。

```swift
// 点击自定义形状的底部中心
.accessibilityActivationPoint(CGPoint(x: frame.midX, y: frame.maxY - 8))
```

### 拖放

```swift
.accessibilityDragPoint(UnitPoint.center, description: "Drag to reorder")
.accessibilityDropPoint(UnitPoint.center, description: "Drop here to add")
```

---

## 分组和结构

### `.accessibilityElement(children:)`

**`.combine`** —— 将所有子元素合并为一个，按顺序朗读它们的标签。用于作为单个单元更有意义的相关 UI。

```swift
// ✅ 评分行朗读为"4.5 stars, 2,304 reviews"
HStack {
    Image(systemName: "star.fill")
    Text("4.5")
    Text("(2,304 reviews)")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("4.5 stars, 2,304 reviews")
```

**`.contain`** —— 分组元素但仍单独暴露每个子元素。用于需要组标签同时保留子元素可导航性的容器。

**`.ignore`** —— 向 VoiceOver 隐藏所有子元素。用于装饰性容器。

```swift
// 装饰性分隔符容器
HStack {
    Divider()
    Text("OR")
    Divider()
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Or")
```

### `.accessibilityChildren(_:)` —— 显式子元素列表

提供自定义子元素列表，覆盖默认树。

```swift
.accessibilityChildren {
    ForEach(items) { item in
        Text(item.title)
    }
}
```

### `.accessibilityHidden(_:)`

```swift
Image("decorative-background")
    .accessibilityHidden(true)

// 条件隐藏
Text(status)
    .accessibilityHidden(!isVisible)
```

### `.accessibilitySortPriority(_:)`

值越高越先朗读。默认为 0。

```swift
VStack {
    Text("Summary").accessibilitySortPriority(2)     // 先读
    Text("Details").accessibilitySortPriority(1)      // 第二读
    DismissButton().accessibilitySortPriority(-1)      // 最后读
}
```

## 焦点管理

### `@AccessibilityFocusState` + `.accessibilityFocused(_:)`

编程式地将 VoiceOver 焦点移到特定元素。

```swift
@AccessibilityFocusState private var isConfirmFocused: Bool

Button("Delete") { showConfirm = true }

if showConfirm {
    ConfirmationView()
        .accessibilityFocused($isConfirmFocused)
        .onAppear { isConfirmFocused = true }
}
```

### 使用枚举（多个元素）

```swift
enum FormField { case name, email, password }

@AccessibilityFocusState private var focusedField: FormField?

TextField("Name", text: $name)
    .accessibilityFocused($focusedField, equals: .name)

// 编程式移动焦点
Button("Next") { focusedField = .email }
```

### `.accessibilityDefaultFocus(_:_:)`

设置视图出现时默认接收焦点的元素（iOS 17+）。

```swift
VStack {
    HeaderView()
    PrimaryButton().accessibilityDefaultFocus($isDefault, true)
    SecondaryButton()
}
```

### `.accessibilityChildrenInNavigationOrder(_:)` —— 显式顺序

用显式序列覆盖默认导航顺序。

```swift
.accessibilityChildrenInNavigationOrder([heading, body, footer])
```

---

## 自定义转子

VoiceOver 转子允许用户在特定类型的元素之间跳转。自定义转子添加应用特定的导航。

### 基本自定义转子

```swift
.accessibilityRotor("Unread Messages") {
    ForEach(messages.filter(\.isUnread)) { message in
        AccessibilityRotorEntry(message.preview, id: message.id)
    }
}
```

### 文字范围转子

在 `Text` 元素内的范围之间导航。

```swift
Text(articleBody)
    .accessibilityRotor("Links") {
        ForEach(links) { link in
            AccessibilityRotorEntry(link.text, textRange: link.range)
        }
    }
```

### `accessibilityRotorEntry(id:in:)` —— 独立条目

```swift
ForEach(headings) { heading in
    Text(heading.text)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
        .accessibilityRotorEntry(id: heading.id, in: headingNamespace)
}
```

---

## 播报和实时区域

### 发送播报

当不在视图层级中的变化发生时使用（例如后台上传完成）。

```swift
// iOS 17+（首选）
AccessibilityNotification.Announcement("Upload complete").post()

// 旧语法
UIAccessibility.post(notification: .announcement, argument: "Upload complete")
```

### 屏幕变化（完整导航重置）

当整个屏幕内容变化时发送（例如手动 push 新视图）。

```swift
AccessibilityNotification.ScreenChanged().post()
// 或指定要聚焦的元素：
AccessibilityNotification.ScreenChanged(nil).post() // 系统默认焦点
```

### 布局变化（部分更新）

当屏幕部分变化时发送（例如分区展开、项目加载）。

```swift
AccessibilityNotification.LayoutChanged().post()
```

### 实时区域 —— `.updatesFrequently`

用于持续更新的标签（计时器、股价、状态指示器）。值变化时 VoiceOver 重新朗读。

```swift
Text(timerLabel)
    .accessibilityAddTraits(.updatesFrequently)
    .accessibilityLabel("Time remaining: \(timerLabel)")
```

---

## 语音修饰符

控制 VoiceOver 如何朗读特定元素的文字。

```swift
Text("Chapter 1: The Beginning")
    .speechAlwaysIncludesPunctuation()    // 始终朗读标点符号

Text("A.I.")
    .speechSpellsOutCharacters()          // 拼写："A dot I dot"

Text("Error: invalid input")
    .speechAdjustedPitch(0.5)            // 错误用更低音调（0.0–2.0）

// 排队播报而非打断
Text(statusMessage)
    .speechAnnouncementsQueued()
```

---

## 高级修饰符

### `.accessibilityCustomContent(_:_:importance:)` —— 分块信息

通过 VoiceOver"More Content"转子传递额外内容。用于不应一次性朗读的复杂项（联系人、邮件）。

```swift
ContactRow(contact: contact)
    .accessibilityLabel(contact.fullName)
    .accessibilityCustomContent("Phone", contact.phoneNumber, importance: .high)
    .accessibilityCustomContent("Email", contact.email)
    .accessibilityCustomContent("Company", contact.company, importance: .default)
```

### `.accessibilityRepresentation(representation:)` —— 替换无障碍树

用不同视图的树替换整个 VoiceOver 子树。用于复杂自定义控件。

```swift
CustomSlider(value: $value, range: 0...100)
    .accessibilityRepresentation {
        Slider(value: $value, in: 0...100)
            .accessibilityLabel("Brightness")
    }
```

### `.accessibilityTextContentType(_:)` —— 朗读风格

提示 VoiceOver 如何朗读文字（语速、停顿）。

```swift
Text(poemBody)
    .accessibilityTextContentType(.poetry)

// 可用类型：plain, fileSystem, messaging, narrative,
// poetry, reading, sourceCode, spreadsheet, wordProcessing
```

### `.accessibilityHeading(_:)` —— 标题级别

```swift
Text("Section Title")
    .accessibilityAddTraits(.isHeader)
    .accessibilityHeading(.h2)
```

### `.accessibilityIgnoresInvertColors(_:)` —— Smart Invert 保护

防止视图在 Smart Invert 启用时反转颜色。始终应用于图片、视频和地图。

```swift
AsyncImage(url: url) { image in
    image.resizable()
}
.accessibilityIgnoresInvertColors()
```

### `.accessibilityShowsLargeContentViewer()` —— Large Content Viewer

用于无法随 Dynamic Type 缩放的 UI 元素（标签栏、工具栏）。长按时显示放大版本。

```swift
// 无法增大的标签栏项
Label("Library", systemImage: "books.vertical")
    .accessibilityShowsLargeContentViewer()

// 带显式内容的自定义版本
TabItem()
    .accessibilityShowsLargeContentViewer {
        Label("Library", systemImage: "books.vertical")
    }
```

### `.accessibilityDirectTouch(_:options:)` —— 直通手势

用于即使 VoiceOver 活跃时也需要原始触摸输入的视图（绘图画布、钢琴键）。

```swift
DrawingCanvas()
    .accessibilityLabel("Drawing canvas")
    .accessibilityDirectTouch(.automatic, options: .silenceOnTouch)
```

### `.accessibilityChartDescriptor(_:)` —— 图表无障碍

为图表（Swift Charts 和自定义图表）提供完整数据描述。

```swift
Chart(data) { item in
    BarMark(x: .value("Month", item.month), y: .value("Sales", item.sales))
}
.accessibilityChartDescriptor(SalesChartDescriptor(data: data))

// Descriptor 实现：
struct SalesChartDescriptor: AXChartDescriptorRepresentable {
    let data: [SalesData]
    func makeChartDescriptor() -> AXChartDescriptor {
        AXChartDescriptor(
            title: "Monthly Sales",
            summary: "Sales increased 23% year-over-year",
            xAxis: AXCategoricalDataAxisDescriptor(title: "Month", categoryOrder: months),
            yAxis: AXNumericDataAxisDescriptor(title: "Revenue", range: 0...maxValue, gridlinePositions: []),
            series: [AXDataSeriesDescriptor(name: "Sales", isContinuous: false, dataPoints: points)]
        )
    }
}
```

---

## 常见错误

| 错误 | 修复 |
|---|---|
| 图标按钮缺少标签 | 添加 `.accessibilityLabel("Share")` |
| 标签包含控件类型："Save button" | 只用"Save"——VoiceOver 自动添加类型 |
| 标签描述操作："Tap to delete" | 只用"Delete"——提示描述结果 |
| 装饰性图片被朗读 | 添加 `.accessibilityHidden(true)` |
| 状态在标签中："Selected item" | 使用 `.accessibilityAddTraits(.isSelected)` |
| 嵌套 `accessibilityElement(children: .combine)` | 只有一层；扁平化结构 |
| 自定义可点击视图无特质 | 添加 `.accessibilityAddTraits(.isButton)` |
| 长按菜单无 VoiceOver 等价物 | 为每项添加 `.accessibilityAction(named:)` |
| `accessibilityValue` 重复标签 | 值仅用于动态数据 |
| `accessibilityLabel` 中硬编码字符串 | 使用 `LocalizedStringKey` 或 `Text` 进行本地化 |
| 每次渲染都在 `body` 中播报 | 响应事件发送播报，而非在渲染时 |
