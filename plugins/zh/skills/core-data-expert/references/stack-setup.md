# Core Data 栈配置

正确配置 Core Data 栈是构建良好架构应用的基础。本指南涵盖配置 `NSPersistentContainer`、管理上下文以及建立可扩展模式的最佳实践。

## 自定义 NSPersistentContainer

创建自定义子类，而不是在 `AppDelegate` 中配置一切。这样可以让栈配置保持有序且可测试。

```swift
import CoreData

class PersistentContainer: NSPersistentContainer {
    static let shared = PersistentContainer(name: "DataModel")
    
    private override init(name: String, managedObjectModel model: NSManagedObjectModel) {
        super.init(name: name, managedObjectModel: model)
        configure()
    }
    
    convenience init(name: String) {
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load data model")
        }
        self.init(name: name, managedObjectModel: model)
    }
    
    private func configure() {
        // 设置用于处理约束的合并策略
        viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // 启用从父上下文自动合并
        viewContext.automaticallyMergesChangesFromParent = true
        
        // 为 view context 命名以便调试
        viewContext.name = "ViewContext"

        // 在加载前配置存储选项
        configureStoreDescription()
        
        // 加载持久化存储
        loadPersistentStores { description, error in
            if let error = error {
                // 适当处理错误
                fatalError("Failed to load persistent store: \(error)")
            }
        }
    }
    
    private func configureStoreDescription() {
        guard let description = persistentStoreDescriptions.first else { return }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }
}
```

## 单例模式 vs 依赖注入

### 单例模式（推荐用于大多数应用）

```swift
class PersistentContainer: NSPersistentContainer {
    static let shared = PersistentContainer(name: "DataModel")
    
    // 防止外部初始化
    private override init(name: String, managedObjectModel model: NSManagedObjectModel) {
        super.init(name: name, managedObjectModel: model)
    }
}

// 使用
let context = PersistentContainer.shared.viewContext
```

**优点：**
- 简单，全应用一致访问
- 无需在应用中传递容器
- 与 SwiftUI environment 配合良好

**缺点：**
- 难以用不同配置进行测试
- 全局状态

### 依赖注入（更适合测试）

```swift
class DataController {
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
    }
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
}

// 使用
let dataController = DataController()
let context = dataController.viewContext

// 测试
let testController = DataController(inMemory: true)
```

**优点：**
- 更容易用内存存储进行测试
- 更灵活的配置
- 更适合单元测试

**缺点：**
- 必须在应用中传递控制器
- 更多样板代码

## 合并策略

合并策略决定了 Core Data 在保存时如何解决冲突。根据应用需求选择。

### NSMergeByPropertyStoreTrumpMergePolicy（推荐）

存储值优先于内存值。**约束功能要求使用此策略。**

```swift
viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
```

**适用场景：**
- 使用唯一约束
- 存储数据应优先
- 多个上下文可能修改相同对象

### NSMergeByPropertyObjectTrumpMergePolicy

内存值优先于存储值。

```swift
viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
```

**适用场景：**
- 用户编辑应始终优先
- 内存变更更重要

### NSOverwriteMergePolicy

内存对象完全替换存储对象。

```swift
viewContext.mergePolicy = NSOverwriteMergePolicy
```

**适用场景：**
- 你想要完全替换
- 不应发生冲突

### NSRollbackMergePolicy

丢弃内存变更，保留存储值。

```swift
viewContext.mergePolicy = NSRollbackMergePolicy
```

**适用场景：**
- 存储是数据源
- 冲突时应丢弃内存变更

### NSErrorMergePolicy（默认）

冲突时抛出错误。必须手动处理。

```swift
viewContext.mergePolicy = NSErrorMergePolicy

do {
    try context.save()
} catch let error as NSError {
    if error.code == NSManagedObjectMergeError {
        // 处理合并冲突
    }
}
```

**适用场景：**
- 需要自定义冲突解决
- 冲突应被显式处理

## 上下文配置

### View Context

view context 运行在主线程上，应用于所有 UI 操作。

```swift
let viewContext = container.viewContext
viewContext.name = "ViewContext"
viewContext.automaticallyMergesChangesFromParent = true
viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
```

