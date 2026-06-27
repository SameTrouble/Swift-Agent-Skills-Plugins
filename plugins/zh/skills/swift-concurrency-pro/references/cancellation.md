# 取消

Swift 并发中的取消是协作式的。设置取消标志本身不起作用，除非运行中的代码检查它。

## 取消如何传播

- 取消父任务会取消其所有子任务（结构化并发）。
- 取消任务组会取消该组中的所有子任务。
- `Task {}` 和 `Task.detached {}` 是非结构化的——必须通过存储任务句柄并调用 `.cancel()` 来显式取消。
- SwiftUI 的 `.task()` 修饰符在视图消失时自动取消其任务。这是在视图中优先使用 `.task()` 而非 `onAppear()` 或松散 `Task {}` 的主要原因。


## 检查取消

在长时间运行或循环的异步工作中使用这些很重要，但仅在实际可以安全退出时：

- `try Task.checkCancellation()`——取消时抛出 `CancellationError`。在抛出上下文中优先使用。
- `Task.isCancelled`——返回 `Bool`。在非抛出上下文中使用，或在退出前需要清理时使用。

```swift
func processAll(_ items: [Item]) async throws {
    for item in items {
        try Task.checkCancellation()
        try await process(item)
    }
}
```

调用其他异步函数的函数在每个 `await` 挂起点会获得隐式取消检查——但仅当被调用函数本身检查时。没有 `await` 的 CPU 密集型循环永远不会看到取消，除非你显式检查。


## `withTaskCancellationHandler`

将 Swift 取消桥接到拥有自己取消机制的遗留 API。`onCancel` 闭包在请求取消时立即触发——即使异步体正在挂起中——并且可能在任何线程上运行。

```swift
func fetchImage(_ url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    return try await withTaskCancellationHandler {
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    } onCancel: {
        // 这里没有直接取消的句柄——URLSession.data(for:) 已经
        // 在内部检查任务取消。此模式在包装返回可取消句柄的 API 时
        // 最有用。
    }
}
```

更实际的使用是包装提供取消句柄的内容：

```swift
func observe() async throws -> [Change] {
    let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
    let operation = CKQueryOperation(query: query)

    return try await withTaskCancellationHandler {
        try await performOperation(operation)
    } onCancel: {
        operation.cancel()
    }
}
```


## 错误的取消模式

**捕获并忽略 `CancellationError`：**

```swift
// 错误：对正常的生命周期事件重试或显示警报。
catch {
    showAlert(error.localizedDescription)
}
```

始终优先在处理其他错误之前过滤掉 `CancellationError`。参见 `bug-patterns.md`。

**忘记取消已存储的任务：**

```swift
// 错误：任务在对象使用完毕后仍在运行。
class ViewModel {
    var loadTask: Task<Void, Never>?

    func load() {
        loadTask = Task { await fetchData() }
    }
}
```

在启动新任务之前取消前一个任务，并在销毁时取消：

```swift
func load() {
    loadTask?.cancel()
    loadTask = Task { await fetchData() }
}

deinit {
    loadTask?.cancel()
}
```

**CPU 密集型工作中没有取消检查：**

没有 `await` 点的紧密计算循环即使被取消也会运行到完成，因为没有取消可以生效的挂起点。在安全的地方插入定期的 `try Task.checkCancellation()` 调用。
