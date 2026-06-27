# 主题与动态字号

## 意图

提供干净、可扩展的主题方法，使视图代码语义化且一致。

## 核心模式

- 用单一 `Theme` 对象作为数据源（颜色、字体、间距）。
- 在应用根注入主题，视图中通过 `@Environment(Theme.self)` 读取。
- 优先用语义颜色（`primaryBackground`、`secondaryBackground`、`label`、`tint`）而非原始颜色。
- 将面向用户的主题控件保留在专门设置屏幕。
- 通过自定义字体或 `.font(.scaled...)` 应用动态字号缩放。

## 示例：Theme 对象

```swift
@MainActor
@Observable
final class Theme {
  var tintColor: Color = .blue
  var primaryBackground: Color = .white
  var secondaryBackground: Color = .gray.opacity(0.1)
  var labelColor: Color = .primary
  var fontSizeScale: Double = 1.0
}
```

## 示例：在应用根注入

```swift
@main
struct MyApp: App {
  @State private var theme = Theme()

  var body: some Scene {
    WindowGroup {
      AppView()
        .environment(theme)
    }
  }
}
```

## 示例：视图用法

```swift
struct ProfileView: View {
  @Environment(Theme.self) private var theme

  var body: some View {
    VStack {
      Text("Profile")
        .foregroundStyle(theme.labelColor)
    }
    .background(theme.primaryBackground)
  }
}
```

## 应保留的设计选择

- 保持主题值语义化且最小化；避免重复系统颜色。
- 如需将用户选择的主题值存入持久化存储。
- 确保文本与背景之间对比度。

## 陷阱

- 避免在视图中散落原始 `Color` 值；会破坏一致性。
- 不要把主题绑到单个视图的局部状态。
- 避免把 `@Environment(\\.colorScheme)` 作为唯一主题控制；它应补充你的主题。
