# 测试并发代码

使用本文件当：

- 你正在编写异步测试。
- 测试因任务调度或 actor 隔离而不稳定。
- 你需要替换 XCTest 等待 API 或验证释放。

跳过本文件如果：

- 你主要需要生产所有权指导。使用 `actors.md`、`tasks.md` 或 `memory-management.md`。

跳转到：

- Swift Testing（推荐）
- 等待异步回调
- 设置和拆卸
- 处理不稳定测试
- Swift Concurrency Extras
- XCTest 模式（遗留）
- 内存管理测试
- 测试清单

## 建议：使用 Swift Testing

**强烈推荐**在新项目和测试中使用 Swift Testing。它提供：
- 带宏的现代 Swift 语法
- 更好的并发支持
- 更清晰的测试结构
- 更灵活的测试组织

XCTest 模式包含用于遗留代码库。

## Swift Testing 基础

### 简单异步测试

```swift
@Test
@MainActor
func emptyQuery() async {
    let searcher = ArticleSearcher()
    await searcher.search("")
    #expect(searcher.results == ArticleSearcher.allArticles)
}
```

**与 XCTest 的关键区别**：
- `@Test` 宏代替 `XCTestCase`
- `#expect` 代替 `XCTAssert`
- 优先使用结构体而非类
- 不需要 `test` 前缀

### 测试 actor

```swift
@Test
@MainActor
func searchReturnsResults() async {
    let searcher = ArticleSearcher()
    await searcher.search("swift")
    #expect(!searcher.results.isEmpty)
}
```

如果被测系统需要，用 actor 标记测试。

