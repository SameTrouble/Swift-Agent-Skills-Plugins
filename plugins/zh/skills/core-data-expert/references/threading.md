# 线程与并发

Core Data 的线程规则严格但对于数据完整性至关重要。本指南涵盖安全的多线程模式、常见陷阱和调试技术。

## 黄金法则

**切勿跨线程传递 `NSManagedObject` 实例。始终使用 `NSManagedObjectID`。**

```swift
// ❌ 错误：跨上下文传递对象
let article = viewContext.object(...)
backgroundContext.perform {
    article.name = "Updated" // 崩溃！
}

// ✅ 正确：传递对象 ID
let objectID = article.objectID
backgroundContext.perform {
    guard let article = try? backgroundContext.existingObject(with: objectID) as? Article else { return }
    article.name = "Updated" // 安全！
    try? backgroundContext.save()
}
```

## 为什么 NSManagedObjectID 是线程安全的

`NSManagedObjectID` 是不可变的且线程安全的。它是一个跨上下文和线程工作的唯一标识符。

```swift
// 对象 ID 是线程安全的
let objectID: NSManagedObjectID = article.objectID

// 可以传递到任何线程/上下文
DispatchQueue.global().async {
    let context = container.newBackgroundContext()
    context.perform {
        if let article = try? context.existingObject(with: objectID) as? Article {
            // 安全地操作 article
        }
    }
}
```

## 上下文类型与并发

### View Context（主队列）

运行在主线程上。用于所有 UI 操作。

```swift
let viewContext = container.viewContext
viewContext.perform {
    // 运行在主线程
    let article = Article(context: viewContext)
    article.name = "New Article"
    try? viewContext.save()
}
```

**特点：**
- 主队列并发类型
- 运行在主线程
- 仅用于 UI 相关操作
- 保持操作轻量

### Background Context（私有队列）

运行在私有队列上。用于繁重任务。

```swift
let backgroundContext = container.newBackgroundContext()
backgroundContext.perform {
    // 运行在私有后台队列
    for i in 0..<1000 {
        let article = Article(context: backgroundContext)
        article.name = "Article \(i)"
    }
    try? backgroundContext.save()
}
```

**特点：**
- 私有队列并发类型
- 运行在后台线程
- 用于导入、导出、批量操作
- 不阻塞 UI

## perform vs performAndWait

### perform（异步 - 首选）

```swift
context.perform {
    // 异步执行任务
    let article = Article(context: context)
    try? context.save()
}
// 此处代码立即执行，在 perform 块完成之前
```

**好处：**
- 非阻塞
- 更好的性能
- 大多数情况推荐

### performAndWait（同步 - 谨慎使用）

```swift
context.performAndWait {
    // 同步执行任务
    let article = Article(context: context)
    try? context.save()
}
// 此处代码在 perform 块完成后执行
```

**注意：**
- 阻塞调用线程
- 即使是 background context 也可能阻塞主线程
- 仅在需要立即获取结果时使用

**阻塞行为示例：**

```swift
// 从主线程调用
let backgroundContext = container.newBackgroundContext()

// 这会阻塞主线程！
backgroundContext.performAndWait {
    // 繁重任务阻塞 UI
    for i in 0..<10000 {
        let article = Article(context: backgroundContext)
    }
}
```

## 常见线程模式

### 模式 1：后台导入

```swift
func importArticles(_ data: [ArticleData]) {
    let backgroundContext = container.newBackgroundContext()
    backgroundContext.perform {
        for item in data {
            let article = Article(context: backgroundContext)
            article.name = item.name
            article.content = item.content
        }
        
        do {
            try backgroundContext.save()
        } catch {
            print("保存失败: \(error)")
        }
    }
}
```

### 模式 2：从后台更新对象

```swift
func updateArticle(_ article: Article, newName: String) {
    let objectID = article.objectID
    let backgroundContext = container.newBackgroundContext()
    
    backgroundContext.perform {
        guard let article = try? backgroundContext.existingObject(with: objectID) as? Article else {
            return
        }
        
        article.name = newName
        try? backgroundContext.save()
    }
}
```

### 模式 3：后台获取，主线程更新 UI

