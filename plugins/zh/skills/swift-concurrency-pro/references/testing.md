# 测试并发代码

## 使用 Swift Testing 的异步测试

Swift Testing 原生支持异步测试函数。无需特殊设置：

```swift
@Test func userLoads() async throws {
    let user = try await UserService().load(id: "123")
    #expect(user.name == "Alice")
}
```

不要在 Swift Testing 测试中将异步工作包装在 `Task {}` 中，也不要使用 expectation/信号量——只需将测试函数设为 `async`。


## 测试 actor 状态

在测试中通过 `await` 访问 actor 属性，就像生产代码一样。不要尝试用仅为测试添加的 `nonisolated` 访问器来绕过 actor 隔离。

```swift
@Test func cachingWorks() async throws {
    let cache = ImageCache()
    let image = try await cache.image(for: testURL)
    let cached = try await cache.image(for: testURL)
    #expect(image == cached)
}
```


## `.serialized` trait 与并发测试

Swift Testing 默认并行运行测试，这对于并发代码通常是你想要的。然而，你可能会遇到用于控制执行顺序的 `.serialized` trait。

**重要：** `.serialized` 仅影响参数化测试。它告诉 Swift Testing 逐个运行该测试的参数用例而非并行。将 `.serialized` 应用于非参数化测试没有任何效果。将其应用于整个 suite 只会串行化该 suite 内的参数化测试；suite 中的其他测试不受影响。

代理常常假设 `.serialized` 对任何测试都有效。事实并非如此。

```swift
// .serialized 仅控制参数化用例的执行顺序。
@Test(.serialized, arguments: ["alice", "bob", "charlie"])
func accountCreation(username: String) async throws {
    let account = try await AccountService().create(username: username)
    #expect(account.isActive)
}
```


## 用于异步事件的 Confirmation

当测试某个异步事件是否触发（例如回调、通知或流值）时，使用 Swift Testing 的 `confirmation()`：

```swift
@Test func notificationFires() async {
    await confirmation { confirmed in
        // 在发布之前开始监听，并 yield 以确保
        // for-await 循环在通知发送之前确实在迭代。
        // 没有 yield，post 可能在监听器准备好之前
        // 到达，使测试不稳定。
        let task = Task {
            for await _ in NotificationCenter.default.notifications(named: .dataDidChange) {
                confirmed()
                break
            }
        }

        // 给任务一个机会到达其 for-await 循环内的
        // 第一个挂起点。
        await Task.yield()

        NotificationCenter.default.post(name: .dataDidChange, object: nil)
        await task.value
    }
}
```

如果闭包从未被调用，`confirmation()` 会使测试失败，替代了旧的 XCTest 模式 `XCTestExpectation` + `wait(for:timeout:)`。

**重要：** 所有被确认的异步工作必须在 `confirmation()` 闭包返回之前完成。如果被测代码内部生成一个 `Task` 而测试没有办法 await 该任务，`confirmation()` 会在工作完成之前结束，测试将失败。要么将生产 API 设为 `async` 以便测试可以直接 await 它，要么让它返回其 `Task` 句柄以便测试可以在闭包结束前调用 `await task.value`。


## 测试中的 actor 隔离

默认情况下，Swift Testing 在它选择的任何执行器上运行测试。当测试需要特定 actor 隔离的代码时，你可以约束这一点。

当代码需要 main actor 隔离时，用 `@MainActor` 标记单个测试或整个 suite：

```swift
@MainActor
@Test func viewModelUpdatesOnMainActor() async {
    let vm = ViewModel()
    await vm.refresh()
    #expect(vm.items.isEmpty == false)
}
```

对于更细粒度的控制，`confirmation()` 和 `withKnownIssue()` 都接受 `isolation` 参数。这仅在该闭包上运行特定 actor，而测试的其余部分在其他地方运行：

```swift
@Test func loadingUpdatesUI() async {
    await confirmation(isolation: MainActor.shared) { confirmed in
        let vm = ViewModel(onUpdate: { confirmed() })
        await vm.load()
    }
}
```

