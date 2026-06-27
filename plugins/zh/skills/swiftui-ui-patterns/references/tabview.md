# TabView

## 意图

用此模式做可扩展、多平台的标签页架构，具备：
- 标签页身份和内容的单一数据源，
- 平台专属标签页集和侧边栏分区，
- 来源于数据的动态标签页，
- 对特殊标签页（如撰写）的拦截钩子。

## 核心架构

- `AppTab` 枚举定义身份、标签、图标和内容构建器。
- `SidebarSections` 枚举为侧边栏分区分组标签页。
- `AppView` 持有 `TabView` 和选择绑定，并通过 `updateTab` 路由标签页变化。

## 示例：带副作用的自定义绑定

当标签页选择需要副作用时使用，如拦截特殊标签页以执行操作而非改变选择。

```swift
@MainActor
struct AppView: View {
  @Binding var selectedTab: AppTab

  var body: some View {
    TabView(selection: .init(
      get: { selectedTab },
      set: { updateTab(with: $0) }
    )) {
      ForEach(availableSections) { section in
        TabSection(section.title) {
          ForEach(section.tabs) { tab in
            Tab(value: tab) {
              tab.makeContentView(
                homeTimeline: $timeline,
                selectedTab: $selectedTab,
                pinnedFilters: $pinnedFilters
              )
            } label: {
              tab.label
            }
            .tabPlacement(tab.tabPlacement)
          }
        }
        .tabPlacement(.sidebarOnly)
      }
    }
  }

  private func updateTab(with newTab: AppTab) {
    if newTab == .post {
      // 拦截特殊标签页（撰写）而非改变选择。
      presentComposer()
      return
    }
    selectedTab = newTab
  }
}
```

## 示例：无副作用的直接绑定

当选择纯状态驱动时使用。

```swift
@MainActor
struct AppView: View {
  @Binding var selectedTab: AppTab

  var body: some View {
    TabView(selection: $selectedTab) {
      ForEach(availableSections) { section in
        TabSection(section.title) {
          ForEach(section.tabs) { tab in
            Tab(value: tab) {
              tab.makeContentView(
                homeTimeline: $timeline,
                selectedTab: $selectedTab,
                pinnedFilters: $pinnedFilters
              )
            } label: {
              tab.label
            }
            .tabPlacement(tab.tabPlacement)
          }
        }
        .tabPlacement(.sidebarOnly)
      }
    }
  }
}
```

## 应保留的设计选择

- 在 `AppTab` 中用 `makeContentView(...)` 集中标签页身份和内容。
- 用 `Tab(value:)` 配合 `selection` 绑定做状态驱动的标签页选择。
- 通过 `updateTab` 路由选择变化以处理特殊标签页和滚动到顶行为。
- 用 `TabSection` + `.tabPlacement(.sidebarOnly)` 做侧边栏结构。
- 在 `AppTab.tabPlacement` 中用 `.tabPlacement(.pinned)` 做单个固定标签页；这常用于 iOS 26 `.searchable` 标签页内容，但可用于任何标签页。

## 动态标签页模式

- `SidebarSections` 处理动态数据标签页。
- `AppTab.anyTimelineFilter(filter:)` 把动态标签页包在单个枚举 case 中。
- 该枚举通过筛选器类型为动态标签页提供标签/图标/标题。

## 陷阱

- 避免为标签页添加 ViewModels；保持状态局部或在 `@Observable` 服务中。
- 不要把 `@Observable` 对象嵌套在其他 `@Observable` 对象内。
- 确保 `AppTab.id` 值稳定；动态 case 应基于稳定 ID 哈希。
- 特殊标签页（撰写）不应改变选择。
