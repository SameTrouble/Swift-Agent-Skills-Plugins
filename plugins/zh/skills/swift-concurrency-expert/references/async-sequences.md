# 异步序列和流

使用本文件当：

- 你需要迭代随时间到达的值。
- 你正在将基于回调或基于代理的 API 桥接到 async/await。
- 你需要在 `AsyncSequence`、`AsyncStream` 或常规异步方法之间做选择。

跳过本文件如果：

- 你需要基于时间的操作符如 debounce、throttle 或 merge。使用 `async-algorithms.md`。
- 你正在 `Task`、`async let` 或任务组之间做选择。使用 `tasks.md`。

跳转到：

- AsyncSequence 协议
- AsyncStream / AsyncThrowingStream
- 桥接回调和代理
- 流生命周期和清理
- 缓冲策略
- 标准库集成
- 限制
- 何时使用 AsyncAlgorithms

## AsyncSequence

用于对随时间可用的值进行异步迭代的协议。

### 基本用法

```swift
for await value in someAsyncSequence {
    print(value)
}
```

**与 Sequence 的关键区别**：值可能不会立即可用。

### 自定义实现

```swift
struct Counter: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Int
    
    let limit: Int
    var current = 1
    
    mutating func next() async -> Int? {
        guard !Task.isCancelled else { return nil }
        guard current <= limit else { return nil }
        
        let result = current
        current += 1
        return result
    }
    
    func makeAsyncIterator() -> Counter {
        self
    }
}

// 用法
for await count in Counter(limit: 5) {
    print(count) // 1, 2, 3, 4, 5
}
```

### 标准操作符

与常规序列相同的函数式操作符：

```swift
// Filter
for await even in Counter(limit: 5).filter({ $0 % 2 == 0 }) {
    print(even) // 2, 4
}

// Map
let mapped = Counter(limit: 5).map { $0 % 2 == 0 ? "Even" : "Odd" }
for await label in mapped {
    print(label)
}

// Contains（等待直到找到或序列结束）
let contains = await Counter(limit: 5).contains(3) // true
```

### 终止

从 `next()` 返回 `nil` 以结束迭代：

```swift
mutating func next() async -> Int? {
    guard !Task.isCancelled else {
        return nil // 取消时停止
    }
    
    guard current <= limit else {
        return nil // 到达限制时停止
    }
    
    return current
}
```