**最佳实践：**
- 仅用于 UI 相关的 fetch 和更新
- 保持操作轻量
- 启用从父上下文自动合并
- 设置描述性名称以便调试

### Background Context

background context 运行在私有队列上，应用于繁重任务。

```swift
override func newBackgroundContext() -> NSManagedObjectContext {
    let context = super.newBackgroundContext()
    context.name = "BackgroundContext"
    context.transactionAuthor = "BackgroundAuthor"
    context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    context.automaticallyMergesChangesFromParent = true
    return context
}

// 使用
let context = container.newBackgroundContext()
context.perform {
    // 繁重任务
    try? context.save()
}
```

**最佳实践：**
- 用于导入、导出、批量操作
- 始终在 `perform { }` 中执行任务
- 设置 transaction author 以便持久化历史跟踪
- 启用自动合并

### 上下文命名与 Transaction Author

为上下文命名有助于调试和持久化历史跟踪。

```swift
context.name = "ImportContext"
context.transactionAuthor = "ImportAuthor"
```

**好处：**
- 在 Instruments 中识别上下文
- 过滤持久化历史事务
- 更容易调试线程问题
- 跟踪应用的哪个部分做了变更

**App Extension 示例：**

```swift
// 主应用
mainContext.transactionAuthor = "MainApp"

// Share extension
shareContext.transactionAuthor = "ShareExtension"

// 按 author 过滤事务
let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
if let historyFetch = fetchRequest as? NSPersistentHistoryChangeRequest {
    historyFetch.fetchRequest?.predicate = NSPredicate(
        format: "author != %@", "MainApp"
    )
}
```

## 理解存储加载行为

`loadPersistentStores` 方法**始终是异步的**——它使用在加载完成时调用的完成处理器。此 API 没有同步版本。

### 标准模式（推荐）

```swift
container.loadPersistentStores { description, error in
    if let error = error {
        fatalError("Failed to load store: \(error)")
    }
}
// 此处代码立即执行，在存储加载完成之前
// 但是，在典型的 setup() 方法中，应用会等待完成
```

**特点：**
- 加载完成时异步调用完成处理器
- `loadPersistentStores` 之后的代码立即执行
- 应用通常在显示 UI 前等待存储加载完成
- 最常见且推荐的模式

**适用场景：**
- 标准应用初始化
- 当你控制配置流程时
- 当你能确保存储就绪前不显示 UI 时

### 现代 async/await 模式（iOS 15+）

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

// 在 async 上下文中使用
func setupCoreData() async throws {
    let container = NSPersistentContainer(name: "Model")
    try await container.loadPersistentStores()
    // 此处保证存储已加载
}
```

**好处：**
- 更简洁的 async/await 语法
- 更好的 try/catch 错误处理
- 更容易与其他 async 操作组合
- 明确表达异步性质

**适用场景：**
- iOS 15+ 部署目标
- 现代 Swift 并发代码库
- 需要与其他 async 操作组合时

### 延迟加载模式（高级）

在少数需要应用在存储加载完成前启动的情况：

```swift
class CoreDataStack {
    let container: NSPersistentContainer
    private(set) var isStoreLoaded = false
    
    init() {
        container = NSPersistentContainer(name: "Model")
        loadStoresInBackground()
    }
    
