# 自动化测试

iOS 的自动化无障碍测试：UI 测试、静态分析和 Accessibility Inspector。

## 自动化能做什么

自动化工具擅长：
- 检测缺失标签
- 捕获代码更改后的回归
- 强制执行基线规则
- 标记明显问题（对比度、目标大小）

## 自动化不能做什么

自动化无法评估：
- 标签在上下文中是否有意义
- 导航顺序是否合理
- 体验是否真正可用
- 复杂交互的感受

**始终将自动化与手动测试结合。**

## 无障碍 UI 测试

### 使用 accessibilityIdentifier 进行测试

`accessibilityIdentifier` 用于测试自动化。`accessibilityLabel` 被 VoiceOver 读取。

```swift
// 在生产代码中
submitButton.accessibilityIdentifier = "submit-button"
submitButton.accessibilityLabel = "Submit order"
```

```swift
// 在 UI 测试中
let submitButton = app.buttons["submit-button"]
XCTAssertTrue(submitButton.exists)
```

### 断言无障碍属性

```swift
let cell = app.cells["order-cell"]
XCTAssertEqual(cell.label, "Order #1234, $42.00")
XCTAssertTrue(cell.accessibilityTraits.contains(.button))
```

### 以编程方式测试 VoiceOver 体验

查询无障碍树：

```swift
let app = XCUIApplication()
let elements = app.descendants(matching: .any).allElementsBoundByAccessibilityElement

for element in elements {
    if element.isHittable && element.label.isEmpty {
        XCTFail("Unlabeled element: \(element)")
    }
}
```

### 测试 Dynamic Type

以无障碍尺寸启动：

```swift
let app = XCUIApplication()
app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraLarge"]
app.launch()
```

## Accessibility Inspector 审计

### 启动

**Xcode > 打开开发者工具 > Accessibility Inspector**

### 运行审计

1. 选择目标（模拟器或设备）
2. 点击审计标签页
3. 点击"Run Audit"

### 常见审计发现

| 问题 | 修复 |
|-------|-----|
| 缺失标签 | 添加 `accessibilityLabel` |
| 对比度不足 | 增加颜色对比度 |
| 触摸目标小 | 扩大点击区域至 44×44 |
| 缺失特质 | 添加适当特质 |
| 图片标签是文件名 | 提供有意义的标签或隐藏装饰性图片 |

### 逐元素检查

1. 点击十字准线按钮
2. 点击模拟器中的元素
3. 查看其无障碍属性

### VoiceOver 预览

使用扬声器图标听 VoiceOver 如何读取当前屏幕。你可以逐步浏览元素或播放全部。

### 颜色对比度计算器

在 Accessibility Inspector 中：**窗口 > 颜色对比度计算器**用于快速对比度检查。

### 通知日志

**窗口 > 显示通知**以查看已发布的无障碍通知。

## SwiftUI Accessibility Inspector

在 Xcode 的检查器面板（右侧边栏）中，无障碍部分显示：
- 标签
- 值
- 特质
- 标识符

在画布中选择视图以查看其无障碍信息。

## SwiftLint 规则

添加 lint 规则以捕获常见问题：

```yaml
# .swiftlint.yml
custom_rules:
  image_accessibility:
    regex: 'Image\s*\(\s*\"[^\"]+\"\s*\)'
    message: "Image should have accessibilityLabel or use Image(decorative:)"
```

社区也存在用于强制无障碍的规则。

## 自动化对比度检查

### Accessibility Inspector

**窗口 > 显示颜色对比度计算器**

输入前景和背景颜色以检查比例。

### 编程检查

```swift
extension UIColor {
    func contrastRatio(with other: UIColor) -> CGFloat {
        let l1 = relativeLuminance
        let l2 = other.relativeLuminance
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    var relativeLuminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        
        func adjust(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        
        return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)
    }
}
```

### 对比度单元测试

```swift
func testButtonContrastMeetsMinimum() {
    let foreground = UIColor.white
    let background = UIColor.systemBlue
    let ratio = foreground.contrastRatio(with: background)
    XCTAssertGreaterThanOrEqual(ratio, 4.5, "Text contrast should be at least 4.5:1")
}
```

## 环境覆盖

在 Xcode 的调试区域工具栏中，点击环境覆盖按钮以测试：
- Dynamic Type 尺寸
- 增强对比度
- 减弱动效
- 减弱透明度
- 粗体文本

更改立即应用，无需重新构建。

## 持续集成

### 在 CI 中运行 UI 测试

```bash
xcodebuild test \
    -scheme MyApp \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -testPlan AccessibilityTests
```

### 无障碍测试计划

为无障碍检查创建专用测试计划。在每个 PR 上运行。

## 局限性

| 工具 | 覆盖范围 |
|------|----------|
| Accessibility Inspector 审计 | 约 30% 的问题 |
| UI 测试 | 回归、标签存在性 |
| SwiftLint | 仅代码模式 |

剩余 70%+ 需要手动测试。

## 清单

- [ ] 使用 `accessibilityIdentifier` 进行测试自动化
- [ ] UI 测试中有 `accessibilityLabel` 断言
- [ ] Accessibility Inspector 审计通过
- [ ] 自定义颜色对比度已检查
- [ ] 调试中测试环境覆盖
- [ ] 执行手动测试

## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
