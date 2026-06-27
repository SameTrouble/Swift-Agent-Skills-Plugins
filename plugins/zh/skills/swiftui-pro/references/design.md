# 设计

## 在本应用中创建统一的设计

优先将标准字体、大小、颜色、栈间距、内边距、圆角、动画时长等放入一个共享的枚举常量中，以便所有视图都可以使用。这使得应用的设计感觉统一一致，且易于调整。


## 灵活、无障碍设计的要求

- 永远不要使用 `UIScreen.main.bounds` 来读取可用空间；优先使用 `containerRelativeFrame()`、`visualEffect()` 等替代方案，或者（在没有替代方案时）使用 `GeometryReader`。
- 除非内容能整齐地放入其中，否则优先避免为视图设置固定尺寸；这会在不同设备尺寸、不同 Dynamic Type 设置等情况下引发问题。通常最好给尺寸一些灵活性。
- Apple 在 iOS 上可接受的最小点击区域为 44x44。确保严格执行此标准。


## 标准系统样式

- 当数据缺失或为空时，强烈优先使用 `ContentUnavailableView`，而不是设计自定义内容。
- 使用 `searchable()` 时，可以使用 `ContentUnavailableView.search` 来显示空结果，它会自动包含用户使用的搜索词——无需使用 `ContentUnavailableView.search(text: searchText)` 或类似写法。
- 如果需要将图标和一些文本水平并排放置，优先使用 `Label` 而非 `HStack`。
- 尽可能优先使用系统层级样式（如 secondary/tertiary），而不是手动设置透明度，以便系统能自动适应正确的上下文。
- 使用 `Form` 时，将 `Slider` 等控件包装在 `LabeledContent` 中，以便标题和控件正确布局。
- `LabeledContent` 也可以在 `Form` 之外用于任何标题-值显示；可能需要定义自定义 `LabeledContentStyle` 以在各视图间保持一致的布局。
- 使用 `RoundedRectangle` 时，默认圆角样式是 `.continuous`——无需显式指定。


## 确保设计适用于所有人

- 使用 `bold()` 而非 `fontWeight(.bold)`，因为使用 `bold()` 允许系统为当前上下文选择正确的字重。
- 仅在有重要原因时才对非粗体字重使用 `fontWeight()`——到处散布 `fontWeight(.medium)` 或 `fontWeight(.semibold)` 会适得其反。
- 除非有明确要求，否则避免对内边距和栈间距使用硬编码值。
- 避免 SwiftUI 代码中使用 UIKit 颜色（`UIColor`）；使用 SwiftUI `Color` 或资产目录颜色。
- 字体大小 `.caption2` 非常小，通常最好避免使用。即使是 `.caption` 字体大小也偏小，应谨慎使用。
