# macOS 设置

## 意图

在使用 SwiftUI 的 `Settings` 场景构建 macOS 设置窗口时使用此模式。

## 核心模式

- 在 `App` 中声明 Settings 场景，且仅对 macOS 编译。
- 将设置内容保留在专门的根视图（`SettingsView`）中，用 `@AppStorage` 驱动值。
- 当类别多于一个时用 `TabView` 分组设置分区。
- 每个标签内用 `Form` 保持控件对齐且可访问。
- 用 `OpenSettingsAction` 或 `SettingsLink` 做应用内进入设置窗口的入口点。

## 示例：设置场景

```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    #if os(macOS)
    Settings {
      SettingsView()
    }
    #endif
  }
}
```

## 示例：带标签的设置视图

```swift
@MainActor
struct SettingsView: View {
  @AppStorage("showPreviews") private var showPreviews = true
  @AppStorage("fontSize") private var fontSize = 12.0

  var body: some View {
    TabView {
      Form {
        Toggle("Show Previews", isOn: $showPreviews)
        Slider(value: $fontSize, in: 9...96) {
          Text("Font Size (\(fontSize, specifier: "%.0f") pts)")
        }
      }
      .tabItem { Label("General", systemImage: "gear") }

      Form {
        Toggle("Enable Advanced Mode", isOn: .constant(false))
      }
      .tabItem { Label("Advanced", systemImage: "star") }
    }
    .scenePadding()
    .frame(maxWidth: 420, minHeight: 240)
  }
}
```

## 跳过导航

- 除非确实需要深度 push 导航，否则避免把 `SettingsView` 包在 `NavigationStack` 中。
- 优先用标签或分区；设置已作为单独窗口展示，应保持扁平。
- 如果必须展示分层设置，用单个 `NavigationSplitView` 加类别侧边栏列表。

## 陷阱

- 不要复用 iOS 专属设置布局（全屏栈、工具栏密集流程）。
- 避免在 `Form` 内放大型自定义视图层级；保持行聚焦且可访问。
