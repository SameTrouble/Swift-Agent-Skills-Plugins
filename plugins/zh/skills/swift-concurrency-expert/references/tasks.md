# 任务

使用本文件当：

- 你需要从同步代码启动异步工作。
- 你正在 `Task`、`async let` 和任务组之间做选择。
- 你需要取消、优先级或结构化与非结构化指导。

跳过本文件如果：

- 问题主要是 actor 隔离或可发送性。使用 `actors.md` 或 `sendable.md`。
- 工作是流形状的。使用 `async-sequences.md` 或 `async-algorithms.md`。

跳转到：

- 什么是 Task？
- 取消
- 任务组
- 丢弃任务组
- 高级：Task 超时模式
- SwiftUI 集成
- 结构化 vs 非结构化任务
- 任务优先级

## 什么是 Task？

Task 桥接同步和异步上下文。它们在创建时立即开始执行——无需 `resume()`。

```swift
func synchronousMethod() {
    Task {
        await someAsyncMethod()
    }
}
```


### Task 入口隔离

`Task { ... }` 继承包围的隔离域。在使用 `defaultIsolation(MainActor.self)` 的模块中特别容易忽略，因为裸任务然后默认在 `@MainActor` 上启动。

使用同步前缀规则（第一个 `await` 之前的所有内容）选择任务入口隔离：
- 如果前缀需要 main-actor 工作，保持继承的 `@MainActor` 入口。
- 如果前缀不需要 main actor，优先使用 `Task { @concurrent in ... }`，仅在 UI 变更时跳回。

```swift
// ❌ 前缀无 main-actor 工作；第一个 await 跳走
Task {
    await someActor.refresh()
}

// ✅ 前缀需要 @MainActor；保持继承的 main 启动
Task {
    print("debug")        // 简单非 main 行顺带执行
    self.isLoading = true  // 第一个 await 之前的 main-actor 状态
    await fetchData()
}
```

有关更深入的指导和扩展示例，见 `threading.md#choosing-task-entry-isolation`。

## Task 引用

存储引用是可选的，但可以实现取消和等待结果：

```swift
final class ImageLoader {
    var loadTask: Task<UIImage, Error>?
    
    func load() {
        loadTask = Task {
            try await fetchImage()
        }
    }
    
    deinit {
        loadTask?.cancel()
    }
}
```

无论你是否保持引用，任务都会运行。

