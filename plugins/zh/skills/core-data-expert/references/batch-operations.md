# 批量操作

批量操作为大规模数据修改提供显著的性能提升。它们直接在 SQL 层级操作，绕过对象图。

## 概述

Core Data 提供三种批量操作类型：
- **NSBatchInsertRequest** - 批量插入（iOS 14+）
- **NSBatchDeleteRequest** - 批量删除
- **NSBatchUpdateRequest** - 批量更新

**关键特性：**
- 在 SQL 层级操作（非常快）
- 不将对象加载到内存
- 不触发验证
- 不发送变更通知（需要持久化历史跟踪）
- 批量插入时不能设置关系

## NSBatchInsertRequest（iOS 14+）

### 基本用法

```swift
let context = container.newBackgroundContext()

context.perform {
    let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { (object: NSManagedObject) -> Bool in
        guard let article = object as? Article else { return true }
        
        article.name = "Sample Article"
        article.content = "Content here"
        article.creationDate = Date()
        
        return false // 继续插入
    }
    
    do {
        try context.execute(batchInsert)
    } catch {
        print("批量插入失败: \(error)")
    }
}
```

### 插入多个对象

```swift
func batchInsertArticles(_ data: [ArticleData]) {
    let context = container.newBackgroundContext()
    
    context.perform {
        var index = 0
        let batchInsert = NSBatchInsertRequest(
            entity: Article.entity()
        ) { (object: NSManagedObject) -> Bool in
            guard index < data.count else { return true } // 停止
            guard let article = object as? Article else { return true }
            
            let articleData = data[index]
            article.name = articleData.name
            article.content = articleData.content
            article.creationDate = Date()
            
            index += 1
            return false // 继续
        }
        
        do {
            try context.execute(batchInsert)
        } catch {
            print("批量插入失败: \(error)")
        }
    }
}
```

### 使用字典表示（替代方式）

```swift
let context = container.newBackgroundContext()

context.perform {
    let objects: [[String: Any]] = [
        ["name": "Article 1", "content": "Content 1", "creationDate": Date()],
        ["name": "Article 2", "content": "Content 2", "creationDate": Date()],
        ["name": "Article 3", "content": "Content 3", "creationDate": Date()]
    ]
    
    let batchInsert = NSBatchInsertRequest(
        entity: Article.entity(),
        objects: objects
    )
    
    do {
        try context.execute(batchInsert)
    } catch {
        print("批量插入失败: \(error)")
    }
}
```

### 局限性

**不能设置关系：**
```swift
// ❌ 这不起作用
let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
    guard let article = object as? Article else { return true }
    article.category = someCategory // 不能设置关系！
    return false
}
```

**变通方案：** 在批量插入后设置关系：
```swift
// 1. 批量插入 article
let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
    guard let article = object as? Article else { return true }
    article.name = "Article"
    return false
}
try context.execute(batchInsert)

// 2. 获取并设置关系
let fetchRequest = Article.fetchRequest()
let articles = try context.fetch(fetchRequest)
for article in articles {
    article.category = defaultCategory
}
try context.save()
```

## NSBatchDeleteRequest

### 基本用法

```swift
let context = container.newBackgroundContext()

context.perform {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
    let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    
    do {
        try context.execute(batchDelete)
    } catch {
        print("批量删除失败: \(error)")
    }
}
```

### 带谓词

```swift
let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "views < %d", 10)

let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)

context.perform {
    do {
        try context.execute(batchDelete)
    } catch {
        print("批量删除失败: \(error)")
    }
}
```

### 获取已删除的对象 ID

```swift
let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
batchDelete.resultType = .resultTypeObjectIDs

context.perform {
    do {
        let result = try context.execute(batchDelete) as? NSBatchDeleteResult
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            print("删除了 \(objectIDs.count) 个对象")
        }
    } catch {
        print("批量删除失败: \(error)")
    }
}
```

## NSBatchUpdateRequest

### 基本用法

```swift
let context = container.newBackgroundContext()

context.perform {
    let batchUpdate = NSBatchUpdateRequest(entityName: "Article")
    batchUpdate.predicate = NSPredicate(format: "isRead == NO")
    batchUpdate.propertiesToUpdate = ["isRead": true]
    
    do {
        try context.execute(batchUpdate)
    } catch {
        print("批量更新失败: \(error)")
    }
}
```

### 更新多个属性

```swift
let batchUpdate = NSBatchUpdateRequest(entityName: "Article")
batchUpdate.predicate = NSPredicate(format: "views < %d", 100)
batchUpdate.propertiesToUpdate = [
    "views": 100,
    "lastModified": Date(),
    "isPopular": true
]

context.perform {
    try? context.execute(batchUpdate)
}
```

### 使用表达式

```swift
// 浏览量加 1
let batchUpdate = NSBatchUpdateRequest(entityName: "Article")
batchUpdate.propertiesToUpdate = [
    "views": NSExpression(format: "views + 1")
]

context.perform {
    try? context.execute(batchUpdate)
}
```

### 获取已更新的对象 ID

```swift
let batchUpdate = NSBatchUpdateRequest(entityName: "Article")
batchUpdate.propertiesToUpdate = ["isRead": true]
batchUpdate.resultType = .updatedObjectIDsResultType

context.perform {
    do {
        let result = try context.execute(batchUpdate) as? NSBatchUpdateResult
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            print("更新了 \(objectIDs.count) 个对象")
        }
    } catch {
        print("批量更新失败: \(error)")
    }
}
```

## 持久化历史跟踪集成

**关键：** 批量操作不发送变更通知。你**必须**启用持久化历史跟踪以实现 UI 更新。

### 启用持久化历史跟踪

