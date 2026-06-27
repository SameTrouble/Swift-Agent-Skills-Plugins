# 异步测试

使用 Swift Testing 测试异步代码。

## 基本异步测试

```swift
@Test func asyncOperation() async {
    let result = await service.fetch()
    #expect(result.isValid)
}

@Test func asyncThrowingOperation() async throws {
    let data = try await service.fetchData()
    #expect(!data.isEmpty)
}
```

## 测试异步序列

```swift
@Test func asyncSequence() async {
    let sequence = Counter().values
    var collected: [Int] = []

    for await value in sequence.prefix(3) {
        collected.append(value)
    }

    #expect(collected == [1, 2, 3])
}
```

## Confirmation（用于回调/代理）

测试代理模式或回调时使用 `confirmation`：

```swift
@Test func delegateCallback() async {
    await confirmation { confirm in
        let delegate = TestDelegate(onComplete: {
            confirm()
        })

        service.delegate = delegate
        service.performAction()
    }
}
```

### 多次 Confirmation

```swift
@Test func multipleCallbacks() async {
    await confirmation(expectedCount: 3) { confirm in
        let observer = Observer(onEvent: { _ in
            confirm()
        })

        emitter.emit(.event1)
        emitter.emit(.event2)
        emitter.emit(.event3)
    }
}
```

### 可选 Confirmation

```swift
@Test func optionalCallback() async {
    await confirmation(expectedCount: 0...1) { confirm in
        // 可能调用也可能不调用
        service.maybeNotify { confirm() }
    }
}
```

## 测试超时

### 内置时间限制

```swift
@Test(.timeLimit(.seconds(5)))
func mustCompleteQuickly() async {
    await slowOperation()
}
```

### 自定义超时

```swift
@Test func withCustomTimeout() async throws {
    try await withTimeout(seconds: 2) {
        try await service.fetch()
    }
}

func withTimeout<T>(
    seconds: Double,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

## 测试取消

```swift
@Test func cancellation() async {
    let task = Task {
        try await longRunningOperation()
    }

    // 给它时间启动
    try? await Task.sleep(for: .milliseconds(100))

    task.cancel()

    do {
        _ = try await task.value
        Issue.record("Should have been cancelled")
    } catch is CancellationError {
        // 预期行为
    }
}
```

## 测试 Actor

```swift
actor Counter {
    var value = 0
    func increment() { value += 1 }
}

@Test func actorState() async {
    let counter = Counter()

    await counter.increment()
    await counter.increment()

    let value = await counter.value
    #expect(value == 2)
}
```

## 测试 MainActor 代码

```swift
@MainActor
class ViewModel {
    var items: [Item] = []
    func load() async {
        items = await fetchItems()
    }
}

@Test @MainActor
func viewModelLoading() async {
    let viewModel = ViewModel()
    await viewModel.load()
    #expect(!viewModel.items.isEmpty)
}
```

## Mock 异步依赖

```swift
struct APIClient {
    var fetch: @Sendable (URL) async throws -> Data
}

@Test func withMockedClient() async throws {
    let mockData = "test".data(using: .utf8)!
    let client = APIClient(
        fetch: { _ in mockData }
    )

    let service = Service(client: client)
    let result = try await service.getData()

    #expect(result == mockData)
}
```

## 测试防抖操作

```swift
@Test func debounce() async throws {
    let debouncer = Debouncer(delay: .milliseconds(100))
    var callCount = 0

    // 快速连续调用
    for _ in 1...5 {
        await debouncer.submit {
            callCount += 1
        }
    }

    // 等待防抖
    try await Task.sleep(for: .milliseconds(150))

    #expect(callCount == 1)  // 只有最后一次调用执行
}
```

## 测试重试逻辑

```swift
@Test func retryOnFailure() async throws {
    var attempts = 0
    let service = Service(
        fetch: {
            attempts += 1
            if attempts < 3 {
                throw NetworkError.timeout
            }
            return Data()
        }
    )

    let result = try await service.fetchWithRetry(maxAttempts: 3)

    #expect(attempts == 3)
    #expect(result != nil)
}
```

## 最佳实践

1. **直接使用 async/await**：不需要 expectation/wait
2. **回调使用 confirmation**：测试代理模式时
3. **设置时间限制**：防止测试挂起
4. **测试取消**：确保正确清理
5. **Mock 异步依赖**：使用闭包提高可测试性
6. **在正确的 actor 上运行**：UI 测试使用 @MainActor
