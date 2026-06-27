# MVVM 手册（Swift + SwiftUI/UIKit）

当涉及 MVVM 请求或带异步副作用的屏幕级状态时使用本参考。

## 目录
- [核心边界](#核心边界)
- [功能结构](#功能结构)
- [状态建模](#状态建模)
- [ViewModel 模式](#viewmodel-模式)
- [依赖注入](#依赖注入)
- [视图指导](#视图指导)
- [导航模式](#导航模式)
- [反模式与修复](#反模式与修复)
- [测试期望](#测试期望)
- [何时优先使用 MVVM](#何时优先使用-mvvm)
- [PR 评审清单](#pr-评审清单)

## 核心边界

- Model：领域实体与业务规则。保持与 UI 框架无关。
- View：渲染状态并转发用户意图。不直接调用服务。
- ViewModel：持有表现层状态，将领域数据映射为视图数据，协调副作用。
- Services/Repositories：副作用边界（网络、持久化、分析）。

依赖方向：
- View -> ViewModel
- ViewModel -> UseCases/Repositories/Services（通过协议）
- Model -> 不依赖 View/ViewModel

## 功能结构

优先采用具有清晰边界的垂直功能切片。此布局为示例，并非每个功能都必须遵循的文件清单：

```text
App/
  Features/
    Feed/
      FeedView.swift
      FeedViewModel.swift
      FeedState.swift
      FeedViewData.swift
      FeedDestination.swift
      FeedAssembly.swift
  Navigation/
    AppRouter.swift
    DeepLink.swift
Domain/
  Entities/
  UseCases/
Data/
  Repositories/
  API/
  Persistence/
```

## 状态建模

优先使用显式状态类型，而非布尔值组合。

```swift
enum Loadable<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

struct FeedItemViewData: Identifiable, Hashable {
    let id: UUID
    let title: String
}

struct ToastState: Equatable {
    let message: String
}

struct FeedState: Equatable {
    var load: Loadable<Void> = .idle
    var items: [FeedItemViewData] = []
    var isRefreshing = false
    var toast: ToastState?
}
```

## ViewModel 模式

将状态变更保持在主线程上，持有任务句柄，并取消过期任务。

### 现代模式（iOS 17+ / `@Observable`）

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()

    private let repository: FeedRepository
    private var loadTask: Task<Void, Never>?

    init(repository: FeedRepository) {
        self.repository = repository
    }

    func onAppear() {
        guard case .idle = state.load else { return }
        load()
    }

    func load() {
        loadTask?.cancel()
        state.load = .loading

        loadTask = Task {
            do {
                let page = try await repository.fetchPage(cursor: nil)
                try Task.checkCancellation()
                state.items = page.items.map(FeedItemViewData.init)
                state.load = .loaded(())
            } catch is CancellationError {
                // 忽略取消。
            } catch {
                state.load = .failed(error.localizedDescription)
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
```

### 旧版模式（iOS 16 及更早 / `ObservableObject`）

```swift
@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var state = FeedState()

    private let repository: FeedRepository
    private var loadTask: Task<Void, Never>?

    init(repository: FeedRepository) {
        self.repository = repository
    }

    func onAppear() {
        guard case .idle = state.load else { return }
        load()
    }

    func load() {
        loadTask?.cancel()
        state.load = .loading

        loadTask = Task {
            do {
                let page = try await repository.fetchPage(cursor: nil)
                try Task.checkCancellation()
                state.items = page.items.map(FeedItemViewData.init)
                state.load = .loaded(())
            } catch is CancellationError {
                // 忽略取消。
            } catch {
                state.load = .failed(error.localizedDescription)
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
```

## 依赖注入

将抽象注入 ViewModel 构造器。在功能装配层构建实际依赖。

```swift
protocol FeedRepository {
    func fetchPage(cursor: String?) async throws -> FeedPage
}

enum FeedAssembly {
    static func makeViewModel() -> FeedViewModel {
        FeedViewModel(repository: LiveFeedRepository(api: .live))
    }
}
```

`FeedAssembly.makeViewModel()` 使功能装配一目了然，但随着应用增长可能会受限。常见的演进路径是引入应用级依赖容器（组合根），持有共享的依赖图。

```swift
protocol AppDependencies {
    var feedRepository: FeedRepository { get }
}

struct LiveDependencies: AppDependencies {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var feedRepository: FeedRepository {
        LiveFeedRepository(api: api)
    }
}

@MainActor
final class AppContainer {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func makeFeedViewModel() -> FeedViewModel {
        FeedViewModel(repository: dependencies.feedRepository)
    }
}
```

## 视图指导

- 仅绑定到 ViewModel 状态。
- 不要在 `body`/`cellForRowAt` 中做业务转换。
- 为格式化和展示关注点提供专门的 `ViewData` 结构体。
- View 本地状态仅用于瞬时 UI 细节（焦点、滚动位置）。

使用 `@Observable` ViewModel 的 SwiftUI 视图（iOS 17+）：

```swift
struct FeedView: View {
    @State private var viewModel: FeedViewModel

    init(viewModel: FeedViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        List(viewModel.state.items, id: \.id) { item in
            Text(item.title)
        }
        .task { viewModel.onAppear() }
    }
}
```

使用 `ObservableObject` ViewModel 的 SwiftUI 视图（iOS 16 及更早）：

```swift
struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    init(viewModel: FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(viewModel.state.items, id: \.id) { item in
            Text(item.title)
        }
        .task { viewModel.onAppear() }
    }
}
```

## 导航模式

保持路由决策可测试并与表现层 API 解耦：ViewModel 决定 *去哪里*，路由层决定 *怎么去*。

### SwiftUI 导航（iOS 16+ / `NavigationStack`）

将目的地建模为枚举。优先使用稳定 ID 而非列表专属的 `ViewData`。

路径归属是一个真实权衡：
- ViewModel 持有路径：最简单的端到端 SwiftUI 接线，但将数据/加载状态与导航状态混在一起。
- View 持有路径：保持 ViewModel 状态聚焦于数据/加载，但需要 intent API 以使路由决策可测试。
- Router 持有路径：最适合多屏流程和深度链接，但需要额外类型与接线成本。

以下示例展示 ViewModel 持有和 Router 持有两种模式。

```swift
enum FeedDestination: Hashable {
    case detail(id: UUID)
    case profile(userId: UUID)
    case settings
}
```

方案 A：ViewModel 持有路径。

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()
    var navigationPath: [FeedDestination] = []

    // ...现有属性...

    func didTapItem(_ item: FeedItemViewData) {
        navigationPath.append(.detail(id: item.id))
    }

    func didTapProfile(userId: UUID) {
        navigationPath.append(.profile(userId: userId))
    }
}
```

视图将路径绑定到 `NavigationStack`：

```swift
struct FeedView: View {
    @State private var viewModel: FeedViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack(path: $viewModel.navigationPath) {
            List(viewModel.state.items) { item in
                Button(item.title) {
                    viewModel.didTapItem(item)
                }
            }
            .navigationDestination(for: FeedDestination.self) { destination in
                switch destination {
                case .detail(let itemID):
                    FeedDetailView(viewModel: FeedDetailViewModel(itemID: itemID))
                case .profile(let userId):
                    ProfileView(viewModel: ProfileViewModel(userId: userId))
                case .settings:
                    SettingsView(viewModel: SettingsViewModel())
                }
            }
            .task { viewModel.onAppear() }
        }
    }
}
```

方案 B：专用 router 让 `FeedState` 聚焦于表现层数据/加载。

```swift
@MainActor
@Observable
final class FeedRouter {
    var path: [FeedDestination] = []

    func push(_ destination: FeedDestination) {
        path.append(destination)
    }
}

@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()

    func destinationForItem(_ item: FeedItemViewData) -> FeedDestination {
        .detail(id: item.id)
    }
}

struct FeedView: View {
    @State private var viewModel: FeedViewModel
    @State private var router = FeedRouter()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            List(viewModel.state.items) { item in
                Button(item.title) {
                    router.push(viewModel.destinationForItem(item))
                }
            }
        }
    }
}
```

### 模态 / Sheet 展示

将 sheet 展示建模为 ViewModel 上的可选状态。

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()
    var activeSheet: FeedSheet?

    struct FeedFilter: Equatable {
        var showUnreadOnly = false
    }

    enum FeedSheet: Identifiable {
        case compose
        case filter(current: FeedFilter)

        var id: String {
            switch self {
            case .compose: "compose"
            case .filter: "filter"
            }
        }
    }

    func didTapCompose() {
        activeSheet = .compose
    }
}
```

```swift
struct FeedView: View {
    @State private var viewModel: FeedViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        List(viewModel.state.items) { item in
            Text(item.title)
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .compose:
                ComposeView(viewModel: ComposeViewModel())
            case .filter(let current):
                FilterView(viewModel: FilterViewModel(filter: current))
            }
        }
    }
}
```

### Coordinator 模式（UIKit 或混合代码库）

当涉及 UIKit 或复杂多步流程需要集中控制时，使用 Coordinator 协议。

```swift
@MainActor
protocol FeedCoordinator: AnyObject {
    func showDetail(itemID: UUID)
    func showProfile(userId: UUID)
    func presentCompose(onComplete: @MainActor @escaping () -> Void)
}
```

将 Coordinator 注入 ViewModel：

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()

    private let repository: FeedRepository
    private weak var coordinator: FeedCoordinator?
    private var loadTask: Task<Void, Never>?

    init(repository: FeedRepository, coordinator: FeedCoordinator) {
        self.repository = repository
        self.coordinator = coordinator
    }

    func didTapItem(_ item: FeedItemViewData) {
        coordinator?.showDetail(itemID: item.id)
    }

    func didTapCompose() {
        coordinator?.presentCompose { [weak self] in
            self?.load()
        }
    }
}
```

具体实现位于导航层：

```swift
@MainActor
final class FeedFlowCoordinator: FeedCoordinator {
    private let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func showDetail(itemID: UUID) {
        let viewModel = FeedDetailAssembly.makeViewModel(itemID: itemID)
        let vc = UIHostingController(rootView: FeedDetailView(viewModel: viewModel))
        navigationController.pushViewController(vc, animated: true)
    }

    func showProfile(userId: UUID) {
        let viewModel = ProfileAssembly.makeViewModel(userId: userId)
        let vc = UIHostingController(rootView: ProfileView(viewModel: viewModel))
        navigationController.pushViewController(vc, animated: true)
    }

    func presentCompose(onComplete: @MainActor @escaping () -> Void) {
        let composeVM = ComposeAssembly.makeViewModel(onComplete: onComplete)
        let vc = UIHostingController(rootView: ComposeView(viewModel: composeVM))
        navigationController.present(vc, animated: true)
    }
}
```

### 深度链接

在 router 中集中处理深度链接解析，将 URL 映射到导航目的地。

```swift
enum DeepLink {
    case feedItem(id: UUID)
    case profile(userId: UUID)
    case settings

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return nil }
        switch host {
        case "feed":
            guard let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  let id = UUID(uuidString: idString) else { return nil }
            self = .feedItem(id: id)
        case "profile":
            guard let idString = components.queryItems?.first(where: { $0.name == "userId" })?.value,
                  let id = UUID(uuidString: idString) else { return nil }
            self = .profile(userId: id)
        case "settings":
            self = .settings
        default:
            return nil
        }
    }
}
```

将深度链接应用到现有导航状态：

```swift
@MainActor
@Observable
final class AppRouter {
    var feedViewModel: FeedViewModel

    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .feedItem(let id):
            feedViewModel.navigationPath = [.detail(id: id)]
        case .profile(let userId):
            feedViewModel.navigationPath = [.profile(userId: userId)]
        case .settings:
            feedViewModel.navigationPath = [.settings]
        }
    }
}
```

### 如何选择模式

| 场景 | 推荐模式 |
|---|---|
| 纯 SwiftUI，线性流程 | ViewModel 上的 `NavigationStack` 路径 |
| Sheet、alert、确认弹窗 | 可选状态驱动展示 |
| UIKit 宿主或混合 SwiftUI/UIKit | Coordinator 协议 |
| 多步流程（引导、结账） | 带子 coordinator 的 Coordinator |
| Universal Links / 推送通知 | 深度链接 router + 状态驱动导航 |

## 反模式与修复

1. 上帝 ViewModel：
- 症状：网络、解析、持久化和状态编排全塞在一个类中。
- 修复：抽取 UseCases/Repositories；让 ViewModel 聚焦于状态和意图处理。

2. View 和 ViewModel 中状态重复：
- 症状：`@State var items` 与 `viewModel.state.items` 共存。
- 修复：在 ViewModel 中保留唯一真相源。

3. 过期异步覆盖：
- 症状：旧响应覆盖了新状态。
- 修复：在新请求前取消进行中任务，并检查取消状态。

4. ViewModel 中使用 UIKit 类型做导航逻辑：
- 症状：ViewModel 中直接使用 `UINavigationController`。
- 修复：注入 Router/Coordinator 协议。

5. 主线程上执行重活：
- 症状：在主线程方法中解码或做昂贵映射。
- 修复：将 CPU 密集工作移出主线程；在主线程上赋值最终状态。

```swift
// 反模式：昂贵的映射在 @MainActor 上运行。
@MainActor
func load() {
    loadTask?.cancel()
    state.load = .loading

    loadTask = Task {
        do {
            let page = try await repository.fetchPage(cursor: nil)
            state.items = page.items.map(FeedItemViewData.init) // 大页面下可能卡顿
            state.load = .loaded(())
        } catch is CancellationError {
            // 忽略取消。
        } catch {
            state.load = .failed(error.localizedDescription)
        }
    }
}

// 更好：在 actor 之外做 CPU 密集映射，然后在 @MainActor 上提交状态。
@MainActor
func load() {
    loadTask?.cancel()
    state.load = .loading

    loadTask = Task {
        do {
            let page = try await repository.fetchPage(cursor: nil)
            let mappedItems = try await Task.detached(priority: .userInitiated) {
                page.items.map(FeedItemViewData.init)
            }.value
            try Task.checkCancellation()
            state.items = mappedItems
            state.load = .loaded(())
        } catch is CancellationError {
            // 忽略取消。
        } catch {
            state.load = .failed(error.localizedDescription)
        }
    }
}
```

如果映射量小但可复用，将其抽取为纯函数（`static`/`nonisolated`）以便测试；如果开销大，则移出 actor（`Task.detached` 或后台服务）。在严格并发（Swift 6）下，确保 detached 任务捕获/结果是 `Sendable`，或将工作放到后台 actor/服务边界之后。

## 测试期望

聚焦确定性状态转换：
- 成功路径（`loading -> loaded`）
- 失败路径（`loading -> failed`）
- 取消路径（无过期覆盖）
- 映射正确性（领域 -> 视图数据）

测试策略：
- 为仓库使用协议 stub/fake。
- 避免基于 sleep 的测试；使用可控的 stub 响应。
- 如果 ViewModel 是 `@MainActor`，通过 `await MainActor.run` 执行断言。

```swift
import XCTest

struct FeedItem: Equatable {
    let id: UUID
    let title: String
}

struct FeedPage: Equatable {
    let items: [FeedItem]
}

extension FeedItemViewData {
    init(_ item: FeedItem) {
        self.id = item.id
        self.title = item.title
    }
}

actor ControlledFeedRepository: FeedRepository {
    private var continuations: [CheckedContinuation<FeedPage, Error>] = []

    func fetchPage(cursor: String?) async throws -> FeedPage {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resolveNext(with result: Result<FeedPage, Error>) {
        guard !continuations.isEmpty else { return }
        let continuation = continuations.removeFirst()
        switch result {
        case .success(let page):
            continuation.resume(returning: page)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

@MainActor
final class FeedViewModelTests: XCTestCase {
    func test_load_success_setsLoadedAndMapsItems() async {
        let repository = ControlledFeedRepository()
        let sut = FeedViewModel(repository: repository)
        let expected = FeedPage(items: [FeedItem(id: UUID(), title: "A")])

        sut.load()
        await repository.resolveNext(with: .success(expected))
        await Task.yield()

        XCTAssertEqual(sut.state.items.map(\.title), ["A"])
        if case .loaded = sut.state.load {
            // 符合预期
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_load_failure_setsFailed() async {
        let repository = ControlledFeedRepository()
        let sut = FeedViewModel(repository: repository)

        sut.load()
        await repository.resolveNext(with: .failure(TestError.offline))
        await Task.yield()

        if case .failed = sut.state.load {
            // 符合预期
        } else {
            XCTFail("Expected failed state")
        }
    }

    func test_load_cancellation_ignoresStaleResult() async {
        let repository = ControlledFeedRepository()
        let sut = FeedViewModel(repository: repository)

        let stale = FeedPage(items: [FeedItem(id: UUID(), title: "stale")])
        let latest = FeedPage(items: [FeedItem(id: UUID(), title: "latest")])

        sut.load() // 请求 A
        sut.load() // 请求 B 取消 A

        await repository.resolveNext(with: .success(stale))
        await repository.resolveNext(with: .success(latest))
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(sut.state.items.map(\.title), ["latest"])
    }
}

private enum TestError: Error {
    case offline
}
```

## 何时优先使用 MVVM

优先使用 MVVM 的场景：
- 主要关注屏幕级状态管理
- 团队希望有明确的 View/ViewModel 边界，但不想引入完整的 reducer/store 框架
- 功能复杂度中等，不需要严格单向数据流
- 团队接受适度结构（例如 `State`、`ViewData`、assembly/router 类型），以换取清晰度和可测试性

MVVM 通常比 TCA/VIPER 样板更少，但并非"零样板"。严格的 MVVM 风格可能每个功能引入多个文件；请根据实际复杂度决定文件拆分粒度，而非一开始就套用所有类型。

优先使用 MVI/TCA 的场景：
- 需要确定性状态机建模
- 复杂的副作用编排与取消正确性至关重要

优先使用 Clean Architecture/VIPER 的场景：
- 严格的层边界与用例隔离比表现层简洁更重要

## PR 评审清单

- View 不直接调用服务。
- ViewModel 暴露显式状态模型。
- 依赖通过注入提供（ViewModel 中无应用级单例依赖）。
- 异步任务有取消策略。
- 领域模型不直接耦合到 View 渲染。
- 导航目的地建模为值类型（枚举/结构体），而非命令式调用。
- ViewModel 不导入 UIKit 或直接引用表现层 API。
- 深度链接处理通过集中 router 路由，而非临时视图逻辑。
- 单元测试覆盖成功、失败和取消路径。
