# Bug 模式

LLM 经常产生的真实并发失败模式，以及每种模式的首选修复方案。

## Actor 可重入性：跨 `await` 的检查后行动

**失败：** Actor 方法检查状态、await、然后基于过时的检查行动。其他调用方可能在挂起期间改变了状态。

```swift
// BUG：两个调用方都可能看到 nil 并都下载。
// 如果第三个调用方在执行中途清除了缓存，强制解包可能崩溃。
actor Cache {
    var data: [String: Data] = [:]

    func load(_ key: String) async throws -> Data {
        if data[key] == nil {
            data[key] = try await download(key)
        }
        return data[key]!
    }
}
```

**修复：** 将异步结果捕获到局部变量中然后再写入。对于去重，存储进行中的 `Task` 句柄。完整模式参见 `actors.md`。


## Continuation 恢复零次

**失败：** `withCheckedThrowingContinuation` 回调永不触发（对象被释放、网络超时且无回调、注册处理程序前提前返回等）。调用方永远挂起。

**修复：** 审查每条代码路径以确认 continuation 被恢复。如果底层 API 可能静默丢弃回调，添加超时或重构以使调用方不会被留在等待中。始终使用 `withCheckedThrowingContinuation`（而非 unsafe 变体），以便遗漏恢复更容易诊断。


## Continuation 恢复两次

**失败：** 两个回调（例如成功处理程序和取消处理程序）都恢复了同一个 continuation。`CheckedContinuation` 在运行时陷入陷阱；`UnsafeContinuation` 导致未定义行为。

**修复：** 重构回调连线，使只有一条路径能到达 continuation。如果不可能，使用 `Bool` 标志保护或使用 `actor` 串行化访问。始终默认使用 `CheckedContinuation`，以便双重恢复在开发和测试期间立即暴露。


## 循环中的非结构化任务

**失败：** `for item in items { Task { await process(item) } }` 创建了即发即弃的任务，没有取消传播、没有错误收集，也没有办法 await 完成。

**修复：** 使用 `withTaskGroup` 或 `withThrowingTaskGroup`。参见 `structured.md`。


## Task 闭包中被吞没的错误

**失败：** `Task { try await riskyWork() }`——如果 `riskyWork` 抛出，错误被静默丢失。用户什么也看不到；操作就是不发生。

**修复：** 在闭包内处理错误——显示警报、记录到可见的界面，或通过 `@State` 错误属性传播。

```swift
Task {
    do {
        try await riskyWork()
    } catch {
        self.errorMessage = error.localizedDescription
    }
}
```


## 用同步工作阻塞 main actor

**失败：** CPU 密集型工作在 `@MainActor` 上运行（或从 `@MainActor` 调用的 `Task {}` 内运行），导致 UI 冻结。在 Swift 6.2 中这更可能发生，因为 `nonisolated` async 函数现在默认留在调用方的执行器上。

**修复：** 使用 `@concurrent` 将昂贵的工作移入显式卸载的函数，或作为最后手段使用 `Task.detached`。


## 无限制的 AsyncStream 缓冲区

**失败：** 高吞吐量生产者 yield 值的速度快于消费者处理的速度。使用默认的 `.unbounded` 缓冲策略，内存无限制增长。

**修复：** 指定 `.bufferingNewest(n)` 或 `.bufferingOldest(n)`。参见 `async-streams.md`。


## 在 catch 块中忽略 `CancellationError`

**失败：** `catch` 块对 `CancellationError` 进行重试或显示错误警报，而这是正常的生命周期事件（例如用户导航离开）。

**修复：** 在处理其他错误之前检查取消：

```swift
do {
    try await loadData()
} catch is CancellationError {
    // 正常——视图消失或任务被取消。什么也不做。
} catch {
    self.errorMessage = error.localizedDescription
}
```


## `@unchecked Sendable` 隐藏真实竞态

**失败：** 类被标记为 `@unchecked Sendable` 以压制编译器错误，但其可变 `var` 属性没有同步。数据竞争在运行时仍然存在。

**修复：** 重构以使用值类型、使用 `actor`，或将状态移到锁之后。参见 `bridging.md`。
