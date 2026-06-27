# 性能优化

优化 Core Data 性能需要理解瓶颈所在并应用有针对性的解决方案。

## 使用 Instruments 分析

### Time Profiler

1. 在 Xcode 中：Product → Profile
2. 选择 Time Profiler
3. 在使用应用时录制
4. 查找最重的堆栈跟踪

**查找：**
- 过多的 fault
- 慢的 fetch request
- 耗时过长的保存操作

### Allocations Instrument

1. Product → Profile
2. 选择 Allocations
3. 监控内存增长
4. 识别 retained 对象

**查找：**
- 无限内存增长
- 未被释放的对象
- 大内存分配

## SQL 调试日志

启用 SQL 日志：
```
-com.apple.CoreData.SQLDebug 1
```

**输出：**
```sql
CoreData: sql: SELECT Z_PK, ZNAME FROM ZARTICLE WHERE ZVIEWS > ? LIMIT 20
CoreData: annotation: sql execution time: 0.0023s
```

**分析：**
- 查询复杂度
- 执行时间
- 查询数量（N+1 问题）

## 常见性能问题

### 1. N+1 查询问题

**问题：**
```swift
// 获取文章
let articles = try context.fetch(Article.fetchRequest())

// 每次访问都触发 fault（N 次查询）
for article in articles {
    print(article.category?.name) // Fault！
}
```

**解决方案：**
```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.relationshipKeyPathsForPrefetching = ["category"]
let articles = try context.fetch(fetchRequest)

// 不触发 fault
for article in articles {
    print(article.category?.name) // 已加载
}
```

### 2. 获取过多数据

**问题：**
```swift
// 获取所有对象的所有属性
let articles = try context.fetch(Article.fetchRequest())
let count = articles.count
```

**解决方案：**
```swift
// 只计数，不获取对象
let count = try context.count(for: Article.fetchRequest())
```

### 3. 不使用批量大小

**问题：**
```swift
// 将 10,000 个对象加载到内存
let fetchRequest = Article.fetchRequest()
let articles = try context.fetch(fetchRequest)
```

**解决方案：**
```swift
fetchRequest.fetchBatchSize = 20
// 一次只加载 20 个
```

### 4. 获取不必要的属性

**问题：**
```swift
// 获取所有属性
let fetchRequest = Article.fetchRequest()
```

**解决方案：**
```swift
fetchRequest.propertiesToFetch = ["name", "creationDate"]
// 只获取需要的属性
```

### 5. 太频繁保存

**问题：**
```swift
for item in items {
    item.processed = true
    try? context.save() // 非常慢！
}
```

**解决方案：**
```swift
for item in items {
    item.processed = true
}
try? context.save() // 只保存一次
```

### 6. 不重置上下文

**问题：**
```swift
// 上下文积累对象
for i in 0..<10000 {
    let article = Article(context: context)
    // 内存无限增长
}
```

**解决方案：**
```swift
for i in 0..<10000 {
    let article = Article(context: context)
    
    if i % 100 == 0 {
        try? context.save()
        context.reset() // 清除内存
    }
}
```

## 内存管理

### 上下文重置

```swift
context.reset()
```

**适用场景：**
- 处理大批量之后
- 上下文积累大量对象时
- 释放内存

**注意：** 使此上下文中所有已获取的对象失效。

### 刷新对象

```swift
context.refresh(article, mergeChanges: false)
```

**适用场景：**
- 丢弃内存中的变更
- 释放特定对象的内存
- 从数据库重新加载

### 将对象转为 Fault

```swift
context.refreshAllObjects()
```

**适用场景：**
- 释放所有对象的内存
- 大规模操作之后
- 内存紧张时

## Fetch Request 优化

### 清单

```swift
let fetchRequest = Article.fetchRequest()

// ✅ 设置批量大小
fetchRequest.fetchBatchSize = 20

// ✅ 限制属性
fetchRequest.propertiesToFetch = ["name", "views"]

// ✅ 预取关系
fetchRequest.relationshipKeyPathsForPrefetching = ["category"]

// ✅ 使用谓词过滤
fetchRequest.predicate = NSPredicate(format: "views > %d", 100)

// ✅ 如适用设置 fetch limit
fetchRequest.fetchLimit = 10

// ✅ 指定排序描述符
fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
```

## 批量操作

对于大规模操作，使用批量请求：

```swift
// 替代：
for article in articles {
    article.isRead = true
}
try context.save()

// 使用：
let batchUpdate = NSBatchUpdateRequest(entityName: "Article")
batchUpdate.propertiesToUpdate = ["isRead": true]
try context.execute(batchUpdate)
```

**好处：**
- 快 10-20 倍
- 更低内存使用
- SQL 层级操作

## 用于测试的数据生成器

创建可重现的测试数据集：

```swift
class DataGenerator {
    func generate(count: Int, in context: NSManagedObjectContext) {
        for i in 0..<count {
            let article = Article(context: context)
            article.name = "Article \(i)"
            
            if i % 100 == 0 {
                try? context.save()
                context.reset()
            }
        }
        try? context.save()
    }
}

// 使用
let generator = DataGenerator()
generator.generate(count: 10000, in: backgroundContext)
```

## 分析清单

1. **启用 SQL 调试** - 查看实际查询
2. **使用 Time Profiler 分析** - 查找慢操作
3. **使用 Allocations 分析** - 查找内存问题
4. **用真实数据测试** - 小数据集隐藏问题
5. **在设备上监控** - 模拟器性能不同
6. **在旧设备上测试** - 性能有差异

## 快速见效

1. **使用 `count(for:)` 而非获取** - 快 100 倍
2. **设置 `fetchBatchSize`** - 减少内存
3. **预取关系** - 消除 N+1 查询
4. **使用 `propertiesToFetch`** - 减少数据传输
5. **定期重置上下文** - 释放内存
6. **使用批量操作** - 批量变更快 10-20 倍
7. **条件保存** - 检查 `hasPersistentChanges`
8. **使用 background context** - 保持 UI 响应

## 总结

1. **先分析** - 优化前先测量
2. **使用 Instruments** - Time Profiler 和 Allocations
3. **启用 SQL 调试** - 理解查询行为
4. **优化 fetch request** - 批量大小、属性、预取
5. **使用批量操作** - 用于大规模变更
6. **重置上下文** - 定期释放内存
7. **用真实数据测试** - 小数据集隐藏问题
8. **在设备上监控** - 真实世界性能很重要
