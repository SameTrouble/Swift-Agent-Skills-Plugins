# Schema 迁移

Schema 迁移是随着应用演进更新 Core Data 模型的过程。Core Data 提供三种迁移策略：轻量级、分阶段（iOS 17+）和延迟（iOS 14+）。

## 何时需要迁移

当模型不匹配时，Core Data 拒绝打开存储：

```
Error: NSPersistentStoreIncompatibleVersionHashError
```

**这意味着：** 你的数据模型已变更，需要迁移。

## 轻量级迁移（推荐）

轻量级迁移是自动的，能处理大多数常见变更。

### 启用轻量级迁移

使用 `NSPersistentContainer`（自动）：
```swift
let container = NSPersistentContainer(name: "Model")
// 默认启用轻量级迁移
```

使用 `NSPersistentStoreDescription`（自动）：
```swift
let description = NSPersistentStoreDescription(url: storeURL)
// 默认启用轻量级迁移
```

手动设置（如需要）：
```swift
let options = [
    NSMigratePersistentStoresAutomaticallyOption: true,
    NSInferMappingModelAutomaticallyOption: true
]
try coordinator.addPersistentStore(
    ofType: NSSQLiteStoreType,
    configurationName: nil,
    at: storeURL,
    options: options
)
```

### 支持的操作

**属性：**
- 添加属性
- 删除属性
- 将可选属性变为非可选（带默认值）
- 将非可选属性变为可选
- 重命名属性（使用重命名标识符）

**关系：**
- 添加关系
- 删除关系
- 重命名关系（使用重命名标识符）
- 更改基数（一对一 ↔ 一对多）
- 更改排序（有序 ↔ 无序）

**实体：**
- 添加实体
- 删除实体
- 重命名实体（使用重命名标识符）
- 创建父/子实体
- 在层级中上/下移动属性
- 在层级中移入/移出实体

**不能做：**
- 合并实体层级（没有共同父级的实体不能共享父级）

### 重命名属性/实体

将重命名标识符设置为**旧名称**：

```swift
// 在 Data Model Editor 中：
// 1. 将属性从 "color" 重命名为 "paintColor"
// 2. 将 Renaming Identifier 设置为 "color"
```

这允许跨版本链式重命名：
- V1：`color`
- V2：`paintColor`（重命名 ID：`color`）
- V3：`primaryColor`（重命名 ID：`paintColor`）

迁移可工作：V1→V2、V2→V3 和 V1→V3。

### 测试轻量级迁移

```swift
// 检查迁移是否可能
let sourceModel = // ... 加载 V1 模型
let destinationModel = // ... 加载 V2 模型

if let mappingModel = try? NSMappingModel.inferredMappingModel(
    forSourceModel: sourceModel,
    destinationModel: destinationModel
) {
    print("轻量级迁移可行")
} else {
    print("轻量级迁移不可行")
}
```

## 复合属性（iOS 17+）

iOS 17 新增：单个属性内的结构化数据。

### 创建复合属性

在 Data Model Editor 中：
1. 添加 Composite Attribute
2. 添加元素（String、Int、Date 等）
3. 可以嵌套复合属性

```swift
// 示例：ColorScheme 复合属性
// - primary: String
// - secondary: String
// - tertiary: String

class Aircraft: NSManagedObject {
    @NSManaged var colorScheme: [String: Any]
}

// 使用
aircraft.colorScheme = [
    "primary": "Red",
    "secondary": "White",
    "tertiary": "Blue"
]

// 查询
fetchRequest.predicate = NSPredicate(format: "colorScheme.primary == %@", "Red")
```

### 好处

- 无需 transformable 代码
- 支持带 keypath 的谓词
- 比扁平化属性更好
- 可以防止跨关系触发 fault

## 分阶段迁移（iOS 17+）

用于超出轻量级能力的复杂迁移。

### 何时使用

- 变更不符合轻量级模式
- 需要在迁移期间运行自定义代码
- 需要将复杂变更分解为步骤

### 关键类

- `NSStagedMigrationManager` - 管理迁移事件循环
- `NSCustomMigrationStage` - 自定义代码执行
- `NSLightweightMigrationStage` - 符合轻量级条件的变更
- `NSManagedObjectModelReference` - 带校验和的模型引用

### 示例：数据反范式化

**问题：** 将 `flightData` 属性移到单独实体。

**解决方案：** 分解为阶段：

**阶段 1（轻量级）：** 添加新实体和关系
```swift
// ModelV1 → ModelV2
// 添加 FlightData 实体
// 添加 flightParameters 关系到 Aircraft
```

**阶段 2（自定义）：** 复制数据
- 使用通用的 `NSManagedObject` / `NSFetchRequestResult` 类型获取行。
- 在迁移阶段处理器内创建新实体并复制数据。
- 确保自定义逻辑在进程中断时可重启。

**阶段 3（轻量级）：** 删除旧属性
```swift
// ModelV3 → ModelV4
// 从 Aircraft 删除 flightData 属性
```

### 获取版本校验和

从 Xcode 构建日志：
```
Compile data model Model.xcdatamodeld
version checksum: ABC123...
```

## 延迟迁移（iOS 14+）

