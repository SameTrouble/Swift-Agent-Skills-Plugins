# 焦点视觉反馈（tvOS + macOS）

## SwiftUI ButtonStyle 与 @Environment(\.isFocused)

自定义 tvOS 按钮样式的标准模式。从环境读取焦点状态，应用视觉更改。

```swift
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CardButton(configuration: configuration)
    }

    struct CardButton: View {
        @Environment(\.isFocused) var isFocused
        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .shadow(radius: isFocused ? 20 : 0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}
```

### 三态按钮模式（正常 / 聚焦 / 按下）

```swift
struct PrimaryButtonStyle: ButtonStyle {
    struct PrimaryButton: View {
        @Environment(\.isFocused) var isFocused
        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .background { background }
                .animation(.easeInOut, value: isFocused)
        }

        @ViewBuilder private var background: some View {
            if configuration.isPressed {
                Color(.pressedBackground)
            } else if isFocused {
                Color(.focusedBackground)
            } else {
                Color(.normalBackground)
            }
        }
    }
}
```

### ButtonStyle 中的条件性可聚焦

```swift
struct IconButtonStyle: ButtonStyle {
    struct IconButton: View {
        @Environment(\.isEnabled) var isEnabled
        @Environment(\.isFocused) var isFocused

        var body: some View {
            content
                .opacity(isEnabled ? 1.0 : 0.3)
                .focusable(isEnabled)  // 在这里可以——ButtonStyle 内部视图，非包装 Button
                .animation(.easeInOut, value: isFocused)
        }
    }
}
```

## FocusBorder ViewModifier

焦点出现时显示的可重用渐变边框：

```swift
struct FocusBorder: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    let outset: Bool

    func body(content: Content) -> some View {
        content
            .cornerRadius(cornerRadius)
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.blue, .purple],
                                         startPoint: .leading, endPoint: .trailing),
                            lineWidth: 4
                        )
                        .padding(outset ? -8 : 0)
                }
            }
            .animation(.easeInOut, value: isFocused)
    }
}

extension View {
    func focusBorder(isFocused: Bool, cornerRadius: CGFloat = 20, outset: Bool = true) -> some View {
        modifier(FocusBorder(isFocused: isFocused, cornerRadius: cornerRadius, outset: outset))
    }
}
```

## tvOS 系统按钮样式

- `.buttonStyle(.card)`——标准的聚焦抬起 + 视差 + 阴影。最适合媒体卡片/海报。
- `.buttonStyle(.plain)`——无视觉焦点反馈。仅在提供自定义样式时使用。
- `.buttonStyle(.bordered)`——带焦点高亮的边框按钮。

媒体内容优先使用 `.card`——它提供视差、阴影和标准 tvOS"抬起"感，这些是自定义缩放效果无法复制的。

## UIKit 焦点动画

### 单元格中的协调缩放 + 阴影

```swift
override func didUpdateFocus(in context: UIFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    if context.nextFocusedView === self {
        coordinator.addCoordinatedFocusingAnimations({ _ in
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.layer.zPosition = 1
        }, completion: nil)
        // 阴影必须使用 CABasicAnimation
        animateShadow(to: 0.5)
    } else if context.previouslyFocusedView === self {
        coordinator.addCoordinatedUnfocusingAnimations({ _ in
            self.transform = .identity
            self.layer.zPosition = 0
        }, completion: nil)
        animateShadow(to: 0)
    }
}

private func animateShadow(to opacity: Float) {
    let anim = CABasicAnimation(keyPath: "shadowOpacity")
    anim.fromValue = layer.shadowOpacity
    anim.toValue = opacity
    anim.duration = 0.3
    layer.add(anim, forKey: "shadowOpacity")
    layer.shadowOpacity = opacity
}
```

### zPosition 管理

缩放聚焦的单元格可能重叠相邻单元格或节标题。管理 `layer.zPosition`：
- 聚焦时设为 1（将单元格置于邻居之上）
- 未聚焦时设为 0
- 如果单元格在标题后面缩放，将标题设为 `layer.zPosition = -1`

### prepareForReuse 清理

```swift
override func prepareForReuse() {
    super.prepareForReuse()
    transform = .identity
    layer.shadowOpacity = 0
    layer.zPosition = 0
    layer.removeAnimation(forKey: "shadowOpacity")
}
```

## clipsToBounds 注意事项

当单元格聚焦时缩放，如果 `clipsToBounds = true` 内容会被裁剪。在单元格及其 contentView 上设置 `clipsToBounds = false`，或使用 SwiftUI 辅助：

```swift
extension View {
    func clipsToBoundsDisabled() -> some View {
        self.background(
            GeometryReader { _ in
                Color.clear
                    .preference(key: ClipsToBoundsKey.self, value: false)
            }
        )
    }
}
```

## macOS 焦点环样式

### 系统焦点环

macOS 使用由 AppKit 绘制的蓝色焦点环（系统强调色）。它会自动动画进出。

```swift
class MyView: NSView {
    override var acceptsFirstResponder: Bool { true }

    // .exterior——环在视图边界外（默认）
    // .interior——环在视图边界内
    // .none——无环（提供自己的视觉）
    override var focusRingType: NSFocusRingType { .exterior }
}
```

### 自定义焦点环形状

默认焦点环匹配视图边界（矩形）。为非矩形内容重写：

```swift
class CircularAvatarView: NSView {
    override var focusRingMaskBounds: NSRect {
        return bounds  // 包含遮罩的区域
    }

    override func drawFocusRingMask() {
        // 环跟随此形状而非视图的矩形
        let path = NSBezierPath(ovalIn: bounds)
        path.fill()
    }

    // 遮罩形状更改时通知 AppKit（例如调整大小）
    override func noteFocusRingChanged() {
        super.noteFocusRingChanged()
    }
}
```

### 为自定义视觉禁用焦点环

```swift
class CustomStyledView: NSView {
    override var focusRingType: NSFocusRingType { .none }

    override func drawRect(_ dirtyRect: NSRect) {
        // 聚焦时绘制自定义焦点指示器
        if window?.firstResponder === self {
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2),
                                     xRadius: 6, yRadius: 6)
            path.lineWidth = 2
            path.stroke()
        }
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true  // 用焦点指示器重绘
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true  // 无焦点指示器重绘
        return super.resignFirstResponder()
    }
}
```

### macOS 上的 SwiftUI 自定义焦点样式

```swift
struct MacCardView: View {
    @FocusState private var isFocused: Bool

    var body: some View {
        content
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()  // 隐藏系统环
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
            )
            .shadow(color: isFocused ? .accentColor.opacity(0.3) : .clear, radius: 8)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
```

### macOS vs tvOS 焦点样式对比

| 方面 | tvOS | macOS |
|--------|------|-------|
| 默认效果 | 缩放 + 阴影 + 视差 | 蓝色焦点环 |
| 自定义方式 | ButtonStyle 中的 `@Environment(\.isFocused)` | `focusRingType` + `drawFocusRingMask()` 或 SwiftUI `@FocusState` |
| 动画 | `UIFocusAnimationCoordinator` | `needsDisplay = true` 或 SwiftUI `.animation` |
| 系统样式 | `.buttonStyle(.card)` | 系统焦点环（自动） |
| 禁用默认 | `.buttonStyle(.plain)` | `.focusEffectDisabled()` 或 `focusRingType = .none` |
