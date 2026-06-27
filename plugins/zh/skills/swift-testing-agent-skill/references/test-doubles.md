# 测试替身

测试替身帮助将待测系统（SUT）与副作用隔离。术语来自 [Martin Fowler 的 "Mocks Aren't Stubs"](https://martinfowler.com/articles/mocksArentStubs.html)。

## 状态验证 vs 行为验证

| 方法 | 描述 | 使用的测试替身 |
|------|------|----------------|
| **状态验证** | 对操作后的最终状态进行断言 | Stub、Fake、Spy |
| **行为验证** | 验证对协作者的调用是否正确 | Mock |

**优先使用状态验证**——测试更简单、更不易碎。

## Dummy

Dummy 不做任何事情——只是一个占位符：

```swift
struct UserServiceDummy: UserServiceProtocol {
    func login(_ user: User, completion: (Result<Void, Error>) -> Void) {
        // 什么都不做
    }
}
```

## Fake

带捷径的工作实现（如内存数据库）：

```swift
final class FavoritesManagerFake: FavoritesManagerProtocol {
    var favorites: [Movie] = []

    func add(_ movie: Movie) throws {
        guard !favorites.contains(where: { $0.id == movie.id }) else {
            throw FavoritesError.alreadyExists
        }
        favorites.append(movie)
    }

    func remove(_ movie: Movie) throws {
        guard let index = favorites.firstIndex(where: { $0.id == movie.id }) else {
            throw FavoritesError.notFound
        }
        favorites.remove(at: index)
    }
}
```

## Stub

返回预设值：

```swift
final class PostsServiceStub: PostsServiceProtocol {
    var fetchAllResultToBeReturned: Result<[Post], Error> = .success([])

    func fetchAll() async throws -> [Post] {
        try fetchAllResultToBeReturned.get()
    }
}

// 命名：[methodName]ToBeReturned
```

## Spy

记录调用以供验证：

```swift
final class SafeStorageSpy: SafeStorageProtocol, @unchecked Sendable {
    private(set) var storeUserDataCalled = false
    private(set) var userPassed: User?
    private(set) var storeUserDataCount = 0

    func storeUserData(_ user: User) {
        storeUserDataCalled = true
        storeUserDataCount += 1
        userPassed = user
    }
}

// 命名约定：
// - 方法被调用：[name]Called（Bool）
// - 捕获参数：[name]Passed
// - 调用计数：[name]Count（Int）
// - 都应为 private(set)
```

## SpyingStub（最常见）

Stub + Spy 的组合——这就是 Swift 开发者通常所说的 "Mock"：

```swift
final class PersonalRecordsRepositorySpyingStub: PersonalRecordsRepositoryProtocol, @unchecked Sendable {
    // Spy：捕获调用
    private(set) var savedRecords: [PersonalRecord] = []
    private(set) var deletedIds: [UUID] = []
    private(set) var getAllCalled = false

    // Stub：可配置的响应
    var recordsToReturn: [PersonalRecord] = []
    var errorToThrow: Error?

    func getAll() async throws -> [PersonalRecord] {
        getAllCalled = true
        if let error = errorToThrow { throw error }
        return recordsToReturn
    }

    func save(_ record: PersonalRecord) async throws {
        if let error = errorToThrow { throw error }
        savedRecords.append(record)
    }

    func delete(id: UUID) async throws {
        if let error = errorToThrow { throw error }
        deletedIds.append(id)
    }
}

// 命名：[ProtocolName]SpyingStub
```

## 真正的 Mock（Fowler 定义）

预设期望并自我验证：

```swift
final class UserServiceMock: UserServiceProtocol {
    struct Expectation: Equatable {
        let method: String
        let userId: String?
    }

    private var expectations: [Expectation] = []
    private var actualCalls: [Expectation] = []
    private var returnValues: [String: User] = [:]

    // 设置（测试前）
    func expectGetUser(id: String, returning user: User) {
        expectations.append(Expectation(method: "getUser", userId: id))
        returnValues[id] = user
    }

    // 协议实现
    func getUser(id: String) async throws -> User {
        let call = Expectation(method: "getUser", userId: id)
        actualCalls.append(call)

        guard expectations.contains(call) else {
            fatalError("Unexpected call: getUser(id: \(id))")
        }

        guard let user = returnValues[id] else {
            throw UserError.notFound
        }
        return user
    }

    // 验证（测试后）
    func verify() {
        assert(expectations == actualCalls)
    }
}

// 用法
@Test("fetches user with expected ID")
func fetchesExpectedUser() async throws {
    let mock = UserServiceMock()
    mock.expectGetUser(id: "123", returning: User.fixture())

    await sut.loadProfile(userId: "123")

    mock.verify()  // 自我验证
}
```

**在以下情况使用真正的 mock**：
- 测试交互协议（代理）
- 验证确切的调用序列
- 测试某些调用**不**发生

## Failing（未实现）

被意外调用时失败：

```swift
import XCTestDynamicOverlay

struct FailingNetworkService: NetworkServiceProtocol {
    func fetchData(from url: URL) async throws -> Data {
        XCTFail("fetchData(from:) was not expected to be called!")
        fatalError()
    }
}
```

使用 swift-dependencies：

```swift
extension PersonalRecordsRepository: TestDependencyKey {
    static let testValue = PersonalRecordsRepository(
        getAll: unimplemented("\(Self.self).getAll"),
        save: unimplemented("\(Self.self).save")
    )
}
```

## 选择合适的替身

| 需求 | 使用 |
|------|------|
| 填充参数 | Dummy |
| 工作的轻量级实现 | Fake |
| 控制返回值 | Stub |
| 验证调用是否发生 | Spy |
| 既控制又验证 | SpyingStub |
| 验证精确交互 | Mock |
| 捕获意外使用 | Failing |

## 放置位置

将测试替身放在**接口附近**，而非测试 target 中：

```swift
// 在 ModuleName-Interface/Sources/...

public protocol MyServiceProtocol: Sendable {
    func doSomething() async throws
}

#if DEBUG
public final class MyServiceSpyingStub: MyServiceProtocol {
    // 实现
}
#endif
```

优势：
- 所有测试 target 都可用
- 与其实现的契约放在一起
- 使用 `#if DEBUG` 实现零生产开销
