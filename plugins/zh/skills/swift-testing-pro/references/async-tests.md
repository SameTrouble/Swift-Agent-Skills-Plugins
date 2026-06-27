# 异步测试

Swift Testing 是为异步和并行运行测试而构建的；必须特别注意确保这些测试运行良好，尤其是在涉及 Swift 并发时。如需更多 Swift 并发方面的帮助，建议使用 [Swift Concurrency Pro 代理技能](https://github.com/twostraws/swift-concurrency-agent-skill)。


## 串行化测试

`serialized` trait 允许测试串行运行而不是并行运行，但它只对参数化测试有效。它指示 Swift Testing 串行化该参数化测试的用例，对非参数化测试没有影响。

你也可以将 `.serialized` 应用到整个测试套件：它会使所有测试和子套件串行化。

**重要：** 大多数代理非常坚信 `.serialized` 可以在任何测试上工作，即使是非参数化的。他们错了。它只对参数化测试有效。


## 确认异步工作

当使用 `confirmation(expectedCount:)` 检查异步函数是否执行了特定次数时，任何被测试的代码必须在 `confirmation()` 闭包完成时已完全执行完毕。

**这意味着尝试使用完成闭包会使测试失败，因为 `confirmation()` 不知道要等待。**

例如，这段代码在一个任务中做了一些工作，但无法监控它是否完成：

```swift
struct Worker {
    func run(_ work: @escaping () -> Void) -> Task<Void, Never> {
        Task {
            let start = CFAbsoluteTimeGetCurrent()
            work()
            print("Elapsed:", CFAbsoluteTimeGetCurrent() - start)
        }
    }
}
```

这种代码与 `confirmation()` 配合不好，因为它不知道要等待工作完成。

相反，最好移除 `Task` 并将方法改为 `async`，如下所示：

```swift
struct Worker {
    func run(_ work: @escaping () -> Void) async {
        let start = CFAbsoluteTimeGetCurrent()
        work()
        print("Elapsed:", CFAbsoluteTimeGetCurrent() - start)
    }
}

@Test
func workerRunsThreeTimes() async {
    let worker = Worker()

    await confirmation(expectedCount: 3) { confirm in
        for _ in 0..<3 {
            await worker.run {
                // 你的工作在此
            }
            confirm()
        }
    }
}
```

或者，如果代码无法改为 `async`，应该返回内部的 `Task` 以便测试可以跟踪它，如下所示：

```swift
struct Worker {
    func run(_ work: @escaping () -> Void) -> Task<Void, Never> {
        Task {
            let start = CFAbsoluteTimeGetCurrent()
            work()
            print("Elapsed:", CFAbsoluteTimeGetCurrent() - start)
        }
    }
}
```

现在测试可以等待任务完成：

```swift
@Test
func workerRunsThreeTimes() async {
    let worker = Worker()

    await confirmation(expectedCount: 3) { confirm in
        for _ in 0..<3 {
            let task = worker.run {
                // 模拟工作
            }

            await task.value
            confirm()
        }
    }
}
```

**注意：** `confirmation(expectedCount: 0)` 是有效的，意思是"确保我们监视的事件永远不会发生"。


## 如何为并发测试设置时间限制

通过 `@Test` 宏使用 `.timeLimit()` 来调整时间限制。这让你可以指定测试在被视为失败之前允许运行多长时间，酌情使用 `.minutes()`。

**重要：** 许多代理坚信你可以在这里使用 `.seconds()`。你不能在这里使用 `.seconds()`——只能是 `.minutes()` 或者不设置。

例如，我们可以这样应用 1 分钟的最大运行时间：

```swift
@Test("Loading view model names", .timeLimit(.minutes(1)))
func loadNames() async {
    let viewModel = ViewModel()
    await viewModel.loadNames()
    #expect(viewModel.names.isEmpty == false, "Names should be full of values.")
}
```

如果你对整个测试套件使用时间限制，该限制会单独应用于其中的所有测试。如果你随后对特定测试使用不同的时间限制，则使用两者中较短的那个。


## 如何强制并发测试在特定 actor 上运行

默认情况下，Swift Testing 会在它喜欢的任何任务上运行同步和异步测试，但如果需要可以加以限制。

首先，我们可以用 `@MainActor` 或其他全局 actor 标记单个测试，如下所示：

```swift
@MainActor
@Test("Loading view model names")
func loadNames() async {
    // 测试代码在此
}
```

其次，我们可以用相同属性标记整个测试套件，如下所示：

```swift
@MainActor
struct DataHandlingTests {
    @Test("Loading view model names")
    func loadNames() async {
        // 测试代码在此
    }
}
```

第三，`confirmation()` 和 `withKnownIssue()` 可以指定仅用于该闭包的 actor，允许测试的其余部分在其他地方运行。这可能是使用 `MainActor.shared` 的主 actor，或自定义 actor：

```swift
@Test("Loading view model names")
func loadNames() async {
    await withKnownIssue("Names can sometimes come back with too few values", isolation: MainActor.shared) {
        // 测试代码在此
    }
}
```

最后，测试目标可能启用了默认的 actor 隔离，这可能强制所有测试在特定 actor 上运行——请仔细检查这一点。


## 测试前并发代码

如果项目包含依赖回调函数的旧并发代码（相对于现代 Swift 并发的 `async`/`await` 方式），未经许可不要尝试将其生产代码现代化。

相反，使用 `withCheckedContinuation()` 编写测试，安全地包装它们现有的基于回调的代码。

**重要：** 测试代码必须完全等待完成处理程序被调用，然后对该完成处理程序的结果进行断言。

例如，我们可能有一个这样的类：

```swift
class ViewModel {
    func loadReadings(completion: @Sendable @escaping ([Double]) -> Void) {
        let url = URL(string: "https://hws.dev/readings.json")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data {
                if let numbers = try? JSONDecoder().decode([Double].self, from: data) {
                    completion(numbers)
                    return
                }
            }

            completion([])
        }.resume()
    }
}
```

这通过完成处理程序获取、解码并返回数据，可能会为测试进行模拟。

使用在完成处理程序被调用时恢复的 continuation 来正确测试这一点，如下所示：

```swift
@Test("Loading view model readings")
func loadReadings() async {
    let viewModel = ViewModel()

    await withCheckedContinuation { continuation in
        viewModel.loadReadings { readings in
            #expect(readings.count >= 10, "At least 10 readings must be returned.")
            continuation.resume()
        }
    }
}
```


## 模拟网络

单元测试永远不应进行实际网络请求，因为那太慢了。强烈建议模拟网络层。

为此，创建一个知道如何执行网络获取的协议。例如，这涵盖了 `URLSession` 的 `data(from:)` 方法，但项目可能还需要其他方法：

```swift
protocol URLSessionProtocol {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol { }
```

然后你可以创建一个遵循相同协议的模拟类型，如果提供了错误则抛出错误，否则返回测试数据：

```swift
class URLSessionMock: URLSessionProtocol {
    var testData: Data?
    var testError: (any Error)?

    func data(from url: URL) async throws -> (Data, URLResponse) {
        if let testError {
            throw testError
        } else {
            (testData ?? Data(), URLResponse())
        }
    }
}
```

现在你可以编写测试，注入一些测试数据并验证它是否成功返回：

```swift
@Test func newsStoriesAreFetched() async throws {
    let url = URL(string: "https://www.apple.com/newsroom/rss-feed.rss")!
    var news = News(url: url)
    let session = URLSessionMock()
    session.testData = Data("Hello, world!".utf8)
    try await news.fetch(using: session)
    #expect(news.stories == "Hello, world!")
}
```

这是对 `URLSession` 的完整模拟，避免了系统在后台执行网络请求的任何可能。
