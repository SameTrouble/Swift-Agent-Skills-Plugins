# 异步流

## 优先使用 `makeStream(of:)` 工厂

创建 `AsyncStream` 的现代方式是静态工厂方法，它以元组形式返回流和其 continuation。这避免了在闭包中捕获 continuation。

```swift
// 旧方式：基于闭包，难以存储 continuation。
var continuation: AsyncStream<Event>.Continuation?
let stream = AsyncStream<Event> { cont in
    continuation = cont
}

// 新方式：简洁，无需闭包捕获。
let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
```

这也适用于 `AsyncThrowingStream.makeStream(of:throwing:)`。


## Continuation 生命周期

continuation 必须始终恰好完成一次。未能完成会导致消费者的 `for await` 循环无限挂起。完成两次是程序员错误（尽管 `AsyncStream.Continuation` 容忍它，但 `CheckedContinuation` 不容忍）。

始终在清理路径中完成：

```swift
let (stream, continuation) = AsyncStream.makeStream(of: Event.self)

let monitor = NetworkMonitor()

monitor.onEvent = { event in
    continuation.yield(event)
}

monitor.onComplete = {
    continuation.finish()
}

// 如果监视器可能在完成之前被释放：
continuation.onTermination = { _ in
    monitor.stop()
}
```


## 缓冲和背压

`AsyncStream` 默认缓冲区大小为无限。对于高吞吐量生产者，这可能导致无限制的内存增长。指定缓冲策略：

```swift
let (stream, continuation) = AsyncStream.makeStream(
    of: SensorReading.self,
    bufferingPolicy: .bufferingNewest(100)
)
```

可选项：

- `.bufferingNewest(n)` 保留最近的 `n` 个元素，丢弃较旧的。
- `.bufferingOldest(n)` 保留前 `n` 个元素，丢弃较新的。
- `.unbounded` 是默认值；仅当消费者能跟上时使用。


## `for await` 与取消

`for await` 循环在任务被取消或流完成时自动停止。你不需要在循环内部手动检查取消——但循环*之后*的代码确实会运行，因此如果需要，在那里处理清理。
