# Sendable

使用本文件当：

- 值或引用类型必须安全地跨越隔离边界。
- 你正在解决 "non-Sendable type" 编译器诊断。
- 你需要在值类型、`@unchecked Sendable`、actor 或基于区域的隔离之间做选择。

跳过本文件如果：

- 问题是关于哪个 actor 应该拥有状态。使用 `actors.md`。
- 问题是关于异步函数如何执行。使用 `threading.md`。

跳转到：

- 隔离域
- 值类型（结构体、枚举）
- 引用类型（类）
- 函数和闭包（@Sendable）
- @unchecked Sendable
- 基于区域的隔离 / `sending`
- 全局变量
- 决策树

## 什么是 Sendable？

`Sendable` 指示类型可以安全地跨隔离域（actor、任务、线程）共享。编译器在编译时验证线程安全性。

```swift
public protocol Sendable {}
```

空协议，但触发编译器对线程安全性的验证。

> **课程深入**：此主题在 [Lesson 4.1: Explaining the concept of Sendable in Swift](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 隔离域

Swift Concurrency 中的三种隔离类型：

### 1. 非隔离（默认）

无并发限制，但不能修改隔离状态：

```swift
func computeValue(a: Int, b: Int) -> Int {
    return a + b
}
```

### 2. Actor 隔离

带串行化访问的专用隔离域：

```swift
actor Library {
    var books: [String] = []
    
    func addBook(_ title: String) {
        books.append(title)
    }
}

// 外部访问需要 await
await library.addBook("Swift Concurrency")
```

### 3. 全局 actor 隔离

跨类型的共享隔离域：

```swift
@MainActor
func updateUI() {
    // 在主线程运行
}
```

## 数据竞争 vs 竞争条件

### 数据竞争

多个线程访问共享可变状态，至少一个写入，无同步：

```swift
// ⚠️ 数据竞争
var counter = 0
DispatchQueue.global().async { counter += 1 }
DispatchQueue.global().async { counter += 1 }
```

**检测**：在 scheme 设置中启用 Thread Sanitizer。

**预防**：使用 actor 或 Sendable 类型：

```swift
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1
    }
}
```

### 竞争条件

导致不可预测结果的时序依赖行为：

```swift
let counter = Counter()

for _ in 1...10 {
    Task { await counter.increment() }
}

// 可能打印不一致的值
print(await counter.getValue())
```

**关键区别**：Swift Concurrency 防止数据竞争但不防止竞争条件。你仍必须确保正确的顺序。

> **课程深入**：此主题在 [Lesson 4.2: Understanding Data Races vs. Race Conditions: Key Differences Explained](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 值类型（结构体、枚举）

### 隐式一致性

具有 Sendable 成员的非公共结构体/枚举：

```swift
// 隐式 Sendable
struct Person {
    var name: String
}
```

### 需要显式一致性

公共类型需要显式声明：

```swift
public struct Person: Sendable {
    var name: String
}
```

**原因**：编译器无法跨模块验证公共类型的内部细节。

### 冻结类型

公共冻结类型可以隐式 Sendable：

```swift
@frozen
public struct Point: Sendable {
    public var x: Double
    public var y: Double
}
```

### 所有成员必须是 Sendable

```swift
public struct Person: Sendable {
    var name: String
    var hometown: Location // 也必须是 Sendable
}

public struct Location: Sendable {
    var name: String
}
```

> **课程深入**：此主题在 [Lesson 4.3: Conforming your code to the Sendable protocol](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 写时复制使可变性安全

```swift
public struct Person: Sendable {
    var name: String // 可变但由于 COW 安全
}
```

每次修改创建副本，防止对同一实例的并发访问。

> **课程深入**：此主题在 [Lesson 4.4: Sendable and Value Types](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 引用类型（类）

### Sendable 类的要求

必须是：
1. `final`（无继承）
2. 仅不可变存储属性
3. 所有属性 Sendable
4. 无超类或仅 `NSObject`

```swift
final class User: Sendable {
    let name: String
    let id: Int
    
    init(name: String, id: Int) {
        self.name = name
        self.id = id
    }
}
```

### 为什么非 final 类不能是 Sendable

子类可能引入不安全的可变性：

```swift
// 不能是 Sendable
class Purchaser {
    func purchase() { }
}

// 可能引入数据竞争
class GamePurchaser: Purchaser {
    var credits: Int = 0 // 可变！
}
```

### Actor 隔离使类 Sendable

```swift
@MainActor
class ViewModel {
    var data: [Item] = [] // 由于 actor 隔离安全
}
// 隐式 Sendable
```

### 组合优于继承

```swift
final class Purchaser: Sendable {
    func purchase() { }
}

final class GamePurchaser {
    let purchaser: Purchaser = Purchaser()
    // 单独处理 credits
}
```

> **课程深入**：此主题在 [Lesson 4.5: Sendable and Reference Types](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 函数和闭包（@Sendable）

标记跨越隔离域的函数/闭包：

```swift
actor ContactsStore {
    func removeAll(_ shouldRemove: @Sendable (Contact) -> Bool) async {
        contacts.removeAll { shouldRemove($0) }
    }
}
```

### 捕获的值必须是 Sendable

```swift
let query = "search"

// ✅ 不可变捕获
store.filter { contact in
    contact.name.contains(query)
}

var query = "search"

// ❌ 可变捕获
store.filter { contact in
    contact.name.contains(query) // 错误
}
```

### 用于可变值的捕获列表

```swift
var query = "search"

// ✅ 捕获不可变快照
store.filter { [query] contact in
    contact.name.contains(query)
}
```

> **课程深入**：此主题在 [Lesson 4.6: Using @Sendable with closures](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## @unchecked Sendable

**作为最后手段使用。** 告诉编译器跳过验证——你保证线程安全。

### 何时使用

编译器无法验证的手动锁定机制：

```swift
final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]
    
    func get(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return items[key]
    }
    
    func set(_ key: String, value: Data) {
        lock.lock()
        defer { lock.unlock() }
        items[key] = value
    }
}
```

### 风险

- 无编译时安全
- 容易引入数据竞争
- 必须手动确保所有访问使用锁

```swift
final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]
    
    // ⚠️ 忘记锁——数据竞争！
    var count: Int {
        items.count
    }
}
```

**更好**：改用 actor：

```swift
actor Cache {
    private var items: [String: Data] = [:]
    
    var count: Int { items.count }
    
    func get(_ key: String) -> Data? {
        items[key]
    }
    
    func set(_ key: String, value: Data) {
        items[key] = value
    }
}
```

> **课程深入**：此主题在 [Lesson 4.7: Using @unchecked Sendable](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 基于区域的隔离

编译器允许在同一作用域中使用非 Sendable 类型：

```swift
class Article {
    var title: String
    init(title: String) { self.title = title }
}

func check() {
    let article = Article(title: "Swift")
    
    Task {
        print(article.title) // ✅ OK——同一区域
    }
}
```

**原因**：传递后无修改，因此无数据竞争风险。

### 在传递后访问时打破

```swift
func check() {
    let article = Article(title: "Swift")
    
    Task {
        print(article.title)
    }
    
    print(article.title) // ❌ 错误——传递后访问
}
```

## sending 关键字

为非 Sendable 类型强制所有权转移：

### 参数值

```swift
actor Logger {
    func log(article: Article) {
        print(article.title)
    }
}

func printTitle(article: sending Article) async {
    let logger = Logger()
    await logger.log(article: article)
}

// 用法
let article = Article(title: "Swift")
await printTitle(article: article)
// article 在此处不再可访问
```

### 返回值

```swift
@SomeActor
func createArticle(title: String) -> sending Article {
    return Article(title: title)
}
```

将所有权转移到调用方的区域。

> **课程深入**：此主题在 [Lesson 4.8: Understanding region-based isolation and the sending keyword](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 全局变量

必须并发安全，因为可从任何上下文访问。

### 问题

```swift
class ImageCache {
    static var shared = ImageCache() // ⚠️ 非并发安全
}
```

### 解决方案 1：Actor 隔离

```swift
@MainActor
class ImageCache {
    static var shared = ImageCache()
}
```

### 解决方案 2：不可变 + Sendable

```swift
final class ImageCache: Sendable {
    static let shared = ImageCache()
}
```

### 解决方案 3：nonisolated(unsafe)

**最后手段**——你保证安全：

```swift
struct APIProvider: Sendable {
    nonisolated(unsafe) static private(set) var shared: APIProvider!
    
    static func configure(apiURL: URL) {
        shared = APIProvider(apiURL: apiURL)
    }
}
```

使用 `private(set)` 限制修改点。

> **课程深入**：此主题在 [Lesson 4.9: Concurrency-safe global variables](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 自定义锁 + Sendable

### 带锁的遗留代码

```swift
final class BankAccount: @unchecked Sendable {
    private var balance: Int = 0
    private let lock = NSLock()
    
    func deposit(amount: Int) {
        lock.lock()
        balance += amount
        lock.unlock()
    }
    
    func getBalance() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return balance
    }
}
```

### 迁移策略

**新代码**：使用 actor

**现有代码**：
1. 如果隔离且作用域小 → 迁移到 actor
2. 如果广泛使用 → 使用 `@unchecked Sendable`，提交迁移工单

```swift
// 更好：迁移到 actor
actor BankAccount {
    private var balance: Int = 0
    
    func deposit(amount: Int) {
        balance += amount
    }
    
    func getBalance() -> Int {
        balance
    }
}
```

> **课程深入**：此主题在 [Lesson 4.10: Combining Sendable with custom Locks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 决策树

```
需要跨隔离域共享类型？
├─ 值类型（结构体/枚举）？
│  ├─ 公共？ → 添加显式 Sendable
│  └─ 内部？ → 隐式 Sendable（如果成员 Sendable）
│
├─ 引用类型（类）？
│  ├─ 可以 final + 不可变？ → Sendable
│  ├─ 需要修改？
│  │  ├─ 可以使用 actor？ → 使用 actor（自动 Sendable）
│  │  ├─ 仅主线程？ → @MainActor
│  │  └─ 有自定义锁？ → @unchecked Sendable（临时）
│  └─ 可以改为结构体？ → 重构为结构体
│
└─ 函数/闭包？ → @Sendable 属性
```

## 常见模式

### 重构以避免非 Sendable 依赖

```swift
// 而非存储非 Sendable 类型
public struct Person: Sendable {
    var hometown: String // 仅名称
    
    init(hometown: Location) {
        self.hometown = hometown.name
    }
}
```

### 可变状态优先使用 actor

```swift
// 而非带锁的 @unchecked Sendable
actor Cache {
    private var items: [String: Data] = [:]
    
    func get(_ key: String) -> Data? {
        items[key]
    }
}
```

### UI 绑定类型使用 @MainActor

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```

## 最佳实践

1. **优先使用值类型**——结构体/枚举更容易使 Sendable
2. **可变状态使用 actor**——自动线程安全
3. **避免 @unchecked Sendable**——仅用于证明线程安全的代码
4. **显式标记公共类型**——不依赖隐式一致性
5. **确保所有成员 Sendable**——一个非 Sendable 打破链
6. **UI 类型使用 @MainActor**——视图模型的简单隔离
7. **不可变捕获**——为可变变量使用捕获列表
8. **使用 Thread Sanitizer 测试**——捕获运行时数据竞争
9. **提交迁移工单**——跟踪 @unchecked Sendable 使用

## 进一步学习

有关迁移策略、真实世界示例和 actor 模式，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
