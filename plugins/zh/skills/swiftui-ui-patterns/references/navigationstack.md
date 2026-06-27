# NavigationStack

## 意图

用此模式做编程式导航和深度链接，尤其是当每个标签页需要独立导航历史时。核心思想是每个标签页一个 `NavigationStack`，各自拥有独立的路径绑定和路由器对象。

## 核心架构

- 定义一个 `Hashable` 且代表所有目标的路由枚举。
- 创建一个轻量路由器（或使用诸如 `https://github.com/Dimillian/AppRouter` 的库）来持有 `path` 和任何 sheet 状态。
- 每个标签页拥有自己的路由器实例，并将 `NavigationStack(path:)` 绑定到它。
- 将路由器注入环境，使子视图能编程式导航。
- 用单个 `navigationDestination(for:)` 块（或 `withAppRouter()` 修饰符）集中目标映射。

## 示例：带各标签页栈的自定义路由器

```swift
@MainActor
@Observable
final class RouterPath {
  var path: [Route] = []
  var presentedSheet: SheetDestination?

  func navigate(to route: Route) {
    path.append(route)
  }

  func reset() {
    path = []
  }
}

enum Route: Hashable {
  case account(id: String)
  case status(id: String)
}

@MainActor
struct TimelineTab: View {
  @State private var routerPath = RouterPath()

  var body: some View {
    NavigationStack(path: $routerPath.path) {
      TimelineView()
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .account(let id): AccountView(id: id)
          case .status(let id): StatusView(id: id)
          }
        }
    }
    .environment(routerPath)
  }
}
```

## 示例：集中式目标映射

用共享视图修饰符避免在各屏幕重复路由 switch。

```swift
extension View {
  func withAppRouter() -> some View {
    navigationDestination(for: Route.self) { route in
      switch route {
      case .account(let id):
        AccountView(id: id)
      case .status(let id):
        StatusView(id: id)
      }
    }
  }
}
```

然后每个栈应用一次：

```swift
NavigationStack(path: $routerPath.path) {
  TimelineView()
    .withAppRouter()
}
```

## 示例：各标签页绑定（带独立历史的标签页）

```swift
@MainActor
struct TabsView: View {
  @State private var timelineRouter = RouterPath()
  @State private var notificationsRouter = RouterPath()

  var body: some View {
    TabView {
      TimelineTab(router: timelineRouter)
      NotificationsTab(router: notificationsRouter)
    }
  }
}
```

## 示例：带各标签页 NavigationStack 的通用标签页

当标签页由数据构建且每个需要独立路径而无硬编码名称时使用。

```swift
@MainActor
struct TabsView: View {
  @State private var selectedTab: AppTab = .timeline
  @State private var tabRouter = TabRouter()

  var body: some View {
    TabView(selection: $selectedTab) {
      ForEach(AppTab.allCases) { tab in
        NavigationStack(path: tabRouter.binding(for: tab)) {
          tab.makeContentView()
        }
        .environment(tabRouter.router(for: tab))
        .tabItem { tab.label }
        .tag(tab)
      }
    }
  }
}
```

@MainActor
@Observable
final class TabRouter {
  private var routers: [AppTab: RouterPath] = [:]

  func router(for tab: AppTab) -> RouterPath {
    if let router = routers[tab] { return router }
    let router = RouterPath()
    routers[tab] = router
    return router
  }

  func binding(for tab: AppTab) -> Binding<[Route]> {
    let router = router(for: tab)
    return Binding(get: { router.path }, set: { router.path = $0 })
  }
}

## 应保留的设计选择

- 每个标签页一个 `NavigationStack` 以保留独立历史。
- 导航状态的单一数据源（`RouterPath` 或库路由器）。
- 用 `navigationDestination(for:)` 把路由映射到视图。
- 应用上下文变化时（账户切换、登出等）重置路径。
- 将路由器注入环境，使子视图能导航和展示 sheet 而无需属性穿透。
- 如果想用单一位置管理模态，把 sheet 展示状态保留在路由器上。

## 陷阱

- 除非想要全局历史，否则不要在所有标签页间共享一个路径。
- 确保路由标识符稳定且 `Hashable`。
- 避免在路径中存储视图实例；存储轻量路由数据。
- 如果使用路由器对象，把它放在其他 `@Observable` 对象之外，以避免嵌套观察。