> **课程深入**：此主题在 [Lesson 11.2: Testing concurrent code using Swift Testing](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 等待异步回调

### 使用 continuation

测试非结构化任务时：

```swift
@Test
@MainActor
func searchTaskCompletes() async {
    let searcher = ArticleSearcher()
    
    await withCheckedContinuation { continuation in
        _ = withObservationTracking {
            searcher.results
        } onChange: {
            continuation.resume()
        }
        
        searcher.startSearchTask("swift")
    }
    
    #expect(searcher.results.count > 0)
}
```

**使用当**：测试派生非结构化任务的代码。

### 使用 confirmation

用于结构化异步代码：

```swift
@Test
@MainActor
func searchTriggersObservation() async {
    let searcher = ArticleSearcher()
    
    await confirmation { confirm in
        _ = withObservationTracking {
            searcher.results
        } onChange: {
            confirm()
        }
        
        // 必须在此 await 以使 confirmation 生效
        await searcher.search("swift")
    }
    
    #expect(!searcher.results.isEmpty)
}
```

**关键**：必须 `await` 异步工作才能使 confirmation 验证。

## 设置和拆卸

### 使用 init/deinit

```swift
@MainActor
final class DatabaseTests {
    let database: Database
    
    init() async throws {
        database = Database()
        await database.prepare()
    }
    
    deinit {
        // 仅同步清理
    }
    
    @Test
    func insertsData() async throws {
        try await database.insert(item)
        #expect(await database.count() == 1)
    }
}
```

**限制**：`deinit` 不能调用异步方法。

### 测试作用域 Trait

用于异步拆卸：

```swift
@MainActor
struct DatabaseTrait: SuiteTrait, TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: () async throws -> Void
    ) async throws {
        let database = Database()
        
        try await Environment.$database.withValue(database) {
            await database.prepare()
            try await function()
            await database.cleanup() // 异步拆卸
        }
    }
}

// 用于 task-local 存储的环境
@MainActor
struct Environment {
    @TaskLocal static var database = Database()
}

// 应用到套件
@Suite(DatabaseTrait())
@MainActor
final class DatabaseTests {
    @Test
    func insertsData() async throws {
        try await Environment.database.insert(item)
    }
}

// 或应用到单个测试
@Test(DatabaseTrait())
func specificTest() async throws {
    // 测试代码
}
```

**使用当**：每个测试后需要异步清理。

## 处理不稳定测试

### 问题：竞争条件

```swift
@Test
@MainActor
func isLoadingState() async throws {
    let fetcher = ImageFetcher()
    
    let task = Task { try await fetcher.fetch(url) }
    
    // ❌ 不稳定——可能通过或失败
    #expect(fetcher.isLoading == true)
    
    try await task.value
    #expect(fetcher.isLoading == false)
}
```

**问题**：任务可能在我们检查 `isLoading` 之前完成。

### 解决方案：Swift Concurrency Extras

```swift
import ConcurrencyExtras

@Test
@MainActor
func isLoadingState() async throws {
    try await withMainSerialExecutor {
        let fetcher = ImageFetcher { url in
            await Task.yield() // 允许测试检查状态
            return Data()
        }
        
        let task = Task { try await fetcher.fetch(url) }
        
        await Task.yield() // 切换到任务
        
        #expect(fetcher.isLoading == true) // ✅ 可靠
        
        try await task.value
        #expect(fetcher.isLoading == false)
    }
}
```

**添加包**：`https://github.com/pointfreeco/swift-concurrency-extras.git`

> **课程深入**：此主题在 [Lesson 11.3: Using Swift Concurrency Extras by Point-Free](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 需要串行执行

```swift
@Suite(.serialized)
@MainActor
final class ImageFetcherTests {
    // 使用 withMainSerialExecutor 时测试串行运行
}
```

**关键**：主串行执行器不与并行测试执行一起工作。

## XCTest 模式（遗留）

### 基本异步测试

```swift
final class ArticleSearcherTests: XCTestCase {
    @MainActor
    func testEmptyQuery() async {
        let searcher = ArticleSearcher()
        await searcher.search("")
        XCTAssertEqual(searcher.results, ArticleSearcher.allArticles)
    }
}
```

### 使用 expectation

```swift
@MainActor
func testSearchTask() async {
    let searcher = ArticleSearcher()
    let expectation = expectation(description: "Search complete")
    
    _ = withObservationTracking {
        searcher.results
    } onChange: {
        expectation.fulfill()
    }
    
    searcher.startSearchTask("swift")
    
    // 使用 fulfillment，而非 wait
    await fulfillment(of: [expectation], timeout: 10)
    
    XCTAssertEqual(searcher.results.count, 1)
}
```

**关键**：使用 `await fulfillment(of:)`，而非 `wait(for:)` 以避免死锁。

### 设置和拆卸

```swift
final class DatabaseTests: XCTestCase {
    override func setUp() async throws {
        // 异步设置
    }
    
    override func tearDown() async throws {
        // 异步拆卸
    }
}
```

标记为 `async throws` 以调用异步方法。

> **课程深入**：此主题在 [Lesson 11.1: Testing concurrent code using XCTest](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 所有测试的主串行执行器

```swift
final class MyTests: XCTestCase {
    override func invokeTest() {
        withMainSerialExecutor {
            super.invokeTest()
        }
    }
}
```

## 常见模式

### 测试 @MainActor 代码

```swift
@Test
@MainActor
func viewModelUpdates() async {
    let viewModel = ViewModel()
    await viewModel.loadData()
    #expect(viewModel.items.count > 0)
}
```

### 测试 actor

```swift
@Test
func actorIsolation() async {
    let store = DataStore()
    await store.insert(item)
    let count = await store.count()
    #expect(count == 1)
}
```

### 测试取消

```swift
@Test
func cancellationStopsWork() async throws {
    let processor = DataProcessor()
    
    let task = Task {
        try await processor.processLargeDataset()
    }
    
    task.cancel()
    
    do {
        try await task.value
        Issue.record("Should have thrown cancellation error")
    } catch is CancellationError {
        // 预期
    }
}
```

### 测试延迟

```swift
@Test
func debouncedSearch() async throws {
    try await withMainSerialExecutor {
        let searcher = DebouncedSearcher()
        
        searcher.search("a")
        await Task.yield()
        
        searcher.search("ab")
        await Task.yield()
        
        searcher.search("abc")
        
        // 等待 debounce
        try await Task.sleep(for: .milliseconds(600))
        
        #expect(searcher.searchCount == 1) // 仅最后一次搜索执行
    }
}
```

### 测试任务组

```swift
@Test
func taskGroupProcessesAll() async throws {
    let processor = BatchProcessor()
    
    let results = await withTaskGroup(of: Int.self) { group in
        for i in 1...5 {
            group.addTask { await processor.process(i) }
        }
        
        var collected: [Int] = []
        for await result in group {
            collected.append(result)
        }
        return collected
    }
    
    #expect(results.count == 5)
}
```

## 测试内存管理

### 验证释放

```swift
@Test
func viewModelDeallocates() async {
    var viewModel: ViewModel? = ViewModel()
    weak var weakViewModel = viewModel
    
    viewModel?.startWork()
    viewModel = nil
    
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(weakViewModel == nil)
}
```

### 检测循环引用

```swift
@Test
func noRetainCycle() async {
    var manager: Manager? = Manager()
    weak var weakManager = manager
    
    manager?.startLongRunningTask()
    manager = nil
    
    #expect(weakManager == nil)
}
```

## 最佳实践

1. **新代码使用 Swift Testing**——现代，更好的并发支持
2. **用正确的隔离标记测试**——需要时用 @MainActor
3. **优先使用 confirmation 而非 continuation**——当结构化并发允许时
4. **用主串行执行器串行化测试**——避免不稳定测试
5. **显式测试取消**——确保正确清理
6. **验证释放**——及早捕获循环引用
7. **策略性使用 Task.yield()**——控制测试中的执行
8. **避免测试中的 sleep**——改用 continuation/confirmation
9. **测试 actor 隔离**——验证线程安全
10. **保持测试确定性**——避免时序依赖

## 从 XCTest 迁移

### XCTest → Swift Testing

```swift
// XCTest
final class MyTests: XCTestCase {
    func testExample() async {
        XCTAssertEqual(value, expected)
    }
}

// Swift Testing
@Suite
struct MyTests {
    @Test
    func example() async {
        #expect(value == expected)
    }
}
```

### Expectation → Confirmation

```swift
// XCTest
let expectation = expectation(description: "Done")
doWork { expectation.fulfill() }
await fulfillment(of: [expectation])

// Swift Testing
await confirmation { confirm in
    await doWork { confirm() }
}
```

### 设置/拆卸 → Trait

```swift
// XCTest
override func setUp() async throws {
    await prepare()
}

// Swift Testing
struct SetupTrait: TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: () async throws -> Void
    ) async throws {
        await prepare()
        try await function()
    }
}
```

## 故障排除

### 测试挂起

**原因**：等待永不完成的 expectation。

**解决方案**：添加超时，验证观察跟踪。

### 不稳定测试

**原因**：非结构化任务中的竞争条件。

**解决方案**：使用主串行执行器 + Task.yield()。

### 死锁

**原因**：在异步上下文中使用 `wait(for:)`。

**解决方案**：改用 `await fulfillment(of:)`。

### Confirmation 失败

**原因**：在 confirmation 块中未 await 异步工作。

**解决方案**：在异步调用前添加 `await`。

### Actor 隔离错误

**原因**：测试未标记所需 actor。

**解决方案**：为测试添加 `@MainActor` 或适当的 actor。

## 代理常犯的错误

- **不稳定的中期状态断言**：在创建 `Task` 后立即断言 `isLoading == true` 是竞争条件——任务可能尚未启动。在断言中期状态之前使用 `withMainSerialExecutor` + `Task.yield()` 控制调度。
- **在测试中使用 `Task.sleep` 作为同步原语**，而非确定性调度。
- **在不控制调度的情况下断言中期状态**：当需要在任务创建和完成之间观察状态时，始终使用 `withMainSerialExecutor`。注意：`withMainSerialExecutor` 不与并行测试执行一起工作——标记套件 `@Suite(.serialized)`。
- **深入隔离的内部**而非测试公共行为。
- **保留同一示例的 Swift Testing 和 XCTest 两个版本**，除非它们教授不同的迁移路径。

## 测试清单

- [ ] 测试用正确的隔离标记
- [ ] 使用 Swift Testing（推荐）
- [ ] 异步方法正确 await
- [ ] 测试取消
- [ ] 检查内存泄漏
- [ ] 处理竞争条件
- [ ] 超时适当
- [ ] 用串行执行器修复不稳定测试
- [ ] 验证 actor 隔离
- [ ] 在 trait 中清理（而非 deinit）

## 进一步学习

有关高级测试模式、真实世界示例和迁移策略：
- [Swift Testing 文档](https://developer.apple.com/documentation/testing)
- [Swift Concurrency Extras](https://github.com/pointfreeco/swift-concurrency-extras)
- [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)
