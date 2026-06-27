# 标题菜单

## 意图

在导航栏用标题菜单提供上下文专属筛选或快捷操作，而不增加额外 chrome。

## 核心模式

- 用 `ToolbarTitleMenu` 把菜单附加到导航标题。
- 保持菜单内容紧凑并用分隔线分组。

## 示例：筛选标题菜单

```swift
@ToolbarContentBuilder
private var toolbarView: some ToolbarContent {
  ToolbarTitleMenu {
    Button("Latest") { timeline = .latest }
    Button("Resume") { timeline = .resume }
    Divider()
    Button("Local") { timeline = .local }
    Button("Federated") { timeline = .federated }
  }
}
```

## 示例：附加到视图

```swift
NavigationStack {
  TimelineView()
    .toolbar {
      toolbarView
    }
}
```

## 示例：标题 + 菜单组合

```swift
struct TimelineScreen: View {
  @State private var timeline: TimelineFilter = .home

  var body: some View {
    NavigationStack {
      TimelineView()
        .toolbar {
          ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
              Text(timeline.title)
                .font(.headline)
              Text(timeline.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          ToolbarTitleMenu {
            Button("Home") { timeline = .home }
            Button("Local") { timeline = .local }
            Button("Federated") { timeline = .federated }
          }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}
```

## 示例：带菜单的标题 + 副标题

```swift
ToolbarItem(placement: .principal) {
  VStack(spacing: 2) {
    Text(title)
      .font(.headline)
    Text(subtitle)
      .font(.caption)
      .foregroundStyle(.secondary)
  }
}
```

## 应保留的设计选择

- 仅当有筛选或上下文切换时才展示标题菜单。
- 保持标题可读；避免会被截断的长标签。
- 如需额外上下文，在标题下用次要文本。

## 陷阱

- 不要给菜单塞太多选项。
- 避免用标题菜单做破坏性操作。
