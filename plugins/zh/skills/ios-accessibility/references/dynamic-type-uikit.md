# Dynamic Type — UIKit

Dynamic Type 和可缩放布局的 UIKit 实现。

如需核心概念，请参阅 `dynamic-type.md`。

## 目录

- [文本样式](#文本样式)
- [自定义字体](#自定义字体)
- [布局适应](#布局适应)
- [缩放非文本元素](#缩放非文本元素)
- [Large Content Viewer](#large-content-viewer)
- [Web 内容](#web-内容)
- [示例](#示例自适应卡片)

## 文本样式

```swift
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

**重要：** 设置 `adjustsFontForContentSizeCategory = true` 以在用户更改文本大小时自动更新。
如需按文本样式和内容大小类别的精确点大小，请参阅 Apple HIG：[iOS/iPadOS Dynamic Type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-Dynamic-Type-sizes)。

## 自定义字体

使用 `UIFontMetrics` 缩放自定义字体：

```swift
let customFont = UIFont(name: "Avenir-Medium", size: 17)!
let fontMetrics = UIFontMetrics(forTextStyle: .body)
label.font = fontMetrics.scaledFont(for: customFont)
label.adjustsFontForContentSizeCategory = true
```

## 多行标签

允许文本换行：

```swift
label.numberOfLines = 0
```

避免固定高度约束。

如果出于产品原因必须限制行数，在更大尺寸时放宽限制（例如，无障碍类别加倍或三倍）：

```swift
func updateLineLimit(for category: UIContentSizeCategory) {
    switch category {
    case .accessibilityExtraExtraExtraLarge:
        titleLabel.numberOfLines = 6   // 从 2 三倍
    case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge:
        titleLabel.numberOfLines = 4   // 从 2 加倍
    default:
        titleLabel.numberOfLines = 2
    }
}
```

## 检测无障碍尺寸

如需更大的无障碍类别及其参考大小，请参阅 Apple HIG：[iOS/iPadOS larger accessibility type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-larger-accessibility-type-sizes)。

```swift
if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
    // 无障碍尺寸（5 个最大尺寸之一）
}
```

### 比较尺寸类别

```swift
if traitCollection.preferredContentSizeCategory >= .accessibilityLarge {
    // Large 或更大
}
```

## 响应尺寸变化

### traitCollectionDidChange

```swift
override func traitCollectionDidChange(_ previous: UITraitCollection?) {
    super.traitCollectionDidChange(previous)
    if traitCollection.preferredContentSizeCategory != previous?.preferredContentSizeCategory {
        updateLayout()
    }
}
```

### 通知

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleSizeChange),
    name: UIContentSizeCategory.didChangeNotification,
    object: nil
)
```

## 布局适应

在更大文本尺寸时，从水平布局切换到垂直布局，以便文本可以跨全屏宽度流动。

### 翻转堆栈轴

```swift
func updateLayout() {
    stackView.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        ? .vertical
        : .horizontal
}
```

### 监听变化

```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
        updateLayout()
    }
}
```

### 示例：表格单元格

```swift
final class DrinkTableViewCell: UITableViewCell {
    @IBOutlet private weak var outerStackView: UIStackView!
    @IBOutlet private weak var drinkNameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Dynamic Type 字体
        drinkNameLabel.font = .preferredFont(forTextStyle: .body)
        drinkNameLabel.adjustsFontForContentSizeCategory = true
        
        updateLayout()
    }
    
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        if previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateLayout()
        }
    }
    
    private func updateLayout() {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            outerStackView.axis = .vertical
            outerStackView.alignment = .leading
            drinkNameLabel.numberOfLines = 0  // 无限行
        } else {
            outerStackView.axis = .horizontal
            outerStackView.alignment = .center
            drinkNameLabel.numberOfLines = 1
        }
    }
}
```

### 示例：步进器控件

```swift
class ExtraShotsView: UIView {
    @IBOutlet private weak var mainStackView: UIStackView!
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            mainStackView.axis = .vertical
        } else {
            mainStackView.axis = .horizontal
        }
    }
}
```

### 回退：超大内容的滚动视图

如果大文本仍然放不下，在无障碍尺寸时将屏幕嵌入滚动视图：

```swift
func updateLayout() {
    if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
        contentScrollView.isScrollEnabled = true
    } else {
        contentScrollView.isScrollEnabled = false
    }
}
```

### 切换为单列

```swift
let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
```

### 约束集

创建单独的约束集并根据尺寸激活：

```swift
var defaultConstraints: [NSLayoutConstraint] = []
var accessibilityConstraints: [NSLayoutConstraint] = []

func updateConstraints() {
    if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
        NSLayoutConstraint.deactivate(defaultConstraints)
        NSLayoutConstraint.activate(accessibilityConstraints)
    } else {
        NSLayoutConstraint.deactivate(accessibilityConstraints)
        NSLayoutConstraint.activate(defaultConstraints)
    }
}
```

## 可读内容指南

对于长篇文本，约束到 `readableContentGuide` 以获得舒适的行宽：

```swift
textView.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor).isActive = true
textView.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor).isActive = true
```

## 基线间距

使用系统基线间距而非固定常量：

```swift
subtitleLabel.firstBaselineAnchor.constraint(
    equalToSystemSpacingBelow: titleLabel.lastBaselineAnchor,
    multiplier: 1.0
).isActive = true
```

## 缩放非文本元素

使用 `UIFontMetrics.scaledValue(for:)` 缩放图标和其他 UI：

```swift
let baseHeight: CGFloat = 20
let scaledHeight = UIFontMetrics.default.scaledValue(for: baseHeight)
progressView.heightAnchor.constraint(equalToConstant: scaledHeight).isActive = true
```

## 缩放图片

```swift
imageView.adjustsImageSizeForAccessibilityContentSizeCategory = true
```

使用启用了**保留矢量数据**的 PDF/矢量资源。

### 优先使用带文本样式的 SF Symbols

SF Symbols 像字体一样缩放，可以绑定到文本样式：

```swift
iconImageView.image = UIImage(systemName: "xmark.octagon")
iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
```

这使图标大小与相邻文本保持同步。

## Large Content Viewer

对于不可缩放的元素（栏、紧凑控件），让用户点击并按住以查看放大的内容。

当 UI **无法随 Dynamic Type 缩放**时（导航栏、标签栏、工具栏）使用此功能。如果内容可以缩放，优先使用 Dynamic Type。

### 标签栏大预览资源

如果无法提供矢量 PDF，使用更大的位图图像作为预览：

```swift
// 为大预览提供更高分辨率的图像
tabBarItem.largeContentSizeImage = UIImage(named: "tab-large")
```

### 自定义栏元素

自定义视图需要显式标题/图像：

```swift
customBarView.addInteraction(UILargeContentViewerInteraction())
customBarButton.showsLargeContentViewer = true
customBarTabView.showsLargeContentViewer = true
customBarTabView.largeContentTitle = "Videos"
customBarTabView.largeContentImage = UIImage(named: "play")
```

### 协议实现

```swift
class CustomTabItem: UIView, UILargeContentViewerItem {
    var showsLargeContentViewer: Bool { true }
    var largeContentTitle: String? { "Home" }
    var largeContentImage: UIImage? { UIImage(systemName: "house") }
}

// 为容器添加交互
tabBar.addInteraction(UILargeContentViewerInteraction())
```

### 示例：带徽章的购物车按钮

```swift
class OrderButtonView: UIView {
    @IBOutlet private weak var orderButton: UIButton!
    
    private var numberOfItems: UInt = 0 {
        didSet {
            // 用当前计数更新 Large Content Viewer
            orderButton.largeContentTitle = "Cart, \(numberOfItems) items"
        }
    }
    
    func enableLargeContentViewer() {
        orderButton.showsLargeContentViewer = true
        orderButton.addInteraction(UILargeContentViewerInteraction())
    }
}
```

使用更大无障碍字号的用户可以点击并按住以在屏幕中央看到放大的按钮内容。

## Web 内容

在 `WKWebView` 中，在 CSS 中使用 Apple 系统字体——它们在 Apple 设备上自动遵循 Dynamic Type。始终为跨平台 HTML 包含回退字体：

```css
body {
    font: -apple-system-body;
}
h1 {
    font: -apple-system-headline;
    color: darkblue;
}
.footnote {
    font: -apple-system-footnote;
    color: gray;
}
```

当用户更改文本大小偏好时，Web 内容不会自动调整大小。监听 `UIContentSizeCategory.didChangeNotification` 并重新加载页面：

```swift
class WebViewController: UIViewController {
    @IBOutlet weak var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        loadContent()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    private func loadContent() {
        guard let baseURL = Bundle.main.resourceURL else { return }
        let fileURL = baseURL.appendingPathComponent("content.html")
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL)
    }

    @objc private func contentSizeCategoryDidChange() {
        webView.reload()
    }
}
```

> Apple CSS 字体名称的完整列表记录在 webkit.org/blog/3709/using-the-system-font-in-web-content/。

## Interface Builder

在 Interface Builder 中配置 Dynamic Type：
1. 选择标签
2. 在属性检查器中，为字体选择文本样式
3. 勾选"Automatically Adjusts Font"

## 示例：自适应卡片

```swift
class CardView: UIView {
    let stackView = UIStackView()
    let imageView = UIImageView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 0
        
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        addSubview(stackView)
        updateLayout()
    }
    
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateLayout()
    }
    
    func updateLayout() {
        stackView.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? .vertical
            : .horizontal
    }
}
```


## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
- https://github.com/Apress/developing-accessible-iOS-apps
- https://github.com/dadederk/fromZeroToAccessible（Daniel Devesa Derksen-Staats 和 Rob Whitaker）
