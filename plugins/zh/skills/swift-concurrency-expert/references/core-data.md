# Core Data 和 Swift Concurrency

使用本文件当：

- 你需要在 async/await 或 actor 中使用 Core Data。
- `NSManagedObject` 实例跨越了上下文或 actor 边界。
- 你正在解决默认 `@MainActor` 隔离与生成的 NSManagedObject 子类之间的冲突。

跳过本文件如果：

- 问题是通用 actor 隔离，而非 Core Data 特定。使用 `actors.md`。
- 你需要通用 Sendable 指导。使用 `sendable.md`。

跳转到：

- 核心原则
- 数据访问对象（DAO）模式
- 不使用 DAO（NSManagedObjectID）
- 将闭包桥接到 Async
- 自定义 Actor 执行器（高级）
- 默认 MainActor 隔离
- SwiftUI 集成
- 常见错误

## 核心原则

### 线程安全仍然重要

Core Data 的线程安全规则不随 Swift Concurrency 改变：
- 不能在线程之间传递 `NSManagedObject`
- 必须在对象上下文的线程上访问对象
- `NSManagedObjectID` 是线程安全的（可以传递）

### NSManagedObject 不能是 Sendable

```swift
@objc(Article)
public class Article: NSManagedObject {
    @NSManaged public var title: String // ❌ 可变，不能是 Sendable
}
```

**不要使用 `@unchecked Sendable`**——隐藏警告而不修复安全性。

