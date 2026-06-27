# Core Data 中的保存

高效保存数据对应用性能和用户体验至关重要。本指南涵盖何时、如何以及在何处保存 Core Data 变更的最佳实践。

## 总是保存的问题

无条件调用 `save()` 有性能成本：

```swift
// ❌ 错误：即使没有变更也总是保存
func updateUI() {
    article.lastViewed = Date()
    try? context.save() // 即使没有变更也很耗时！
}
```

**问题：**
- 即使没有变更也写入磁盘
- 不必要地触发合并通知
- 浪费 CPU 和电池
- 拖慢应用

## 使用 hasChanges 的条件保存

第一个改进是检查 `hasChanges`：

```swift
// ✅ 更好：仅在有变更时保存
if context.hasChanges {
    try context.save()
}
```

**好处：**
- 避免不必要的磁盘写入
- 更快的性能
- 仍然简单易用

**局限：**
- `hasChanges` 对临时属性也返回 `true`
- 临时变更不需要持久化

## 最佳实践：hasPersistentChanges

仅检查**持久化**变更，排除临时属性：

```swift
extension NSManagedObjectContext {
    var hasPersistentChanges: Bool {
        return !insertedObjects.isEmpty || 
               !deletedObjects.isEmpty || 
               updatedObjects.contains(where: { $0.hasPersistentChangedValues })
    }
    
    func saveIfNeeded() throws {
        guard hasPersistentChanges else { return }
        try save()
    }
}

// 使用
try context.saveIfNeeded()
```

**为什么这更好：**
- 排除临时属性变更
- 仅在数据确实需要持久化时保存
- 最高效的方法

### 理解 hasPersistentChangedValues

```swift
extension NSManagedObject {
    var hasPersistentChangedValues: Bool {
        return !changedValues().isEmpty
    }
}
```

这检查对象是否有**任何**变更值。如需更精细的控制：

```swift
extension NSManagedObject {
    var hasPersistentChangedValues: Bool {
        let changedKeys = Set(changedValues().keys)
        let persistentKeys = Set(entity.attributesByName.keys)
            .union(entity.relationshipsByName.keys)
            .subtracting(entity.transientAttributeNames)
        return !changedKeys.intersection(persistentKeys).isEmpty
    }
}

extension NSEntityDescription {
    var transientAttributeNames: Set<String> {
        return Set(attributesByName.filter { $0.value.isTransient }.map { $0.key })
    }
}
```

## 何时保存

### 在应用生命周期事件时保存

```swift
// AppDelegate 或 SceneDelegate
func applicationWillTerminate(_ application: UIApplication) {
    try? CoreDataStack.shared.viewContext.saveIfNeeded()
}

func sceneDidEnterBackground(_ scene: UIScene) {
    try? CoreDataStack.shared.viewContext.saveIfNeeded()
}
```

### 在用户操作后保存

```swift
// 用户完成操作后
@IBAction func saveButtonTapped(_ sender: UIButton) {
    article.name = nameTextField.text
    article.content = contentTextView.text
    
    do {
        try context.saveIfNeeded()
        dismiss(animated: true)
    } catch {
        // 处理错误
        showError(error)
    }
}
```

### 长时间运行的操作定期保存

```swift
func importLargeDataset() {
    let context = container.newBackgroundContext()
    context.perform {
        for (index, data) in largeDataset.enumerated() {
            let article = Article(context: context)
            article.name = data.name
            
            // 每 100 个对象保存一次
            if index % 100 == 0 {
                try? context.saveIfNeeded()
            }
        }
        
        // 最终保存
        try? context.saveIfNeeded()
    }
}
```

### 不要太频繁保存

```swift
// ❌ 错误：每次按键都保存
func textFieldDidChange(_ textField: UITextField) {
    article.name = textField.text
    try? context.save() // 太频繁！
}

// ✅ 更好：编辑结束时保存
func textFieldDidEndEditing(_ textField: UITextField) {
    article.name = textField.text
    try? context.saveIfNeeded()
}

// ✅ 最佳：使用防抖进行自动保存
private var saveWorkItem: DispatchWorkItem?

func textFieldDidChange(_ textField: UITextField) {
    article.name = textField.text
    
    // 取消之前的保存
    saveWorkItem?.cancel()
    
    // 在 2 秒无操作后调度新保存
    let workItem = DispatchWorkItem { [weak self] in
        try? self?.context.saveIfNeeded()
    }
    saveWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
}
```

