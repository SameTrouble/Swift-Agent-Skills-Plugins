# 持久化历史跟踪

持久化历史跟踪使 Core Data 能够跨上下文、App Extension 和批量操作跟踪变更。这对于保持 UI 同步和支持多目标应用至关重要。

## 为什么需要持久化历史跟踪？

**没有持久化历史跟踪：**
- 批量操作不更新 UI
- App Extension 无法通知主应用变更
- 多个上下文不同步

**有持久化历史跟踪：**
- 所有变更记录在事务日志中
- 变更可合并到任何上下文
- 跨应用目标工作（主应用、extension 等）

## 启用持久化历史跟踪

### 在 NSPersistentContainer 中

```swift
class PersistentContainer: NSPersistentContainer {
    override init(name: String, managedObjectModel model: NSManagedObjectModel) {
        super.init(name: name, managedObjectModel: model)
        
        guard let description = persistentStoreDescriptions.first else {
            fatalError("No store description")
        }
        
        // 启用持久化历史跟踪
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        
        // 启用远程变更通知
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
    }
}
```

### 用于 App Group（Extension）

```swift
let storeURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.example.app"
)?.appendingPathComponent("Shared.sqlite")

let description = NSPersistentStoreDescription(url: storeURL!)
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

container.persistentStoreDescriptions = [description]
```

## 四个组件

持久化历史跟踪通常涉及四个组件：

1. **Observer** - 监听远程变更通知
2. **Fetcher** - 检索相关事务
3. **Merger** - 将事务合并到 view context
4. **Cleaner** - 删除旧事务

## 1. Observer：监听变更

```swift
final class PersistentHistoryObserver {
    private let coordinator: NSPersistentStoreCoordinator
    private let historyContext: NSManagedObjectContext
    private let merger: PersistentHistoryMerger

    init(container: NSPersistentContainer, viewContext: NSManagedObjectContext) {
        self.coordinator = container.persistentStoreCoordinator
        self.historyContext = container.newBackgroundContext()
        self.historyContext.name = "PersistentHistoryContext"
        self.historyContext.transactionAuthor = "PersistentHistory"
        self.merger = PersistentHistoryMerger(historyContext: historyContext, viewContext: viewContext)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processStoreRemoteChanges),
            name: .NSPersistentStoreRemoteChange,
            object: coordinator
        )
    }

    @objc private func processStoreRemoteChanges(_ notification: Notification) {
        merger.merge()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

## 2. Fetcher：检索事务

```swift
class PersistentHistoryFetcher {
    private let context: NSManagedObjectContext
    private let lastToken: NSPersistentHistoryToken?
    
    init(context: NSManagedObjectContext, lastToken: NSPersistentHistoryToken?) {
        self.context = context
        self.lastToken = lastToken
    }
    
    func fetch() throws -> [NSPersistentHistoryTransaction] {
        let fetchRequest = createFetchRequest()
        
        guard let historyResult = try context.execute(fetchRequest) as? NSPersistentHistoryResult,
              let transactions = historyResult.result as? [NSPersistentHistoryTransaction] else {
            return []
        }
        
        return transactions
    }
    
    private func createFetchRequest() -> NSPersistentHistoryChangeRequest {
        let request: NSPersistentHistoryChangeRequest
        
        if let token = lastToken {
            request = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
        } else {
            request = NSPersistentHistoryChangeRequest.fetchHistory(after: Date.distantPast)
        }
        
        // 过滤掉来自此应用目标的事务
        if let fetchRequest = request.fetchRequest {
            fetchRequest.predicate = NSPredicate(
                format: "author != %@",
                "MainApp" // 你的应用的 transaction author
            )
        }
        
        return request
    }
}
```

## 3. Merger：应用变更

```swift
final class PersistentHistoryMerger {
    private let historyContext: NSManagedObjectContext
    private let viewContext: NSManagedObjectContext
    private var lastToken: NSPersistentHistoryToken?

    init(historyContext: NSManagedObjectContext, viewContext: NSManagedObjectContext) {
        self.historyContext = historyContext
        self.viewContext = viewContext
        self.lastToken = loadLastToken()
    }