> **课程深入**：此主题在 [Lesson 9.1: An introduction to Swift Concurrency and Core Data](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 可用的 Async API

### Context perform

```swift
extension NSManagedObjectContext {
    func perform<T>(
        schedule: ScheduledTaskType = .immediate,
        _ block: @escaping () throws -> T
    ) async rethrows -> T
}
```

### 缺少什么

以下没有异步替代方案：
```swift
func loadPersistentStores(
    completionHandler: @escaping (NSPersistentStoreDescription, Error?) -> Void
)
```

必须手动桥接（见下文）。

## 数据访问对象（DAO）

表示托管对象的线程安全值类型。

### 模式

```swift
// 托管对象（非 Sendable）
@objc(Article)
public class Article: NSManagedObject {
    @NSManaged public var title: String?
    @NSManaged public var timestamp: Date?
}

// DAO（Sendable）
struct ArticleDAO: Sendable, Identifiable {
    let id: NSManagedObjectID
    let title: String
    let timestamp: Date
    
    init?(managedObject: Article) {
        guard let title = managedObject.title,
              let timestamp = managedObject.timestamp else {
            return nil
        }
        self.id = managedObject.objectID
        self.title = title
        self.timestamp = timestamp
    }
}
```

### 好处

- **Sendable**：可以安全地跨隔离域传递
- **不可变**：无意外修改
- **清晰 API**：显式数据传输

### 缺点

- **需要重写**：所有获取/修改逻辑
- **样板代码**：每个实体一个 DAO
- **复杂性**：额外的抽象层

> **课程深入**：此主题在 [Lesson 9.2: Sendable and NSManageObjects](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 不使用 DAO

仅在上下文之间传递 `NSManagedObjectID`。

### 基本模式

```swift
@MainActor
func fetchArticle(id: NSManagedObjectID) -> Article? {
    viewContext.object(with: id) as? Article
}

func processInBackground(articleID: NSManagedObjectID) async throws {
    let backgroundContext = container.newBackgroundContext()
    try await backgroundContext.perform {
        guard let article = backgroundContext.object(with: articleID) as? Article else {
            return
        }
        // 处理 article
        try backgroundContext.save()
    }
}
```

### NSManagedObjectID 是 Sendable

```swift
// 可以在任务之间安全传递
let articleID = article.objectID

Task {
    await processInBackground(articleID: articleID)
}
```

## 将闭包桥接到 Async

### 加载持久化存储

```swift
extension NSPersistentContainer {
    func loadPersistentStores() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.loadPersistentStores { description, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

// 用法
try await container.loadPersistentStores()
```

## 简单 CoreDataStore 模式

在 API 级别强制隔离：

```swift
nonisolated struct CoreDataStore {
    static let shared = CoreDataStore()
    
    let persistentContainer: NSPersistentContainer
    private var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "MyApp")
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        
        Task { [persistentContainer] in
            try? await persistentContainer.loadPersistentStores()
        }
    }
    
    // 视图上下文操作（主线程）
    @MainActor
    func perform(_ block: (NSManagedObjectContext) throws -> Void) rethrows {
        try block(viewContext)
    }
    
    // 后台操作
    @concurrent
    func performInBackground<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async rethrows -> T {
        let context = persistentContainer.newBackgroundContext()
        return try await context.perform {
            try block(context)
        }
    }
}
```

### 用法

```swift
// 主线程操作
@MainActor
func loadArticles() throws -> [Article] {
    try CoreDataStore.shared.perform { context in
        let request = Article.fetchRequest()
        return try context.fetch(request)
    }
}

// 后台操作
func deleteAll() async throws {
    try await CoreDataStore.shared.performInBackground { context in
        let request = Article.fetchRequest()
        let articles = try context.fetch(request)
        articles.forEach { context.delete($0) }
        try context.save()
    }
}
```

### 为什么此模式有效

- **@MainActor**：强制视图上下文在主线程
- **@concurrent**：强制后台执行
- **编译时安全**：错误隔离 = 错误
- **简单**：无需自定义执行器

## 自定义 Actor 执行器（高级）

**注意**：通常不需要。先考虑简单模式。

> **课程深入**：此主题在 [Lesson 9.3: Using a custom Actor executor for Core Data (advanced)](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 实现

```swift
final class NSManagedObjectContextExecutor: @unchecked Sendable, SerialExecutor {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        
        context.perform {
            unownedJob.runSynchronously(on: executor)
        }
    }
    
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}
```

### Actor 用法

```swift
actor CoreDataStore {
    let persistentContainer: NSPersistentContainer
    nonisolated let modelExecutor: NSManagedObjectContextExecutor
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        modelExecutor.asUnownedSerialExecutor()
    }
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "MyApp")
        let context = persistentContainer.newBackgroundContext()
        modelExecutor = NSManagedObjectContextExecutor(context: context)
    }
    
    func deleteAll<T: NSManagedObject>(
        using request: NSFetchRequest<T>
    ) throws {
        let objects = try context.fetch(request)
        objects.forEach { context.delete($0) }
        try context.save()
    }
}
```

### 缺点

- **隐藏复杂性**：执行器细节掩盖了 Core Data
- **强制并发**：即使是主线程操作
- **不更简单**：比 `perform { }` 代码更多
- **容易出错**：容易使用错误的上下文

**建议**：改用简单模式。

## 默认 MainActor 隔离

### 自动生成代码的问题

当默认隔离设置为 `@MainActor` 时，自动生成的托管对象会冲突：

```swift
// 自动生成（不能修改）
class Article: NSManagedObject {
    // 继承 @MainActor，与 NSManagedObject 冲突
}
```

**错误**：`Main actor-isolated initializer has different actor isolation from nonisolated overridden declaration`

### 解决方案：手动代码生成

1. 将实体设置为 "Manual/None" 代码生成
2. 生成类定义
3. 标记为 `nonisolated`：

```swift
nonisolated class Article: NSManagedObject {
    @NSManaged public var title: String?
    @NSManaged public var timestamp: Date?
}

> **课程深入**：此主题在 [Lesson 9.4: Autogenerated Core Data Objects and Default MainActor Isolation Conflicts](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍
```

**好处**：完全控制隔离。

## 常见模式

### 主线程获取

```swift
@MainActor
func fetchArticles() throws -> [Article] {
    let request = Article.fetchRequest()
    return try viewContext.fetch(request)
}
```

### 后台保存

```swift
func saveInBackground() async throws {
    let context = container.newBackgroundContext()
    try await context.perform {
        let article = Article(context: context)
        article.title = "New Article"
        try context.save()
    }
}
```

### 传递 ID，在上下文中获取

```swift
@MainActor
func displayArticle(id: NSManagedObjectID) {
    guard let article = viewContext.object(with: id) as? Article else {
        return
    }
    // 使用 article
}

func processArticle(id: NSManagedObjectID) async throws {
    try await CoreDataStore.shared.performInBackground { context in
        guard let article = context.object(with: id) as? Article else {
            return
        }
        // 处理 article
        try context.save()
    }
}
```

### 批量操作

```swift
@concurrent
func deleteAllArticles() async throws {
    try await CoreDataStore.shared.performInBackground { context in
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Article")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        try context.execute(deleteRequest)
    }
}
```

## SwiftUI 集成

### 环境注入

```swift
@main
struct MyApp: App {
    let persistentContainer = NSPersistentContainer(name: "MyApp")
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
    }
}
```

### 视图用法

```swift
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.timestamp, ascending: true)]
    ) private var articles: FetchedResults<Article>
    
    var body: some View {
        List(articles) { article in
            Text(article.title ?? "")
        }
    }
}
```

## 最佳实践

1. **仅传递 NSManagedObjectID**——绝不传递托管对象
2. **使用 perform { }**——不要直接访问上下文
3. **@MainActor 用于视图上下文**——强制主线程
4. **@concurrent 用于后台**——强制后台执行
5. **手动代码生成**——控制隔离
6. **保持简单**——除非需要，避免自定义执行器
7. **启用 Core Data 调试**——捕获线程违规
8. **自动合并更改**——`automaticallyMergesChangesFromParent = true`
9. **使用后台上下文**——用于重操作
10. **使用 Thread Sanitizer 测试**——及早捕获违规

## 调试

### 启用 Core Data 并发调试

```swift
// 启动参数
-com.apple.CoreData.ConcurrencyDebug 1
```

线程违规时立即崩溃。

### Thread Sanitizer

在 scheme 设置中启用以捕获数据竞争。

### 断言

```swift
@MainActor
func fetchArticles() -> [Article] {
    assert(Thread.isMainThread)
    // 从 viewContext 获取
}
```

## 决策树

```
需要访问 Core Data？
├─ UI/视图上下文？
│  └─ 使用 @MainActor + viewContext
│
├─ 后台操作？
│  ├─ 快速操作？ → 在后台上下文上 perform { }
│  └─ 批量操作？ → NSBatchDeleteRequest/NSBatchUpdateRequest
│
├─ 在上下文之间传递？
│  └─ 仅使用 NSManagedObjectID
│
└─ 需要 Sendable 类型？
   ├─ 可以重构？ → 使用 DAO 模式
   └─ 不能重构？ → 传递 NSManagedObjectID
```

## 迁移策略

### 对于现有项目

1. 为所有实体启用手动代码生成
2. 如果使用默认 @MainActor，将实体标记为 nonisolated
3. 在 CoreDataStore 中包装 Core Data 访问
4. 视图上下文操作使用 @MainActor
5. 后台操作使用 @concurrent
6. 在上下文之间传递 NSManagedObjectID
7. 启用调试进行测试

### 对于新项目

1. 从简单模式开始（CoreDataStore）
2. 从一开始就使用手动代码生成
3. 如果有大量跨上下文使用，考虑 DAO
4. 尽早启用严格并发

## 常见错误

### ❌ 传递托管对象

```swift
func process(article: Article) async {
    // ❌ Article 不是 Sendable
}
```

### ❌ 从错误线程访问上下文

```swift
func background() async {
    let articles = viewContext.fetch(request) // ❌ 不在主线程
}
```

### ❌ 使用 @unchecked Sendable

```swift
extension Article: @unchecked Sendable {} // ❌ 不能使其安全
```

### ❌ 不使用 perform

```swift
func save() async {
    backgroundContext.save() // ❌ 不在上下文的线程
}
```

## 代理常犯的错误

- **跨 actor 传递 `NSManagedObject` 实例**：始终传递 `NSManagedObjectID` 或 Sendable 值快照。
- **在 `NSManagedObject` 上使用 `@unchecked Sendable`**：这不能使其线程安全。对象仍然绑定到其上下文的队列。
- **跳过 `perform { }`**：所有后台上下文访问必须通过 `perform` 或 `performAndWait`。
- **从后台任务访问 `viewContext`**：视图上下文属于 main actor；仅从 `@MainActor` 隔离的代码访问。

## 进一步学习

有关 Core Data 最佳实践、迁移策略和高级模式：
- [Core Data Best Practices](https://github.com/avanderlee/CoreDataBestPractices)
- [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)
