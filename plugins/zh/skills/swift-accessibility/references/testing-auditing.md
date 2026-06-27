# 测试和审计

覆盖 Accessibility Inspector、SwiftUI Previews、XCTest / XCUITest、手动测试流程和常见审计发现——用于验证 Accessibility Nutrition Label 准备情况。

## 目录
- [Accessibility Inspector (Xcode)](#accessibility-inspector-xcode)
- [在 Xcode 中验证无障碍](#在-xcode-中验证无障碍)
- [XCUITest —— 自动化无障碍测试](#xcuitest----自动化无障碍测试)
- [手动测试清单](#手动测试清单)
- [常见审计发现](#常见审计发现)

---

## Accessibility Inspector (Xcode)

检查和审计无障碍的主要工具，无需真实设备。通过 Xcode → Open Developer Tool → Accessibility Inspector 获取。

### 检查模式

指向 Simulator 或连接的 Mac 应用中的任意元素。Inspector 显示：
- `accessibilityLabel`、`accessibilityHint`、`accessibilityValue`
- `accessibilityTraits`（button、header、selected 等）
- `accessibilityFrame`（点击目标大小，以点为单位）
- 容器信息

**用法：** 点击十字准星图标，然后在 Simulator 中悬停元素。验证每个元素报告正确的标签和特质。确认点击目标 ≥ 44×44pt。

### Audit 标签

对当前屏幕运行自动化检查。

```
Accessibility Inspector → Audit → Run Audit
```

发现包括：
- 交互元素缺少标签
- 低颜色对比度（与 WCAG 阈值比较）
- 触摸目标低于 44×44pt
- 特质与角色矛盾的元素
- 暴露给无障碍树的装饰性图片

**流程：** 在进行手动测试之前修复每个发现。将高严重性发现视为阻断项。

### 对比度检查器

```
Accessibility Inspector → Inspection → Color 标签 → 使用吸管
```

测量两种颜色之间的对比度比率。验证：
- 4.5:1 用于正常文字
- 3:1 用于大文字和非文字交互元素

测试每个颜色对：正文的前景/背景、按钮标签、占位符文字和状态指示器。

### Settings 标签（模拟无障碍设置）

在不更改实际设备配置的情况下模拟设备设置：
- Increase Contrast
- Reduce Motion
- Bold Text
- Button Shapes
- Reduce Transparency
- Grayscale（通过 Simulator）
- Dynamic Type 大小

---

## 在 Xcode 中验证无障碍

使用 Xcode 内置的 Canvas 工具和 Accessibility Inspector 测试无障碍配置，无需编写自定义预览代码。许多无障碍环境值（`colorSchemeContrast`、`accessibilityReduceMotion`、`accessibilityReduceTransparency`、`accessibilityDifferentiateWithoutColor`）是**只读**的——对这些值的 `.environment()` 调用可以编译但在运行时被**静默忽略**。改用 Accessibility Inspector（Settings 标签）或 Simulator 设置。

### Xcode Canvas Variants

预览画布底部有 **Variants** 按钮（网格图标）。点击选择：

| Variants 模式 | 显示内容 |
|---|---|
| **Dynamic Type Variants** | 你的视图并排以所有 12 种 Dynamic Type 大小渲染——捕获裁剪、重叠和截断 |
| **Color Scheme Variants** | 浅色和深色模式预览——捕获对比度失败和不可见边框 |
| **Orientation Variants** | 竖屏 + 横屏——捕获布局断裂 |

这是无需编写任何代码即可视觉验证 Dynamic Type 和深色模式的最快方式。

### Xcode Canvas Device Settings

预览画布底部有 **Device Settings** 按钮（滑块图标）。用它配置单个预览：

- **Color Scheme**：浅色 / 深色
- **Dynamic Type 大小**：12 种大小中的任意一种
- **Orientation**：竖屏 / 横屏

组合这些以测试特定场景（例如：深色模式 + 无障碍大文字 + 横屏）。

### Accessibility Inspector —— Settings 标签

对于只读无障碍设置，在 Simulator 上使用 Accessibility Inspector：

**打开：** Xcode 菜单 → Open Developer Tool → Accessibility Inspector

**Settings 标签** —— 在 Simulator 上切换这些而无需更改设备设置：

| 设置 | 模拟内容 |
|---|---|
| Increase Contrast | 测试 `colorSchemeContrast == .increased` |
| Reduce Motion | 测试 `accessibilityReduceMotion == true` |
| Bold Text | 测试 `legibilityWeight == .bold` |
| Reduce Transparency | 测试 `accessibilityReduceTransparency == true` |
| Button Shapes | 测试 `accessibilityShowButtonShapes == true` |
| Grayscale | 测试仅颜色指示器（通过 Simulator Color Filters） |
| Dynamic Type | 调整 Simulator 上的文字大小 |

**流程：** 启用每个设置，然后与 Simulator 交互以验证你的 UI 正确适配。

### `#Preview` 的可写环境值

仅这些无障碍相关值是可写的，可在 `#Preview` 中与 `.environment()` 一起使用：

```swift
#Preview("Large Text") {
    ProductCardView(product: .sample)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Dark Mode") {
    ProductCardView(product: .sample)
        .environment(\.colorScheme, .dark)
}
```

测试自适应布局断点：

```swift
#Preview("Before breakpoint") {
    AdaptiveCardView()
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("After breakpoint") {
    AdaptiveCardView()
        .environment(\.dynamicTypeSize, .accessibility1)
}
```

### 每个设置检查什么

| 设置 | 检查内容 |
|---|---|
| Dynamic Type（大尺寸） | 文字裁剪、元素重叠、截断标签无 `...` 提示 |
| Dark Mode | 不可读文字、不可见边框、低对比度图标 |
| Increase Contrast | 边框/分隔线可见、文字对比度改善 |
| Reduce Motion | 无动画播放、状态变化仍通过透明度/淡入淡出可见 |
| Grayscale | 状态指示器仍可通过形状/图标/文字区分 |
| Bold Text | 更重字重下布局不破坏 |

---

## XCUITest —— 自动化无障碍测试

### 通过无障碍标识符查找元素

```swift
// 在生产代码中设置稳定标识符
TextField("Search", text: $query)
    .accessibilityIdentifier("searchField")

Button("Submit") { submit() }
    .accessibilityIdentifier("submitButton")

// 在 UI 测试中查找
func testSearchFlow() throws {
    let app = XCUIApplication()
    app.launch()

    let searchField = app.textFields["searchField"]
    XCTAssert(searchField.exists, "Search field must exist")
    XCTAssert(searchField.isEnabled, "Search field must be enabled")

    searchField.tap()
    searchField.typeText("accessibility")

    let submitButton = app.buttons["submitButton"]
    XCTAssert(submitButton.exists)
    submitButton.tap()
}
```

### 通过无障碍标签查询

```swift
// 按标签查找（匹配 accessibilityLabel）
let shareButton = app.buttons["Share"]
XCTAssert(shareButton.exists)

// 按部分标签查找
let deleteButtons = app.buttons.matching(identifier: "Delete")
XCTAssert(deleteButtons.count > 0)
```

### 打印无障碍树

```swift
// 调试时无价——打印完整的可访问元素树
func testPrintTree() {
    let app = XCUIApplication()
    app.launch()
    print(app.debugDescription)
}
```

### 验证无障碍属性

```swift
func testProductCardAccessibility() throws {
    let app = XCUIApplication()
    app.launch()

    // 验证卡片是单个可访问元素
    let card = app.otherElements["Product Card"]
    XCTAssert(card.exists)

    // 验证标签有意义
    XCTAssertFalse(card.label.isEmpty, "Card must have an accessibility label")

    // 验证交互元素有标签
    let favoriteButton = app.buttons["Add to favorites"]
    XCTAssert(favoriteButton.exists, "Favorite button must have correct label")

    // 验证按钮足够大（间接通过存在性和交互）
    XCTAssert(favoriteButton.isHittable, "Favorite button must be tappable")
}
```

### 测试 VoiceOver 导航流程

```swift
func testVoiceOverReadingOrder() {
    let app = XCUIApplication()
    app.launchArguments = ["-UIAccessibilityEnabled", "YES"]
    app.launch()

    // 滑动穿过元素并验证顺序
    // 注意：XCUITest 中完整的 VoiceOver 模拟有限
    // 使用 Accessibility Inspector + 手动测试进行完整 VoiceOver 验证
}
```

### performAccessibilityAudit()（iOS 17+ / macOS 14+ / tvOS 17+ / watchOS 10+ / visionOS 1+）

在 XCUITest 内编程式运行 Accessibility Inspector 的审计引擎。在 CI 中自动捕获无障碍回归——无需手动检查。`XCUIAutomation` 框架的一部分。

#### API 签名

```swift
@MainActor func performAccessibilityAudit(
    for auditTypes: XCUIAccessibilityAuditType = .all,
    _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil
) throws
```

#### 审计类型

| 类型 | 检查内容 | 平台 |
|---|---|---|
| `.contrast` | WCAG 对比度比率（4.5:1 文字，3:1 非文字） | 所有 |
| `.elementDetection` | 无障碍树中缺失的元素 | 所有 |
| `.hitRegion` | 触摸目标小于 44×44pt | 所有 |
| `.sufficientElementDescription` | 缺失或空的无障碍标签 | 所有 |
| `.dynamicType` | 不随 Dynamic Type 缩放的文字 | 所有 |
| `.textClipped` | 大尺寸下裁剪或截断的文字 | 所有 |
| `.trait` | 不正确或缺失的无障碍特质 | 所有 |
| `.action` | 缺失或无效的无障碍操作 | 仅 macOS |
| `.parentChild` | 无障碍树中的父子关系问题 | 仅 macOS |

#### XCUIAccessibilityAuditIssue 属性

| 属性 | 类型 | 描述 |
|---|---|---|
| `auditType` | `XCUIAccessibilityAuditType` | 标记此问题的审计类型 |
| `element` | `XCUIElement?` | 有问题的元素（如不可识别则为 nil） |
| `compactDescription` | `String` | 问题简短描述 |
| `detailedDescription` | `String` | 带修复指导的完整描述 |

#### 基本用法 —— 运行所有检查

```swift
func testAccessibilityAudit() throws {
    let app = XCUIApplication()
    app.launch()

    // 运行所有审计类型——任何问题都导致测试失败
    try app.performAccessibilityAudit()
}
```

#### 按审计类型过滤

```swift
func testContrastAndLabels() throws {
    let app = XCUIApplication()
    app.launch()

    // 仅运行对比度和标签检查
    try app.performAccessibilityAudit(for: [.contrast, .sufficientElementDescription])
}
```

#### 忽略已知问题

使用问题处理闭包抑制已知问题。返回 `true` 忽略问题，`false` 在其上失败。使用 `compactDescription` 或 `detailedDescription` 进行调试。

```swift
func testAccessibilityAuditWithExclusions() throws {
    let app = XCUIApplication()
    app.launch()

    try app.performAccessibilityAudit(for: .all) { issue in
        // 记录问题详情以便调试
        print(issue.detailedDescription)

        // 忽略启动屏幕上的对比度问题（使用品牌颜色）
        if issue.auditType == .contrast,
           issue.element?.identifier == "splashLogo" {
            return true
        }
        return false
    }
}
```

#### 排除特定审计类型

```swift
func testAccessibilityAuditExcludingContrast() throws {
    let app = XCUIApplication()
    app.launch()

    var auditTypes: XCUIAccessibilityAuditType = .all
    auditTypes.remove(.contrast) // 跳过对比度检查

    try app.performAccessibilityAudit(for: auditTypes)
}
```

#### 多屏幕回归测试

使用这样的 UI 测试在一次运行中审计多个重要屏幕。
测试启动应用，导航通过关键流程，并在每个导航步骤后运行 `performAccessibilityAudit()`。
这有助于捕获常见回归，如缺失标签、低对比度、裁剪文字、小点击区域和不正确的特质。

```swift
class AccessibilityRegressionTests: XCTestCase {
    func testFullAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()

        // 审计启动屏幕。
        try app.performAccessibilityAudit()

        // 导航到 Settings 并审计该屏幕。
        app.tabBars.buttons["Settings"].tap()
        try app.performAccessibilityAudit()

        // 导航到 Profile 并审计该屏幕。
        app.tabBars.buttons["Profile"].tap()
        try app.performAccessibilityAudit()
    }
}
```

这不替代使用 VoiceOver、Voice Control、Switch Control 或真实设备检查的手动测试。
它仅审计测试实际访问的屏幕，因此扩展导航流程以覆盖应用中的重要用户路径。

---

## 手动测试清单

### VoiceOver 测试（需要真实设备）

启用：Settings → Accessibility → VoiceOver

| 测试 | 通过标准 |
|---|---|
| 右滑穿过所有元素 | 每个交互元素可达 |
| 点击任意元素 | 朗读标签、值和特质 |
| 双击交互元素 | 执行正确操作 |
| 在可调元素上上下滑动 | 值改变（滑块、步进器） |
| 模态上双指 Z 手势 | 模态关闭 |
| 转子导航 | 标题、链接、操作都可导航 |
| "Read All"（双指上滑） | 按逻辑顺序朗读整个屏幕 |
| 导航 push 后聚焦 | 焦点移到新屏幕的第一个元素 |
| 模态关闭后聚焦 | 焦点返回触发元素 |

**要测试的关键流程：**
1. 用 VoiceOver 从头到尾完成主要用户任务
2. 登录/账户创建
3. 关键购买或数据录入流程
4. 设置更改

### Voice Control 测试（需要真实设备）

启用：Settings → Accessibility → Voice Control

| 测试 | 通过标准 |
|---|---|
| "Show numbers" | 每个交互元素都有数字 |
| "Tap [数字]" | 激活正确元素 |
| "Show names" | 每个元素显示可见文字标签 |
| "Tap [标签]" | 语音激活元素 |
| "Type [文字]" | 在活动字段插入文字 |
| "Select [单词]" | 选择匹配的文字 |
| "Delete that" | 删除选中的文字 |
| "Scroll down/up" | 滚动内容 |

### Switch Control 测试（需要真实设备或设置）

启用：Settings → Accessibility → Switch Control

| 测试 | 通过标准 |
|---|---|
| 项目扫描 | 每个元素轮流高亮 |
| 组扫描 | 相关组作为单元高亮 |
| 选择高亮元素 | 触发正确操作 |
| 自定义操作可用 | 操作出现在扫描菜单中 |
| 无限时交互 | 无 UI 超时或自动前进 |

### Full Keyboard Access（iPad/Mac）

启用：Settings → Accessibility → Keyboards → Full Keyboard Access

| 测试 | 通过标准 |
|---|---|
| Tab 键 | 焦点向前穿过所有交互元素 |
| Shift+Tab | 焦点向后移动 |
| Space/Return | 激活聚焦元素 |
| Escape | 关闭模态/取消 |
| 方向键 | 在选择器、滑块内导航 |
| 无焦点间隙 | 焦点永不卡在死区 |

### Dynamic Type

启用：Settings → Accessibility → Display & Text Size → Larger Text → Enable Larger Accessibility Sizes

| 大小 | 测试 |
|---|---|
| 小 | 文字可读，无裁剪 |
| 大（默认） | 正常体验 |
| Accessibility Large | 布局适配，无重叠 |
| Accessibility 5（最大） | 所有内容可访问，无截断且无提示 |

### Grayscale（Differentiate Without Color）

启用：Settings → Accessibility → Display & Text Size → Color Filters → Grayscale

| 测试 | 通过标准 |
|---|---|
| 状态指示器 | 灰度下仍有意义 |
| 图表和图形 | 数据可通过形状/位置区分 |
| 错误状态 | 与成功清晰区分 |
| 所有 UI | 灰度下无信息丢失 |

### Reduce Motion

启用：Settings → Accessibility → Motion → Reduce Motion

| 测试 | 通过标准 |
|---|---|
| 导航转场 | 无滑动；改用溶解/淡入淡出 |
| 状态变化上的动画 | 要么移除要么用淡入淡出替换 |
| 自动播放内容 | 已停止或提供手动控制 |
| 加载动画 | 已替换或移除 |

### Dark Mode + Increase Contrast

启用：Settings → Appearance → Dark，AND Settings → Accessibility → Display & Text Size → Increase Contrast

| 测试 | 通过标准 |
|---|---|
| 所有文字 | 在深色背景下可读 |
| 边框和分隔线 | 可见 |
| 状态指示器 | 高对比度 |
| 深色背景上的图片 | 无白色光晕效果 |

---

## 常见审计发现

| 发现 | 严重性 | 检测方式 | 修复 |
|---|---|---|---|
| 仅图标按钮缺少标签 | Blocks Assistive Tech | Accessibility Inspector → 缺失标签警告 | `.accessibilityLabel("Share")` |
| 装饰性图片被朗读 | Degrades Experience | VO 朗读图片名或"image" | `.accessibilityHidden(true)` |
| 触摸目标 < 44pt | Degrades Experience | Inspector → Accessibility Frame < 44×44 | `.frame(minWidth: 44, minHeight: 44)` 或 `.contentShape` |
| 状态嵌入标签 | Degrades Experience | Inspector → 切换时标签变化 | 使用 `.accessibilityAddTraits(.isSelected)` |
| 阅读顺序错误 | Degrades Experience | VO 导航与视觉不匹配 | `.accessibilitySortPriority` 或 `accessibilityElements` |
| 仅颜色状态指示器 | Incomplete Support | 灰度滤镜测试 | 添加形状/图标/文字冗余 |
| 文字对比度深色模式失败 | Incomplete Support | Inspector 对比度检查器 | 使用语义颜色，两种模式都测试 |
| Reduce Motion 下播放动画 | Incomplete Support | 启用 Reduce Motion，检查运动 | 控制 `withAnimation` 或提供 `.opacity` 转场 |
| 长列表无自定义转子 | Incomplete Support | VoiceOver 导航测试 | 添加 `accessibilityRotor` |
| 模态不捕获 VoiceOver | Blocks Assistive Tech | VO 可到达背景内容 | `accessibilityViewIsModal = true` |
| push 后无焦点移动 | Degrades Experience | VO 停留在前一个屏幕 | 导航后发送 `.screenChanged` |
| 自定义文字任意大小截断 | Incomplete Support | Dynamic Type 最大大小测试 | `fixedSize()` → 滚动，或自适应布局 |
| 缺少 `accessibilityPerformEscape` | Blocks Assistive Tech | VO 双指 Z 不关闭 | 实现 `accessibilityPerformEscape()` |
| Voice Control 元素缺失 | Blocks Assistive Tech | "Show numbers"测试 | 使用 `Button` 或添加 `.accessibilityTraits(.button)` |
| 提示描述操作而非结果 | Degrades Experience | 听 VO 提示播报 | 重写："Saves your changes" 而非 "Tap to save" |

> **自动化提示：** `performAccessibilityAudit()`（iOS 17+）自动检测缺失标签、低对比度、小点击区域、裁剪文字、缺失特质和 Dynamic Type 失败。在 CI 中运行以在手动测试前捕获大部分这些发现。
