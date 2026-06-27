# VIPER 手册（Swift + SwiftUI/UIKit）

当需要严格的功能级分离时使用本参考，尤其是大型或遗留 UIKit 代码库。

## 目录
- [核心组件](#核心组件)
- [规范功能布局](#规范功能布局)
- [职责](#职责)
- [接线模式](#接线模式)
- [装配指导](#装配指导)
- [并发与取消](#并发与取消)
- [反模式与修复](#反模式与修复)
- [测试策略](#测试策略)
- [何时优先使用 VIPER](#何时优先使用-viper)
- [PR 评审清单](#pr-评审清单)

## 核心组件

- View：渲染 UI 并转发用户动作
- Interactor：执行业务逻辑并协调数据访问
- Presenter：将实体转换为可展示的输出并控制视图状态
- Entity：功能使用的领域模型
- Router：导航与模块装配

预期交互：

```text
View -> Presenter -> Interactor -> Repository/Service -> Interactor -> Presenter -> View
Presenter -> Router (navigation)
```

## 规范功能布局

```text
Feature/
  View/
  Presenter/
  Interactor/
  Entity/
  Router/
```

每个功能保持一个 VIPER 模块，防止跨功能泄漏。

## 职责

### View

- 渲染由 Presenter 提供的数据。
- 转发用户输入（`didTap...`、`didAppear`、文本变更）。
- 避免直接访问服务/仓库。
- 在 SwiftUI 中，使用适配器（iOS 17+ 用 `@Observable`，需要 Combine/UIKit 互操作时用 `ObservableObject`）转发给 Presenter。

### Presenter

- 持有该功能的表现层流程。
- 向 Interactor 请求业务结果。
- 将实体映射为 view model/展示字符串。
- 调用 Router 进行导航。

### Interactor

- 执行业务规则和用例。
- 通过协议调用仓库/服务。
- 将领域结果返回给 Presenter。
- 避免直接涉及视图或导航。

### Router

- 执行导航转场。
- 构建并连接模块依赖。

### Entity

- 表示领域数据和业务不变量。
- 尽可能避免 UI 和框架耦合。
- 将展示格式化排除在 `Entity` 之外；Presenter 负责实体 -> 展示模型映射。

```swift
struct User: Equatable {
    let id: UUID
    let name: String
    let isPremium: Bool
}

struct ProfileViewData: Equatable {
    let displayName: String
    let badgeText: String?
}

extension ProfileViewData {
    init(user: User) {
        self.displayName = user.name
        self.badgeText = user.isPremium ? "Premium" : nil
    }
}
```

## 接线模式

使用边界协议和定向引用。

```swift
@MainActor
protocol ProfileView: AnyObject {
    func showLoading(_ isLoading: Bool)
    func show(profile: ProfileViewData)
    func showError(message: String)
}

protocol ProfileInteracting {
    func loadUser() async throws -> User
}

protocol ProfileRouting {
    func showSettings()
}

@MainActor
final class ProfilePresenter {
    weak var view: ProfileView?
    private let interactor: ProfileInteracting
    private let router: ProfileRouting
    private var loadTask: Task<Void, Never>?
    private var latestLoadRequestID: UUID?

    init(interactor: ProfileInteracting, router: ProfileRouting) {
        self.interactor = interactor
        self.router = router
    }

    func load() {
        let requestID = UUID()
        latestLoadRequestID = requestID
        loadTask?.cancel()
        view?.showLoading(true)

        loadTask = Task {
            do {
                let user = try await interactor.loadUser()
                try Task.checkCancellation()
                guard latestLoadRequestID == requestID else { return }
                view?.show(profile: ProfileViewData(user: user))
            } catch is CancellationError {
                // 被更新的加载请求取消。
            } catch {
                guard latestLoadRequestID == requestID else { return }
                view?.showError(message: "Failed to load profile. Please try again.")
            }
            guard latestLoadRequestID == requestID else { return }
            view?.showLoading(false)
        }
    }

    func didTapSettings() {
        router.showSettings()
    }

    deinit {
        loadTask?.cancel()
    }
}
```

将 `view` 设为 weak 以避免循环引用。
将 presenter/view 更新保持在主线程上，确保 UI 调用线程安全。

## 装配指导

通过 Router/Assembly 工厂创建模块：
- 实例化 View、Presenter、Interactor、Router
- 注入协议，而非具体全局单例
- 在构建时一次性设置引用

这集中了接线并减少循环依赖错误。

```swift
enum ProfileModule {
    static func build(
        userRepository: UserRepository,
        navigationController: UINavigationController
    ) -> UIViewController {
        let interactor = ProfileInteractor(repository: userRepository)
        let router = ProfileRouter(navigationController: navigationController)
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        let viewController = ProfileViewController(presenter: presenter)
        presenter.view = viewController
        return viewController
    }
}
```

规则：
- 将工厂方法作为模块创建的唯一入口
- 从调用方注入外部依赖（仓库、服务）
- 在构造之后设置 weak 反向引用（例如 `presenter.view`）

SwiftUI 集成选项：
- 保持 Presenter/Interactor/Router 不变
- 将 SwiftUI 功能视图包装在 `UIHostingController` 中
- 通过小型适配器对象桥接 Presenter 输出
- 对于纯 SwiftUI 应用，注入 SwiftUI router 对象，而非要求 `UINavigationController`

```swift
import SwiftUI
import UIKit

@MainActor
final class ProfileViewAdapter: ObservableObject, ProfileView {
    @Published private(set) var name = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let presenter: ProfilePresenter

    init(presenter: ProfilePresenter) {
        self.presenter = presenter
    }

    func showLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func show(profile: ProfileViewData) {
        self.name = profile.displayName
        self.errorMessage = nil
    }

    func showError(message: String) {
        self.errorMessage = message
    }

    func load() { presenter.load() }
    func didTapSettings() { presenter.didTapSettings() }
}

struct ProfileScreen: View {
    @ObservedObject var adapter: ProfileViewAdapter

    var body: some View {
        VStack {
            Text(adapter.name)
            if adapter.isLoading { ProgressView() }
            if let errorMessage = adapter.errorMessage {
                Text(errorMessage)
            }
            Button("Settings") { adapter.didTapSettings() }
        }
        .task { adapter.load() }
    }
}

enum ProfileModuleSwiftUI {
    static func build(
        userRepository: UserRepository,
        navigationController: UINavigationController
    ) -> UIViewController {
        let interactor = ProfileInteractor(repository: userRepository)
        let router = ProfileRouter(navigationController: navigationController)
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        let adapter = ProfileViewAdapter(presenter: presenter)
        presenter.view = adapter
        return UIHostingController(rootView: ProfileScreen(adapter: adapter))
    }
}
```

纯 SwiftUI 应用选项（无 `UINavigationController`）：

```swift
import SwiftUI

enum AppDestination: Hashable {
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppDestination] = []

    func push(_ destination: AppDestination) {
        path.append(destination)
    }
}

@MainActor
final class ProfileSwiftUIRouter: ProfileRouting {
    private let appRouter: AppRouter

    init(appRouter: AppRouter) {
        self.appRouter = appRouter
    }

    func showSettings() {
        appRouter.push(.settings)
    }
}

enum ProfileModulePureSwiftUI {
    @MainActor
    static func build(
        userRepository: UserRepository,
        appRouter: AppRouter
    ) -> ProfileScreen {
        let interactor = ProfileInteractor(repository: userRepository)
        let router = ProfileSwiftUIRouter(appRouter: appRouter)
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        let adapter = ProfileViewAdapter(presenter: presenter)
        presenter.view = adapter
        return ProfileScreen(adapter: adapter)
    }
}
```

在应用根视图，将共享 router 路径绑定到 `NavigationStack`：

```swift
struct AppRootView: View {
    @State private var appRouter = AppRouter()

    var body: some View {
        @Bindable var appRouter = appRouter

        NavigationStack(path: $appRouter.path) {
            ProfileModulePureSwiftUI.build(
                userRepository: LiveUserRepository(),
                appRouter: appRouter
            )
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}
```

## 并发与取消

当 Presenter 协调异步工作时，追踪活动任务并取消过期请求。上面接线模式部分展示的 `ProfilePresenter` 已实现完整的取消策略——它持有 `loadTask: Task<Void, Never>?`、`latestLoadRequestID: UUID?`，并显式处理 `CancellationError` 以防止过期 UI 更新。

规则：
- 在发起新请求前取消进行中任务
- 显式处理 `CancellationError` 以避免过期 UI 更新
- 按请求标识把关 UI 更新，确保只有最新请求能更新视图状态
- 在模块销毁时取消所有任务
- 保持 presenter intent 方法同步（`func load()`），内部管理异步任务

## 反模式与修复

1. 臃肿的 Presenter：
- 症状：presenter 包含业务逻辑、格式化、网络和导航细节。
- 修复：将业务逻辑移到 Interactor 和格式化辅助方法；保持 Presenter 聚焦于编排。

2. Interactor 执行导航：
- 症状：interactor 直接 push/present 屏幕。
- 修复：通过 Presenter 调用 Router 进行导航路由。

3. 循环依赖和强引用环：
- 症状：View <-> Presenter <-> Router 相互强引用。
- 修复：使用边界协议并在需要处使用 weak 引用。

4. View 做业务工作：
- 症状：View 转换数据或直接调用服务。
- 修复：将逻辑移入 Presenter/Interactor。

5. Router 包含业务逻辑：
- 症状：Router 决定领域结果。
- 修复：保持 Router 仅限于导航和装配。

## 测试策略

优先按组件进行隔离测试：
- 使用 mock View/Interactor/Router 的 Presenter 测试
- 使用 mock 仓库/服务的 Interactor 测试
- 在可行时进行 Router 导航触发测试

测试规则：
- 断言交互和输出，而非具体实现
- 单元测试中避免网络
- 验证 presenter 处理成功和失败状态
- 验证失败路径的 Presenter-to-View 错误契约（`showError(message:)`）
- 当更新加载替换进行中请求时测试取消行为
- 使用可控 stub/时钟保持异步测试确定性（避免 sleep）

使用"并发与取消"部分中支持取消的 presenter 进行取消路径测试。

```swift
@MainActor
final class MockProfileView: ProfileView {
    var shownName: String?
    var shownError: String?
    var isLoading = false

    func showLoading(_ isLoading: Bool) { self.isLoading = isLoading }

    func show(profile: ProfileViewData) {
        shownName = profile.displayName
    }

    func showError(message: String) {
        shownError = message
    }
}

struct StubProfileInteractor: ProfileInteracting {
    var load: () async throws -> User
    func loadUser() async throws -> User { try await load() }
}

final class SpyProfileRouter: ProfileRouting {
    var didShowSettings = false
    func showSettings() { didShowSettings = true }
}

@MainActor
final class ProfilePresenterTests: XCTestCase {
    func test_load_success_showsUserName() async {
        let user = User(id: UUID(), name: "Alice", isPremium: false)
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { user }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownName, "Alice")
    }

    func test_load_failure_showsError() async {
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { throw TestError.notFound }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownError, "Failed to load profile. Please try again.")
    }

    func test_didTapSettings_routesToSettings() {
        let router = SpyProfileRouter()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { User(id: UUID(), name: "", isPremium: false) }),
            router: router
        )

        presenter.didTapSettings()

        XCTAssertTrue(router.didShowSettings)
    }

    func test_load_cancellation_doesNotOverwriteExistingName() async {
        let view = MockProfileView()
        view.shownName = "Current"
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { throw CancellationError() }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownName, "Current")
    }
}

private enum TestError: Error { case notFound }
```

## 何时优先使用 VIPER

优先使用 VIPER 的场景：
- 多团队需要独立拥有的功能模块，边界明确
- 严格角色分离减少长期代码库中的架构漂移
- interactor 级业务规则必须可在不启动 UI 屏幕的情况下测试
- 模块化编译和清晰的依赖方向是高优先级
- UIKit 为主的代码库受益于 router 驱动的装配/导航

优先使用更轻模式的情况：
- 应用较小或快速原型
- 样板成本超过边界/可测试性收益

与有组织的 MVVM 相比，VIPER 通常需要更多设置，但在规模化时更强地强制角色边界，尤其是当团队和模块解耦时。

## PR 评审清单

- 组件职责得到尊重（View/Interactor/Presenter/Router 分离）。
- Presenter 不持有业务逻辑实现细节。
- Interactor 不执行导航。
- Router 仅处理导航和模块装配。
- 边界协议避免具体耦合。
- 需要处使用 weak 引用防止循环引用。
- 测试覆盖 presenter 编排和 interactor 业务规则。