    func merge() {
        historyContext.perform {
            do {
                let fetcher = PersistentHistoryFetcher(
                    context: self.historyContext,
                    lastToken: self.lastToken
                )

                let transactions = try fetcher.fetch()
                guard !transactions.isEmpty else { return }

                self.viewContext.perform {
                    self.mergeTransactions(transactions)
                }

                if let newToken = transactions.last?.token {
                    self.lastToken = newToken
                    self.saveLastToken(newToken)
                }
            } catch {
                print("合并历史失败: \(error)")
            }
        }
    }

    private func mergeTransactions(_ transactions: [NSPersistentHistoryTransaction]) {
        for transaction in transactions {
            guard let userInfo = transaction.objectIDNotification().userInfo else { continue }
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [viewContext])
        }
    }
    
    private func loadLastToken() -> NSPersistentHistoryToken? {
        guard let data = UserDefaults.standard.data(forKey: "lastHistoryToken") else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSPersistentHistoryToken.self,
            from: data
        )
    }
    
    private func saveLastToken(_ token: NSPersistentHistoryToken) {
        if let data = try? NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        ) {
            UserDefaults.standard.set(data, forKey: "lastHistoryToken")
        }
    }
}
```

## 4. Cleaner：删除旧事务

```swift
class PersistentHistoryCleaner {
    private let context: NSManagedObjectContext
    private let targets: [AppTarget]
    
    enum AppTarget {
        case mainApp
        case shareExtension
        case widgetExtension
        
        var lastTokenKey: String {
            switch self {
            case .mainApp: return "mainApp.lastHistoryToken"
            case .shareExtension: return "shareExtension.lastHistoryToken"
            case .widgetExtension: return "widgetExtension.lastHistoryToken"
            }
        }
    }
    
    init(context: NSManagedObjectContext, targets: [AppTarget]) {
        self.context = context
        self.targets = targets
    }
    
    func clean() {
        context.perform {
            // 查找所有目标中最旧的 token
            guard let oldestToken = self.findOldestToken() else { return }
            
            // 删除该 token 之前的历史
            let deleteRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: oldestToken)
            
            do {
                try self.context.execute(deleteRequest)
            } catch {
                print("清理历史失败: \(error)")
            }
        }
    }
    
    private func findOldestToken() -> NSPersistentHistoryToken? {
        var oldestDate: Date?
        var oldestToken: NSPersistentHistoryToken?
        
        for target in targets {
            guard let token = loadToken(for: target) else { continue }
            
            // 从 token 获取时间戳（需要获取事务）
            let historyRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
            historyRequest.fetchRequest?.fetchLimit = 1
            
            guard let result = try? context.execute(historyRequest) as? NSPersistentHistoryResult,
                  let transactions = result.result as? [NSPersistentHistoryTransaction],
                  let transaction = transactions.first else {
                continue
            }
            
            let date = transaction.timestamp
            if oldestDate == nil || date < oldestDate! {
                oldestDate = date
                oldestToken = token
            }
        }
        
        return oldestToken
    }
    
    private func loadToken(for target: AppTarget) -> NSPersistentHistoryToken? {
        guard let data = UserDefaults.standard.data(forKey: target.lastTokenKey) else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSPersistentHistoryToken.self,
            from: data
        )
    }
}
```

## 完整集成示例

```swift
class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        
        // 配置存储
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No store description")
        }
        
        // 启用持久化历史跟踪
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }

            self.setupHistoryTracking(container: container)
        }
        
        // 配置 view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "ViewContext"
        container.viewContext.transactionAuthor = "MainApp"
        
        return container
    }()
    
    private var historyObserver: PersistentHistoryObserver?
    
    private init() {}
    
    private func setupHistoryTracking(container: NSPersistentContainer) {
        historyObserver = PersistentHistoryObserver(container: container, viewContext: container.viewContext)
        cleanHistoryPeriodically(container: container)
    }
    
    private func cleanHistoryPeriodically(container: NSPersistentContainer) {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            let context = container.newBackgroundContext()
            let cleaner = PersistentHistoryCleaner(
                context: context,
                targets: [.mainApp, .shareExtension]
            )
            cleaner.clean()
        }
    }
}
```

## Transaction Author

为每个应用目标设置唯一的 transaction author：

```swift
// 主应用
viewContext.transactionAuthor = "MainApp"

