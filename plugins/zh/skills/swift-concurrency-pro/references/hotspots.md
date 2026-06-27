# 热点区域

并发审查的搜索目标。当代码中出现以下任何内容时，使用引用的规则仔细检查。

## `DispatchQueue`

在应用层代码中，`DispatchQueue.main.async`、`DispatchQueue.global()` 和自定义串行队列通常有对应的 Swift 并发等价物——参见 `interop.md`。然而，在低层库、框架互操作和性能关键的同步代码段中，队列或锁是正确的工具，GCD 仍然适用。在标记之前请仔细检查上下文。


## `Task.detached`

很少是正确的选择。通常意味着作者想要后台执行，但应该使用 `@concurrent`（Swift 6.2）或任务组。检查脱离 actor 隔离和优先级是否确实是刻意为之。参见 `unstructured.md`。


## 循环内的 `Task {}`

通常是个坏主意——评估是否应该改用任务组。参见 `structured.md`。


## `withCheckedContinuation` / `withCheckedThrowingContinuation`

审查每条代码路径，确保 continuation 恰好恢复一次。注意提前返回、抛出错误以及可能永不触发的回调。参见 `bridging.md`。


## `AsyncStream`（基于闭包的初始化器）

优先使用现代的 `AsyncStream.makeStream(of:)` 工厂方法。如果使用闭包形式，请验证在所有清理路径中都完成了 continuation。参见 `async-streams.md`。


## `@unchecked Sendable`

应当非常罕见。检查该类型是否真正提供了线程安全（内部锁定、不可变性）。如果只是为了压制编译器错误而添加，真正的修复通常是使用 actor 或值类型。检查 Swift 6 的基于区域的隔离是否使其变得不必要。参见 `bridging.md`。


## `MainActor.run {}`

通常是不必要的。如果周围代码已经是 `@MainActor`（显式或通过默认隔离），这就是一个空操作。如果它是用于从后台上下文跳转到 main actor，检查该函数是否应该直接标记为 `@MainActor`。


## Actor

检查可重入 bug：任何读取状态、await、然后写入状态的方法都是可疑的。参见 `actors.md` 和 `bug-patterns.md`。


## actor 内 `await` 之后的强制解包

在 `await` 之后对 actor 状态使用 `!` 是潜在崩溃的主要目标，因为另一个调用方可能在挂起期间将该值设为 `nil`。参见 `bug-patterns.md`。
