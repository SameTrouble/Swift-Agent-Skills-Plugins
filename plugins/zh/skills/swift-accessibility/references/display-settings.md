# 显示设置和视觉无障碍

覆盖四个 Accessibility Nutrition Label 类别：**Reduced Motion**、**Sufficient Contrast**、**Dark Interface** 和 **Differentiate Without Color**。还覆盖 Reduce Transparency、Bold Text 和 Smart Invert。

## 目录
- [Reduce Motion](#reduce-motion)
- [Sufficient Contrast 和 Dark Interface](#sufficient-contrast-和-dark-interface)
- [Differentiate Without Color](#differentiate-without-color)
- [Reduce Transparency](#reduce-transparency)
- [Bold Text](#bold-text)
- [Smart Invert / Invert Colors](#smart-invert--invert-colors)
- [UIKit 通知观察](#uikit-通知观察)
- [常见失败](#常见失败)

---

## Reduce Motion

患有前庭障碍的用户启用 Reduce Motion 以避免某些动画引起的恶心、眩晕或头痛。**动画不得被忽略——必须被适当地替换。**

### 检测

```swift
// SwiftUI
@Environment(\.accessibilityReduceMotion) var reduceMotion

// UIKit
UIAccessibility.isReduceMotionEnabled

// watchOS
WKAccessibilityIsReduceMotionEnabled()
```

### 决策树

**动画纯粹是装饰性的吗？**（例如弹跳的标志、粒子效果）
→ Reduce Motion 启用时完全移除它。

**动画传达含义吗？**（例如卡片滑入堆栈表示已保存，视图放大显示层级）
→ 用无运动替代方案替换：淡入淡出、溶解、高亮、颜色变化。
→ 永远不要移除——移除会破坏理解。

### SwiftUI 模式

```swift
// ✅ 模式 1：控制 withAnimation
@Environment(\.accessibilityReduceMotion) var reduceMotion

Button("Show Detail") {
    if reduceMotion {
        isVisible = true    // 即时——无动画
    } else {
        withAnimation(.spring()) { isVisible = true }
    }
}

// ✅ 模式 2：条件动画修饰符
Text("Status: \(status)")
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: status)

// ✅ 模式 3：交叉淡入淡出而非滑动
if reduceMotion {
    content.transition(.opacity)      // 淡入淡出——安全
} else {
    content.transition(.slide)        // 滑动——可能引起问题
}
```

### UIKit 模式

```swift
// ✅ 动画前检查
func showCard() {
    if UIAccessibility.isReduceMotionEnabled {
        cardView.alpha = 1           // 即时出现
    } else {
        UIView.animate(withDuration: 0.3) {
            self.cardView.alpha = 1
        }
    }
}

// ✅ 观察运行时变化
NotificationCenter.default.addObserver(
    forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
    object: nil, queue: .main
) { _ in
    self.updateAnimationPreferences()
}
```

### 自动前进内容

轮播、幻灯片和自动播放内容必须停止或提供手动控制。

```swift
struct AutoScrollBanner: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var currentIndex = 0

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(banners.indices, id: \.self) { index in
                BannerView(banner: banners[index]).tag(index)
            }
        }
        .tabViewStyle(.page)
        .onAppear {
            if !reduceMotion { startAutoScroll() }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue { stopAutoScroll() }
        }
    }
}
```

### Nutrition Label 标准

要表明支持 **Reduced Motion**：
- 视差、深度模拟、动画模糊 → 禁用
- 旋转/涡旋/多轴运动 → 移除或替换
- 自动前进内容 → 停止或提供手动控制
- 有意义的动画 → 替换（而非移除）为淡入淡出/溶解/颜色偏移
- 系统设置自动检测（无需应用内设置）

---

## Sufficient Contrast 和 Dark Interface

### WCAG 对比度

| 元素 | 最低比率 | 增强（WCAG AAA） |
|---|---|---|
| 正常文字（<18pt 常规，<14pt 粗体） | **4.5:1** | 7:1 |
| 大文字（≥18pt 常规或 ≥14pt 粗体） | **3:1** | 4.5:1 |
| 非文字交互元素 | **3:1** | — |
| 状态指示器（复选框边框） | **3:1** | — |
| 无信息价值的装饰性文字 | 无要求 | — |

### 语义颜色 —— 始终自适应

使用自动适应浅色/深色模式和 Increase Contrast 的语义颜色。

```swift
// SwiftUI —— 语义颜色自动适应
Text("Primary content")
    .foregroundStyle(.primary)            // 浅色模式黑色，深色模式白色

Text("Secondary content")
    .foregroundStyle(.secondary)          // 灰色，需要时更高对比度

Rectangle()
    .fill(Color(.systemBackground))       // 白/黑

// ❌ 避免硬编码颜色——不适应
Text("Label")
    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))  // 深色模式下可能失败
```

```swift
// UIKit —— UIColor 语义变体
label.textColor = .label              // 适应浅色/深色
label.textColor = .secondaryLabel     // 适应
view.backgroundColor = .systemBackground
view.backgroundColor = .secondarySystemBackground
```

### 支持深色模式的自定义颜色

```swift
// SwiftUI —— Asset catalog 中带深色变体的 Color Set
Color("BrandPrimary")   // 在 Assets.xcassets 中定义 Light 和 Dark

// SwiftUI 不提供内联浅色/深色 Color 初始化器。
// 应用定义的自适应颜色优先使用 Color Sets。

// UIKit —— 动态颜色
let brandColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1)   // 深色上的浅蓝
        : UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1)   // 浅色上的深蓝
}
```

### Increase Contrast

```swift
// SwiftUI
@Environment(\.colorSchemeContrast) var contrast
let increaseContrast = (contrast == .increased)

// 示例：增强边框可见度
RoundedRectangle(cornerRadius: 8)
    .stroke(increaseContrast ? Color(.label) : Color(.separator), lineWidth: increaseContrast ? 2 : 1)

// UIKit
UIAccessibility.isDarkerSystemColorsEnabled

NotificationCenter.default.addObserver(
    forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
    object: nil, queue: .main
) { _ in self.updateContrast() }
```

### Dark Interface —— 深色模式

```swift
// SwiftUI —— 支持系统深色模式
// 使用语义颜色——它们自动适应（见上文）

// 检测当前配色方案
@Environment(\.colorScheme) var colorScheme

// 强制深色用于测试
ContentView().environment(\.colorScheme, .dark)

// UIKit —— 响应 trait 变化
// iOS 17 之前：
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) { // Deprecated in iOS 17
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        updateColors()
    }
}

// iOS 17+ 替代：
registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
    self.updateColors()
}
```

### 关键：同时测试深色 + Increase Contrast

最常见的失败是浅色模式下对比度正确但深色模式下失败。始终两者都测试。

```swift
// Simulator 测试：Settings → Developer → Dark Appearance
// 并且：Settings → Accessibility → Display & Text Size → Increase Contrast
//
// 使用 Accessibility Inspector
// (Xcode → Open Developer Tool → Accessibility Inspector → Settings tab)
// 在 Simulator 上模拟 Increase Contrast。
#Preview("Dark Mode") {
    MyView()
        .environment(\.colorScheme, .dark)
}
```

**常见深色模式陷阱：**
- 深色背景上的灰色文字（即使对正常视力也低对比度）
- 在深色模式下不满足对比度的半透明遮罩
- 白色背景图片反转效果差
- 在深色模式下消失的边框和分隔线

### Nutrition Label 标准

要表明 **Sufficient Contrast**：所有常见任务 UI 在浅色和深色模式下都满足文字 4.5:1、非文字 3:1，且启用了 Increase Contrast 和 Bold Text。

要表明 **Dark Interface**：应用默认深色或支持系统深色模式，无明亮闪烁且所有视图外观一致深色。

---

## Differentiate Without Color

多达 10% 的人有某种形式的色觉缺陷。颜色绝不能是意义的**唯一**指示器。

### 测试方法

启用灰度颜色滤镜：Settings → Accessibility → Display & Text Size → Color Filters → Grayscale。
如果任何信息在灰度下变得模糊或不可见，应用未通过此测试。

### 检测

```swift
// SwiftUI
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

// UIKit
UIAccessibility.shouldDifferentiateWithoutColor

NotificationCenter.default.addObserver(
    forName: UIAccessibility.differentiateWithoutColorDidChangeNotification,
    object: nil, queue: .main
) { _ in self.updateForColorAccessibility() }
```

### 模式

**状态指示器**

```swift
// ❌ 仅颜色——灰度失败
Circle().fill(isOnline ? .green : .red)

// ✅ 颜色 + 形状
Group {
    if isOnline {
        Circle().fill(.green)               // 绿色圆圈
    } else {
        Circle()
            .fill(.red)
            .overlay(
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .font(.caption2)
            )
    }
}
// VoiceOver 仍需要标签：
.accessibilityLabel(isOnline ? "Online" : "Offline")
```

**图表和数据可视化**

```swift
// ❌ 仅颜色——灰度下柱状图不可区分
BarMark(x: .value("Month", month), y: .value("Sales", sales))
    .foregroundStyle(by: .value("Category", category))

// ✅ 颜色 + 图案或符号
BarMark(...)
    .foregroundStyle(by: .value("Category", category))
    .symbol(by: .value("Category", category))  // 每个类别不同符号

// ✅ 或直接在图表元素上标注
```

**条件增强**

```swift
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiate

// 通常颜色编码，设置开启时用图标增强
HStack {
    if differentiate {
        Image(systemName: status.iconName)
    }
    Text(status.label)
}
.foregroundStyle(status.color)
```

### Nutrition Label 标准

要表明 **Differentiate Without Color**：
- 应用通过灰度滤镜测试（所有信息可理解）
- 状态指示器在颜色之外使用形状/图标/文字
- 图表/图形在颜色之外使用图案、标签或符号

---

## Reduce Transparency

```swift
// SwiftUI
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

// UIKit
UIAccessibility.isReduceTransparencyEnabled

NotificationCenter.default.addObserver(
    forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
    object: nil, queue: .main
) { _ in self.updateBlurEffects() }
```

### 用不透明背景替换模糊/毛玻璃

```swift
// SwiftUI —— 条件材质
.background {
    if reduceTransparency {
        Color(.secondarySystemBackground)     // 不透明
    } else {
        Rectangle().fill(.ultraThinMaterial)  // 模糊
    }
}

// iOS 26 Liquid Glass [VERIFY] iOS 26 beta — API 可能变化
if #available(iOS 26, *) {
    content.glassEffect(
        reduceTransparency ? .clear : .regular
    )
}

// UIKit
blurView.isHidden = UIAccessibility.isReduceTransparencyEnabled
solidBackground.isHidden = !UIAccessibility.isReduceTransparencyEnabled
```

---

## Bold Text

启用 Bold Text 时，系统字体渲染更重。自定义字体可能需要响应。

```swift
// SwiftUI
@Environment(\.legibilityWeight) var legibilityWeight
let boldTextEnabled = (legibilityWeight == .bold)

Text("Important")
    .fontWeight(boldTextEnabled ? .heavy : .medium)

// UIKit
UIAccessibility.isBoldTextEnabled

// 使用 preferredFont() 时系统字体自动响应
// 自定义字体可能需要手动调整字重：
NotificationCenter.default.addObserver(
    forName: UIAccessibility.boldTextStatusDidChangeNotification,
    object: nil, queue: .main
) { _ in self.updateFontWeights() }
```

---

## Smart Invert / Invert Colors

Smart Invert 智能地反转大部分 UI 颜色，但应保留图片、视频和应用特定内容不变。

### 排除特定视图

```swift
// SwiftUI —— 保护图片、视频缩略图、地图、图表
AsyncImage(url: photoURL) { image in
    image.resizable()
}
.accessibilityIgnoresInvertColors()

// UIKit
imageView.accessibilityIgnoresInvertColors = true
mapView.accessibilityIgnoresInvertColors = true
```

### 应保护什么

- 照片和用户生成的图片
- 视频缩略图和播放器
- 地图和卫星图像
- 内容中显示的应用图标
- 颜色编码数据的图表（颜色含义会被反转）

### 不应保护什么

- UI chrome（按钮、背景、导航栏）——应反转
- 文字和图标——应反转
- 自定义绘制的背景——应反转

---

## UIKit 通知观察

无障碍状态变化通知完整列表：

```swift
// 一次性注册所有
let notifications: [(Notification.Name, Selector)] = [
    (UIAccessibility.reduceMotionStatusDidChangeNotification, #selector(motionChanged)),
    (UIAccessibility.darkerSystemColorsStatusDidChangeNotification, #selector(contrastChanged)),
    (UIAccessibility.reduceTransparencyStatusDidChangeNotification, #selector(transparencyChanged)),
    (UIAccessibility.boldTextStatusDidChangeNotification, #selector(boldTextChanged)),
    (UIAccessibility.differentiateWithoutColorDidChangeNotification, #selector(colorChanged)),
    (UIAccessibility.invertColorsStatusDidChangeNotification, #selector(invertChanged)),
    (UIAccessibility.voiceOverStatusDidChangeNotification, #selector(voiceOverChanged)),
    (UIAccessibility.switchControlStatusDidChangeNotification, #selector(switchControlChanged)),
    (UIAccessibility.assistiveTouchStatusDidChangeNotification, #selector(assistiveTouchChanged)),
]

notifications.forEach { name, selector in
    NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
}
```

---

## 常见失败

| 失败 | 类别 | 修复 |
|---|---|---|
| Reduce Motion 开启时播放动画 | Reduced Motion | 用 `accessibilityReduceMotion` 控制 |
| 装饰性动画未移除 | Reduced Motion | 装饰性完全移除；功能性替换 |
| 深色模式下低对比度灰色文字 | Dark Interface / Contrast | 使用 `.secondary` 颜色，用深色 + Increase Contrast 测试 |
| 仅颜色状态点 | Differentiate Without Color | 添加图标或形状 |
| Reduce Transparency 下使用模糊效果 | Reduce Transparency | 用不透明回退替换 |
| Smart Invert 下照片反转 | Invert Colors | 添加 `.accessibilityIgnoresInvertColors()` |
| 自定义颜色不适应深色模式 | Dark Interface | 使用 `UIColor` 动态提供者或 Color Set 资产 |
| 硬编码 WCAG 值未检查 | Sufficient Contrast | 使用 Accessibility Inspector 对比度检查器 |
| 自定义字体忽略 Bold Text | Bold Text | 监听通知，更新字重 |
| 自动轮播不停止 | Reduced Motion | `accessibilityReduceMotion` 为 true 时停止自动播放 |