```swift
func loadArticles(completion: @escaping ([Article]) -> Void) {
    let backgroundContext = container.newBackgroundContext()
    
    backgroundContext.perform {
        let fetchRequest = Article.fetchRequest()
        guard let articles = try? backgroundContext.fetch(fetchRequest) else {
            return
        }
        
        // 获取对象 ID（线程安全）
        let objectIDs = articles.map { $0.objectID }
        
        // 切换到主上下文更新 UI
        DispatchQueue.main.async {
            let viewContext = self.container.viewContext
            let mainArticles = objectIDs.compactMap { 
                try? viewContext.existingObject(with: $0) as? Article 
            }
            completion(mainArticles)
        }
    }
}
```

### 模式 4：使用对象 ID 批量删除

```swift
func deleteArticles(_ articles: [Article]) {
    let objectIDs = articles.map { $0.objectID }
    let backgroundContext = container.newBackgroundContext()
    
    backgroundContext.perform {
        for objectID in objectIDs {
            guard let article = try? backgroundContext.existingObject(with: objectID) else {
                continue
            }
            backgroundContext.delete(article)
        }
        
        try? backgroundContext.save()
    }
}
```

## 上下文层级与父上下文

### 子上下文模式

```swift
// 父上下文（view context）
let parentContext = container.viewContext

// 用于编辑的子上下文
let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
childContext.parent = parentContext

// 在子上下文中进行变更
let article = childContext.object(with: articleID) as! Article
article.name = "Updated"

// 保存到父上下文（尚未写入磁盘）
try? childContext.save()

// 保存父上下文以持久化
try? parentContext.save()
```

**好处：**
- 可以通过不保存子上下文来丢弃变更
- 适用于表单/编辑
- 隔离变更

**注意：**
- 增加复杂性
- 持久化需要两次保存
- 必须保存父上下文才能持久化变更

## 调试线程问题

### 启用并发调试

添加启动参数：
```
-com.apple.CoreData.ConcurrencyDebug 1
```

**它能捕获：**
- 从错误线程访问对象
- 从错误队列使用上下文
- 线程安全违规

**示例错误：**
```
CoreData: error: Serious application error.
An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent:.
*** -[NSManagedObjectContext performSelector:withObject:] called from thread which is not the context's thread with userInfo (null)
```

### 常见线程错误

#### 错误 1：从错误上下文访问对象

```swift
// ❌ 错误
let article = viewContext.object(...)
backgroundContext.perform {
    print(article.name) // 崩溃！
}

// ✅ 正确
let objectID = article.objectID
backgroundContext.perform {
    if let article = try? backgroundContext.existingObject(with: objectID) as? Article {
        print(article.name)
    }
}
```

#### 错误 2：不使用 perform

```swift
// ❌ 错误
let backgroundContext = container.newBackgroundContext()
let article = Article(context: backgroundContext) // 崩溃！

// ✅ 正确
let backgroundContext = container.newBackgroundContext()
backgroundContext.perform {
    let article = Article(context: backgroundContext)
}
```

#### 错误 3：跨线程传递上下文

```swift
// ❌ 错误
DispatchQueue.global().async {
    try? viewContext.save() // 崩溃！
}

// ✅ 正确
viewContext.perform {
    try? viewContext.save()
}
```

## 上下文间合并变更

### 自动合并

启用从父上下文自动合并：

```swift
context.automaticallyMergesChangesFromParent = true
```

**好处：**
- 其他上下文的变更自动合并
- 无需手动合并代码
- 大多数情况推荐

### 手动合并

监听保存通知：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(contextDidSave),
    name: .NSManagedObjectContextDidSave,
    object: backgroundContext
)

@objc func contextDidSave(_ notification: Notification) {
    viewContext.perform {
        viewContext.mergeChanges(fromContextDidSave: notification)
    }
}
```

## Core Data 中的 Async/Await（iOS 15+）

### 使用 async/await

```swift
func fetchArticles() async throws -> [Article] {
    let context = container.newBackgroundContext()
    
    return try await context.perform {
        let fetchRequest = Article.fetchRequest()
        return try context.fetch(fetchRequest)
    }
}

// 使用
Task {
    do {
        let articles = try await fetchArticles()
        // 用 articles 更新 UI
    } catch {
        print("获取失败: \(error)")
    }
}
```

### 使用 async/await 保存

```swift
func saveArticle(name: String) async throws {
    let context = container.newBackgroundContext()
    
    try await context.perform {
        let article = Article(context: context)
        article.name = name
        try context.save()
    }
}
```

## 性能考虑

### 上下文复用

```swift
// ❌ 错误：为每个操作创建新上下文
func updateArticle1() {
    let context = container.newBackgroundContext()
    context.perform { /* ... */ }
}

func updateArticle2() {
    let context = container.newBackgroundContext() // 新上下文！
    context.perform { /* ... */ }
}

