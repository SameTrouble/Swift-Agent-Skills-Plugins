# 分栏视图与列

## 意图

为 iPad/macOS 提供轻量、可自定义的多列布局，而不依赖 `NavigationSplitView`。

## 自定义分栏模式（手动 HStack）

当你想要完全控制列尺寸、行为和环境调整时使用。

```swift
@MainActor
struct AppView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @AppStorage("showSecondaryColumn") private var showSecondaryColumn = true

  var body: some View {
    HStack(spacing: 0) {
      primaryColumn
      if shouldShowSecondaryColumn {
        Divider().edgesIgnoringSafeArea(.all)
        secondaryColumn
      }
    }
  }

  private var shouldShowSecondaryColumn: Bool {
    horizontalSizeClass == .regular
      && showSecondaryColumn
  }

  private var primaryColumn: some View {
    TabView { /* tabs */ }
  }

  private var secondaryColumn: some View {
    NotificationsTab()
      .environment(\.isSecondaryColumn, true)
      .frame(maxWidth: .secondaryColumnWidth)
  }
}
```

## 自定义方法说明

- 用共享偏好或设置来切换次级列。
- 注入环境标志（如 `isSecondaryColumn`），使子视图能调整行为。
- 次级列优先用固定或上限宽度，以避免布局抖动。

## 替代：NavigationSplitView

`NavigationSplitView` 可为你处理侧边栏 + 详情 + 补充列，但在以下情况难以自定义：\n- 独立于选择的专用通知列，\n- 自定义尺寸，或\n- 每列不同的工具栏行为。

```swift
@MainActor
struct AppView: View {
  var body: some View {
    NavigationSplitView {
      SidebarView()
    } content: {
      MainContentView()
    } detail: {
      NotificationsView()
    }
  }
}
```

## 如何选择

- 当需要完全控制或非标准次级列时使用手动 HStack 分栏。
- 当想要标准系统布局且最小化自定义时使用 `NavigationSplitView`。