> **课程深入**：此主题在 [Lesson 6.1: Working with asynchronous sequences](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## AsyncStream

无需实现协议即可创建异步序列的便捷方式。

### 基本创建

```swift
let stream = AsyncStream<Int> { continuation in
    for i in 1...5 {
        continuation.yield(i)
    }
    continuation.finish()
}

for await value in stream {
    print(value)
}
```

### AsyncThrowingStream

用于可能失败的流：

```swift
let throwingStream = AsyncThrowingStream<Int, Error> { continuation in
    continuation.yield(1)
    continuation.yield(2)
    continuation.finish(throwing: SomeError())
}

do {
    for try await value in throwingStream {
        print(value)
    }
} catch {
    print("Error: \(error)")
}
```

> **课程深入**：此主题在 [Lesson 6.2: Using AsyncStream and AsyncThrowingStream in your code](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 将闭包桥接到流

### 进度 + 完成处理程序

```swift
// 旧基于闭包的 API
struct FileDownloader {
    enum Status {
        case downloading(Float)
        case finished(Data)
    }
    
    func download(
        _ url: URL,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<Data, Error>) -> Void
    ) throws {
        // 实现
    }
}

// 现代基于流的 API
extension FileDownloader {
    func download(_ url: URL) -> AsyncThrowingStream<Status, Error> {
        AsyncThrowingStream { continuation in
            do {
                try self.download(url, progressHandler: { progress in
                    continuation.yield(.downloading(progress))
                }, completion: { result in
                    switch result {
                    case .success(let data):
                        continuation.yield(.finished(data))
                        continuation.finish()
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                })
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

// 用法
for try await status in downloader.download(url) {
    switch status {
    case .downloading(let progress):
        print("Progress: \(progress)")
    case .finished(let data):
        print("Done: \(data.count) bytes")
    }
}
```

### 使用 Result 简化

```swift
AsyncThrowingStream { continuation in
    try self.download(url, progressHandler: { progress in
        continuation.yield(.downloading(progress))
    }, completion: { result in
        continuation.yield(with: result.map { .finished($0) })
        continuation.finish()
    })
}
```

## 桥接代理

### 位置更新示例

```swift
final class LocationMonitor: NSObject {
    private var continuation: AsyncThrowingStream<CLLocation, Error>.Continuation?
    let stream: AsyncThrowingStream<CLLocation, Error>
    
    override init() {
        var capturedContinuation: AsyncThrowingStream<CLLocation, Error>.Continuation?
        stream = AsyncThrowingStream { continuation in
            capturedContinuation = continuation
        }
        super.init()
        self.continuation = capturedContinuation
        
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
}

extension LocationMonitor: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            continuation?.yield(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.finish(throwing: error)
    }
}

// 用法
let monitor = LocationMonitor()
for try await location in monitor.stream {
    print("Location: \(location.coordinate)")
}
```

## 流生命周期

### 终止回调

```swift
AsyncThrowingStream<Int, Error> { continuation in
    continuation.onTermination = { @Sendable reason in
        print("Terminated: \(reason)")
        // 清理：移除观察者、取消工作等
    }
    
    continuation.yield(1)
    continuation.finish()
}
```

**终止原因**：
- `.finished`——正常完成
- `.finished(Error?)`——带错误完成（throwing 流）
- `.cancelled`——Task 被取消

### 取消

流在以下情况取消：
- 包裹的 task 取消
- 流离开作用域

```swift
let task = Task {
    for try await status in download(url) {
        print(status)
    }
}

task.cancel() // 触发 onTermination 为 .cancelled
```

**无显式取消方法**——依赖 task 取消。

## 缓冲策略

控制当没有人在等待时值会发生什么：

### .unbounded（默认）

缓冲所有值直到被消费：

```swift
let stream = AsyncStream<Int> { continuation in
    (0...5).forEach { continuation.yield($0) }
    continuation.finish()
}

try await Task.sleep(for: .seconds(1))

for await value in stream {
    print(value) // 打印所有：0, 1, 2, 3, 4, 5
}
```

### .bufferingNewest(n)

仅保留最新 N 个值：

```swift
let stream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
    (0...5).forEach { continuation.yield($0) }
    continuation.finish()
}

try await Task.sleep(for: .seconds(1))

for await value in stream {
    print(value) // 仅打印：5
}
```

### .bufferingOldest(n)

仅保留最旧 N 个值：

```swift
let stream = AsyncStream(bufferingPolicy: .bufferingOldest(1)) { continuation in
    (0...5).forEach { continuation.yield($0) }
    continuation.finish()
}

try await Task.sleep(for: .seconds(1))

for await value in stream {
    print(value) // 仅打印：0
}
```

### .bufferingNewest(0)

仅接收迭代开始后发出的值：

```swift
let stream = AsyncStream(bufferingPolicy: .bufferingNewest(0)) { continuation in
    continuation.yield(1) // 被丢弃
    
    Task {
        try await Task.sleep(for: .seconds(2))
        continuation.yield(2) // 被接收
        continuation.finish()
    }
}

try await Task.sleep(for: .seconds(1))

for await value in stream {
    print(value) // 仅打印：2
}
```

**用例**：位置更新、文件系统变更——只关心最新值。

## 重复异步调用

使用 `init(unfolding:onCancel:)` 进行轮询：

```swift
struct PingService {
    func startPinging() -> AsyncStream<Bool> {
        AsyncStream {
            try? await Task.sleep(for: .seconds(5))
            return await ping()
        } onCancel: {
            print("Pinging cancelled")
        }
    }
    
    func ping() async -> Bool {
        // 网络请求
        return true
    }
}

// 用法
for await result in pingService.startPinging() {
    print("Ping: \(result)")
}
```

## 标准库集成

### NotificationCenter

```swift
let stream = NotificationCenter.default.notifications(
    named: .NSSystemTimeZoneDidChange
)

for await notification in stream {
    print("Time zone changed")
}
```

### Combine 发布者

```swift
let numbers = [1, 2, 3, 4, 5]
let filtered = numbers.publisher.filter { $0 % 2 == 0 }

for await number in filtered.values {
    print(number) // 2, 4
}
```

### 任务组

```swift
await withTaskGroup(of: Image.self) { group in
    for url in urls {
        group.addTask { await download(url) }
    }
    
    for await image in group {
        display(image)
    }
}
```

## 限制

### 仅单消费者

与 Combine 不同，流一次只支持一个消费者：

```swift
let stream = AsyncStream { continuation in
    (0...5).forEach { continuation.yield($0) }
    continuation.finish()
}

Task {
    for await value in stream {
        print("Consumer 1: \(value)")
    }
}

Task {
    for await value in stream {
        print("Consumer 2: \(value)")
    }
}

// 不可预测的输出——值在消费者之间分割
// Consumer 1: 0
// Consumer 2: 1
// Consumer 1: 2
// Consumer 2: 3
```

**解决方案**：创建单独的流或使用第三方库（AsyncExtensions）。

### 终止后无值

一旦完成，流不会发出新值：

```swift
let stream = AsyncStream<Int> { continuation in
    continuation.finish() // 立即终止
    continuation.yield(1) // 永不接收
}

for await value in stream {
    print(value) // 循环立即退出
}
```

## 决策指南

### 使用 AsyncSequence 当：

- 实现标准库风格的协议
- 需要对迭代进行细粒度控制
- 构建可重用的序列类型
- 使用现有序列协议

**现实**：在应用代码中很少需要。

### 使用 AsyncStream 当：

- 将代理桥接到 async/await
- 转换基于闭包的 API
- 手动发出事件
- 轮询或重复异步操作
- 最常见的用例

---

## 何时使用 AsyncAlgorithms vs 标准库

### 使用 AsyncAlgorithms 当：

- **基于时间的操作**需要 debounce/throttle/计时器
- **组合多个异步序列**（merge、combineLatest、zip）
- **多消费者场景**需要背压（AsyncChannel）
- **复杂的操作符链**，Combine 会自然处理
- **需要标准库中没有的特定操作符**

### 使用标准库当：

- **桥接回调 API** → AsyncStream
- **简单迭代** → for await in sequence
- **单值操作** → async/await
- **基本转换** → map/filter/contains

### 快速决策表

| 需求 | 解决方案 |
|------|----------|
| Debounce 搜索输入 | ✅ AsyncAlgorithms.debounce() |
| Throttle 按钮点击 | ✅ AsyncAlgorithms.throttle() |
| 合并独立流 | ✅ AsyncAlgorithms.merge() |
| 组合依赖值 | ✅ AsyncAlgorithms.combineLatest() 或 async let |
| 配对两个源的值 | ✅ AsyncAlgorithms.zip() |
| 桥接回调 API | AsyncStream |
| 带背压的多消费者 | ✅ AsyncChannel |
| 定期计时器 | ✅ AsyncTimerSequence |
| 简单异步迭代 | for await in... |

> **参见**：[async-algorithms.md](async-algorithms.md) 获取使用真实世界模式的详细示例。

### 使用常规异步方法当：

- 返回单个值
- 不需要进度更新
- 简单的请求/响应模式

```swift
// 使用这个
func fetchData() async throws -> Data

// 而非这个
func fetchData() -> AsyncThrowingStream<Data, Error>

> **课程深入**：此主题在 [Lesson 6.3: Deciding between AsyncSequence, AsyncStream, or regular asynchronous methods](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍
```

## 常见模式

### 进度报告

```swift
func download(_ url: URL) -> AsyncThrowingStream<DownloadEvent, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                var progress: Double = 0
                while progress < 1.0 {
                    progress += 0.1
                    continuation.yield(.progress(progress))
                    try await Task.sleep(for: .milliseconds(100))
                }
                
                let data = try await URLSession.shared.data(from: url).0
                continuation.yield(.completed(data))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

### 监控文件系统

```swift
func watchDirectory(_ path: String) -> AsyncStream<FileEvent> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        
        source.setEventHandler {
            continuation.yield(.fileChanged(path))
        }
        
        continuation.onTermination = { _ in
            source.cancel()
        }
        
        source.resume()
    }
}
```

### 计时器/轮询

```swift
func timer(interval: Duration) -> AsyncStream<Date> {
    AsyncStream { continuation in
        Task {
            while !Task.isCancelled {
                continuation.yield(Date())
                try? await Task.sleep(for: interval)
            }
            continuation.finish()
        }
    }
}