还要注意，测试 target 可以在模块级别启用默认 actor 隔离（例如默认 main actor 模块）。在审查关于隔离的测试失败时，检查 target 的构建设置。


## 使用 `@TaskLocal` 的测试作用域 trait

**需要 Swift 6.1 或更高版本。**

当多个测试需要共享配置（例如 mock 环境或注入的依赖）时，测试作用域 trait 提供了一种并发安全的方式来设置它，使用任务局部值而非共享可变状态。

创建一个遵循 `TestTrait` 和 `TestScoping` 的类型，然后在 `provideScope()` 中设置任务局部值：

```swift
struct MockEnvironmentTrait: TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: () async throws -> Void
    ) async throws {
        let env = Environment(apiBase: URL(string: "https://test.example.com")!)

        try await Environment.$current.withValue(env) {
            try await function()
        }
    }
}

extension Trait where Self == MockEnvironmentTrait {
    static var mockEnvironment: Self { Self() }
}
```

然后将其应用于任何测试或 suite：

```swift
@Test(.mockEnvironment) func fetchUsesTestAPI() async throws {
    // Environment.current 现在是 mock，作用域仅限于该测试的任务。
    let users = try await UserService().fetchAll()
    #expect(users.isEmpty == false)
}
```

这避免了共享 `setUp()` 改变全局状态的并发风险。每个测试的配置存在于任务局部中，因此并行测试自动获得独立的值。


## 避免基于时间的测试

永远不要使用 `Task.sleep`、`Thread.sleep` 或固定延迟来"等待某事发生"。这些测试不稳定：它们可能在快速机器上通过，但在负载下或 CI 上失败。

```swift
// 错误：依赖时序。
@Test func dataLoads() async throws {
    viewModel.load()
    try await Task.sleep(for: .seconds(1))
    #expect(viewModel.items.isEmpty == false)
}
```

相反，await 实际的异步操作：

```swift
// 正确：await 真实的工作。
@Test func dataLoads() async throws {
    await viewModel.load()
    #expect(viewModel.items.isEmpty == false)
}
```

如果 API 是基于回调的，用 `withCheckedContinuation` 包装它或使用 `confirmation()`。


## 测试取消

目标是验证*被测代码*检查取消，而不仅仅是 `Task.checkCancellation()` 在测试工具中是否工作。设计测试使被测代码是观察取消标志的那个。

可靠的方法：给被测代码一个它阻塞的流或信号，在它挂起在该信号上时取消任务，然后验证它以 `CancellationError` 退出：

```swift
@Test func processorRespectsCancel() async throws {
    // Processor.run() 在项目之间调用 Task.checkCancellation()。
    // 给它足够的工作使取消在执行中途被检查。
    let processor = Processor(items: Array(repeating: .stub, count: 1_000))

    let task = Task {
        try await processor.run()
    }

    // 让处理器启动，然后取消。
    try await Task.sleep(for: .zero)
    task.cancel()

    await #expect(throws: CancellationError.self) {
        try await task.value
    }
}
```

如果被测代码是 `for await` 循环，你可以取消消费任务并验证循环退出。关键点：测试必须练习存在于生产代码中的取消检查，而不是你添加到测试本身的。


## 竞态检测

在测试 scheme 中启用线程清理器（TSan）以在运行时捕获数据竞态是个好主意。TSan 能发现编译器静态检查经常遗漏的竞态，特别是在使用 `@unchecked Sendable` 或不安全指针的代码中。

在 Xcode 中：Product → Scheme → Edit Scheme → Diagnostics → Thread Sanitizer。

TSan 会增加开销，因此考虑将其用于专门的 CI 任务而非每次本地运行。


## Swift Testing + Swift 并发

如需更多 Swift Testing 帮助，建议使用 [Swift Testing Pro agent skill](https://github.com/twostraws/swift-testing-agent-skill)。