> **课程深入**：此主题在 [Lesson 3.1: Introduction to tasks in Swift Concurrency](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 取消

### 检查取消

任务必须手动检查取消：

```swift
// 如果取消则抛出 CancellationError
try Task.checkCancellation()

// 布尔检查用于自定义处理
guard !Task.isCancelled else {
    return fallbackValue
}
```

### 在哪里检查

在自然断点处添加检查：

```swift
let task = Task {
    // 在昂贵工作之前
    try Task.checkCancellation()
    
    let data = try await URLSession.shared.data(from: url)
    
    // 网络之后，处理之前
    try Task.checkCancellation()
    
    return processData(data)
}
```

### 子任务取消

取消父任务自动通知所有子任务：

```swift
let parent = Task {
    async let child1 = work(1)
    async let child2 = work(2)
    let results = try await [child1, child2]
}

parent.cancel() // 两个子任务都被通知
```

子任务仍必须检查 `Task.isCancelled` 来停止工作。

> **课程深入**：此主题在 [Lesson 3.2: Task cancellation](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 错误处理

Task 错误类型从操作推断：

```swift
// 可以抛出
let throwingTask: Task<String, Error> = Task {
    throw URLError(.badURL)
}

// 不能抛出
let nonThrowingTask: Task<String, Never> = Task {
    "Success"
}
```

### 等待结果

```swift
do {
    let result = try await task.value
} catch {
    // 处理错误
}
```

### 内部处理错误

```swift
let safeTask: Task<String, Never> = Task {
    do {
        return try await riskyOperation()
    } catch {
        return "Fallback value"
    }
}
```

> **课程深入**：此主题在 [Lesson 3.3: Error handling in Tasks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## SwiftUI 集成

### .task 修饰符

自动管理任务生命周期与视图生命周期：

```swift
struct ContentView: View {
    @State private var data: Data?
    
    var body: some View {
        Text(data?.description ?? "Loading...")
            .task {
                data = try? await fetchData()
            }
    }
}
```

视图消失时任务自动取消。

### 响应值变化

```swift
.task(id: searchQuery) {
    await performSearch(searchQuery)
}
```

当 `searchQuery` 变化时：
1. 之前的任务取消
2. 新任务以更新值启动

> **课程深入**：此主题在 [Lesson 3.12: Running tasks in SwiftUI](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 优先级配置

```swift
// 高优先级（SwiftUI 默认）
.task(priority: .userInitiated) {
    await fetchUserData()
}

// 后台工作用更低优先级
.task(priority: .low) {
    await trackAnalytics()
}
```

## 任务组

编译时未知任务数量的动态并行任务执行。

### 基本用法

```swift
await withTaskGroup(of: UIImage.self) { group in
    for url in photoURLs {
        group.addTask {
            await downloadPhoto(url: url)
        }
    }
}
```

### 收集结果

```swift
let images = await withTaskGroup(of: UIImage.self) { group in
    for url in photoURLs {
        group.addTask { await downloadPhoto(url: url) }
    }
    
    return await group.reduce(into: []) { $0.append($1) }
}
```

### 错误处理

```swift
let images = try await withThrowingTaskGroup(of: UIImage.self) { group in
    for url in photoURLs {
        group.addTask { try await downloadPhoto(url: url) }
    }
    
    // 迭代以传播错误
    var results: [UIImage] = []
    for try await image in group {
        results.append(image)
    }
    return results
}
```

**关键**：子任务中的错误不会自动使组失败。使用迭代（`for try await`、`next()`、`reduce()`）传播错误。

> **课程深入**：此主题在 [Lesson 3.5: Task Groups](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 错误时提前终止

```swift
try await withThrowingTaskGroup(of: Data.self) { group in
    for id in ids {
        group.addTask { try await fetch(id) }
    }
    
    // 第一个错误取消剩余任务
    while let data = try await group.next() {
        process(data)
    }
}
```

### 取消

```swift
await withTaskGroup(of: Result.self) { group in
    for item in items {
        group.addTask { await process(item) }
    }
    
    // 取消所有剩余任务
    group.cancelAll()
}
```

或防止向已取消的组添加：

```swift
let didAdd = group.addTaskUnlessCancelled {
    await work()
}
```

## 丢弃任务组

用于结果无关紧要的即发即忘操作：

```swift
await withDiscardingTaskGroup { group in
    group.addTask { await logEvent("user_login") }
    group.addTask { await preloadCache() }
    group.addTask { await syncAnalytics() }
}
```

### 好处

- 更内存高效（不存储结果）
- 无需 `next()` 调用
- 自动等待完成
- 非常适合副作用

### 错误处理

```swift
try await withThrowingDiscardingTaskGroup { group in
    group.addTask { try await uploadLog() }
    group.addTask { try await syncSettings() }
}
// 第一个错误取消组并抛出
```

### 真实世界模式：多个通知

```swift
extension NotificationCenter {
    func notifications(named names: [Notification.Name]) -> AsyncStream<()> {
        AsyncStream { continuation in
            let task = Task {
                await withDiscardingTaskGroup { group in
                    for name in names {
                        group.addTask {
                            for await _ in self.notifications(named: name) {
                                continuation.yield(())
                            }
                        }
                    }
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// 用法
for await _ in NotificationCenter.default.notifications(
    named: [.userDidLogin, UIApplication.didBecomeActiveNotification]
) {
    refreshData()
}
```

> **课程深入**：此主题在 [Lesson 3.6: Discarding Task Groups](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 结构化 vs 非结构化任务

### 结构化（首选）

绑定到父任务，继承上下文，自动取消：

```swift
// async let
async let data1 = fetch(1)
async let data2 = fetch(2)
let results = await [data1, data2]

// 任务组
await withTaskGroup(of: Data.self) { group in
    group.addTask { await fetch(1) }
    group.addTask { await fetch(2) }
}
```

> **课程深入**：此主题在 [Lesson 3.7: The difference between structured and unstructured tasks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 非结构化（谨慎使用）

独立生命周期，手动取消：

```swift
// 常规任务（非结构化但继承优先级）
let task = Task {
    await doWork()
}

// 分离任务（完全独立）
Task.detached(priority: .background) {
    await cleanup()
}
```

## 分离任务

**作为最后手段使用。** 它们不继承：
- 优先级
- Task-local 值
- 取消状态

```swift
Task.detached(priority: .background) {
    await DirectoryCleaner.cleanup()
}
```

### 何时使用

- 独立后台工作
- 不需要与父任务连接
- 父任务取消后完成也可接受
- 不需要 `self` 引用

**首选**：对于大多数并行工作使用任务组或 `async let`。

> **课程深入**：此主题在 [Lesson 3.4: Detached Tasks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 任务优先级

### 可用优先级

```swift
.high           // 立即用户反馈
.userInitiated  // 用户触发的工作（同 .high）
.medium         // 分离任务的默认值
.utility        // 较长时间运行，非紧急
.low            // 类似 .background
.background     // 最低优先级
```

### 设置优先级

```swift
Task(priority: .background) {
    await prefetchData()
}
```

### 优先级继承

结构化任务继承父任务优先级：

```swift
Task(priority: .high) {
    async let result = work() // 也是 .high
    await result
}
```

分离任务不继承：

```swift
Task(priority: .high) {
    Task.detached {
        // 以 .medium 运行（默认）
    }
}
```

### 优先级升级

系统自动提升优先级以防止优先级反转：
- Actor 等待低优先级任务
- 高优先级任务等待低优先级任务的 `.value`

> **课程深入**：此主题在 [Lesson 3.8: Managing Task priorities](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## Task.sleep() vs Task.yield()

### Task.sleep()

挂起固定时长，非阻塞：

```swift
try await Task.sleep(for: .seconds(5))
```

**用于：**
- 对用户输入进行 debounce
- 轮询间隔
- 速率限制
- 人为延迟

**尊重取消**（抛出 `CancellationError`）

### Task.yield()

临时挂起以允许其他任务运行：

```swift
await Task.yield()
```

**用于：**
- 测试异步代码
- 允许协作式调度

**注意**：如果当前任务优先级最高，可能立即恢复。

### 实践：Debounced 搜索

```swift
func search(_ query: String) async {
    guard !query.isEmpty else {
        searchResults = allResults
        return
    }
    
    do {
        try await Task.sleep(for: .milliseconds(500))
        searchResults = allResults.filter { $0.contains(query) }
    } catch {
        // 被取消（用户继续输入）
    }
}

// 在 SwiftUI 中
.task(id: searchQuery) {
    await searcher.search(searchQuery)
}
```

> **课程深入**：此主题在 [Lesson 3.10: Task.yield() vs. Task.sleep()](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## async let vs TaskGroup

| 特性 | async let | TaskGroup |
|---------|-----------|-----------|
| 任务数量 | 编译时固定 | 运行时动态 |
| 语法 | 轻量级 | 更冗长 |
| 取消 | 作用域退出时自动 | 通过 `cancelAll()` 手动 |
| 何时使用 | 2-5 个已知并行任务 | 基于循环的并行工作 |

```swift
// async let：已知任务数量
async let user = fetchUser()
async let settings = fetchSettings()
let profile = Profile(user: await user, settings: await settings)

// TaskGroup：动态任务数量
await withTaskGroup(of: Image.self) { group in
    for url in urls {
        group.addTask { await download(url) }
    }
}
```

## 高级：Task 超时模式

使用任务组创建超时包装器：

```swift
func withTimeout<T>(
    _ duration: Duration,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

// 用法
let data = try await withTimeout(.seconds(5)) {
    try await slowNetworkRequest()
}
```

**`cancelAll()` 至关重要**——没有它，失败的任务会运行到作用域退出。

`Task.sleep` 在任务取消时抛出 `CancellationError`，使其成为轮询循环中有用的取消检查点。`Task.yield()` 仅给其他任务运行的机会，不检查取消——如果当前任务优先级最高，它可能立即恢复。

> **课程深入**：此主题在 [Lesson 3.14: Creating a Task timeout handler using a Task Group (advanced)](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 常见模式

### 带提前退出的顺序执行

```swift
let user = try await fetchUser()
guard user.isActive else { return }

let posts = try await fetchPosts(userId: user.id)
```

### 并行独立工作

```swift
async let user = fetchUser()
async let settings = fetchSettings()
async let notifications = fetchNotifications()

let data = try await (user, settings, notifications)
```

### 混合：先顺序后并行

```swift
let user = try await fetchUser()

async let posts = fetchPosts(userId: user.id)
async let followers = fetchFollowers(userId: user.id)

let profile = Profile(
    user: user,
    posts: try await posts,
    followers: try await followers
)
```

## 代理常犯的错误

- 用许多无关的顶层任务替换结构化子工作。
- 使用 `Task.detached` 仅为了"使其后台"。
- 在长时间运行的操作中忽略取消。
- 永远保持存储任务而没有明确的所有者或清理路径。
- 从包围上下文而非任务的同步前缀选择入口隔离——从 `@MainActor` 上下文中的 `Task { await someActor.x() }` 应该是 `Task { @concurrent in ... }`；前缀修改 `@MainActor` 状态的 `Task` 应该保持继承的 `@MainActor`，即使它也有 `print`。
- 优先级是提示而非保证。系统自动提升优先级以防止反转（例如，高优先级任务等待低优先级任务的 `.value`）。不要依赖优先级来保证正确性。

## 最佳实践

1. **在长时间运行的任务中定期检查取消**
2. **使用结构化并发**（避免分离任务）
3. **利用 SwiftUI 的 `.task` 修饰符**用于视图绑定工作
4. **选择正确工具**：`async let` 用于固定，TaskGroup 用于动态
5. **在抛出任务组中显式处理错误**
6. **仅在需要时设置优先级**（默认继承）
7. **不要从创建上下文外部修改任务组**

## 进一步学习

有关动手示例、高级模式和迁移策略，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
