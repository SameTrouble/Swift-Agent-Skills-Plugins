# 之前/之后：AppKit 无障碍

macOS AppKit 应用的具体代码转换。每个示例展示不可访问版本、修正版本以及每个更改的摘要。

优先级层级：
- **Blocks Assistive Tech** —— 元素完全不可达或不可用
- **Degrades Experience** —— 可达但摩擦显著
- **Incomplete Support** —— 阻止 Nutrition Label 声明的缺口

## 目录

### Blocks Assistive Tech
- 仅图标 NSButton 缺少标签
- 自定义 NSView 不在无障碍树中
- NSTableView 行无无障碍摘要

### Degrades Experience
- 自定义视图缺少键盘焦点
- 上下文菜单无键盘等价物
- 自定义控件角色错误

### Incomplete Support
- 硬编码字体大小（无 Dynamic Type）
- NSTableView 单元格中仅颜色状态

---

## [Blocks Assistive Tech] 仅图标 NSButton 缺少标签

**问题：** VoiceOver 朗读"button"但无描述。用户无法知道按钮的功能。
这通常发生在依赖自定义资产的支持仅图标控件上。

```swift
// ❌ 之前
let shareButton = NSButton()
shareButton.image = NSImage(named: "share")
shareButton.imageScaling = .scaleProportionallyDown
shareButton.isBordered = false
shareButton.bezelStyle = .toolbar
```

```swift
// ✅ 之后
let shareButton = NSButton()
shareButton.image = NSImage(named: "share")
shareButton.imageScaling = .scaleProportionallyDown
shareButton.isBordered = false
shareButton.bezelStyle = .toolbar
shareButton.setAccessibilityLabel("Share") // [VERIFY] confirm label matches intent
shareButton.toolTip = "Share"
```

**更改：**
| 更改 | 原因 |
|---|---|
| 两个版本中保持相同的仅图标视觉 | 将无障碍差异隔离到语义标记，而非视觉 |
| 添加 `setAccessibilityLabel("Share")` | 符合 AppKit 指导：控件而非其装饰图片拥有语义标签 |
| 保持自定义图片资产不变 | 确保改进来自语义，而非图片替换 |
| 添加 `toolTip` | 改善视力键盘和指针用户的可发现性 |

---

## [Blocks Assistive Tech] 自定义 NSView 不在无障碍树中

**问题：** 自定义绘制的卡片视图视觉上存在但 VoiceOver 完全无法到达。

```swift
// ❌ 之前
class ProjectCardView: NSView {
    var title: String = ""
    var status: String = ""

    override func draw(_ dirtyRect: NSRect) {
        // 自定义绘制...
    }
}
```

