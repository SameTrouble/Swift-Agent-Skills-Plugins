# MVP 手册（Swift + SwiftUI/UIKit）

当你需要一个被动 View，将所有逻辑委托给 Presenter 时使用本参考，尤其在 UIKit 代码库中，直接测试表现层逻辑是优先项。

## 目录
- [核心边界](#核心边界)
- [功能结构](#功能结构)
- [View 协议](#view-协议)
- [View Data](#view-data)
- [Presenter 模式](#presenter-模式)
- [UIKit View 实现](#uikit-view-实现)
- [SwiftUI 适配器](#swiftui-适配器)
- [装配](#装配)
- [反模式与修复](#反模式与修复)
- [测试策略](#测试策略)
- [何时优先使用 MVP](#何时优先使用-mvp)
- [PR 评审清单](#pr-评审清单)

## 核心边界

- Model：领域实体和业务规则。无 UI 依赖。
- View：被动渲染器，完全由 Presenter 命令驱动。不持有逻辑。
- Presenter：持有所有表现层逻辑，将 Model 数据映射为展示输出，并通过协议驱动 View 更新。
- Services/Repositories：副作用边界（网络、持久化），注入到 Presenter。

依赖方向：

```text
View -> Presenter (user actions)
Presenter -> View (via ViewProtocol, one-way commands)
Presenter -> Repository/Service (via protocols)
```

与 MVVM 的关键区别：View 不持有可观察状态——它被动执行 Presenter 派发的命令。

## 功能结构

```text
App/
  Features/
    Profile/
      ProfileViewController.swift   (View)
      ProfilePresenter.swift
      ProfileViewProtocol.swift
      ProfileViewData.swift
      ProfileAssembly.swift
  Navigation/
    AppCoordinator.swift
Domain/
  Entities/
  Repositories/
Data/
  Repositories/
  API/
```

## View 协议

将 View 定义为 weak 协议。Presenter 通过它驱动状态。

```swift
@MainActor
protocol ProfileView: AnyObject {
    func showLoading(_ isLoading: Bool)
    func show(profile: ProfileViewData)
    func showError(message: String)
}
```

规则：
- 使用 `AnyObject` 以允许 weak 引用
- 方法表示视图命令，而非状态标志
- 保持协议聚焦——每个不同 UI 关注点一个命令

## View Data

在 Presenter 中将领域实体映射为可展示值，而非在 View 中。

```swift
struct ProfileViewData: Equatable {
    let displayName: String
    let badgeText: String?
    let formattedJoinDate: String
}
```

## Presenter 模式

持有任务管理，取消过期工作，并按请求标识把关更新。

```swift
@MainActor
final class ProfilePresenter {
    weak var view: ProfileView?
    private let repository: ProfileRepository
    private var loadTask: Task<Void, Never>?
    private var latestRequestID: UUID?

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func viewDidAppear() {
        load()
    }

    func load() {
        let requestID = UUID()
        latestRequestID = requestID
        loadTask?.cancel()
        view?.showLoading(true)

        loadTask = Task {
            do {
                let user = try await repository.fetchCurrentUser()
                try Task.checkCancellation()
                guard latestRequestID == requestID else { return }
                let viewData = ProfileViewData(user: user)
                view?.show(profile: viewData)
            } catch is CancellationError {
                // 被更新的请求取消——不更新视图。
            } catch {
                guard latestRequestID == requestID else { return }
                view?.showError(message: "Failed to load profile. Please try again.")
            }
            guard latestRequestID == requestID else { return }
            view?.showLoading(false)
        }
    }

    deinit {
        loadTask?.cancel()
    }
}

extension ProfileViewData {
    init(user: User) {
        self.displayName = user.name
        self.badgeText = user.isPremium ? "Premium" : nil
        self.formattedJoinDate = user.joinDate.formatted(.dateTime.year().month())
    }
}
```

规则：
- `view` 为 `weak` 以避免循环引用
- 在开始新任务前取消进行中任务
- 用 `requestID` 把关状态更新，防止过期覆盖

## UIKit View 实现

UIKit 视图控制器将动作转发给 Presenter 并执行视图命令。

```swift
@MainActor
final class ProfileViewController: UIViewController, ProfileView {
    private let presenter: ProfilePresenter
    private let nameLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()

    init(presenter: ProfilePresenter) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presenter.viewDidAppear()
    }

    // MARK: - ProfileView

    func showLoading(_ isLoading: Bool) {
        isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    func show(profile: ProfileViewData) {
        nameLabel.text = profile.displayName
        errorLabel.isHidden = true
    }

    func showError(message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    private func setupLayout() {
        // 布局设置省略。
    }
}
```

## SwiftUI 适配器

对于 SwiftUI，通过一个轻量 observable 适配器桥接，该适配器遵循 `ProfileView`。

```swift
@MainActor
@Observable
final class ProfileViewAdapter: ProfileView {
    private(set) var viewData: ProfileViewData?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let presenter: ProfilePresenter

    init(presenter: ProfilePresenter) {
        self.presenter = presenter
        presenter.view = self
    }

    func showLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func show(profile: ProfileViewData) {
        self.viewData = profile
        self.errorMessage = nil
    }

    func showError(message: String) {
        self.errorMessage = message
    }

    func viewDidAppear() { presenter.viewDidAppear() }
}

struct ProfileScreen: View {
    @State private var adapter: ProfileViewAdapter

    init(adapter: ProfileViewAdapter) {
        self._adapter = State(initialValue: adapter)
    }

    var body: some View {
        Group {
            if adapter.isLoading {
                ProgressView()
            } else if let viewData = adapter.viewData {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewData.displayName).font(.title)
                    if let badge = viewData.badgeText {
                        Text(badge).font(.caption)
                    }
                }
            } else if let error = adapter.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .onAppear { adapter.viewDidAppear() }
    }
}
```

## 装配

在一处——装配器或 coordinator——接线依赖。

```swift
enum ProfileAssembly {
    static func build(repository: ProfileRepository) -> UIViewController {
        let presenter = ProfilePresenter(repository: repository)
        let viewController = ProfileViewController(presenter: presenter)
        presenter.view = viewController
        return viewController
    }

    @MainActor
    static func buildSwiftUI(repository: ProfileRepository) -> ProfileScreen {
        let presenter = ProfilePresenter(repository: repository)
        let adapter = ProfileViewAdapter(presenter: presenter)
        return ProfileScreen(adapter: adapter)
    }
}
```

规则：
- 在构造之后设置 `presenter.view`，而非在 Presenter 初始化器内
- 从组合根注入具体仓库
- 将装配函数作为创建完整模块的唯一位置

## 反模式与修复

1. View 包含逻辑：
   - 症状：UIViewController 计算展示字符串、格式化日期或调用服务。
   - 修复：将所有逻辑移到 Presenter；View 接收可渲染的 view data。

2. Presenter 观察状态对象（ViewModel 模式泄漏）：
   - 症状：Presenter 发布 `@Published` 属性，View 直接观察。
   - 修复：保持 Presenter 命令驱动；View 状态由协议方法调用驱动，而非 KVO 或 Combine 管道。

3. 双向强引用：
   - 症状：Presenter 强引用 View。
   - 修复：在 Presenter 中声明 `weak var view: ProfileView?`。

4. 无请求标识把关：
   - 症状：快速重新加载相互覆盖，因为任何进行中完成都能更新 View。
   - 修复：为每个请求分配 `UUID`，所有视图更新都受标识相等性保护。

5. 臃肿的 Presenter：
   - 症状：Presenter 包含网络代码、缓存逻辑或路由细节。
   - 修复：将网络和持久化委托给注入的 Repository 协议；将导航委托给注入的 Router 或 Coordinator。

## 测试策略

用 mock View 和 stub Repository 隔离测试 Presenter。
针对成功、失败和取消路径验证 Presenter-to-View 契约。
使用 stub 控制异步行为，保持测试确定性，而非 `sleep`。

```swift
@MainActor
final class MockProfileView: ProfileView {
    var isLoading = false
    var shownViewData: ProfileViewData?
    var shownError: String?

    func showLoading(_ isLoading: Bool) { self.isLoading = isLoading }
    func show(profile: ProfileViewData) { shownViewData = profile }
    func showError(message: String) { shownError = message }
}

struct StubProfileRepository: ProfileRepository {
    var result: Result<User, Error>
    func fetchCurrentUser() async throws -> User { try result.get() }
}

@MainActor
final class ProfilePresenterTests: XCTestCase {
    func test_load_success_showsUserName() async {
        let user = User(id: UUID(), name: "Alice", isPremium: false, joinDate: .now)
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .success(user))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "Alice")
        XCTAssertNil(view.shownError)
    }

    func test_load_failure_showsError() async {
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .failure(TestError.notFound))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertNotNil(view.shownError)
        XCTAssertNil(view.shownViewData)
    }

    func test_load_cancellation_doesNotOverwriteExistingViewData() async {
        let existing = User(id: UUID(), name: "Existing", isPremium: false, joinDate: .now)
        let view = MockProfileView()
        view.show(profile: ProfileViewData(user: existing))
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .failure(CancellationError()))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "Existing")
    }

    func test_rapidLoads_onlyLatestResultShown() async {
        let firstUser = User(id: UUID(), name: "First", isPremium: false, joinDate: .now)
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .success(firstUser))
        )
        presenter.view = view

        // 模拟两次快速加载；第二次取消第一次。
        presenter.load() // 请求 A —— 将被取消
        presenter.load() // 请求 B —— 最新
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "First")
    }
}

private enum TestError: Error { case notFound }
```

## 何时优先使用 MVP

优先使用 MVP 的场景：
- UIKit 是主要技术栈，希望无需 observable 状态对象即可完全测试 Presenter
- View 必须完全被动（无 `if` 逻辑，无 `guard`，无格式化）
- 从 MVC 迁移，希望以最小步骤升级，不引入 Combine 或 `@Observable` 宏
- 现有团队熟悉 Presenter + View 协议模式

优先使用 MVVM 的场景：
- SwiftUI 是主要技术栈，`@Observable` / `@Published` 状态绑定减少接线开销
- 希望响应式数据流，减少手写命令分发

与 VIPER 相比，MVP 省略了 Interactor 和 Router 作为独立组件，对于单屏功能更轻量、更简单。

## PR 评审清单

- View 不含业务逻辑、数据格式化或服务调用。
- Presenter 中的 `view` 属性为 `weak` 且类型为 `ProfileView`。
- Presenter 在开始新加载前取消前一个任务。
- 所有 Presenter-to-View 调用在异步情况下都受请求标识保护。
- Repository 和服务依赖通过协议注入，而非单例。
- 测试覆盖成功、失败和过期取消路径。
- 装配函数从外部接线模块——Presenter 不创建自己的依赖。
