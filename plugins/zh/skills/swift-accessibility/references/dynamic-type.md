# Dynamic Type 和 Larger Text

Dynamic Type 让用户在系统范围内选择首选文字大小。应用必须支持它才能获得 **Larger Text** Accessibility Nutrition Label 资格。

## 目录
- [文字样式参考](#文字样式参考)
- [SwiftUI 实现](#swiftui-实现)
- [@ScaledMetric](#scaledmetric)
- [Large Content Viewer](#large-content-viewer)
- [自适应布局模式](#自适应布局模式)
- [UIKit 实现](#uikit-实现)
- [测试](#测试)
- [常见失败](#常见失败)

---

## 文字样式参考

始终使用文字样式——永远不要硬编码字体大小。文字样式随用户的首选大小自动缩放。

| 样式 | 默认大小 | 用例 |
|---|---|---|
| `.largeTitle` | 34pt | 主屏幕标题 |
| `.title` | 28pt | 分区标题 |
| `.title2` | 22pt | 子分区标题 |
| `.title3` | 20pt | 卡片或组标题 |
| `.headline` | 17pt（半粗） | 表格行标题、重要标签 |
| `.subheadline` | 15pt | 标题旁的辅助文字 |
| `.body` | 17pt | 主要阅读文字 |
| `.callout` | 16pt | 注释、旁注 |
| `.footnote` | 13pt | 细则、时间戳 |
| `.caption` | 12pt | 图片说明、次要标签 |
| `.caption2` | 11pt | 最小可读文字 |

---

## SwiftUI 实现

### 标准文字样式 —— 自动缩放

无需额外工作。SwiftUI 自动缩放这些样式。

```swift
// ✅ 随 Dynamic Type 缩放
Text("Welcome back")
    .font(.title)

Text("Your recent orders")
    .font(.headline)

// ❌ 硬编码——不会缩放
Text("Welcome back")
    .font(.system(size: 28))
```

### 自定义字体配合文字样式

```swift
// ✅ 随 body 文字样式缩放的自定义字体
Text("Note")
    .font(.custom("Merriweather-Regular", size: 17, relativeTo: .body))

// ❌ 固定大小的自定义字体
Text("Note")
    .font(.custom("Merriweather-Regular", size: 17))
```

### 读取 Dynamic Type 大小

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    if dynamicTypeSize >= .accessibility1 {
        // 大字体布局
        VStack(alignment: .leading) {
            avatar
            nameAndDetails
        }
    } else {
        // 标准布局
        HStack {
            avatar
            nameAndDetails
        }
    }
}
```

### `DynamicTypeSize` 参考

```
.xSmall  .small  .medium  .large (默认)  .xLarge  .xxLarge  .xxxLarge
.accessibility1  .accessibility2  .accessibility3  .accessibility4  .accessibility5
```

`.accessibility5` 是最大大小。在此大小下测试你的布局。

### 限制 Dynamic Type 大小

仅在布局确实无法容纳更大文字时才限制大小。始终提供替代方案。

```swift
// 限制紧凑缩略图——Large Content Viewer 补偿
ThumbnailView()
    .dynamicTypeSize(.xSmall ... .accessibility2)
    .accessibilityShowsLargeContentViewer()  // 限制时必需！
```

---

## @ScaledMetric

`@ScaledMetric` 按用户的文字大小偏好成比例缩放任何数值（间距、图标大小、圆角半径）。

```swift
struct ProfileRow: View {
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 16

    var body: some View {
        HStack(spacing: spacing) {
            Avatar()
                .frame(width: avatarSize, height: avatarSize)
            VStack(alignment: .leading, spacing: spacing / 3) {
                nameLabel
                timestampLabel
            }
        }
    }
}
```

**`relativeTo:`** —— 指定指标随哪个文字样式缩放。使用与相邻文字相同的样式。

```swift
// 随 body 文字缩放
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24

// 随 headline 文字缩放
@ScaledMetric(relativeTo: .headline) var rowHeight: CGFloat = 44
```

---

## Large Content Viewer

Large Content Viewer 为无法随 Dynamic Type 缩放的 UI 元素显示放大版本——通常是标签栏和工具栏等固定大小容器中的项。用户长按查看放大版本。

### 何时使用

当元素大小因布局原因被刻意约束且无法随 Dynamic Type 增大时使用。

- 标签栏项
- 工具栏按钮
- 徽章标签
- 使用自定义小尺寸时的导航栏标题

**不要作为替代**常规内容中支持 Dynamic Type 的方案。

### SwiftUI

```swift
// 标签栏项——由 TabView 自动处理
// 对于自定义固定大小元素：

Image(systemName: "bell.fill")
    .font(.system(size: 20))
    .frame(width: 44, height: 44)
    .dynamicTypeSize(.xSmall ... .accessibility2)  // 大小受限
    .accessibilityShowsLargeContentViewer()         // 必需！
    .accessibilityLabel("Notifications")

// 查看器中的自定义内容
Image(systemName: "bell.fill")
    .accessibilityShowsLargeContentViewer {
        Label("Notifications", systemImage: "bell.fill")
    }
```

### UIKit —— `UILargeContentViewerInteraction`

```swift
class CustomTabBarItem: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLargeContentViewer()
    }

    private func setupLargeContentViewer() {
        showsLargeContentViewer = true
        largeContentTitle = "Library"
        largeContentImage = UIImage(systemName: "books.vertical")

        let interaction = UILargeContentViewerInteraction()
        addInteraction(interaction)
    }
}
```

### Large Content Viewer 设计要求

- 最小元素高度：28pt（系统推荐：44pt）
- 简短标题（最多 1-2 个词）
- 清晰图标（SF Symbol 或简单自定义图片）

---

## 自适应布局模式

在大文字尺寸下，水平空间变得稀缺。常见适配：

### HStack → VStack 切换

```swift
@Environment(\.dynamicTypeSize) var typeSize

var body: some View {
    Group {
        if typeSize >= .accessibility1 {
            VStack(alignment: .leading, spacing: 8) { content }
        } else {
            HStack(spacing: 12) { content }
        }
    }
}

// 或使用 ViewThatFits（iOS 16+）——自动选择合适的布局
ViewThatFits {
    HStack { content }   // 先尝试
    VStack { content }   // HStack 不合适时的回退
}
```

### 截断策略

```swift
// ✅ 换行文字，不截断主要内容
Text(longTitle)
    .fixedSize(horizontal: false, vertical: true)   // 允许垂直扩展
    .lineLimit(nil)

// ✅ 截断次要内容，保持主要可读
HStack {
    Text(primaryLabel)
        .lineLimit(2)
    Text(secondaryLabel)
        .lineLimit(1)
        .foregroundStyle(.secondary)
}

// ❌ 截断唯一标签——VoiceOver 仍会朗读，但视觉上不可访问
Text(importantLabel)
    .lineLimit(1)
    .truncationMode(.tail)
```

### 避免固定高度

```swift
// ❌ 大尺寸下裁剪文字
.frame(height: 44)

// ✅ 最小高度且不受限增长
.frame(minHeight: 44)

// ✅ 或让 SwiftUI 自然布局
// （HStack/VStack 子元素增长以适应其内容）
```

---

## UIKit 实现

### 文字样式 —— `UIFont.preferredFont`

```swift
// ✅ 随 Dynamic Type 缩放
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true  // 更新必需

// ❌ 固定大小——不缩放
label.font = UIFont.systemFont(ofSize: 17)
```

`adjustsFontForContentSizeCategory = true` 至关重要——没有它，字体只设置一次，用户改变文字大小时不会更新。

### 自定义字体配合 `UIFontMetrics`

```swift
let customFont = UIFont(name: "Merriweather-Regular", size: 17)!
label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: customFont)
label.adjustsFontForContentSizeCategory = true
```

### 缩放非字体值

```swift
// 缩放间距、图标大小等
let baseSpacing: CGFloat = 8
let scaledSpacing = UIFontMetrics.default.scaledValue(for: baseSpacing)

// 相对于特定文字样式缩放
let bodyMetrics = UIFontMetrics(forTextStyle: .body)
let iconSize = bodyMetrics.scaledValue(for: 24)
```

### 响应大小变化

```swift
// iOS 17 之前：
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) { // Deprecated in iOS 17
    super.traitCollectionDidChange(previousTraitCollection)

    if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
        updateLayout()
    }
}

// iOS 17+ 替代：
registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
    self.updateLayout()
}

// 或观察通知（所有版本可用）
NotificationCenter.default.addObserver(
    self,
    selector: #selector(contentSizeCategoryDidChange),
    name: UIContentSizeCategory.didChangeNotification,
    object: nil
)
```

### `UIContentSizeCategory` 参考

```swift
// 从最小到最大的顺序：
let categoriesInOrder: [UIContentSizeCategory] = [
    .extraSmall,
    .small,
    .medium,
    .large, // 默认
    .extraLarge,
    .extraExtraLarge,
    .extraExtraExtraLarge,
    .accessibilityMedium,
    .accessibilityLarge,
    .accessibilityExtraLarge,
    .accessibilityExtraExtraLarge,
    .accessibilityExtraExtraExtraLarge
]

// 检查是否激活了无障碍大小
let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
```

### SF Symbols 随文字缩放

```swift
// 随相邻 body 文字缩放符号
let config = UIImage.SymbolConfiguration(textStyle: .body)
imageView.image = UIImage(systemName: "star.fill", withConfiguration: config)

// 缩放到特定点大小
let sizedConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
imageView.image = UIImage(systemName: "heart.fill", withConfiguration: sizedConfig)?
    .applyingSymbolConfiguration(.preferringMulticolor()) // 附加配置
```

---

## 测试

### 最低测试要求

| 大小 | 类别 | 设置 |
|---|---|---|
| 小 | `.small` | Settings → Display & Text Size |
| 默认 | `.large` | 默认 |
| 大 | `.extraExtraLarge` | ~150% 缩放 |
| 最大 | `.accessibilityExtraExtraExtraLarge` | 200%+ |
| watchOS 最大 | — | 140%+ |

### SwiftUI Preview 测试

```swift
// 在特定大小下测试
#Preview("Large Accessibility Size") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Default Size") {
    ContentView()
        .environment(\.dynamicTypeSize, .large)
}
```

### Xcode Simulator

在 Simulator 中：Hardware → Device Settings → Increase Contrast + Dynamic Text → 拖到最大。

或在 Accessibility Inspector（macOS）中：连接到 Simulator 并调整字体大小。

---

## 常见失败

| 失败 | 修复 |
|---|---|
| `.font(.system(size: 17))` | 使用 `.font(.body)` |
| 固定 frame 裁剪文字 | 使用 `.frame(minHeight: 44)` 而非 `height: 44` |
| HStack 在大尺寸下溢出 | 切换到 `VStack` 或 `ViewThatFits` |
| 自定义字体不缩放 | 在 `.custom()` 中添加 `relativeTo:` 或使用 `UIFontMetrics` |
| 缺少 `adjustsFontForContentSizeCategory` | 在所有标签上设为 `true` |
| 图标大小保持固定 | 使用 `@ScaledMetric` 或 `UIFontMetrics.scaledValue` |
| 标签栏项未显示 Large Content Viewer | 显式添加 `.accessibilityShowsLargeContentViewer()` |
| 单行截断丢失信息 | 使用 `.lineLimit(nil)` 或提供点击后的详情视图 |
| 缺少语言测试 | 测试德语（长词）、阿拉伯语（RTL）、日语（高字符） |