```swift
// ✅ 之后
class ProjectCardView: NSView {
    var title: String = "" {
        didSet { updateAccessibility() }
    }
    var status: String = "" {
        didSet { updateAccessibility() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        updateAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        updateAccessibility()
    }

    private func updateAccessibility() {
        setAccessibilityLabel("\(title), \(status)")
    }

    override func draw(_ dirtyRect: NSRect) {
        // 自定义绘制...
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `setAccessibilityElement(true)` | 将自定义绘制视图暴露给无障碍树 |
| 添加 `setAccessibilityRole(.group)` | 朗读语义容器角色而非通用未标记内容 |
| 添加 `updateAccessibility()` 和属性观察者 | 标题/状态变化时保持标签同步 |

---

## [Blocks Assistive Tech] NSTableView 行无无障碍摘要

**问题：** VoiceOver 朗读单个单元格但无法摘要行。用户听到的是无上下文的碎片化信息。

```swift
// ❌ 之前
class TaskRowView: NSTableRowView {
    var taskName: String = ""
    var assignee: String = ""
    var dueDate: String = ""
}
```

```swift
// ✅ 之后
class TaskRowView: NSTableRowView {
    var taskName: String = "" {
        didSet { updateAccessibility() }
    }
    var assignee: String = "" {
        didSet { updateAccessibility() }
    }
    var dueDate: String = "" {
        didSet { updateAccessibility() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        updateAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(true)
        updateAccessibility()
    }

    private func updateAccessibility() {
        setAccessibilityLabel(taskName)
        setAccessibilityValue("Assigned to \(assignee), due \(dueDate)")
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `setAccessibilityElement(true)` | 确保行本身可暴露简洁摘要 |
| 添加 `setAccessibilityLabel` | 提供主要行名（任务标题） |
| 添加 `setAccessibilityValue` | 添加次要上下文（分配者和截止日期） |
| 在观察者和初始化器中添加 `updateAccessibility()` | 防止行数据更新时过时的播报 |

---

## [Degrades Experience] 自定义视图缺少键盘焦点

**问题：** 可点击卡片响应鼠标点击但无法通过键盘到达或激活。

```swift
// ❌ 之前
class ClickableCardView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
```

```swift
// ✅ 之后
class ClickableCardView: NSView {
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Project card") // [VERIFY]
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Project card") // [VERIFY]
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 { // Return 或 Space
            onClick?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func drawFocusRingMask() {
        bounds.fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `acceptsFirstResponder` | 启用键盘焦点遍历 |
| 添加 `keyDown` 处理 Return/Space | 支持与鼠标输入的键盘激活对等 |
| 添加焦点环重写 | 使键盘焦点可见 |
| 添加无障碍角色和标签 | 将自定义视图作为可操作控件朗读 |

---

## [Degrades Experience] 上下文菜单无键盘等价物

**问题：** 右键菜单是访问操作的唯一方式。键盘和 VoiceOver 用户无法到达它们。

```swift
// ❌ 之前
class DocumentView: NSView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Duplicate", action: #selector(duplicateDocument), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(deleteDocument), keyEquivalent: ""))
        return menu
    }
}
```

```swift
// ✅ 之后
class DocumentView: NSView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let duplicateItem = NSMenuItem(title: "Duplicate", action: #selector(duplicateDocument), keyEquivalent: "d")
        duplicateItem.target = self
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteDocument), keyEquivalent: "\u{8}") // Delete 键
        deleteItem.target = self
        menu.addItem(duplicateItem)
        menu.addItem(deleteItem)
        return menu
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAccessibilityActions()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAccessibilityActions()
    }

    private func configureAccessibilityActions() {
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(
                name: "Duplicate",
                target: self,
                selector: #selector(duplicateDocument)
            ),
            NSAccessibilityCustomAction(
                name: "Delete",
                target: self,
                selector: #selector(deleteDocument)
            )
        ])
    }

    @objc private func duplicateDocument() {
        // 复制文档内容。
    }

    @objc private func deleteDocument() {
        // 删除文档内容。
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `keyEquivalent` 值 | 将右键操作暴露给键盘用户 |
| 添加显式菜单项 target | 使 selector 分发确定性 |
| 添加 `setAccessibilityCustomActions` | 在 VoiceOver Actions 转子中暴露仅菜单操作 |
| 添加 selector 方法实现 | 使之后示例自包含且可编译 |

---

## [Degrades Experience] 自定义控件角色错误

**问题：** 自定义开关暴露为通用组。VoiceOver 不将其作为开关朗读或报告其状态。

```swift
// ❌ 之前
class CustomToggleView: NSView {
    var isOn = false

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        needsDisplay = true
    }
}
```

```swift
// ✅ 之后
class CustomToggleView: NSView {
    var isOn = false {
        didSet {
            setAccessibilityValue(isOn ? "1" : "0")
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
        setAccessibilityLabel("Feature toggle") // [VERIFY]
        setAccessibilityValue(isOn ? "1" : "0")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
        setAccessibilityLabel("Feature toggle") // [VERIFY]
        setAccessibilityValue(isOn ? "1" : "0")
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
    }

    override func accessibilityPerformPress() -> Bool {
        isOn.toggle()
        return true
    }
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `setAccessibilityRole(.checkBox)` | 朗读正确控件类型而非通用组 |
| 添加 `setAccessibilityValue` 更新 | 为 VoiceOver 用户暴露开/关状态 |
| 添加 `accessibilityPerformPress()` | 启用从辅助技术激活 |
| 添加 `setAccessibilityLabel` | 提供稳定的、人类可读的控件名 |

---

## [Incomplete Support] 硬编码字体大小

**问题：** 文字不随系统 Dynamic Type 设置缩放。在系统设置中增大文字大小的 macOS 用户看不到变化。

```swift
// ❌ 之前
let titleLabel = NSTextField(labelWithString: "Project Name")
titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)

let bodyLabel = NSTextField(labelWithString: "Description")
bodyLabel.font = NSFont.systemFont(ofSize: 14)
```

```swift
// ✅ 之后
let titleLabel = NSTextField(labelWithString: "Project Name")
titleLabel.font = NSFont.preferredFont(forTextStyle: .headline)

let bodyLabel = NSTextField(labelWithString: "Description")
bodyLabel.font = NSFont.preferredFont(forTextStyle: .body)
```

**更改：**
| 更改 | 原因 |
|---|---|
| 用 `preferredFont(forTextStyle:)` 替换 `systemFont(ofSize:)` | 使用用户首选文字样式实现可缩放排版 |
| 使用语义样式（`.headline`、`.body`） | 保留内容层级同时适应文字大小偏好 |

---

## [Incomplete Support] NSTableView 单元格中仅颜色状态

**问题：** 绿/红点指示任务状态。在灰度或色盲用户看来，点不可区分。

```swift
// ❌ 之前
let statusDot = NSView()
statusDot.wantsLayer = true
statusDot.layer?.backgroundColor = task.isComplete ? NSColor.green.cgColor : NSColor.red.cgColor
statusDot.layer?.cornerRadius = 5
```

```swift
// ✅ 之后
let statusDot = NSView()
statusDot.wantsLayer = true
statusDot.layer?.backgroundColor = task.isComplete ? NSColor.systemGreen.cgColor : NSColor.systemRed.cgColor
statusDot.layer?.cornerRadius = 5
statusDot.setAccessibilityElement(false)

let statusIcon = NSImageView()
statusIcon.image = NSImage(
    systemSymbolName: task.isComplete ? "checkmark.circle.fill" : "xmark.circle.fill",
    accessibilityDescription: nil
)
statusIcon.contentTintColor = task.isComplete ? .systemGreen : .systemRed
statusIcon.setAccessibilityLabel(task.isComplete ? "Complete" : "Incomplete")
```

**更改：**
| 更改 | 原因 |
|---|---|
| 在颜色旁添加图标 | 不仅靠颜色区分状态 |
| 切换到语义颜色（`systemGreen` / `systemRed`） | 在外观和对比度设置间更好地适应 |
| 从无障碍中隐藏装饰性点 | 避免重复播报 |
| 在 `NSImageView` 上添加无障碍标签 | 朗读语义状态（`Complete` / `Incomplete`） |