// 用法
for await date in timer(interval: .seconds(1)) {
    print("Tick: \(date)")
}
```

## 最佳实践

1. **始终调用 finish()**——流在终止前保持存活
2. **明智地使用缓冲策略**——匹配你的用例（最新值 vs 所有值）
3. **处理取消**——设置 `onTermination` 进行清理
4. **单消费者**——不要在多个消费者之间共享流
5. **优先使用流而非闭包**——更可组合且可取消
6. **检查 Task.isCancelled**——在自定义序列中尊重取消
7. **使用 throwing 变体**——当操作可能失败时
8. **考虑常规异步**——如果只返回单个值

## 调试

### 添加终止日志

```swift
continuation.onTermination = { reason in
    print("Stream ended: \(reason)")
}
```

### 验证 finish() 调用

```swift
// ❌ 忘记 finish
AsyncStream { continuation in
    continuation.yield(1)
    // 流永不结束！
}

// ✅ 始终 finish
AsyncStream { continuation in
    continuation.yield(1)
    continuation.finish()
}
```

### 检查丢弃的值

```swift
let stream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
    for i in 1...100 {
        continuation.yield(i)
        print("Yielded: \(i)")
    }
    continuation.finish()
}

// 如果消费者慢，许多值被丢弃
for await value in stream {
    print("Received: \(value)")
    try? await Task.sleep(for: .seconds(1))
}
```

## 代理常犯的错误

```swift
// ❌ finish() 之后的值被静默丢弃
continuation.finish()
continuation.yield(1) // 永不接收

// ❌ 流永不终止（忘记 finish）
AsyncStream { continuation in
    continuation.yield(1)
    // 缺少：continuation.finish()
}

// ❌ 将单值 API 包装在流中——改用常规异步函数
func fetchUser() -> AsyncStream<User> { ... } // 对单个结果来说过度
```

- **在多个消费者之间共享单个 `AsyncStream`**：值不可预测地分割。没有内置广播；使用 `AsyncChannel` 实现点对点多消费者模式。
- **桥接代理或观察者 API 时遗忘 `onTermination`**，导致资源泄漏。

## 进一步学习

有关真实世界迁移示例、性能模式和高级流技术，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
