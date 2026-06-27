# 内存管理

使用本文件当：

- 任务或异步序列使对象存活时间超过预期。
- 你怀疑任务与其所有者之间存在循环引用。
- 你需要验证释放行为或使用 `isolated deinit`。

跳过本文件如果：

- 你主要需要保护可变状态免受竞争。使用 `actors.md`。
- 你正在调试慢速异步代码。使用 `performance.md`。

跳转到：

- 核心概念（Task 捕获）
- 循环引用
- 单向保持
- 异步序列和保持
- 隔离 deinit（Swift 6.2+）
- 检测和测试
- 常见模式

## 核心概念

### Task 像闭包一样捕获

Task 像常规闭包一样捕获变量和引用。Swift 不会自动防止并发代码中的循环引用。

```swift
Task {
    self.doWork() // ⚠️ 强捕获 self
}
```

### 为什么并发隐藏内存问题

- 任务可能存活时间超过预期
- 异步操作延迟执行
- 更难跟踪内存何时应释放
- 长期运行的任务可能无限期持有引用

> **课程深入**：此主题在 [Lesson 8.1: Overview of memory management in Swift Concurrency](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 循环引用

### 什么是循环引用？

两个或更多对象相互持有强引用，阻止释放。

```swift
class A {
    var b: B?
}

class B {
    var a: A?
}

let a = A()
let b = B()
a.b = b
b.a = a // 循环引用——都不能被释放
```

### Task 的循环引用

当任务强捕获 `self` 且 `self` 拥有该任务时：

```swift
@MainActor
final class ImageLoader {
    var task: Task<Void, Never>?
    
    func startPolling() {
        task = Task {
            while true {
                self.pollImages() // ⚠️ 强捕获
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

var loader: ImageLoader? = .init()
loader?.startPolling()
loader = nil // ⚠️ loader 永不释放——循环引用！
```

**问题**：Task 持有 `self`，`self` 持有 task → 都不释放。

## 打破循环引用

### 使用 weak self

```swift
func startPolling() {
    task = Task { [weak self] in
        while let self = self {
            self.pollImages()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

var loader: ImageLoader? = .init()
loader?.startPolling()
loader = nil // ✅ loader 释放，任务停止
```

### 长期运行任务的模式

```swift
task = Task { [weak self] in
    while let self = self {
        await self.doWork()
        try? await Task.sleep(for: interval)
    }
}
```

> **课程深入**：此主题在 [Lesson 8.2: Preventing retain cycles when using Tasks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

当 `self` 变为 `nil` 时循环退出。

## 单向保持

Task 保持 `self`，但 `self` 不保持 task。对象保持存活直到任务完成。

```swift
@MainActor
final class ViewModel {
    func fetchData() {
        Task {
            await performRequest()
            updateUI() // ⚠️ 强捕获
        }
    }
}

var viewModel: ViewModel? = .init()
viewModel?.fetchData()
viewModel = nil // ViewModel 保持存活直到任务完成
```

**执行顺序**：
1. Task 启动
2. `viewModel = nil`（但对象未释放）
3. Task 完成
4. ViewModel 最终释放

### 何时单向保持可接受

快速完成的短期任务：

```swift
func saveData() {
    Task {
        await database.save(self.data) // OK——快速完成
    }
}
```

### 何时使用 weak self

长期运行或无限期任务：

```swift
func startMonitoring() {
    Task { [weak self] in
        for await event in eventStream {
            self?.handle(event)
        }
    }
}
```

## 异步序列和保持

### 问题：无限序列

```swift
@MainActor
final class AppLifecycleViewModel {
    private(set) var isActive = false
    private var task: Task<Void, Never>?
    
    func startObserving() {
        task = Task {
            for await _ in NotificationCenter.default.notifications(
                named: .didBecomeActive
            ) {
                isActive = true // ⚠️ 强捕获，永不结束
            }
        }
    }
}

var viewModel: AppLifecycleViewModel? = .init()
viewModel?.startObserving()
viewModel = nil // ⚠️ 永不释放——序列继续
```

**问题**：异步序列永不结束，task 无限期持有 `self`。

### 解决方案 1：手动取消

```swift
func startObserving() {
    task = Task {
        for await _ in NotificationCenter.default.notifications(
            named: .didBecomeActive
        ) {
            isActive = true
        }
    }
}

func stopObserving() {
    task?.cancel()
}

// 用法
viewModel?.startObserving()
viewModel?.stopObserving() // 释放前必须调用
viewModel = nil
```

### 解决方案 2：带 guard 的 weak self

```swift
func startObserving() {
    task = Task { [weak self] in
        for await _ in NotificationCenter.default.notifications(
            named: .didBecomeActive
        ) {
            guard let self = self else { return }
            self.isActive = true
        }
    }
}
```

当 `self` 释放时 task 退出。

## 隔离 deinit（Swift 6.2+）

在 deinit 中清理 actor 隔离状态：

```swift
@MainActor
final class ViewModel {
    private var task: Task<Void, Never>?
    
    isolated deinit {
        task?.cancel()
    }
}
```

**限制**：不能打破循环引用（如果循环存在，deinit 永不调用）。

**用于**：对象正常释放时的清理。

## 常见模式

### 短期任务（强捕获 OK）

```swift
func saveData() {
    Task {
        await database.save(self.data)
        self.updateUI()
    }
}
```

**何时安全**：任务快速完成，对象存活到完成是可接受的。

### 长期运行任务（需要 weak self）

```swift
func startPolling() {
    task = Task { [weak self] in
        while let self = self {
            await self.fetchUpdates()
            try? await Task.sleep(for: .seconds(5))
        }
    }
}
```

### 异步序列监控（weak self + guard）

```swift
func startMonitoring() {
    task = Task { [weak self] in
        for await event in eventStream {
            guard let self = self else { return }
            self.handle(event)
        }
    }
}
```

### 带清理的可取消工作

```swift
func startWork() {
    task = Task { [weak self] in
        defer { self?.cleanup() }
        
        while let self = self {
            await self.doWork()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
```

## 检测策略

### 添加 deinit 日志

```swift
deinit {
    print("✅ \(type(of: self)) deallocated")
}
```

如果 deinit 从不打印 → 可能是循环引用。

### 内存图调试器

1. 在 Xcode 中运行应用
2. Debug → Debug Memory Graph
3. 在对象图中查找循环

### Instruments

使用 Leaks instrument 在运行时检测循环引用。

## 决策树

```
Task 捕获 self？
├─ Task 快速完成？
│  └─ 强捕获 OK
│
├─ 长期运行或无限？
│  ├─ 可以使用 weak self？ → 使用 [weak self]
│  ├─ 需要手动控制？ → 存储 task，显式取消
│  └─ 异步序列？ → [weak self] + guard
│
└─ self 拥有 task？
   ├─ 是 → 高循环引用风险
   └─ 否 → 较低风险，但检查生命周期
```

## 最佳实践

1. **长期运行任务默认使用 weak self**
2. **在异步序列中使用 guard let self**
3. **尽可能显式取消任务**
4. **开发期间添加 deinit 日志**
5. **在单元测试中测试对象释放**
6. **使用 Memory Graph 验证无循环**
7. **在注释中记录生命周期预期**
8. **尽可能优先使用取消而非 weak self**
9. **避免任务闭包中的嵌套强捕获**
10. **使用隔离 deinit 进行清理（Swift 6.2+）**

## 测试泄漏

### 单元测试模式

```swift
func testViewModelDeallocates() async {
    var viewModel: ViewModel? = ViewModel()
    weak var weakViewModel = viewModel
    
    viewModel?.startWork()
    viewModel = nil
    
    // 给任务时间完成
    try? await Task.sleep(for: .milliseconds(100))
    
    XCTAssertNil(weakViewModel, "ViewModel should be deallocated")
}
```

### SwiftUI 视图测试

```swift
func testViewDeallocates() {
    var view: MyView? = MyView()
    weak var weakView = view
    
    view = nil
    
    XCTAssertNil(weakView)
}
```

## 常见错误

### ❌ 在循环中忘记 weak self

```swift
Task {
    while true {
        self.poll() // 循环引用
        try? await Task.sleep(for: .seconds(1))
    }
}
```

### ❌ 在异步序列中强捕获

```swift
Task {
    for await item in stream {
        self.process(item) // 可能永不释放
    }
}
```

### ❌ 不取消存储的任务

```swift
class Manager {
    var task: Task<Void, Never>?
    
    func start() {
        task = Task {
            await self.work() // 循环引用
        }
    }
    
    // 缺少：deinit { task?.cancel() }
}
```

### ❌ 假设 deinit 打破循环

```swift
deinit {
    task?.cancel() // 如果循环引用存在则永不调用
}
```

## 按用例示例

### 轮询服务

```swift
final class PollingService {
    private var task: Task<Void, Never>?
    
    func start() {
        task = Task { [weak self] in
            while let self = self {
                await self.poll()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
    
    func stop() {
        task?.cancel()
    }
}
```

### 通知观察者

```swift
@MainActor
final class NotificationObserver {
    private var task: Task<Void, Never>?
    
    func startObserving() {
        task = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: .someNotification
            ) {
                guard let self = self else { return }
                self.handle(notification)
            }
        }
    }
    
    isolated deinit {
        task?.cancel()
    }
}
```

### 下载管理器

```swift
final class DownloadManager {
    private var tasks: [URL: Task<Data, Error>] = [:]
    
    func download(_ url: URL) async throws -> Data {
        let task = Task { [weak self] in
            defer { self?.tasks.removeValue(forKey: url) }
            return try await URLSession.shared.data(from: url).0
        }
        
        tasks[url] = task
        return try await task.value
    }
    
    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
```

### 计时器

```swift
actor Timer {
    private var task: Task<Void, Never>?
    
    func start(interval: Duration, action: @Sendable () async -> Void) {
        task = Task {
            while !Task.isCancelled {
                await action()
                try? await Task.sleep(for: interval)
            }
        }
    }
    
    func stop() {
        task?.cancel()
    }
}
```

## 代理常犯的错误

- **在存储的任务中遗忘 `[weak self]`**：当 `self` 拥有 task 且 task 捕获 `self` 时，循环引用阻止释放。
- **在无限 `AsyncSequence` 循环中强捕获**：在无限序列上使用强 `self` 捕获的 `for await` 会使对象永远存活。
- **清理时不取消存储的任务**：如果任务比其所有者存活更久，它会无限期保持捕获的对象。
- **假设 `isolated deinit` 打破循环引用**：`isolated deinit` 在正确的 actor 上运行清理，但如果循环阻止 `deinit` 被调用，清理永不执行。
- **在 `Task.sleep` 循环中使用 `try?`**：`try?` 可能吞掉 `CancellationError`，导致循环在取消后继续运行。始终显式检查 `Task.isCancelled`。

## 调试清单

当对象不释放时：

- [ ] 检查任务中的强 self 捕获
- [ ] 验证任务已取消或完成
- [ ] 查找无限循环或序列
- [ ] 检查 self 是否拥有 task
- [ ] 使用 Memory Graph 查找循环
- [ ] 添加 deinit 日志验证
- [ ] 使用弱引用测试
- [ ] 审查异步序列使用
- [ ] 检查嵌套任务捕获
- [ ] 验证 deinit 中的清理

## 进一步学习

有关迁移策略、真实世界示例和高级内存模式，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
