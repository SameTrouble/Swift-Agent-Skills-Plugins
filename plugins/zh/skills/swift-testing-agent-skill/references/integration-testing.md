# 集成测试

集成测试验证模块交互——占测试金字塔的 15%。

## 何时编写集成测试

- 测试组件边界（用例 -> 仓库 -> 存储）
- 验证跨多个组件的工作流
- 使用内存存储测试真实实现
- 验证模块内的端到端数据流

## 基本结构

```swift
import Testing
@testable import PersonalRecordsCore

@Suite("PersonalRecords Integration Tests")
struct PersonalRecordsIntegrationTests {

    @Test("save and retrieve workflow completes successfully")
    func saveAndRetrieveWorkflow() async throws {
        // 使用真实实现和内存存储
        let storage = InMemoryStorageService()
        let repository = PersonalRecordsRepository(storage: storage)
        let saveUseCase = SavePRUseCase(repository: repository)
        let loadUseCase = LoadPRUseCase(repository: repository)

        let record = PersonalRecord.fixture(weight: 120.0)

        // 保存
        try await saveUseCase.dispatch(record)

        // 检索并验证
        let loaded = try await loadUseCase.dispatch()

        #expect(loaded.count == 1)
        #expect(loaded.first?.weight == 120.0)
    }
}
```

## 内存实现

为外部依赖创建 fake：

```swift
final class InMemoryStorageService: StorageServiceProtocol {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    func save(_ data: Data, forKey key: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = data
    }

    func load(forKey key: String) async throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func delete(forKey key: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
```

## 测试工作流

### 多步操作

```swift
@Test("complete user registration workflow")
func registrationWorkflow() async throws {
    // 用测试依赖设置真实组件
    let userStorage = InMemoryUserStorage()
    let tokenStorage = InMemoryTokenStorage()
    let userService = UserService(storage: userStorage)
    let authService = AuthService(tokenStorage: tokenStorage)

    let sut = RegistrationWorker(
        userService: userService,
        authService: authService
    )

    // 执行工作流
    let result = try await sut.register(
        username: "testuser",
        password: "SecurePass123"
    )

    // 验证最终状态
    #expect(result.isSuccess)
    #expect(userStorage.users.contains { $0.username == "testuser" })
    #expect(tokenStorage.hasToken)
}
```

### 错误传播

```swift
@Test("propagates storage errors through use case")
func errorPropagation() async throws {
    let failingStorage = FailingStorageService()
    let repository = PersonalRecordsRepository(storage: failingStorage)
    let sut = LoadPRUseCase(repository: repository)

    #expect(throws: PRError.storageUnavailable) {
        try await sut.dispatch()
    }
}
```

## 标记集成测试

使用标签过滤测试：

```swift
extension Tag {
    @Tag static var integration: Self
}

@Suite("Integration Tests", .tags(.integration))
struct PersonalRecordsIntegrationTests {
    // ...
}
```

仅运行集成测试：

```bash
swift test --filter integration
```

## 集成测试指南

### 应该

- 测试组件边界
- 对存储使用内存实现
- 测试完整工作流
- 验证数据流是否正确
- 为测试打标签以便过滤

### 不应该

- 测试 UI（使用快照/UI 测试）
- 使用真实网络调用
- 使用真实数据库
- 测试第三方库
- 编写过多（占金字塔的 15%）

## 测试组织

```
Tests/
└── PersonalRecordsCoreTests/
    ├── Unit/
    │   ├── UseCases/
    │   └── Repositories/
    ├── Integration/
    │   ├── WorkflowTests.swift
    │   └── DataFlowTests.swift
    └── Helpers/
        └── InMemoryStorage.swift
```

## 性能考虑

集成测试比单元测试慢：

```swift
@Test("bulk import performance", .timeLimit(.minutes(1)))
func bulkImportPerformance() async throws {
    let storage = InMemoryStorageService()
    let repository = PersonalRecordsRepository(storage: storage)
    let sut = BulkImportUseCase(repository: repository)

    let records = PersonalRecord.fixtures(count: 1000)

    try await sut.dispatch(records)

    #expect(storage.count == 1000)
}
```