    private func loadStoresInBackground() {
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                print("Failed to load store: \(error)")
                return
            }
            self?.isStoreLoaded = true
            NotificationCenter.default.post(name: .storeDidLoad, object: nil)
        }
    }
    
    func waitForStoreLoad() async {
        guard !isStoreLoaded else { return }
        
        await withCheckedContinuation { continuation in
            let observer = NotificationCenter.default.addObserver(
                forName: .storeDidLoad,
                object: nil,
                queue: nil
            ) { _ in
                continuation.resume()
            }
            
            // 再次检查，以防在设置 observer 时已加载完成
            if self.isStoreLoaded {
                NotificationCenter.default.removeObserver(observer)
                continuation.resume()
            }
        }
    }
}
```

**注意事项：**
- 必须在整个应用中处理"未就绪"状态
- 更复杂的错误处理
- 不小心可能出现竞态条件
- 仅在有特定需求时使用

**适用场景：**
- 非常大的数据库，加载需要较长时间
- 可以在数据可用前显示 UI 的应用
- 后台初始化场景

### 建议

**对大多数应用使用标准模式**配合完成处理器。加载时间通常可忽略（毫秒级），在显示 UI 前等待存储加载完成可提供可预测的行为并避免竞态条件。

**如果你在 iOS 15+ 且想要现代 Swift 并发模式**，使用 async/await。

**除非有特定的、可衡量的需求，否则避免延迟加载**。其复杂性和潜在 bug 通常超过任何感知到的收益。

## 存储配置选项

### 内存存储（测试）

```swift
let description = NSPersistentStoreDescription()
description.type = NSInMemoryStoreType
container.persistentStoreDescriptions = [description]
```

**用途：**
- 单元测试
- 临时数据
- 原型开发

### SQLite 存储（生产）

```swift
let description = NSPersistentStoreDescription(url: storeURL)
description.type = NSSQLiteStoreType
container.persistentStoreDescriptions = [description]
```

**用途：**
- 生产应用
- 持久化数据
- 最常见的用例

### 存储位置

```swift
// 默认位置
let storeURL = NSPersistentContainer.defaultDirectoryURL()
    .appendingPathComponent("Model.sqlite")

// 自定义位置
let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("MyApp.sqlite")

// App Group（用于 extension）
let storeURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.example.app"
)?.appendingPathComponent("Shared.sqlite")
```

## 完整示例

以下是一个生产就绪的栈配置：

```swift
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    private let containerName = "DataModel"
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: containerName)
        
        // 配置存储描述
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve store description")
        }
        
        // 启用持久化历史跟踪
        description.setOption(true as NSNumber, 
                            forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // 加载存储
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // 在生产环境中适当处理错误
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // 配置 view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        container.viewContext.name = "ViewContext"
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.name = "BackgroundContext"
        context.transactionAuthor = "BackgroundAuthor"
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask { context in
            context.name = "BackgroundTask"
            context.transactionAuthor = "BackgroundTaskAuthor"
            context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            block(context)
        }
    }
    
    private init() {}
}

// 使用
let context = CoreDataStack.shared.viewContext

// 后台任务
CoreDataStack.shared.performBackgroundTask { context in
    // 繁重任务
    try? context.save()
}
```

## SwiftUI 集成

### Environment Object 模式

```swift
import SwiftUI

@main
struct MyApp: App {
    let persistenceController = PersistentContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}

// 在视图中使用
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.name, ascending: true)],
        animation: .default)
    private var articles: FetchedResults<Article>
    
    var body: some View {
        List(articles) { article in
            Text(article.name ?? "")
        }
    }
}
```

## 常见陷阱

### ❌ 在 AppDelegate 中配置

```swift
// 不要这样做 - 难以测试和维护
class AppDelegate: UIApplicationDelegate {
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        // 大量配置代码在这里...
        return container
    }()
}
```

### ❌ 使用约束时未设置合并策略

```swift
// 这会在约束冲突时崩溃
let entity = MyEntity(context: context)
entity.uniqueField = "duplicate" // 约束冲突
try context.save() // 崩溃！
```

### ❌ 不为上下文命名

```swift
// 难以调试哪个上下文有问题
let context = container.newBackgroundContext()
// 没有名称，没有 transaction author
```

### ✅ 正确做法

```swift
class PersistentContainer: NSPersistentContainer {
    static let shared = PersistentContainer(name: "Model")
    
    override func newBackgroundContext() -> NSManagedObjectContext {
        let context = super.newBackgroundContext()
        context.name = "BackgroundContext"
        context.transactionAuthor = "BackgroundAuthor"
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
}
```

## 总结

1. **创建自定义 NSPersistentContainer 子类**以实现有序配置
2. **使用单例模式以简化**，或使用依赖注入以提高可测试性
3. **设置合并策略**为 NSMergeByPropertyStoreTrumpMergePolicy（约束功能要求）
4. **为上下文命名并设置 transaction author**以便调试和历史跟踪
5. **在所有上下文上启用 automaticallyMergesChangesFromParent**
6. **使用完成处理器（或 async 桥接）加载存储**，并在加载完成前限制访问
7. **如果使用批量操作或 App Extension，配置持久化历史跟踪**