## 错误处理

### 基本错误处理

```swift
do {
    try context.save()
} catch {
    print("保存失败: \(error)")
}
```

### 详细错误处理

```swift
do {
    try context.save()
} catch let error as NSError {
    print("保存上下文失败: \(error)")
    print("用户信息: \(error.userInfo)")
    
    // 检查特定错误
    if error.domain == NSCocoaErrorDomain {
        switch error.code {
        case NSValidationStringTooShortError:
            print("字符串太短")
        case NSValidationStringTooLongError:
            print("字符串太长")
        case NSManagedObjectValidationError:
            print("验证错误")
        case NSManagedObjectConstraintValidationError:
            print("约束冲突")
        default:
            print("其他错误: \(error.code)")
        }
    }
}
```

### 用户友好的错误消息

```swift
extension NSError {
    var userFriendlyMessage: String {
        guard domain == NSCocoaErrorDomain else {
            return localizedDescription
        }
        
        switch code {
        case NSValidationStringTooShortError:
            return "文本太短。请至少输入 3 个字符。"
        case NSValidationStringTooLongError:
            return "文本太长。请保持在 100 个字符以内。"
        case NSManagedObjectConstraintValidationError:
            return "此项已存在。请使用不同的名称。"
        case NSManagedObjectValidationError:
            return "请检查您的输入并重试。"
        default:
            return "保存失败: \(localizedDescription)"
        }
    }
}

// 使用
do {
    try context.save()
} catch let error as NSError {
    showAlert(message: error.userFriendlyMessage)
}
```

## 在不同上下文中保存

### View Context（主线程）

```swift
// 始终在主线程
let context = container.viewContext

// 简单保存
try? context.saveIfNeeded()

// 带错误处理
do {
    try context.saveIfNeeded()
} catch {
    print("保存失败: \(error)")
}
```

### Background Context

```swift
let context = container.newBackgroundContext()
context.perform {
    // 进行变更
    let article = Article(context: context)
    article.name = "New Article"
    
    // 在 perform 块内保存
    do {
        try context.saveIfNeeded()
    } catch {
        print("保存失败: \(error)")
    }
}
```

### 嵌套上下文（高级）

```swift
// 父上下文（view context）
let parentContext = container.viewContext

// 用于编辑的子上下文
let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
childContext.parent = parentContext

// 在子上下文中进行变更
let article = childContext.object(with: articleID) as! Article
article.name = "Updated"

// 保存子上下文（推送到父上下文，不写入磁盘）
try? childContext.save()

// 保存父上下文以持久化到磁盘
try? parentContext.save()
```

**使用嵌套上下文用于：**
- 可取消的编辑（丢弃子上下文而不保存父上下文）
- 临时变更
- 复杂表单

## 带验证的保存

Core Data 在保存前验证对象。适当处理验证错误：

```swift
do {
    try context.save()
} catch let error as NSError {
    if error.code == NSValidationMultipleErrorsError {
        // 多个验证错误
        if let errors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for validationError in errors {
                print("验证错误: \(validationError.localizedDescription)")
                
                // 获取验证失败的对象
                if let object = validationError.userInfo[NSValidationObjectErrorKey] as? NSManagedObject {
                    print("失败对象: \(object)")
                }
                
                // 获取失败的属性
                if let key = validationError.userInfo[NSValidationKeyErrorKey] as? String {
                    print("失败属性: \(key)")
                }
            }
        }
    }
}
```

## 优化保存性能

### 导入时批量保存