```swift
guard let description = container.persistentStoreDescriptions.first else { return }

description.setOption(true as NSNumber, 
                     forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber,
                     forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
```

### 观察远程变更

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(storeRemoteChange),
    name: .NSPersistentStoreRemoteChange,
    object: container.persistentStoreCoordinator
)

@objc func storeRemoteChange(_ notification: Notification) {
    // 将变更合并到 view context
    // 完整实现见 persistent-history.md
}
```

## 性能对比

### 传统插入（慢）

```swift
// 插入 1000 个对象：约 10 秒
for i in 0..<1000 {
    let article = Article(context: context)
    article.name = "Article \(i)"
}
try context.save()
```

### 批量插入（快）

```swift
// 插入 1000 个对象：约 0.5 秒
var index = 0
let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
    guard index < 1000 else { return true }
    guard let article = object as? Article else { return true }
    article.name = "Article \(index)"
    index += 1
    return false
}
try context.execute(batchInsert)
```

**性能提升：约快 20 倍**

## 何时使用批量操作

### 使用批量插入当：
- 导入大型数据集（>100 个对象）
- 初始数据种子
- 从服务器同步数据
- 性能至关重要

### 使用批量删除当：
- 一次删除多个对象
- 清除旧数据
- 实施数据保留策略
- 性能至关重要

### 使用批量更新当：
- 用相同值更新多个对象
- 批量状态变更
- 递增计数器
- 性能至关重要

### 不要使用批量操作当：
- 需要设置关系
- 需要验证
- 需要触发生命周期事件（willSave 等）
- 处理小数据集（<50 个对象）
- 需要没有持久化历史跟踪的即时 UI 更新

## 完整示例：使用批量插入导入

```swift
class DataImporter {
    let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    func importArticles(_ data: [ArticleData]) {
        let context = container.newBackgroundContext()
        
        context.perform {
            var index = 0
            let batchInsert = NSBatchInsertRequest(
                entity: Article.entity()
            ) { (object: NSManagedObject) -> Bool in
                guard index < data.count else { return true }
                guard let article = object as? Article else { return true }
                
                let articleData = data[index]
                article.name = articleData.name
                article.content = articleData.content
                article.views = 0
                article.creationDate = Date()
                
                index += 1
                return false
            }
            
            do {
                let result = try context.execute(batchInsert) as? NSBatchInsertResult
                print("插入了 \(data.count) 篇文章")
                
                // 如果需要对象 ID
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    print("对象 ID: \(objectIDs)")
                }
            } catch {
                print("批量插入失败: \(error)")
            }
        }
    }
}
```

## 完整示例：使用批量删除清理

```swift
class DataCleaner {
    let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    func deleteOldArticles(olderThan days: Int) {
        let context = container.newBackgroundContext()
        
        context.perform {
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -days,
                to: Date()
            )!
            
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "creationDate < %@",
                cutoffDate as NSDate
            )
            
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeCount
            
            do {
                let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                if let count = result?.result as? Int {
                    print("删除了 \(count) 篇旧文章")
                }
            } catch {
                print("批量删除失败: \(error)")
            }
        }
    }
}
```

## 常见陷阱

### ❌ 未启用持久化历史跟踪

```swift
// 批量插入执行
let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { ... }
try context.execute(batchInsert)

// UI 不更新！没有发送通知
```

### ❌ 尝试设置关系

```swift
let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
    guard let article = object as? Article else { return true }
    article.category = category // 不起作用！
    return false
}
```

### ❌ 期望验证

```swift
// 没有验证发生！
let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
    guard let article = object as? Article else { return true }
    article.name = "" // 空名称 - 无验证错误
    return false
}
```

### ❌ 在 View Context 上使用

```swift
// 不要在 view context 上使用批量操作
viewContext.perform {
    let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { ... }
    try? viewContext.execute(batchInsert) // 阻塞 UI！
}
```

### ✅ 正确做法

```swift
// 1. 启用持久化历史跟踪
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

// 2. 使用 background context
let context = container.newBackgroundContext()

// 3. 执行批量操作
context.perform {
    let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
        guard let article = object as? Article else { return true }
        article.name = "Valid Name"
        return false
    }
    try? context.execute(batchInsert)
}

// 4. 通过持久化历史跟踪更新 UI
```

## 测试批量操作

```swift
func testBatchInsert() throws {
    let context = container.newBackgroundContext()
    
    let expectation = XCTestExpectation(description: "批量插入")
    
    context.perform {
        var count = 0
        let batchInsert = NSBatchInsertRequest(entity: Article.entity()) { object in
            guard count < 10 else { return true }
            guard let article = object as? Article else { return true }
            article.name = "Article \(count)"
            count += 1
            return false
        }
        
        do {
            try context.execute(batchInsert)
            expectation.fulfill()
        } catch {
            XCTFail("批量插入失败: \(error)")
        }
    }
    
    wait(for: [expectation], timeout: 5.0)
    
    // 验证
    let fetchRequest = Article.fetchRequest()
    let articles = try context.fetch(fetchRequest)
    XCTAssertEqual(articles.count, 10)
}
```

## 总结

1. **对大型数据集使用批量操作** - 10-20 倍性能提升
2. **启用持久化历史跟踪** - UI 更新必需
3. **使用 background context** - 不要阻塞 UI
4. **批量插入不能设置关系** - 如需要则单独设置
5. **无验证或生命周期事件** - 批量操作绕过对象图
6. **获取结果类型** - 使用 resultType 获取对象 ID 或计数
7. **彻底测试** - 验证批量操作后的数据完整性
8. **考虑权衡** - 速度 vs 验证/关系/生命周期事件
