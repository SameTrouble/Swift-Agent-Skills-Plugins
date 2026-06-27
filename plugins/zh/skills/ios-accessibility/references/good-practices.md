# 良好实践

横切无障碍指导：触摸目标、颜色对比度、动效、透明度、触觉和多模态设计。

## 目录

- [触摸目标大小](#触摸目标大小)
- [颜色对比度](#颜色对比度)
- [不要仅依赖颜色](#不要仅依赖颜色)
- [避免图片中的文本](#避免图片中的文本)
- [媒体无障碍](#媒体无障碍)
- [听觉适配](#听觉适配)
- [减弱动效](#减弱动效)
- [减弱透明度](#减弱透明度)
- [视频播放偏好](#视频播放偏好)
- [语义颜色](#语义颜色)
- [粗体文本](#粗体文本)
- [按钮形状](#按钮形状)
- [触觉反馈](#触觉反馈)
- [键盘快捷键](#键盘快捷键)
- [多模态信息](#多模态信息)
- [多种输入路径](#多种输入路径)
- [方向支持](#方向支持)
- [避免临时反馈](#避免临时反馈)
- [共享图片的替代文本](#共享图片的替代文本)
- [Smart Invert](#smart-invert)
- [反转颜色（经典）](#反转颜色经典)
- [开关和切换](#开关和切换)
- [可穿戴设备](#可穿戴设备)
- [清单](#清单)

## 触摸目标大小

Apple 建议最小可点击区域为 **44×44 点**。

同时尽量保持目标**至少相隔 32 点**以减少误触，特别是对于有震颤或低视力的用户。

如果无法增加间距，请使用 insets 或 `contentShape` 增加点击区域。

### 常见违规

- 导航栏按钮
- 自定义工具栏图标
- 关闭/取消按钮
- 行内文本链接

### 修复小目标

在不改变外观的情况下扩大点击区域：

**UIKit**:
```swift
button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
```

或重写 `point(inside:with:)`：
```swift
override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.insetBy(dx: -10, dy: -10).contains(point)
}
```

**SwiftUI**:
```swift
Button(action: dismiss) {
    Image(systemName: "xmark")
        .padding(12)
}
.contentShape(Rectangle())
```

## 颜色对比度

### 最低比例（WCAG 2.1）

| 文本大小 | 比例 |
|-----------|-------|
| 普通文本（<18pt） | 4.5:1 |
| 大文本（≥18pt 或 14pt 粗体） | 3:1 |
| 非文本（图标、边框） | 3:1 |

### 测试对比度

- **Accessibility Inspector**：窗口 > 颜色对比度计算器
- 在线工具：WebAIM Contrast Checker

### 高对比度支持

为**增强对比度**设置提供替代颜色：

**Asset Catalog**：添加高对比度外观变体。

**UIKit**:
```swift
if UIAccessibility.isDarkerSystemColorsEnabled {
    label.textColor = .label // 更高对比度
}
```

**SwiftUI** — 检查环境：
```swift
@Environment(\.colorSchemeContrast) private var contrast

var buttonColor: Color {
    contrast == .increased ? .primary : .accentColor
}

var body: some View {
    Button(action: action) {
        Text(title)
    }
    .foregroundStyle(buttonColor)
}
```

语义系统颜色（`.primary`、`.secondary`）会自动适应，但在需要自定义行为时使用 `colorSchemeContrast`。

## 不要仅依赖颜色

色盲用户或启用了**不使用颜色区分**的用户需要额外的提示。

### 错误做法

```swift
statusLabel.textColor = status == .error ? .red : .green
```

### 正确做法

```swift
statusLabel.text = status == .error ? "⚠️ Error" : "✓ Success"
statusLabel.textColor = status == .error ? .systemRed : .systemGreen
```

在颜色之外使用图标、形状、图案或文本。

## 避免图片中的文本

嵌入图片中的文本无法被 VoiceOver 读取，无法用 Dynamic Type 缩放，也无法本地化。

尽可能使用真实文本。如果必须使用包含文本的图片：
- 提供本地化的 `accessibilityLabel`
- 需要时按语言替换图片
- 优先使用矢量 PDF，以便图片在更大尺寸时保持清晰

## 媒体无障碍

如果你的应用播放音频或视频，提供多种方式访问内容：

- 为所有语音内容提供**字幕/隐藏式字幕**
- 可用时提供 **SDH**（为失聪和听力受损者提供的字幕）
- 为视觉重要内容提供**音频描述**
- 为长篇音频/视频提供**文字稿**

尽可能将系统字幕偏好设为默认。

## 听觉适配

对于失聪或听力受损的用户，包含声音的替代方案：

- **LED 闪烁提醒**（系统设置）是用户注意到通知的常见方式
- **单声道音频**帮助单耳听力受损的用户
- **音频平衡**让用户偏重左/右声道

如果你的应用提供自定义音频控制，避免破坏系统偏好。

### 检查设置

```swift
if UIAccessibility.shouldDifferentiateWithoutColor {
    // 添加额外视觉提示
}
```

## 减弱动效

用户启用**减弱动效**以最小化前庭触发。

### 遵循设置

**UIKit**:
```swift
if UIAccessibility.isReduceMotionEnabled {
    // 使用淡入淡出而非滑动
    // 禁用视差
    // 停止自动播放动画
}
```

**SwiftUI** — 环境值：
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(reduceMotion ? nil : .default, value: isExpanded)
```

### 在用户交互期间检查

对于交互期间（滑块、拖动）的实时检查，使用 UIKit API：

```swift
.onChange(of: sliderValue) { _, newValue in
    let reduceMotion = UIAccessibility.isReduceMotionEnabled
    
    if !reduceMotion {
        // 在拖动期间动画化 UI 更新
        withAnimation(.easeInOut(duration: 0.3)) {
            updateVisualFeedback(newValue)
        }
    } else {
        // 跳过动画，立即更新
        updateVisualFeedback(newValue)
    }
}
```

### 示例：带条件动画的滑块

```swift
Slider(value: $progress)
    .onChange(of: progress) { _, newValue in
        if !UIAccessibility.isReduceMotionEnabled {
            withAnimation { currentLineIndex = calculateLine(newValue) }
        } else {
            currentLineIndex = calculateLine(newValue)
        }
    }
```

### 观察变化

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleReduceMotion),
    name: UIAccessibility.reduceMotionStatusDidChangeNotification,
    object: nil
)
```

## 减弱透明度

当启用**减弱透明度**时简化半透明背景：

**UIKit**:
```swift
override func awakeFromNib() {
    super.awakeFromNib()
    
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(updateBackground),
        name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
        object: nil
    )
    updateBackground()
}

@objc private func updateBackground() {
    let opacity = UIAccessibility.isReduceTransparencyEnabled ? 1.0 : 0.9
    backgroundView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(opacity)
}
```

**注意：** `UIVisualEffectView` 和系统导航栏已遵循减弱透明度。视图上的自定义 alpha 不会——需手动处理。

**SwiftUI**:
```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var body: some View {
    Text(message)
        .background(Color(UIColor.secondarySystemBackground)
            .opacity(reduceTransparency ? 1.0 : 0.90))
}
```

## 视频播放偏好

### 自动播放视频预览

对于动效较多的预览，遵循系统自动播放偏好：

```swift
// 使用系统偏好作为默认
if UIAccessibility.isVideoAutoplayEnabled {
    startPreviewPlayback()
} else {
    showStaticThumbnail()
}

// 观察变化
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleAutoplayPreferenceChange),
    name: UIAccessibility.videoAutoplayStatusDidChangeNotification,
    object: nil
)
```

如果你也有应用内偏好，使用系统设置作为默认，并让用户显式覆盖。

### 隐藏式字幕

如果你的应用播放视频，遵循系统字幕偏好：

```swift
if UIAccessibility.isClosedCaptioningEnabled {
    enableClosedCaptions()
}
```

可用时优先使用 **SDH**（为失聪和听力受损者提供的字幕）。

## 语义颜色

使用语义系统颜色以获得更好的对比度和自动浅色/深色模式支持：

**UIKit**:
```swift
// 而不是：
label.textColor = UIColor.darkGray

// 使用：
label.textColor = .secondaryLabel

// 常用语义颜色：
// .label            - 主要文本
// .secondaryLabel   - 次要文本（适应深色模式 + 增强对比度）
// .systemBackground - 主要背景
// .secondarySystemBackground - 次要背景
```

**SwiftUI**:
```swift
Text("Title")
    .foregroundStyle(.primary)
Text("Subtitle")
    .foregroundStyle(.secondary)
```

使用语义颜色可以免费获得浅色/深色模式和增强对比度支持（4 种组合）。

## 粗体文本

当启用**粗体文本**时，系统字体会自动变粗。自定义字体和非文本元素需要手动处理。

**UIKit**:
```swift
if UIAccessibility.isBoldTextEnabled {
    label.font = UIFont(name: "Avenir-Heavy", size: 17)
} else {
    label.font = UIFont(name: "Avenir-Medium", size: 17)
}
```

对于 SF Symbols，使用加权变体：

```swift
let config = UIImage.SymbolConfiguration(weight: UIAccessibility.isBoldTextEnabled ? .bold : .regular)
imageView.preferredSymbolConfiguration = config
```

**SwiftUI** — 使用 `legibilityWeight` 环境：
```swift
@Environment(\.legibilityWeight) private var legibilityWeight

var fontWeight: Font.Weight {
    legibilityWeight == .bold ? .bold : .regular
}

Text("Content")
    .fontWeight(fontWeight)
```

### 用粗体文本缩放非文本元素

增加边框宽度、图标权重和其他视觉元素：

```swift
@Environment(\.legibilityWeight) private var legibilityWeight
@ScaledMetric(relativeTo: .body) private var baseBorderWidth: CGFloat = 2.0

private var borderWidth: CGFloat {
    legibilityWeight == .bold ? baseBorderWidth * 2 : baseBorderWidth
}

var body: some View {
    content
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.tint, lineWidth: borderWidth)
        )
}
```

系统字体会自动适应——将 `legibilityWeight` 用于自定义视觉元素。

## 按钮形状

当启用**按钮形状**时，按钮显示下划线或边框。标准按钮自动处理此功能；自定义按钮可能需要关注。

**UIKit**:
```swift
if UIAccessibility.buttonShapesEnabled {
    // 为自定义按钮添加视觉边框或下划线
}
```

**SwiftUI**:
```swift
@Environment(\.accessibilityShowButtonShapes) private var showButtonShapes

var body: some View {
    Button(action: onTap) {
        Text(title)
            .padding()
    }
    .overlay {
        if showButtonShapes {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.primary, lineWidth: 1)
        }
    }
}
```

### 示例：自定义列表行按钮

```swift
struct TranscriptLineView: View {
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes
    
    var body: some View {
        Button(action: onTap) {
            content
                .background(backgroundColor)
                .overlay(buttonShapeOverlay)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var buttonShapeOverlay: some View {
        if showButtonShapes {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.primary, lineWidth: 1)
        }
    }
}
```

## 触觉反馈

使用触觉来强化重要事件——但绝不能作为唯一的反馈渠道。

```swift
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success) // .warning, .error
```

```swift
let impact = UIImpactFeedbackGenerator(style: .medium)
impact.impactOccurred()
```

使用 `.success` 表示完成，`.warning` 表示警告，`.error` 表示失败。

当反馈风格很重要时（例如节奏游戏、计时器、教练提示），让用户控制各渠道（音频、触觉、视觉），而不是强制一种输出模式。

## 键盘快捷键

为 iPad 和外部键盘的关键操作提供快捷键。

**UIKit**:
```swift
override var keyCommands: [UIKeyCommand]? {
    [
        UIKeyCommand(title: "Refresh", action: #selector(refresh), input: "r", modifierFlags: .command),
        UIKeyCommand(title: "Search", action: #selector(search), input: "f", modifierFlags: .command)
    ]
}
```

**SwiftUI**:
```swift
Button("Refresh", action: refresh)
    .keyboardShortcut("r", modifiers: .command)
```

用户按住 Command 键时会出现快捷键。

## 多模态信息

通过多种渠道传达重要信息：

| 渠道 | 示例 |
|---------|---------|
| 视觉 | 错误图标 |
| 文本 | "密码太短" |
| 颜色 | 红色文本 |
| 触觉 | 错误反馈 |
| 声音 | 警报音 |

绝不要依赖单一渠道。

## 多种输入路径

对于时间敏感或精度要求高的流程（例如游戏、媒体控制、绘图工具），避免强制一种交互方式。

尽可能提供至少两条可靠的输入路径：
- 触摸手势和屏幕控件
- 硬件键盘快捷键
- 外部控制器或替代导航模式

这改善了一致性，适用于无法持续执行特定手势模式的用户。

## 方向支持

尽可能同时支持竖屏和横屏。不要强制用户旋转设备。

```swift
override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    .all
}
```

一些用户以固定方向安装设备。

## 避免临时反馈

快速消失的 snackbar 和 toast 存在问题：

- VoiceOver 用户可能会错过它们
- Zoom 用户看不到它们
- 阅读速度慢的用户来不及读完

对于关键信息，使用：
- 持久横幅
- 确认对话框
- 行内错误消息

## 共享图片的替代文本

如果你的应用允许用户共享图片，提供添加替代文本的方式：

```swift
let attachment = UIDragItem(itemProvider: provider)
attachment.localObject = ["image": image, "altText": altText]
```

Twitter 和 Slack 等平台在这方面做得很好。

## Smart Invert

防止图片和媒体随 Smart Invert 反转：

```swift
imageView.accessibilityIgnoresInvertColors = true
videoPlayer.accessibilityIgnoresInvertColors = true
```

## 反转颜色（经典）

一些用户启用**反转颜色**（设置 > 无障碍 > 显示与文本大小）。如果你使用自定义颜色组合，可能需要在启用反转时进行调整。

```swift
if UIAccessibility.isInvertColorsEnabled {
    // 如需调整自定义颜色
    contentView.backgroundColor = .systemBackground
}

NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleInvertColorsChange),
    name: UIAccessibility.invertColorsStatusDidChangeNotification,
    object: nil
)

@objc private func handleInvertColorsChange() {
    // 设置变化时更新自定义颜色
}
```

避免仅依赖颜色——使用图标和标签提供上下文，这样反转不会移除含义。

## 开关和切换

将开关与其标签分组：

**UIKit**:
```swift
// 将开关放在表格视图单元格的附件中
cell.accessoryView = toggle
cell.accessibilityLabel = "Notifications"
cell.accessibilityValue = toggle.isOn ? "On" : "Off"
```

**SwiftUI**:
```swift
Toggle("Notifications", isOn: $notificationsEnabled)
```

标准 `Toggle` 自动处理无障碍。

### 公布设置变化

当切换影响其他设置或有副作用时，公布变化：

```swift
Toggle("Respect Assistive Technology Settings", isOn: $prefersATSettings)
    .onChange(of: prefersATSettings) { _, newValue in
        // 更新相关设置
        if newValue {
            customVoiceEnabled = false
        }
        
        // 公布变化
        announceChange(newValue 
            ? "Custom voice disabled" 
            : "Custom voice enabled"
        )
    }

private func announceChange(_ message: String) {
    Task { @MainActor in
        // 小延迟确保 VoiceOver 完成读取切换
        try? await Task.sleep(nanoseconds: 100_000_000)
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
```

这帮助 VoiceOver 用户理解他们选择的级联效应。

## 可穿戴设备

### Apple Watch 上的 Assistive Touch

用户可以用手势（捏合、握拳）导航。如果你的手表应用支持 VoiceOver，Assistive Touch 可能也能工作。

### 快速操作

为最重要的任务实现快速操作：

```swift
.accessibilityQuickAction(style: .prompt) {
    Button("Play") { play() }
}
```

通过双捏手势触发。

## 清单

- [ ] 触摸目标至少 44×44 点
- [ ] 颜色对比度达到最低要求（文本 4.5:1）
- [ ] 自定义颜色遵循增强对比度
- [ ] 信息以多种模式传达（不仅仅是颜色）
- [ ] 遵循减弱动效（包括交互期间）
- [ ] 遵循减弱透明度
- [ ] 自定义字体和边框支持粗体文本
- [ ] 自定义按钮遵循按钮形状
- [ ] 关键事件使用触觉
- [ ] 主要操作有键盘快捷键
- [ ] 支持两种方向
- [ ] 临时消息替换为持久替代方案
- [ ] 图片/视频忽略 Smart Invert
- [ ] 切换与标签分组
- [ ] 有副作用时公布设置变化

## 来源

- [Accessibility Up To 11 — #365DaysIOSAccessibility](https://accessibilityupto11.com/365-days-ios-accessibility/)
- [From Zero to Accessible](https://github.com/dadederk/fromZeroToAccessible)（Daniel Devesa Derksen-Staats 和 Rob Whitaker）
