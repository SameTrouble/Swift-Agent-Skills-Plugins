# Clean Architecture 手册（Swift + SwiftUI/UIKit）

当 Swift 代码库需要严格的层边界和用例驱动的业务逻辑时使用本参考。

## 目录
- [核心依赖规则](#核心依赖规则)
- [规范层布局](#规范层布局)
- [实体](#实体)
- [用例](#用例)
- [仓库边界](#仓库边界)
- [依赖注入模式](#依赖注入模式)
- [DTO 到领域映射](#dto-到领域映射)
- [并发与取消](#并发与取消)
- [表现层边界](#表现层边界)
- [反模式与修复](#反模式与修复)
- [测试策略](#测试策略)
- [何时优先使用 Clean Architecture](#何时优先使用-clean-architecture)
- [PR 评审清单](#pr-评审清单)

## 核心依赖规则

依赖指向内部：

```text
Frameworks / UI
    ->
Interface Adapters
    ->
Use Cases
    ->
Entities (Domain)
```

规则：
- 内层不得导入或依赖外层
- 领域层保持纯 Swift
- 框架是实现细节，可替换

## 规范层布局

```text
Domain/
  Entities/
  UseCases/
Data/
  Repositories/
  API/
  Persistence/
Presentation/
  Features/
App/
```

指导：
- 将实体和用例协议放在 `Domain`
- 将仓库实现和外部适配器放在 `Data`
- 将视图/view model/控制器放在 `Presentation`
- 将 DI 组合根和应用引导放在 `App`

## 实体

实体建模核心业务概念和规则。

```swift
struct User: Equatable {
    let id: UUID
    let name: String
}
```

规则：
- 不导入 SwiftUI/UIKit
- 不含持久化或网络行为
- 除非不可避免，避免使用框架专属类型

## 用例

用例通过抽象编排业务动作。

```swift
protocol LoadUserUseCase {
    func execute(id: UUID) async throws -> User
}

final class LoadUser: LoadUserUseCase {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> User {
        try await repository.fetch(id: id)
    }
}
```

规则：
- 每个用例只承担一个业务职责
- 不含 UI 细节
- 除非已抽象，不直接使用框架

## 仓库边界

在 `Domain` 中定义仓库协议；在 `Data` 中实现它们。

```swift
protocol UserRepository {
    func fetch(id: UUID) async throws -> User
}
```

数据层实现可以协调：
- API 客户端
- 本地持久化
- 将 DTO 映射为领域实体

## 依赖注入模式

在应用或功能装配层组合实际依赖。

```swift
enum UserFeatureAssembly {
    static func makeLoadUserUseCase() -> LoadUserUseCase {
        let repository = LiveUserRepository(api: .live)
        return LoadUser(repository: repository)
    }
}
```

规则：
- 将协议注入用例和表现层
- 避免将全局单例作为隐藏依赖

## DTO 到领域映射

在数据层边界将外部模型映射为领域实体，放在 mapper 或仓库实现中。

```swift
struct UserDTO: Decodable {
    let id: String
    let full_name: String
    let created_at: String
}

enum UserMapper {
    static func toDomain(_ dto: UserDTO) throws -> User {
        guard let id = UUID(uuidString: dto.id) else {
            throw MappingError.invalidID(dto.id)
        }
        return User(id: id, name: dto.full_name)
    }
}

enum MappingError: Error {
    case invalidID(String)
}

final class LiveUserRepository: UserRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func fetch(id: UUID) async throws -> User {
        let dto = try await api.fetchUser(id: id)
        return try UserMapper.toDomain(dto)
    }
}
```

规则：
- 永远不要让 DTO 超出数据层
- 独立测试 mapper 的边界情况和非法输入
- 保持映射为纯函数，无副作用

## 并发与取消

在用例中使用结构化并发，并让取消通过 async 调用传播。

```swift
final class LoadUserProfile: LoadUserProfileUseCase {
    private let userRepo: UserRepository
    private let postsRepo: PostsRepository

    init(userRepo: UserRepository, postsRepo: PostsRepository) {
        self.userRepo = userRepo
        self.postsRepo = postsRepo
    }

    func execute(id: UUID) async throws -> UserProfile {
        async let user = userRepo.fetch(id: id)
        async let posts = postsRepo.fetchRecent(userID: id)
        return try await UserProfile(user: user, posts: posts)
    }
}
```

规则：
- 对并发的独立请求优先使用 `async let`
- 取消通过 `try await` 自动传播
- 需要时在昂贵工作前使用 `Task.checkCancellation()`
- 在表现层，于视图消失或新请求时取消任务

## 表现层边界

表现层依赖用例抽象，而非数据实现。

预期流程：
- View 触发 intent/事件
- 表现层调用 `UseCase`
- UseCase 返回领域实体
- 表现层将实体映射为视图状态

SwiftUI 适配：
- 使用 `@Observable`/`ObservableObject` ViewModel，暴露视图状态
- 从 ViewModel 的 intent 方法触发用例
- 保持 SwiftUI 视图声明式，不含用例/仓库调用

UIKit 适配：
- 使用由视图控制器持有的 Presenter/ViewModel 对象
- 将 delegate/target-action 事件转换为 presenter intent
- 保持控制器仅负责渲染；业务协调放在 presenter/用例层

## 反模式与修复

1. 上帝用例：
- 症状：单个 500+ 行的用例处理大量职责。
- 修复：按业务能力拆分并组合用例。

2. 表现层导入数据层：
- 症状：功能 view model 直接使用 `LiveRepository` 或 API 客户端。
- 修复：仅依赖用例协议。

3. 领域层依赖框架：
- 症状：领域实体使用 UI/网络/持久化框架。
- 修复：保持领域层纯净，将适配器外移。

4. 仓库泄漏传输类型：
- 症状：表现层接收到 DTO/网络模型。
- 修复：在数据层将外部模型映射为领域实体。

5. 通过真实基础设施测试：
- 症状：单元测试需要网络/数据库。
- 修复：用 mock/stub 仓库测试用例。

## 测试策略

优先：
- 使用仓库 stub 的用例单元测试
- 数据层的 mapper 测试（DTO <-> 领域）
- 使用 mock 用例的表现层测试

规则：
- 单元测试中避免网络
- 在用例边界断言业务行为
- 使用可控 stub 保持异步测试确定性
- 为长时间运行的用例测试取消传播

```swift
struct StubUserRepository: UserRepository {
    var result: Result<User, Error>

    func fetch(id: UUID) async throws -> User {
        try result.get()
    }
}

@MainActor
final class LoadUserTests: XCTestCase {
    func test_execute_returnsUser() async throws {
        let expected = User(id: UUID(), name: "Alice")
        let sut = LoadUser(repository: StubUserRepository(result: .success(expected)))
        let user = try await sut.execute(id: expected.id)
        XCTAssertEqual(user, expected)
    }

    func test_execute_propagatesFailure() async {
        let sut = LoadUser(repository: StubUserRepository(result: .failure(TestError.notFound)))
        do {
            _ = try await sut.execute(id: UUID())
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_execute_cancellationPropagates() async {
        let sut = LoadUser(repository: BlockingUserRepository())
        // 确定性是因为此测试类是 @MainActor：
        // Task { ... } 继承 main-actor 隔离，在 await task.value 让出主线程之前不会开始执行，
        // 因此取消会被立即观察到。没有 @MainActor 时此模式会有竞态。
        let task = Task { try await sut.execute(id: UUID()) }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // 符合预期
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor BlockingUserRepository: UserRepository {
    func fetch(id: UUID) async throws -> User {
        try await Task.sleep(for: .seconds(60))
        return User(id: id, name: "")
    }
}

private enum TestError: Error { case notFound }
```

## 何时优先使用 Clean Architecture

优先使用的场景：
- 应用/领域复杂度为中到大型
- 多团队需要稳定边界
- 长期可维护性和可替换基础设施很重要

优先使用更轻分层的情况：
- 应用较小且生命周期短
- 严格分层的开销高于预期收益

## PR 评审清单

- 依赖方向仅指向内部。
- 领域层与框架无关。
- 用例封装业务规则且保持聚焦。
- 表现层不导入数据实现。
- 仓库抽象位于领域边界。
- 测试将用例与基础设施隔离。
