# Actors

使用本文件当：

- 你需要保护基于类的可变状态免受并发访问。
- 你正在 `actor`、`@MainActor`、`nonisolated` 或 `Mutex` 之间做选择。
- 你正在解决 actor 隔离类型上的协议一致性问题。

跳过本文件如果：

- 你主要需要使值能安全地跨边界传递。使用 `sendable.md`。
- 你正在调试执行线程或挂起行为。使用 `threading.md`。

跳转到：

- Actor 隔离
- 全局 Actor / @MainActor
- 隔离 vs 非隔离
- Actor 重入
- 隔离 deinit / 隔离一致性（Swift 6.2+）
- `#isolation` 宏
- Mutex：Actor 的替代方案
- 决策树

## 什么是 Actor？

Actor 通过确保一次只有一个任务访问它来保护可变状态。它们是带有自动同步的引用类型。

```swift
actor Counter {
    var value = 0
    
    func increment() {
        value += 1
    }
}
```

**关键保证**：一次只有一个任务可以访问可变状态（串行化访问）。

> **课程深入**：此主题在 [Lesson 5.1: Understanding actors in Swift Concurrency](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## Actor 隔离

### 由编译器强制执行

```swift
actor BankAccount {
    var balance: Int = 0
    
    func deposit(_ amount: Int) {
        balance += amount
    }
}

let account = BankAccount()
account.balance += 1 // ❌ 错误：不能从外部修改
await account.deposit(1) // ✅ 必须使用 actor 的方法
```

### 读取属性

```swift
let account = BankAccount()
await account.deposit(100)
print(await account.balance) // 读取也必须 await
```

访问 actor 属性/方法时始终使用 `await`——你不知道另一个任务是否在内部。

## Actor vs 类

### 相似之处

- 引用类型（副本共享同一实例）
- 可以有属性、方法、初始化器
- 可以遵循协议

### 区别

- **无继承**（除了用于 Objective-C 互操作的 `NSObject`）
- **自动隔离**（无需手动锁）
- **隐式 Sendable** 一致性

```swift
// ❌ 不能继承 actor
actor Base {}
actor Child: Base {} // 错误

// ✅ NSObject 例外
actor Example: NSObject {} // OK，用于 Objective-C
```

## 全局 Actor

跨类型、函数和属性的共享隔离域。

### @MainActor

确保在主线程上执行：

```swift
@MainActor
final class ViewModel {
    var items: [Item] = []
}

@MainActor
func updateUI() {
    // 始终在主线程运行
}

@MainActor
var title: String = ""
```

### 自定义全局 actor

```swift
@globalActor
actor ImageProcessing {
    static let shared = ImageProcessing()
    private init() {} // 防止创建重复实例
}

@ImageProcessing
final class ImageCache {
    var images: [URL: Data] = [:]
}

@ImageProcessing
func applyFilter(_ image: UIImage) -> UIImage {
    // 所有图像处理被串行化
}
```

**使用 private init** 防止创建多个执行器。

> **课程深入**：此主题在 [Lesson 5.2: An introduction to Global Actors](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## @MainActor 最佳实践

### 何时使用

必须在主线程上运行的 UI 相关代码：

```swift
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```

### 替换 DispatchQueue.main

```swift
// 旧方式
DispatchQueue.main.async {
    // 更新 UI
}

// 现代方式
await MainActor.run {
    // 更新 UI
}

// 更好：使用属性
@MainActor
func updateUI() {
    // 自动在主线程
}
```

### MainActor.assumeIsolated

**谨慎使用**——假设你在主线程上，如果不是则崩溃：

```swift
func methodB() {
    assert(Thread.isMainThread) // 验证假设
    
    MainActor.assumeIsolated {
        someMainActorMethod()
    }
}
```

**优先使用**：显式的 `@MainActor` 或 `await MainActor.run`，而非 `assumeIsolated`。

> **课程深入**：此主题在 [Lesson 5.3: When and how to use @MainActor](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 隔离 vs 非隔离

### 默认：隔离

Actor 方法默认是隔离的：

```swift
actor BankAccount {
    var balance: Double
    
    // 隐式隔离
    func deposit(_ amount: Double) {
        balance += amount
    }
}
```

### 隔离参数

通过继承调用方的隔离来减少挂起点：

```swift
struct Charger {
    static func charge(
        amount: Double,
        from account: isolated BankAccount
    ) async throws -> Double {
        // 不需要 await——我们隔离到 account
        try account.withdraw(amount: amount)
        return account.balance
    }
}
```

### 隔离闭包

```swift
actor Database {
    func transaction<T>(
        _ operation: @Sendable (_ db: isolated Database) throws -> T
    ) throws -> T {
        beginTransaction()
        let result = try operation(self)
        commitTransaction()
        return result
    }
}

// 用法：多个操作，一次 await
try await database.transaction { db in
    db.insert(item1)
    db.insert(item2)
    db.insert(item3)
}
```

### 泛型隔离扩展

```swift
extension Actor {
    func performInIsolation<T: Sendable>(
        _ block: @Sendable (_ actor: isolated Self) throws -> T
    ) async rethrows -> T {
        try block(self)
    }
}

// 用法
try await bankAccount.performInIsolation { account in
    try account.withdraw(amount: 20)
    print("Balance: \(account.balance)")
}
```

### 非隔离

为不可变数据退出隔离：

```swift
actor BankAccount {
    let accountHolder: String
    
    nonisolated var details: String {
        "Account: \(accountHolder)"
    }
}

// 不需要 await
print(account.details)
```

### 协议一致性

```swift
extension BankAccount: CustomStringConvertible {
    nonisolated var description: String {
        "Account: \(accountHolder)"
    }
}
```

> **课程深入**：此主题在 [Lesson 5.4: Isolated vs. non-isolated access in actors](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 隔离 deinit（Swift 6.2+）

在释放时清理 actor 状态：

```swift
actor FileDownloader {
    var downloadTask: Task<Void, Error>?
    
    isolated deinit {
        downloadTask?.cancel() // 可以调用隔离方法
    }
}
```

**要求**：iOS 18.4+、macOS 15.4+

> **课程深入**：此主题在 [Lesson 5.5: Using Isolated synchronous deinit](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 全局 Actor 隔离一致性（Swift 6.2+）

遵循 actor 隔离的协议一致性：

```swift
@MainActor
final class PersonViewModel {
    let id: UUID
    var name: String
}

extension PersonViewModel: @MainActor Equatable {
    static func == (lhs: PersonViewModel, rhs: PersonViewModel) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
```

**启用**：`InferIsolatedConformances` upcoming feature。

> **课程深入**：此主题在 [Lesson 5.6: Adding isolated conformance to protocols](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 隔离一致性导致的 `SendableMetatype` 错误

隔离一致性**不能**满足 `SendableMetatype` 要求。当你将 `MyClass.self` 传递给类型参数要求 `Sendable` 的泛型函数时会出现此问题。

```swift
protocol P {
    static func doSomething()
}

func doSomethingStatic<T: P & SendableMetatype>(_ type: T.Type) { }  // 显式要求 Sendable 类型/元类型

@MainActor
class C { }

extension C: @MainActor P {
    static func doSomething() { }
}

@MainActor
func test(c: C) {
    doSomethingStatic(C.self)
    // ❌ main actor-isolated conformance of 'C' to 'P' cannot satisfy
    //    conformance requirement for a 'Sendable' type parameter
}
```

**修复选项**：

1. 如果协议要求不访问 actor 状态，从原始一致性中移除 actor 隔离：

```swift
@MainActor
class C: P {
    nonisolated static func doSomething() { }  // ✅ 非隔离要求与非隔离一致性
}
```

2. 避免跨隔离边界传递元类型——直接调用静态方法而非通过泛型函数路由。

3. 使泛型函数感知 actor，以接受隔离的一致性（需要更改被调用方的签名）。

## Actor 重入

**关键**：状态可能在挂起点之间发生变化。

```swift
actor BankAccount {
    var balance: Double
    
    func deposit(amount: Double) async {
        balance += amount
        
        // ⚠️ await 期间 actor 解锁
        await logActivity("Deposited \(amount)")
        
        // ⚠️ 余额可能已改变！
        print("Balance: \(balance)")
    }
}
```

### 问题

```swift
async let _ = account.deposit(50)
async let _ = account.deposit(50)
async let _ = account.deposit(50)

// 可能三次打印相同余额：
// Balance: 150
// Balance: 150
// Balance: 150
```

### 解决方案

在挂起之前完成 actor 工作：

```swift
func deposit(amount: Double) async {
    balance += amount
    print("Balance: \(balance)") // 在挂起之前
    
    await logActivity("Deposited \(amount)")
}
```

**规则**：不要假设 `await` 之后状态未改变。

> **课程深入**：此主题在 [Lesson 5.7: Understanding actor reentrancy](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## #isolation 宏

为泛型代码继承调用方的隔离：

```swift
extension Collection where Element: Sendable {
    func sequentialMap<Result: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        transform: (Element) async -> Result
    ) async -> [Result] {
        var results: [Result] = []
        for element in self {
            results.append(await transform(element))
        }
        return results
    }
}

// 从 @MainActor 上下文调用
Task { @MainActor in
    let names = ["Alice", "Bob"]
    let results = await names.sequentialMap { name in
        await process(name) // 继承 @MainActor
    }
}
```

**好处**：避免不必要的挂起，允许非 Sendable 数据。

### Task 闭包和隔离继承

当派生需要处理 `non-Sendable` 类型的非结构化 `Task` 闭包时，你必须捕获 isolation 参数以继承调用方的隔离上下文。

**问题**：`Task` 闭包是 `@Sendable` 的，这阻止了捕获 `non-Sendable` 类型：

```swift
func process(delegate: NonSendableDelegate) {
  Task {
    delegate.doWork() // ❌ 错误：捕获非 Sendable 类型
  }
}
```

**解决方案**：使用 `#isolation` 参数并在 `Task` 内部捕获它：

```swift
func process(
  delegate: NonSendableDelegate,
  isolation: isolated (any Actor)? = #isolation
) {
  Task {
    _ = isolation  // 强制捕获，Task 继承调用方的隔离
    delegate.doWork()  // ✅ 安全——在调用方的 actor 上运行
  }
}
```

**为什么需要 `_ = isolation`**：根据 [SE-0420](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)，`Task` 闭包仅在"闭包捕获了隔离参数的非可选绑定时"才继承隔离。`_ = isolation` 语句强制此捕获。捕获列表语法 `[isolation]` 应该有效，但目前无效。

**何时使用此模式**：
- 派生处理 `non-Sendable` 代理对象的 `Task`
- 需要访问调用方状态的即发即忘异步工作
- 在保持代理存活的同时将基于回调的 API 桥接到异步流

**注意**：此模式使 `non-Sendable` 值在 `Task` 内保持存活和可访问。`Task` 在调用方的隔离域上运行，因此不会发生跨隔离的"发送"。

> **课程深入**：此主题在 [Lesson 5.8: Inheritance of actor isolation using the #isolation macro](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 自定义 Actor 执行器

**高级**：控制 actor 如何调度工作。

### 串行执行器

```swift
final class DispatchQueueExecutor: SerialExecutor {
    private let queue: DispatchQueue
    
    init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        
        queue.async {
            unownedJob.runSynchronously(on: executor)
        }
    }
}

actor LoggingActor {
    private let executor: DispatchQueueExecutor
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    init(queue: DispatchQueue) {
        executor = DispatchQueueExecutor(queue: queue)
    }
}
```

### 何时使用

- 与遗留基于 DispatchQueue 的代码集成
- 特定线程要求（例如 C++ 互操作）
- 自定义调度逻辑

**默认执行器通常已足够。**

> **课程深入**：此主题在 [Lesson 5.9: Using a custom actor executor](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## Mutex：Actor 的替代方案

无 async/await 开销的同步锁定（iOS 18+、macOS 15+）。

### 基本用法

```swift
import Synchronization

final class Counter {
    private let count = Mutex<Int>(0)
    
    var currentCount: Int {
        count.withLock { $0 }
    }
    
    func increment() {
        count.withLock { $0 += 1 }
    }
}
```

### 对非 Sendable 类型的 Sendable 访问

```swift
final class TouchesCapturer: Sendable {
    let path = Mutex<NSBezierPath>(NSBezierPath())
    
    func storeTouch(_ point: NSPoint) {
        path.withLock { path in
            path.move(to: point)
        }
    }
}
```

### 错误处理

```swift
func decrement() throws {
    try count.withLock { count in
        guard count > 0 else {
            throw Error.reachedZero
        }
        count -= 1
    }
}
```

### Mutex vs Actor

| 特性 | Mutex | Actor |
|---------|-------|-------|
| 同步 | ✅ | ❌（需要 await） |
| 异步支持 | ❌ | ✅ |
| 线程阻塞 | ✅ | ❌（协作式） |
| 细粒度锁定 | ✅ | ❌（整个 actor） |
| 遗留代码集成 | ✅ | ❌ |

**使用 Mutex 当**：
- 需要同步访问
- 使用遗留非异步 API
- 需要细粒度锁定
- 低竞争、短临界区

**使用 Actor 当**：
- 可以采用 async/await
- 需要逻辑隔离
- 在异步上下文中工作

> **课程深入**：此主题在 [Lesson 5.10: Using a Mutex as an alternative to actors](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 常见模式

### 带 @MainActor 的视图模型

```swift
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    func loadItems() async {
        items = try await api.fetchItems()
    }
}
```

### 使用自定义 actor 的后台处理

```swift
@ImageProcessing
final class ImageProcessor {
    func process(_ images: [UIImage]) async -> [UIImage] {
        images.map { applyFilters($0) }
    }
}
```

### 混合隔离

```swift
actor DataStore {
    private var items: [Item] = []
    
    func add(_ item: Item) {
        items.append(item)
    }
    
    nonisolated func itemCount() -> Int {
        // ❌ 不能访问 items
        return 0
    }
}
```

### 事务模式

```swift
actor Database {
    func transaction<T>(
        _ operation: @Sendable (_ db: isolated Database) throws -> T
    ) throws -> T {
        beginTransaction()
        defer { commitTransaction() }
        return try operation(self)
    }
}
```

## 最佳实践

1. **在异步代码中优先使用 actor 而非手动锁**
2. **UI 使用 @MainActor**——所有视图模型、UI 更新
3. **最小化 actor 中的工作**——保持临界区短
4. **注意重入**——不要假设 await 后状态未改变
5. **谨慎使用 nonisolated**——仅用于真正不可变的数据
6. **避免 assumeIsolated**——优先显式隔离
7. **自定义执行器很少用**——默认通常最好
8. **同步代码考虑 Mutex**——当不需要异步开销时
9. **在挂起之前完成 actor 工作**——防止重入 bug
10. **使用隔离参数**——减少挂起点

## 决策树

```
需要线程安全的可变状态？
├─ 异步上下文？
│  ├─ 单个实例？ → Actor
│  ├─ 全局/共享？ → 全局 Actor（@MainActor，自定义）
│  └─ UI 相关？ → @MainActor
│
└─ 同步上下文？
   ├─ 可以重构为异步？ → Actor
   ├─ 遗留代码集成？ → Mutex
   └─ 细粒度锁定？ → Mutex
```

## 进一步学习

有关迁移策略、高级模式和真实世界示例，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
