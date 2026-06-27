# 桥接同步与异步代码

## 检查型 continuation

`withCheckedContinuation` 和 `withCheckedThrowingContinuation` 将基于回调的 API 包装为异步函数。关键规则是：**continuation 必须在每条代码路径上恰好恢复一次。**

- 恢复零次：调用方永远挂起。
- 恢复两次：运行时崩溃。

因此，审查每条代码路径。如果回调可能不触发（例如对象被释放），确保你仍然恢复 continuation。

在任何地方都默认使用 `withCheckedContinuation` / `withCheckedThrowingContinuation`，包括生产构建。运行时检查能捕获双重恢复和遗漏恢复的 bug，这些 bug 否则极难诊断。

只有在分析证明检查型版本是热路径中的瓶颈之后才考虑切换到 `withUnsafe` continuation 变体，但这种情况在实践中很少见。


## 包装基于代理的 API

对于随时间传递多个值的代理模式，使用 `AsyncStream`。使用 `makeStream(of:)` 以成对形式获取流和 continuation，并使用 `onTermination` 在消费者停止监听时进行清理。

确保：

- continuation 作为属性存储，以便代理回调可以向其 yield。
- `onTermination` 在消费者的 `for await` 循环结束时（或任务被取消时）运行，因此它是停止底层服务的正确位置。

此模式支持单个消费者。如果需要多个消费者，考虑通过 `@Observable` 类进行广播。


## 回调代码中的运行时 actor 断言

基于回调的 API 是 actor 假设在运行时失败的常见位置。

- 如果回调在没有类型系统保证的情况下触及 main actor 状态，Swift 6 运行时检查可能会陷入陷阱而非静默竞态。
- 仅当回调确实绑定到 main actor 且你正在编码编译器无法看到的保证时，才使用 `MainActor.assumeIsolated()`。


## `@unchecked Sendable`

这会完全压制编译器的 Sendable 检查。这是向编译器承诺你已经自行验证了线程安全，这是一个很高的门槛——非常仔细地评估此类代码。

合理用途：

- 使用内部锁定（例如 `os_unfair_lock`、`NSLock` 等）且真正线程安全的类型。
- 可变状态实际上由 actor 保护但由于某种原因无法向编译器表达的引用类型。

危险信号：

- 应用 `@unchecked Sendable` 来压制编译器错误而不理解错误为何存在。（这以前是 Xcode 中的 Fix-It 建议，因此并不罕见。）
- 将其应用于具有可变 `var` 属性且无同步的类。
- 将其用作变通方法或捷径，而不是根据情况重构代码以使用值类型或 actor。

在考虑使用 `@unchecked Sendable` 之前，检查 Swift 6 的基于区域的隔离是否已经解决了问题——许多以前需要它的情况现在可以干净地编译。