// Share extension
viewContext.transactionAuthor = "ShareExtension"

// Widget extension
viewContext.transactionAuthor = "WidgetExtension"
```

**为什么这很重要：**
- 过滤掉自己的事务（避免冗余合并）
- 识别哪个目标做了变更
- 调试多目标问题

## 过滤事务

### 按 Author

```swift
let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
if let request = fetchRequest.fetchRequest {
    request.predicate = NSPredicate(format: "author != %@", "MainApp")
}
```

### 按日期

```swift
let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: cutoffDate)
```

### 按实体

```swift
let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
if let request = fetchRequest.fetchRequest {
    request.predicate = NSPredicate(format: "ANY changes.changedObjectID.entity.name == %@", "Article")
}
```

## 批量操作集成

持久化历史跟踪是批量操作更新 UI 的**必需条件**：

```swift
// 1. 启用持久化历史跟踪
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

// 2. 执行批量操作
let context = container.newBackgroundContext()
context.perform {
    let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
        // 插入逻辑
        return false
    }
    try? context.execute(batchInsert)
}

// 3. 通过持久化历史跟踪自动更新 UI
// observer 检测到变更并合并到 view context
```

## 测试持久化历史

```swift
func testPersistentHistory() throws {
    // 启用持久化历史
    let description = container.persistentStoreDescriptions.first!
    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    
    // 在后台创建对象
    let backgroundContext = container.newBackgroundContext()
    backgroundContext.transactionAuthor = "Test"
    
    let expectation = XCTestExpectation(description: "保存")
    
    backgroundContext.perform {
        let article = Article(context: backgroundContext)
        article.name = "Test"
        try? backgroundContext.save()
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
    
    // 获取历史
    let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: Date.distantPast)
    let result = try container.viewContext.execute(fetchRequest) as? NSPersistentHistoryResult
    let transactions = result?.result as? [NSPersistentHistoryTransaction]
    
    XCTAssertNotNil(transactions)
    XCTAssertFalse(transactions!.isEmpty)
}
```

## 常见陷阱

### ❌ 未启用远程变更通知

```swift
// 仅这样不够
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

// 需要两个都启用！
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
```

### ❌ 未过滤自己的事务

```swift
// 合并自己的事务（冗余）
let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
```

### ❌ 未清理旧事务

```swift
// 历史无限增长，浪费空间
// 始终实施清理！
```

### ❌ 未设置 Transaction Author

```swift
// 无法按来源过滤事务
context.transactionAuthor = nil // 错误！
```

### ✅ 正确做法

```swift
// 1. 启用两个选项
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

// 2. 设置 transaction author
context.transactionAuthor = "MainApp"

// 3. 过滤自己的事务
fetchRequest.predicate = NSPredicate(format: "author != %@", "MainApp")

// 4. 定期清理
let cleaner = PersistentHistoryCleaner(context: context, targets: [.mainApp, .shareExtension])
cleaner.clean()
```

## 性能考虑

### 定期清理历史

```swift
// 每日清理
Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
    cleaner.clean()
}

// 或在应用启动时
func applicationDidFinishLaunching() {
    cleaner.clean()
}
```

### 限制获取范围

```swift
// 不要获取所有历史
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: sevenDaysAgo)
```

### 批量合并变更

```swift
// 一次合并多个事务
let transactions = try fetcher.fetch()
for transaction in transactions {
    let userInfo = transaction.objectIDNotification().userInfo
    NSManagedObjectContext.mergeChanges(
        fromRemoteContextSave: userInfo!,
        into: [viewContext]
    )
}
```

## 总结

1. **启用持久化历史跟踪** - 批量操作和多目标应用必需
2. **启用远程变更通知** - 跨上下文更新必需
3. **设置 transaction author** - 识别变更来源
4. **过滤自己的事务** - 避免冗余合并
5. **实现所有四个组件** - Observer、Fetcher、Merger、Cleaner
6. **定期清理历史** - 防止无限增长
7. **与批量操作配合使用** - UI 更新的关键
8. **彻底测试** - 验证历史跟踪跨目标工作