```swift
func importArticles(_ articles: [ArticleData]) {
    let context = container.newBackgroundContext()
    context.perform {
        for (index, data) in articles.enumerated() {
            let article = Article(context: context)
            article.name = data.name
            article.content = data.content
            
            // 每 100 个对象保存一次以避免内存堆积
            if index % 100 == 0 && context.hasChanges {
                try? context.save()
                context.reset() // 清除内存
            }
        }
        
        // 最终保存
        try? context.save()
    }
}
```

### 避免在循环中保存

```swift
// ❌ 错误：在循环内保存
for data in dataArray {
    let article = Article(context: context)
    article.name = data.name
    try? context.save() // 非常慢！
}

// ✅ 正确：循环结束后保存一次
for data in dataArray {
    let article = Article(context: context)
    article.name = data.name
}
try? context.save() // 快得多！
```

### 对批量变更使用批量操作

对于大规模操作，使用批量请求而非保存单个对象：

```swift
// 替代：
for article in articles {
    article.isRead = true
}
try? context.save()

// 使用批量更新：
let batchUpdate = NSBatchUpdateRequest(entityName: "Article")
batchUpdate.predicate = NSPredicate(format: "isRead == NO")
batchUpdate.propertiesToUpdate = ["isRead": true]
try? context.execute(batchUpdate)
```

详见 `batch-operations.md`。

## 检查未保存的变更

### 关闭视图前

```swift
func dismiss() {
    if context.hasChanges {
        let alert = UIAlertController(
            title: "未保存的变更",
            message: "是否要保存您的变更？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            try? self.context.save()
            self.dismissView()
        })
        
        alert.addAction(UIAlertAction(title: "丢弃", style: .destructive) { _ in
            self.context.rollback()
            self.dismissView()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    } else {
        dismissView()
    }
}
```

### 回滚未保存的变更

```swift
// 丢弃所有未保存的变更
context.rollback()

// 刷新特定对象以丢弃其变更
context.refresh(article, mergeChanges: false)
```

## 保存通知

观察保存通知以响应变更：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(contextDidSave),
    name: .NSManagedObjectContextDidSave,
    object: context
)

@objc func contextDidSave(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    
    if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
        print("插入: \(inserts.count) 个对象")
    }
    
    if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
        print("更新: \(updates.count) 个对象")
    }
    
    if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
        print("删除: \(deletes.count) 个对象")
    }
}
```

## 测试保存

### 在单元测试中

```swift
func testSaveArticle() throws {
    let context = testContainer.viewContext
    
    let article = Article(context: context)
    article.name = "Test Article"
    
    XCTAssertTrue(context.hasChanges)
    
    try context.save()
    
    XCTAssertFalse(context.hasChanges)
    
    // 验证已保存
    let fetchRequest = Article.fetchRequest()
    let results = try context.fetch(fetchRequest)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.name, "Test Article")
}
```

## 常见陷阱

### ❌ 不检查变更

```swift
// 浪费资源
try? context.save()
```

### ❌ 太频繁保存

```swift
// 在循环中 - 非常慢
for item in items {
    item.processed = true
    try? context.save()
}
```

### ❌ 忽略错误

```swift
// 静默失败
try? context.save()
```

### ❌ 在错误线程保存

```swift
// 崩溃！background context 在主线程
let context = container.newBackgroundContext()
try? context.save() // 不在 perform 块中！
```

### ✅ 正确做法

```swift
// 检查变更
guard context.hasPersistentChanges else { return }

// 处理错误
do {
    try context.save()
} catch {
    print("保存失败: \(error)")
    // 适当处理
}

// 使用正确的线程
context.perform {
    try? context.save()
}
```

## 总结

1. **使用 `saveIfNeeded()` 配合 `hasPersistentChanges`** - 最高效的方法
2. **在适当时机保存** - 应用生命周期事件、用户操作后、定期
3. **不要太频繁保存** - 对自动保存使用防抖，避免在循环中保存
4. **正确处理错误** - 不要忽略保存失败
5. **使用正确的上下文类型** - UI 用 view context，繁重任务用 background
6. **始终在 background context 中使用 `perform`** - 线程安全
7. **考虑批量操作** - 用于大规模更新
8. **测试你的保存** - 验证数据正确持久化
