# 互操作与迁移

将遗留并发机制迁移到 Swift 并发的已批准模式。

## 完成处理程序 → `async`/`await`

除非用户要求你现代化他们的代码，否则最好保留现有的完成处理程序代码不动，因为它已被理解、测试且成熟。

相反，使用 `withCheckedThrowingContinuation` 为其提供现代 Swift 并发包装器。在每条路径上恰好恢复一次。详见 `bridging.md`。

```swift
func loadUser(id: String) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        api.fetchUser(id: id) { result in
            continuation.resume(with: result)
        }
    }
}
```

如果 SDK 已经提供 async 重载，直接使用它而不是包装。


## 代理 → `AsyncStream`

随时间传递多个值的代理很好地映射到 `AsyncStream`。使用 `makeStream(of:)` 并从代理回调中 yield。完整模式参见 `bridging.md`。

单次代理（一次回调然后完成）可以改用 `withCheckedContinuation`。


## `DispatchQueue.main.async` → `@MainActor`

```swift
// 修改前
DispatchQueue.main.async {
    self.label.text = "Done"
}

// 修改后——将外围函数或类型标记为 @MainActor
@MainActor
func updateLabel() {
    label.text = "Done"
}
```

如果从非隔离的异步上下文调用，调用点的 `await` 替代了分发：

```swift
await updateLabel()
```


## `DispatchQueue.global().async` → `@concurrent` 或任务组

对于一次性后台工作：

```swift
// 修改前
DispatchQueue.global().async {
    let result = heavyComputation()
    DispatchQueue.main.async { self.result = result }
}

// 修改后（Swift 6.2）
@concurrent
func heavyComputation() async -> ComputationResult { ... }

// 在调用点：
self.result = await heavyComputation()
```

普通的 `async` 辅助方法本身不会卸载 CPU 工作。如果目标是离开调用方的执行器，请使其显式。

对于并行批量工作，使用 `withTaskGroup`。参见 `structured.md`。


## 串行 `DispatchQueue` → `actor`

保护可变状态的串行分发队列直接映射到 `actor`：

```swift
// 修改前
class TokenStore {
    private let queue = DispatchQueue(label: "token-store")
    private var token: String?

    func setToken(_ t: String) {
        queue.sync { token = t }
    }

    func getToken() -> String? {
        queue.sync { token }
    }
}

// 修改后
actor TokenStore {
    private var token: String?

    func setToken(_ t: String) { token = t }
    func getToken() -> String? { token }
}
```


## 锁与检查型 Sendable

如果 API 必须保持同步，优先使用锁而不是引入 actor 隔离仅为了串行化访问。

- `Mutex` 提供最佳的编译时间，并且可以在拥有类型上保留检查型 `Sendable`。
- 传统锁仍然有效，但拥有的引用类型通常最终会带有 `@unchecked Sendable`。

*仅当 API 本身应该变为 actor 隔离时才选择 actor。*


## 从 Combine 迁移到 `AsyncSequence`

| Combine | Swift 并发 |
|---------|-------------------|
| `publisher.sink { }` | `for await value in stream { }` |
| `publisher.map { }` | `stream.map { }` |
| `publisher.filter { }` | `stream.filter { }` |
| `PassthroughSubject` | 通过 `makeStream(of:)` 创建的 `AsyncStream` |
| `CurrentValueSubject` | 无直接等价物（见下方注释） |
| `publisher.values` | 已经是 `AsyncSequence`——直接使用 |

如果 Combine 发布者已经暴露 `.values` 属性，直接消费它而不是将其包装在新的 `AsyncStream` 中。

Combine 目前尚未被正式弃用，但 Apple 的建议是避免使用它。
