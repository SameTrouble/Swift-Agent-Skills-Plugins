# 应用连接与依赖图

## 意图

展示如何连接应用外壳（TabView + NavigationStack + sheets），并在一处安装全局依赖图（环境对象、服务、流式客户端、SwiftData ModelContainer）。

## 推荐结构

1) 根视图设置标签页、各标签页路由器和 sheets。
2) 一个专门的视图修饰符安装全局依赖和生命周期任务（认证状态、流式监听、推送令牌、数据容器）。
3) 功能视图只从环境中拉取所需内容；功能特定的状态保持局部。

## 依赖选择

- 对应用级服务、共享客户端、主题/配置以及许多后代真正需要的值使用 `@Environment`。
- 对功能局部依赖和模型优先使用初始化器注入。不要为了少传一两个参数就把依赖放进环境。
- 除非有意在应用的广泛部分共享，否则不要将可变功能状态放进环境。
- 仅作为遗留回退或当项目已针对真正共享的对象标准化使用 `@EnvironmentObject` 时才用它。

## 根外壳示例（通用）

```swift
@MainActor
struct AppView: View {
  @State private var selectedTab: AppTab = .home
  @State private var tabRouter = TabRouter()

  var body: some View {
    TabView(selection: $selectedTab) {
      ForEach(AppTab.allCases) { tab in
        let router = tabRouter.router(for: tab)
        NavigationStack(path: tabRouter.binding(for: tab)) {
          tab.makeContentView()
        }
        .withSheetDestinations(sheet: Binding(
          get: { router.presentedSheet },
          set: { router.presentedSheet = $0 }
        ))
        .environment(router)
        .tabItem { tab.label }
        .tag(tab)
      }
    }
    .withAppDependencyGraph()
  }
}
```

最小 `AppTab` 示例：

```swift
@MainActor
enum AppTab: Identifiable, Hashable, CaseIterable {
  case home, notifications, settings
  var id: String { String(describing: self) }

  @ViewBuilder
  func makeContentView() -> some View {
    switch self {
    case .home: HomeView()
    case .notifications: NotificationsView()
    case .settings: SettingsView()
    }
  }

  @ViewBuilder
  var label: some View {
    switch self {
    case .home: Label("Home", systemImage: "house")
    case .notifications: Label("Notifications", systemImage: "bell")
    case .settings: Label("Settings", systemImage: "gear")
    }
  }
}
```

路由器骨架：

```swift
@MainActor
@Observable
final class RouterPath {
  var path: [Route] = []
  var presentedSheet: SheetDestination?
}

enum Route: Hashable {
  case detail(id: String)
}
```

## 依赖图修饰符（通用）

用一个修饰符来安装环境对象并在活跃账户/客户端变化时处理生命周期钩子。这能保持连接一致，避免在调用点遗漏依赖。

```swift
extension View {
  func withAppDependencyGraph(
    accountManager: AccountManager = .shared,
    currentAccount: CurrentAccount = .shared,
    currentInstance: CurrentInstance = .shared,
    userPreferences: UserPreferences = .shared,
    theme: Theme = .shared,
    watcher: StreamWatcher = .shared,
    pushNotifications: PushNotificationsService = .shared,
    intentService: AppIntentService = .shared,
    quickLook: QuickLook = .shared,
    toastCenter: ToastCenter = .shared,
    namespace: Namespace.ID? = nil,
    isSupporter: Bool = false
  ) -> some View {
    environment(accountManager)
      .environment(accountManager.currentClient)
      .environment(quickLook)
      .environment(currentAccount)
      .environment(currentInstance)
      .environment(userPreferences)
      .environment(theme)
      .environment(watcher)
      .environment(pushNotifications)
      .environment(intentService)
      .environment(toastCenter)
      .environment(\.isSupporter, isSupporter)
      .task(id: accountManager.currentClient.id) {
        let client = accountManager.currentClient
        if let namespace { quickLook.namespace = namespace }
        currentAccount.setClient(client: client)
        currentInstance.setClient(client: client)
        userPreferences.setClient(client: client)
        await currentInstance.fetchCurrentInstance()
        watcher.setClient(client: client, instanceStreamingURL: currentInstance.instance?.streamingURL)
        if client.isAuth {
          watcher.watch(streams: [.user, .direct])
        } else {
          watcher.stopWatching()
        }
      }
      .task(id: accountManager.pushAccounts.map(\.token)) {
        pushNotifications.tokens = accountManager.pushAccounts.map(\.token)
      }
  }
}
```

注意事项：
- `.task(id:)` 钩子响应账户/客户端变化，重新播种服务和监听器状态。
- 保持该修饰符聚焦于全局连接；功能特定的状态留在功能内部。
- 调整类型（AccountManager、StreamWatcher 等）以匹配你的项目。

## SwiftData / ModelContainer

在根视图安装 `ModelContainer`，使所有功能视图共享同一存储。保持模型列表最小化，仅包含需要持久化的模型。

```swift
extension View {
  func withModelContainer() -> some View {
    modelContainer(for: [Draft.self, LocalTimeline.self, TagGroup.self])
  }
}
```

原因：单一容器避免每个 sheet 或标签页产生重复存储，并保持数据一致。

## Sheet 路由（枚举驱动）

用一个小型枚举和辅助修饰符集中管理 sheets。

```swift
enum SheetDestination: Identifiable {
  case composer
  case settings
  var id: String { String(describing: self) }
}

extension View {
  func withSheetDestinations(sheet: Binding<SheetDestination?>) -> some View {
    sheet(item: sheet) { destination in
      switch destination {
      case .composer:
        ComposerView().withEnvironments()
      case .settings:
        SettingsView().withEnvironments()
      }
    }
  }
}
```

原因：枚举驱动的 sheets 让展示集中且可测试；新增一个 sheet 只需添加一个枚举 case 和一个 switch 分支。

## 何时使用

- 拥有多个包/模块、共享环境对象和服务的应用。
- 需要响应账户/客户端变化并安全重连流式/推送的应用。
- 任何希望一致的 TabView + NavigationStack + sheet 连接而无需重复环境设置的应用。

## 注意事项

- 保持依赖修饰符精简；不要在里面放功能状态或重逻辑。
- 确保 `.task(id:)` 的工作轻量或被正确取消；长时间运行的工作应放在服务中。
- 如果存在未认证的客户端，对流式/监听调用加门控以避免重连轰炸。
