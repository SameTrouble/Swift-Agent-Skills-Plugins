# Figma 组件变体到 SwiftUI

如何将 Figma 变体属性（State、Size、Style/Type、内容开关）翻译为 SwiftUI 构造。

## 目录

- [在 MCP 输出中识别变体](#在-mcp-输出中识别变体)
- [状态变体](#状态变体)
- [尺寸变体](#尺寸变体)
- [样式 / 类型变体](#样式--类型变体)
- [内容开关变体](#内容开关变体)
- [组合变体](#组合变体)
- [选择架构之前先询问](#选择架构之前先询问)
- [可复用组件模式](#可复用组件模式)
- [表单和输入](#表单和输入)
- [变体实现清单](#变体实现清单)

## 在 MCP 输出中识别变体

Figma 组件使用变体属性定义视觉排列。当 `get_design_context` 返回组件实例时，查找：
- 名为 State、Size、Style、Type、HasIcon、ShowSubtitle 的属性
- 多个变体值（例如 State=Default、Pressed、Disabled、Loading）

获取组件集的所有变体，而不仅仅是默认的。使用 `get_metadata` 查找兄弟变体节点，然后对每个 `get_design_context` 以理解视觉状态的完整范围。

## 状态变体

将 Figma 状态变体映射到最接近的原生 SwiftUI 机制。仅对没有系统等价物的状态创建自定义状态枚举。

### 系统提供的状态（优先使用这些）：

- Pressed -> `ButtonStyle.makeBody(configuration:)` 中的 `configuration.isPressed`
- Disabled -> 样式中的 `@Environment(\.isEnabled)`，或调用处的 `.disabled(true)`
- On/Off（切换）-> `ToggleStyle` 中的 `configuration.isOn`
- Focused -> `@FocusState` 和 `.focused()` 修饰符
- Selected（在列表/选择器中）-> List/Picker 中的 Selection binding

### 自定义状态（无系统等价物）：

- Loading、Error、Empty、Skeleton -> 建模为枚举，用 @State 或 view model 驱动

```swift
enum ButtonLoadingState {
    case idle, loading, success, error
}

struct PrimaryButtonStyle: ButtonStyle {
    let loadingState: ButtonLoadingState
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .overlay {
                if loadingState == .loading {
                    ProgressView()
                }
            }
            .allowsHitTesting(loadingState != .loading)
    }
}
```

规则：如果 Figma 状态匹配系统状态（pressed、disabled、on/off、focused），使用系统机制。自定义枚举仅用于系统不提供的状态。

## 尺寸变体

### 系统控件尺寸：

`.controlSize(.mini / .small / .regular / .large / .extraLarge)` 适用于系统控件（Button、Toggle、Picker、DatePicker 等），但对自定义视图无效。

### 自定义尺寸枚举（用于自定义组件）：

```swift
enum ComponentSize {
    case small, medium, large
}

struct PrimaryButtonStyle: ButtonStyle {
    let size: ComponentSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(fontSize)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }

    private var fontSize: Font {
        switch size {
        case .small: .footnote
        case .medium: .body
        case .large: .title3
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: 12
        case .medium: 16
        case .large: 20
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: 6
        case .medium: 10
        case .large: 14
        }
    }
}
```

规则：当组件包装系统控件时使用 `.controlSize()`。构建完全自定义组件时使用自定义枚举。

## 样式/类型变体

Figma 设计通常有 Style 或 Type 属性（Primary、Secondary、Destructive、Ghost 等）。

### 单一样式带枚举参数——当差异最小（颜色、边框）时：

```swift
enum ButtonVariant {
    case primary, secondary, destructive
}

struct AppButtonStyle: ButtonStyle {
    let variant: ButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: variant == .secondary ? 1 : 0)
            }
    }

    private var foregroundColor: Color { /* switch on variant */ }
    private var backgroundColor: Color { /* switch on variant */ }
    private var borderColor: Color { /* switch on variant */ }
}
```

### 分离样式——当布局或结构显著不同时：

```swift
struct FloatingButtonStyle: ButtonStyle { /* 仅图标、圆形、阴影 */ }
struct TextLinkButtonStyle: ButtonStyle { /* 下划线文本、无背景 */ }
```

规则：当唯一差异是颜色、边框或字重时，优先使用带枚举参数的单一样式。当布局、结构或内容排列不同时，使用分离样式。

## 内容开关

Figma 变体如 HasIcon=true/false、ShowSubtitle=true/false、ShowBadge=true/false 表示可选内容槽。

### 可选参数：

```swift
struct CardView: View {
    let title: String
    var subtitle: String? = nil
    var icon: Image? = nil
    var badge: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon { icon.frame(width: 24, height: 24) }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            if let badge { Text("\(badge)").font(.caption).padding(4).background(.red, in: .capsule) }
        }
    }
}
```

### @ViewBuilder 用于灵活内容槽：

```swift
struct CardView<Header: View, Footer: View>: View {
    let title: String
    @ViewBuilder let header: Header
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text(title).font(.headline)
            footer
        }
    }
}
```

规则：简单开关（图标、副标题、徽章）使用可选参数。当槽内容在结构上显著不同时使用 @ViewBuilder 泛型。

## 完整示例：带状态 + 尺寸 + 样式的按钮

将所有变体维度组合到单个组件中：

```swift
struct AppButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let size: ComponentSize
    let loadingState: ButtonLoadingState

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .foregroundStyle(variant.foregroundColor)
            .background(variant.backgroundColor, in: RoundedRectangle(cornerRadius: size.cornerRadius))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .overlay {
                if loadingState == .loading {
                    ProgressView().tint(variant.foregroundColor)
                }
            }
            .allowsHitTesting(loadingState != .loading)
    }
}

// 用法
Button("Submit") { submit() }
    .buttonStyle(AppButtonStyle(variant: .primary, size: .large, loadingState: viewModel.submitState))
    .disabled(viewModel.isFormInvalid)
```

## 完整示例：带状态变体的文本输入框

```swift
struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var error: String? = nil
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .padding(12)
                .background(isEnabled ? Color(.systemBackground) : Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: isFocused || error != nil ? 2 : 1)
                }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return .red }
        if isFocused { return .accentColor }
        return Color(.separator)
    }
}
```