延迟清理工作以保持应用响应性。

### 何时使用

- 删除属性/关系
- 更改关系层级
- 更改关系排序
- 任何有昂贵清理的迁移

### 工作原理

1. 迁移同步运行（快速）
2. 清理（索引、列删除）被延迟
3. 应用立即使用最新 schema
4. 资源可用时完成清理

### 启用延迟迁移

```swift
let description = NSPersistentStoreDescription(url: storeURL)
description.setOption(
    true as NSNumber,
    forKey: NSPersistentStoreDeferredLightweightMigrationOptionKey
)
```

### 检查待处理工作

```swift
let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
    ofType: NSSQLiteStoreType,
    at: storeURL
)

if let hasDeferredWork = metadata[NSPersistentStoreDeferredLightweightMigrationOptionKey] as? Bool,
   hasDeferredWork {
    print("有待处理的延迟迁移工作")
}
```

### 完成延迟迁移

```swift
func finishDeferredMigration() {
    let coordinator = container.persistentStoreCoordinator
    
    do {
        try coordinator.finishDeferredLightweightMigration()
        print("延迟迁移完成")
    } catch {
        print("完成延迟迁移失败: \(error)")
    }
}
```

### 使用后台任务调度

```swift
import BackgroundTasks

// 注册任务
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.example.app.migration",
    using: nil
) { task in
    self.handleMigrationTask(task as! BGProcessingTask)
}

// 调度任务
func scheduleMigration() {
    let request = BGProcessingTaskRequest(identifier: "com.example.app.migration")
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false
    
    try? BGTaskScheduler.shared.submit(request)
}

// 处理任务
func handleMigrationTask(_ task: BGProcessingTask) {
    task.expirationHandler = {
        task.setTaskCompleted(success: false)
    }
    
    finishDeferredMigration()
    task.setTaskCompleted(success: true)
}
```

## 迁移调试

### 启用迁移调试

```
-com.apple.CoreData.MigrationDebug 1
```

**输出：**
```
CoreData: annotation: Migration: Migrating from version 1 to version 2
CoreData: annotation: Migration: Inferred mapping model
CoreData: annotation: Migration: Completed successfully
```

### 常见错误

**NSPersistentStoreIncompatibleVersionHashError**
- 模型已变更，需要迁移
- 启用轻量级迁移或创建映射模型

**NSMigrationMissingSourceModelError**
- 找不到源模型
- 确保所有模型版本都在 bundle 中

**NSMigrationError**
- 迁移失败
- 检查变更是否兼容轻量级
- 复杂变更使用分阶段迁移

## 最佳实践

1. **彻底测试迁移** - 测试从所有先前版本的升级路径
2. **保留模型版本** - 不要删除旧的 .xcdatamodel 文件
3. **尽可能使用轻量级** - 最简单且最可靠
4. **分解复杂变更** - 非轻量级变更使用分阶段迁移
5. **延迟昂贵清理** - 大数据集使用延迟迁移
6. **版本化你的模型** - 每次发布创建新模型版本
7. **在真实数据上测试** - 大数据集的迁移行为不同
8. **记录变更** - 保留迁移笔记以供将来参考

## 测试迁移

```swift
func testMigration() throws {
    // 1. 用旧模型创建存储
    let oldModelURL = Bundle.main.url(forResource: "ModelV1", withExtension: "momd")!
    let oldModel = NSManagedObjectModel(contentsOf: oldModelURL)!
    
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
    try coordinator.addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: storeURL,
        options: nil
    )
    
    // 2. 添加测试数据
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    
    let entity = NSEntityDescription.insertNewObject(forEntityName: "Article", into: context)
    entity.setValue("Test", forKey: "name")
    try context.save()
    
    // 3. 关闭存储
    try coordinator.remove(coordinator.persistentStores.first!)
    
    // 4. 用新模型迁移
    let newModelURL = Bundle.main.url(forResource: "ModelV2", withExtension: "momd")!
    let newModel = NSManagedObjectModel(contentsOf: newModelURL)!
    
    let newCoordinator = NSPersistentStoreCoordinator(managedObjectModel: newModel)
    let options = [
        NSMigratePersistentStoresAutomaticallyOption: true,
        NSInferMappingModelAutomaticallyOption: true
    ]
    try newCoordinator.addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: storeURL,
        options: options
    )
    
    // 5. 验证数据
    let newContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    newContext.persistentStoreCoordinator = newCoordinator
    
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Article")
    let results = try newContext.fetch(fetchRequest)
    
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Test")
}
```

## 总结

1. **使用轻量级迁移** - 自动处理大多数常见变更
2. **默认启用** - NSPersistentContainer 自动启用
3. **使用重命名标识符** - 用于重命名属性/实体/关系
4. **使用复合属性（iOS 17+）** - 用于结构化数据
5. **使用分阶段迁移（iOS 17+）** - 用于复杂的非轻量级变更
6. **使用延迟迁移（iOS 14+）** - 用于昂贵的清理操作
7. **彻底测试** - 验证所有升级路径
8. **保留所有模型版本** - 迁移所需
9. **启用迁移调试** - 帮助诊断问题
10. **记录变更** - 跟踪每个版本的变更内容