// ✅ 更好：为相关操作复用上下文
class DataManager {
    private lazy var backgroundContext = container.newBackgroundContext()
    
    func updateArticle1() {
        backgroundContext.perform { /* ... */ }
    }
    
    func updateArticle2() {
        backgroundContext.perform { /* ... */ }
    }
}
```

### 上下文重置

对于长时间运行的上下文，定期重置以释放内存：

```swift
backgroundContext.perform {
    for (index, data) in largeDataset.enumerated() {
        let article = Article(context: backgroundContext)
        article.name = data.name
        
        if index % 100 == 0 {
            try? backgroundContext.save()
            backgroundContext.reset() // 清除内存
        }
    }
}
```

## 线程 confinement

每个上下文都 confined 在其队列上。你可以从任何线程调用 `perform`，但所有 Core Data 工作必须在该上下文的 `perform`/`performAndWait` 内执行。

```swift
let context = container.newBackgroundContext()

// ✅ 允许：从任何地方调度工作
DispatchQueue.global().async {
    context.perform {
        // 工作在上下文的队列上执行
    }
}

DispatchQueue.main.async {
    context.perform {
        // 也在上下文的队列上执行
    }
}

// ❌ 错误：在 perform 外部触碰上下文或其对象
DispatchQueue.global().async {
    let article = Article(context: context) // 不在 perform 内
    try? context.save()                     // 不在 perform 内
}
```

## 常见陷阱

### ❌ 直接传递对象

```swift
func updateInBackground(_ article: Article) {
    backgroundContext.perform {
        article.name = "Updated" // 崩溃！
    }
}
```

### ❌ 不使用 perform

```swift
let backgroundContext = container.newBackgroundContext()
let article = Article(context: backgroundContext) // 崩溃！
```

### ❌ 从 background context 访问 UI

```swift
backgroundContext.perform {
    let articles = try? backgroundContext.fetch(Article.fetchRequest())
    tableView.reloadData() // 崩溃！错误线程
}
```

### ❌ 在主线程使用 performAndWait

```swift
// 在主线程
backgroundContext.performAndWait {
    // 繁重任务 - 阻塞 UI！
}
```

### ✅ 正确模式

```swift
// 传递对象 ID
func updateInBackground(_ article: Article) {
    let objectID = article.objectID
    backgroundContext.perform {
        guard let article = try? backgroundContext.existingObject(with: objectID) as? Article else {
            return
        }
        article.name = "Updated"
        try? backgroundContext.save()
    }
}

// 始终使用 perform
let backgroundContext = container.newBackgroundContext()
backgroundContext.perform {
    let article = Article(context: backgroundContext)
}

// 在主线程更新 UI
backgroundContext.perform {
    let articles = try? backgroundContext.fetch(Article.fetchRequest())
    let objectIDs = articles?.map { $0.objectID } ?? []
    
    DispatchQueue.main.async {
        // 用 objectIDs 更新 UI
    }
}

// 使用 perform（异步）而非 performAndWait
backgroundContext.perform {
    // 繁重任务不阻塞 UI
}
```

## 测试线程

```swift
func testThreadSafety() {
    let expectation = XCTestExpectation(description: "Background save")
    
    let objectID = article.objectID
    let backgroundContext = container.newBackgroundContext()
    
    backgroundContext.perform {
        guard let article = try? backgroundContext.existingObject(with: objectID) as? Article else {
            XCTFail("Failed to fetch article")
            return
        }
        
        article.name = "Updated"
        
        do {
            try backgroundContext.save()
            expectation.fulfill()
        } catch {
            XCTFail("保存失败: \(error)")
        }
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

## 总结

1. **切勿跨上下文传递 NSManagedObject** - 始终使用 NSManagedObjectID
2. **始终使用 `perform` 或 `performAndWait`** - 切勿直接访问上下文
3. **优先使用 `perform` 而非 `performAndWait`** - 避免阻塞
4. **view context 仅用于 UI** - 繁重任务在 background context
5. **启用 `-com.apple.CoreData.ConcurrencyDebug 1`** - 捕获线程违规
6. **启用 `automaticallyMergesChangesFromParent`** - 自动变更传播
7. **在 iOS 15+ 使用 async/await** - 更简洁的异步代码
8. **定期重置上下文** - 在长时间运行的操作中释放内存
9. **每个队列一个上下文** - 不要跨队列共享上下文
10. **测试线程行为** - 在测试中验证线程安全
