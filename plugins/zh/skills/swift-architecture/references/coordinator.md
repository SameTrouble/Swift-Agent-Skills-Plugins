# Coordinator 手册（Swift + SwiftUI/UIKit）

当导航逻辑需要与单个屏幕解耦时使用本参考，可实现可复用流程、深度链接和可测试路由，而无需视图控制器自己负责转场。

## 目录
- [核心概念](#核心概念)
- [功能结构](#功能结构)
- [Coordinator 协议](#coordinator-协议)
- [UIKit Coordinator](#uikit-coordinator)
- [SwiftUI Coordinator](#swiftui-coordinator)
- [子 Coordinator 模式](#子-coordinator-模式)
- [深度链接](#深度链接)
- [反模式与修复](#反模式与修复)
- [测试策略](#测试策略)
- [何时优先使用 Coordinator](#何时优先使用-coordinator)
- [PR 评审清单](#pr-评审清单)

## 核心概念

一个 Coordinator 拥一个导航流。它创建并连接屏幕、传递依赖，并决定当用户动作触发转场时下一步发生什么。

```text
AppCoordinator
  -> AuthCoordinator   (owns login/signup flow)
  -> MainCoordinator   (owns tab/home flow)
       -> ProfileCoordinator (owns profile flow)
```

规则：
- 每个 coordinator 拥有一个流（一个屏幕、一个子流，或一个完整模块）
- 屏幕发出导航事件；coordinator 决定如何处理
- 屏幕不引用 coordinator，也不直接 push/present
- 父 coordinator 为嵌套流启动子 coordinator

## 功能结构

```text
App/
  AppCoordinator.swift
  Coordinators/
    AuthCoordinator.swift
    MainCoordinator.swift
    ProfileCoordinator.swift
  Features/
    Auth/
      LoginViewModel.swift
      LoginView.swift
    Profile/
      ProfileViewModel.swift
      ProfileView.swift
Navigation/
  Coordinator.swift         (protocol)
  NavigationRouter.swift    (UIKit helper)
```

## Coordinator 协议

定义一个最小的基础契约。

```swift
@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    func start()
}

extension Coordinator {
    func addChild(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
        coordinator.start()
    }

    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
```

规则：
- 持有子 coordinator，防止其在流程中途被释放
- 当子 coordinator 拥有的流完成时移除它
- `start()` 是启动流的唯一入口

## UIKit Coordinator

对于 UIKit，将 `UINavigationController` 包装在一个轻量 router 中。

```swift
@MainActor
final class NavigationRouter {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController = UINavigationController()) {
        self.navigationController = navigationController
    }

    func push(_ viewController: UIViewController, animated: Bool = true) {
        navigationController.pushViewController(viewController, animated: animated)
    }

    func present(_ viewController: UIViewController, animated: Bool = true) {
        navigationController.present(viewController, animated: animated)
    }

    func pop(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }

    func popToRoot(animated: Bool = true) {
        navigationController.popToRootViewController(animated: animated)
    }
}
```

Profile 流 coordinator 示例：

```swift
@MainActor
final class ProfileCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    private let router: NavigationRouter
    private let userRepository: UserRepository

    init(router: NavigationRouter, userRepository: UserRepository) {
        self.router = router
        self.userRepository = userRepository
    }

    func start() {
        let viewModel = ProfileViewModel(
            repository: userRepository,
            onEditTapped: { [weak self] in self?.showEditProfile() },
            onLogoutTapped: { [weak self] in self?.finish() }
        )
        let viewController = ProfileViewController(viewModel: viewModel)
        router.push(viewController)
    }

    private func showEditProfile() {
        let editCoordinator = EditProfileCoordinator(
            router: router,
            userRepository: userRepository,
            onComplete: { [weak self] in self?.removeChild($0) }
        )
        addChild(editCoordinator)
    }

    private func finish() {
        // 通知父级此流已完成。
    }
}
```

## SwiftUI Coordinator

对于 SwiftUI，将导航状态建模为值类型并绑定到 `NavigationStack`。

```swift
@MainActor
@Observable
final class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var path: [AppDestination] = []
    var sheet: AppSheet?

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func start() {
        // 无需 push——根在视图层设置。
    }

    func showProfile(userID: UUID) {
        path.append(.profile(userID))
    }

    func showSettings() {
        sheet = .settings
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func dismissSheet() {
        sheet = nil
    }
}

enum AppDestination: Hashable {
    case profile(UUID)
    case editProfile(UUID)
}

enum AppSheet: Identifiable {
    case settings
    var id: String { "\(self)" }
}
```

根视图将 coordinator 状态绑定到 `NavigationStack`：

```swift
struct AppRootView: View {
    @State private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self._coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        NavigationStack(path: $coordinator.path) {
            HomeView(
                onProfileTapped: { id in coordinator.showProfile(userID: id) },
                onSettingsTapped: { coordinator.showSettings() }
            )
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .profile(let id):
                    ProfileView(viewModel: makeProfileViewModel(userID: id))
                case .editProfile(let id):
                    EditProfileView(userID: id)
                }
            }
        }
        .sheet(item: $coordinator.sheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView(onDismiss: { coordinator.dismissSheet() })
            }
        }
    }

    private func makeProfileViewModel(userID: UUID) -> ProfileViewModel {
        ProfileViewModel(
            userID: userID,
            repository: coordinator.userRepository,
            onEditTapped: { coordinator.path.append(.editProfile(userID)) }
        )
    }
}
```

规则：
- 将目的地建模为 `Hashable` 枚举，以便 `NavigationStack` 驱动它们
- 将 sheet 建模为 `Identifiable` 枚举以绑定 `sheet(item:)`
- 在主线程上变更 coordinator 状态
- 避免在 `navigationDestination` 闭包中深层条件嵌套——优先使用 `switch`

## 子 Coordinator 模式

父 coordinator 为嵌套流拥有子 coordinator。

```swift
@MainActor
final class MainCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    private let router: NavigationRouter
    private let userRepository: UserRepository

    init(router: NavigationRouter, userRepository: UserRepository) {
        self.router = router
        self.userRepository = userRepository
    }

    func start() {
        showHome()
    }

    func showHome() {
        let viewModel = HomeViewModel(
            onProfileTapped: { [weak self] id in self?.showProfile(userID: id) }
        )
        let viewController = HomeViewController(viewModel: viewModel)
        router.push(viewController)
    }

    private func showProfile(userID: UUID) {
        let profileRouter = NavigationRouter(
            navigationController: router.navigationController
        )
        let coordinator = ProfileCoordinator(
            router: profileRouter,
            userRepository: userRepository
        )
        addChild(coordinator)
    }
}
```

## 深度链接

通过将 URL 解析为目的地并直接路由到它来处理深度链接。
Push 目的地更新 `path`；sheet 目的地设置 `sheet`。

```swift
@MainActor
final class DeepLinkHandler {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func handle(url: URL) {
        guard url.scheme == "myapp" else { return }
        switch url.host {
        case "profile":
            guard
                let idString = url.pathComponents.dropFirst().first,
                let id = UUID(uuidString: idString)
            else { return }
            coordinator.path = [.profile(id)]
        case "settings":
            coordinator.sheet = .settings
        default:
            break
        }
    }
}
```

## 反模式与修复

1. 视图控制器 push 自己的下一个屏幕：
   - 症状：`ProfileViewController` 直接调用 `navigationController?.pushViewController(SettingsViewController(), animated: true)`。
   - 修复：发出闭包或 delegate 事件；让 Coordinator 执行 push。

2. Coordinator 仅被局部变量持有：
   - 症状：父级丢失对子 coordinator 的引用；它在流程中途被释放。
   - 修复：在调用 `start()` 前将子 coordinator 加入 `childCoordinators`。

3. 导航逻辑分散在 ViewModel 中：
   - 症状：ViewModel 持有 `AppCoordinator` 引用并直接调用 `coordinator.showSettings()`。
   - 修复：注入导航闭包（`onSettingsTapped: () -> Void`），使 ViewModel 与 coordinator 类型解耦。

4. 深度链接绕过 coordinator：
   - 症状：`AppDelegate` 在收到深度链接时直接调用 `navigationController.pushViewController(...)`。
   - 修复：所有深度链接通过 `DeepLinkHandler` → `AppCoordinator.handle(url:)` 路由。

5. Coordinator 混入业务逻辑：
   - 症状：Coordinator 在路由前获取数据或应用业务规则。
   - 修复：保持 Coordinator 仅负责导航；将数据工作委托给 ViewModel/Repository。

## 测试策略

通过验证导航状态变更来测试 Coordinator，覆盖成功路径（追加预期目的地）、失败路径（未知输入不崩溃地处理）和取消安全的 pop 操作。
使用 stub 仓库和直接 coordinator 状态检查保持测试确定性。
避免 sleep；优先使用同步状态变更和直接属性断言。

```swift
@MainActor
final class SpyNavigationRouter: NavigationRouter {
    var pushedViewControllers: [UIViewController] = []
    var presentedViewControllers: [UIViewController] = []

    override func push(_ viewController: UIViewController, animated: Bool = true) {
        pushedViewControllers.append(viewController)
    }

    override func present(_ viewController: UIViewController, animated: Bool = true) {
        presentedViewControllers.append(viewController)
    }
}

@MainActor
final class ProfileCoordinatorTests: XCTestCase {
    func test_start_pushesProfileViewController() {
        let router = SpyNavigationRouter()
        let coordinator = ProfileCoordinator(
            router: router,
            userRepository: StubUserRepository()
        )

        coordinator.start()

        XCTAssertEqual(router.pushedViewControllers.count, 1)
        XCTAssertTrue(router.pushedViewControllers.first is ProfileViewController)
    }

    func test_showEditProfile_addsChildCoordinator() {
        let router = SpyNavigationRouter()
        let coordinator = ProfileCoordinator(
            router: router,
            userRepository: StubUserRepository()
        )
        coordinator.start()

        coordinator.showEditProfileForTesting()

        XCTAssertEqual(coordinator.childCoordinators.count, 1)
    }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_showProfile_success_appendsDestination() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        let id = UUID()

        coordinator.showProfile(userID: id)

        XCTAssertEqual(coordinator.path, [.profile(id)])
    }

    func test_pop_removesLastDestination() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        coordinator.path = [.profile(UUID()), .editProfile(UUID())]

        coordinator.pop()

        XCTAssertEqual(coordinator.path.count, 1)
    }

    func test_dismissSheet_clearsSheet() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        coordinator.sheet = .settings

        coordinator.dismissSheet()

        XCTAssertNil(coordinator.sheet)
    }

    func test_deepLink_failure_doesNotCrashOnUnknownScheme() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        let handler = DeepLinkHandler(coordinator: coordinator)
        let unknownURL = URL(string: "https://example.com/profile/123")!

        handler.handle(url: unknownURL)

        XCTAssertTrue(coordinator.path.isEmpty)
    }

    func test_pop_cancellation_onEmptyPath_doesNotCrash() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        XCTAssertTrue(coordinator.path.isEmpty)

        coordinator.pop()

        XCTAssertTrue(coordinator.path.isEmpty)
    }
}

struct StubUserRepository: UserRepository {
    func fetchCurrentUser() async throws -> User {
        User(id: UUID(), name: "Stub", isPremium: false, joinDate: .now)
    }
}
```

注意：`showEditProfileForTesting()` 暴露私有路由动作以供测试访问——用 `#if DEBUG` 标注或使用 `@testable import` 和 `internal` 访问级别，以保持生产代码干净。

## 何时优先使用 Coordinator

优先使用 Coordinator 的场景：
- 导航逻辑复杂（条件流、深度链接、多步向导）
- 多个屏幕需要在不同流程中复用
- 希望在不实例化完整屏幕的情况下测试路由逻辑
- ViewModel 和 View Controller 应零导航耦合

与 MVVM 搭配时，将导航闭包注入 ViewModel；与 MVP 搭配时，让 Presenter 调用由 Coordinator 支撑的 Router 协议。

Coordinator 模式本身不是一个架构——它是一个补充表现层模式的导航层。当 `UINavigationController` 的 push/present 调用散落在视图控制器中，使流程难以追踪或测试时，优先使用它。

## PR 评审清单

- 每个 coordinator 拥有一个明确范围的流。
- 子 coordinator 在调用 `start()` 前被加入 `childCoordinators`。
- 子 coordinator 在其流完成时被移除。
- ViewModel 和 View Controller 接收导航闭包，而非 coordinator 引用。
- 导航状态（SwiftUI path/sheet）建模为值类型。
- 深度链接处理通过 coordinator 路由，而非直接到视图控制器。
- 测试在不依赖 UIKit 展示时序的情况下验证路由状态变更。
