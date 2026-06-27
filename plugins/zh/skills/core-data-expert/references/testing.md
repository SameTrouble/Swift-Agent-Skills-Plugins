# 测试 Core Data

测试 Core Data 需要特殊设置以避免冲突并确保快速、可靠的测试。

## 内存存储

使用内存存储进行快速、隔离的测试：

```swift
class CoreDataTestCase: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        container = NSPersistentContainer(name: "Model", managedObjectModel: Self.sharedModel)
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
    }
    
    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }
}
```

## 共享模型模式

**问题：** 多个模型实例导致实体描述冲突。

**错误：**
```
Failed to find a unique match for an NSEntityDescription
```

**解决方案：** 使用共享模型实例：

```swift
extension NSManagedObjectModel {
    static let shared: NSManagedObjectModel = {
        guard let modelURL = Bundle.main.url(forResource: "Model", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load model")
        }
        return model
    }()
}

// 在测试中使用
container = NSPersistentContainer(name: "Model", managedObjectModel: .shared)
```

## 数据生成器

创建可重现的测试数据：

```swift
class TestDataGenerator {
    static func createArticle(
        name: String = "Test Article",
        views: Int = 0,
        in context: NSManagedObjectContext
    ) -> Article {
        let article = Article(context: context)
        article.name = name
        article.views = Int64(views)
        article.creationDate = Date()
        return article
    }
    
    static func createArticles(
        count: Int,
        in context: NSManagedObjectContext
    ) -> [Article] {
        return (0..<count).map { i in
            createArticle(name: "Article \(i)", in: context)
        }
    }
}

// 使用
func testFetchArticles() throws {
    let articles = TestDataGenerator.createArticles(count: 10, in: context)
    try context.save()
    
    let fetchRequest = Article.fetchRequest()
    let results = try context.fetch(fetchRequest)
    
    XCTAssertEqual(results.count, 10)
}
```

## 测试 Fetch Request

```swift
func testFetchWithPredicate() throws {
    // 设置
    TestDataGenerator.createArticle(name: "Swift", views: 100, in: context)
    TestDataGenerator.createArticle(name: "iOS", views: 50, in: context)
    try context.save()
    
    // 测试
    let fetchRequest = Article.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "views > %d", 75)
    
    let results = try context.fetch(fetchRequest)
    
    // 验证
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.name, "Swift")
}
```

## 测试保存

```swift
func testSaveArticle() throws {
    let article = TestDataGenerator.createArticle(in: context)
    
    XCTAssertTrue(context.hasChanges)
    
    try context.save()
    
    XCTAssertFalse(context.hasChanges)
    
    // 验证持久化
    let fetchRequest = Article.fetchRequest()
    let results = try context.fetch(fetchRequest)
    
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.name, "Test Article")
}
```

## 测试验证

```swift
func testValidation() {
    let article = Article(context: context)
    article.name = "" // 无效
    
    XCTAssertThrowsError(try context.save()) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
    }
}
```

## 测试关系

```swift
func testArticleCategoryRelationship() throws {
    let category = Category(context: context)
    category.name = "Swift"
    
    let article = Article(context: context)
    article.name = "Test"
    article.category = category
    
    try context.save()
    
    XCTAssertEqual(article.category?.name, "Swift")
    XCTAssertTrue(category.articles?.contains(article) ?? false)
}
```

## 测试线程

```swift
func testBackgroundContext() {
    let expectation = XCTestExpectation(description: "后台保存")
    
    let backgroundContext = container.newBackgroundContext()
    backgroundContext.perform {
        let article = Article(context: backgroundContext)
        article.name = "Background Article"
        
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

## 测试 CloudKit 同步

```swift
func testCloudKitExport() {
    let expectation = XCTestExpectation(description: "导出")
    
    let observer = NotificationCenter.default.addObserver(
        forName: NSPersistentCloudKitContainer.eventChangedNotification,
        object: container,
        queue: nil
    ) { notification in
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return
        }
        
        if event.type == .export && event.endDate != nil {
            expectation.fulfill()
        }
    }
    
    let article = Article(context: context)
    article.name = "Test"
    try? context.save()
    
    wait(for: [expectation], timeout: 60)
    NotificationCenter.default.removeObserver(observer)
}
```

## 性能测试

```swift
func testBatchInsertPerformance() {
    measure {
        let context = container.newBackgroundContext()
        context.performAndWait {
            var index = 0
            let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
                guard index < 1000 else { return true }
                guard let article = object as? Article else { return true }
                article.name = "Article \(index)"
                index += 1
                return false
            }
            try? context.execute(batchInsert)
        }
    }
}
```

## 测试工具

```swift
extension XCTestCase {
    func createTestContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: "Model",
            managedObjectModel: .shared
        )
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        let expectation = self.expectation(description: "加载存储")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        return container
    }
}
```

## 最佳实践

1. **使用内存存储** - 快速、隔离的测试
2. **使用共享模型** - 避免实体描述冲突
3. **创建数据生成器** - 可重现的测试数据
4. **在 background context 上测试** - 验证线程
5. **使用 expectation** - 用于异步操作
6. **测量性能** - 使用 `measure` 块
7. **清理** - 测试间重置上下文
8. **测试验证** - 验证业务规则
9. **测试关系** - 确保完整性
10. **测试迁移** - 验证升级路径

## 总结

- 使用内存存储进行快速测试
- 共享模型实例以避免冲突
- 创建数据生成器用于可重现测试
- 测试 fetch request、保存、验证和关系
- 异步操作使用 expectation
- 使用 `measure` 块测量性能
- 使用 background context 测试线程
- 使用事件通知测试 CloudKit 同步
