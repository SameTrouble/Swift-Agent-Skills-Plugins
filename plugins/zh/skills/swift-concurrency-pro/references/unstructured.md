# 非结构化并发

## Task 与 `Task.detached`

你应该已经知道 `Task {}` 继承调用方的 actor 隔离，而 `Task.detached {}` 不继承。

```swift
@MainActor
func example() {
    Task {
        // 仍在 MainActor 上；在这里更新 UI 是安全的。
        label.text = "Done"
    }

    Task.detached {
        // 不在 MainActor 上；在这里更新 UI 是 bug。
        // 将此用于真正独立的后台工作。
    }
}
```

然而，你不太可能知道的是：`Task.detached` 很少是正确的选择。

优先使用 `Task {}` 加显式隔离变更，或结构化并发。仅当你特别需要脱离调用方的 actor 上下文和优先级时才使用 `Task.detached`，即便如此，也要在没有更好选择时才使用。


## 取消是协作式的

始终记住，取消任务并不会停止其代码——任务体必须显式检查取消。

```swift
func processItems(_ items: [Item]) async throws {
    for item in items {
        // 在昂贵的工作之前检查
        try Task.checkCancellation()
        await process(item)
    }
}
```

- `Task.checkCancellation()` 在取消时抛出 `CancellationError`。
- `Task.isCancelled` 在非抛出上下文中返回 Bool。
- `task.cancel()` 只设置标志——它不会中断执行。

这意味着确保复杂任务在安全间隔定期检查取消很重要。

对于提供自己取消机制的遗留 API，使用 `withTaskCancellationHandler` 将 Swift 的协作式取消桥接到底层 API。详见 `cancellation.md`。


## `Task.immediate`（Swift 6.2）

关于 `Task.immediate` 的详情，参见 `new-features.md`。对于大多数情况，常规 `Task {}` 仍是正确的选择。


## `Task {}` 何时是代码坏味道

从同步上下文创建 `Task {}` 来调用异步函数有时是必要的（例如在按钮操作中）。但要注意这些反模式：

- **`onAppear()` 内部的 Task**：永远不要在 SwiftUI `onAppear()` 内部创建 `Task`。改用 `.task()` 修饰符，因为它会在视图消失时自动处理取消。
- **在本身可以是 async 的函数中用 Task 桥接同步→异步**：如果调用方可以变为 async，就那样做，而不是用 `Task {}` 包装。
- **忽略抛出型任务的返回值**：错误会被静默丢失。至少在任务闭包内部处理错误。
