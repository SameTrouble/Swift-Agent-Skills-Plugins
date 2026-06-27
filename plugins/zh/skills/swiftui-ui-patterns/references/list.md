# List 与 Section

## 意图

用 `List` 做信息流式内容和设置样式行，在这些场景中内置的行复用、选择和无障碍很重要。

## 核心模式

- 对有重复行的长垂直滚动内容优先用 `List`。
- 用 `Section` 头分组相关行。
- 需要滚动到顶部或跳到某 id 时配合 `ScrollViewReader`。
- 现代信息流布局用 `.listStyle(.plain)`。
- 对分区分组有助于理解的多分区发现/搜索页用 `.listStyle(.grouped)`。
- 需要主题化表面时应用 `.scrollContentBackground(.hidden)` + 自定义背景。
- 用 `.listRowInsets(...)` 和 `.listRowSeparator(.hidden)` 调整行间距和分隔线。
- 用 `.environment(\\.defaultMinListRowHeight, ...)` 控制密集列表布局。

## 示例：带滚动到顶部的信息流列表

```swift
@MainActor
struct TimelineListView: View {
  @Environment(\.selectedTabScrollToTop) private var selectedTabScrollToTop
  @State private var scrollToId: String?

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(items) { item in
          TimelineRow(item: item)
            .id(item.id)
            .listRowInsets(.init(top: 12, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
        }
      }
      .listStyle(.plain)
      .environment(\\.defaultMinListRowHeight, 1)
      .onChange(of: scrollToId) { _, newValue in
        if let newValue {
          proxy.scrollTo(newValue, anchor: .top)
          scrollToId = nil
        }
      }
      .onChange(of: selectedTabScrollToTop) { _, newValue in
        if newValue == 0 {
          withAnimation {
            proxy.scrollTo(ScrollToView.Constants.scrollToTop, anchor: .top)
          }
        }
      }
    }
  }
}
```

## 示例：设置样式列表

```swift
@MainActor
struct SettingsView: View {
  var body: some View {
    List {
      Section("General") {
        NavigationLink("Display") { DisplaySettingsView() }
        NavigationLink("Haptics") { HapticsSettingsView() }
      }
      Section("Account") {
        Button("Sign Out", role: .destructive) {}
      }
    }
    .listStyle(.insetGrouped)
  }
}
```

## 应保留的设计选择

- 对动态信息流、设置以及任何行语义有帮助的 UI 用 `List`。
- 为行使用稳定 ID，以保持动画和滚动定位可靠。
- 应端到端可点击的行优先用 `.contentShape(Rectangle())`。
- 当数据源支持时用 `.refreshable` 做下拉刷新信息流。

## 陷阱

- 避免在 `List` 行内做重度自定义布局；改用 `ScrollView` + `LazyVStack`。
- 混合 `List` 和嵌套 `ScrollView` 要小心；可能导致手势冲突。
