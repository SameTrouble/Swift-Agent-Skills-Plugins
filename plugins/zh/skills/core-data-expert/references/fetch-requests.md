# Fetch Request 与查询

优化 fetch request 对应用性能至关重要。本指南涵盖从基本 fetch 到高级聚合的高效查询 Core Data 的最佳实践。

## 基本 Fetch Request

```swift
let fetchRequest: NSFetchRequest<Article> = Article.fetchRequest()
let articles = try context.fetch(fetchRequest)
```

## 优化策略

### 1. 限制获取的属性

只获取你实际需要的属性：

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.propertiesToFetch = ["name", "creationDate"]

// 对于列表视图，你可能只需要：
fetchRequest.propertiesToFetch = ["name", "categoryName", "views"]
```

**SQL 影响：**
```sql
-- 没有 propertiesToFetch
SELECT * FROM ZARTICLE

-- 有 propertiesToFetch
SELECT Z_PK, ZNAME, ZCREATIONDATE FROM ZARTICLE
```

**好处：**
- 减少内存使用
- 更快的查询执行
- 从磁盘传输更少数据

### 2. 使用批量获取

分批获取对象以避免一次加载所有内容：

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.fetchBatchSize = 20
```

**工作原理：**
- 初始只获取 20 个对象
- 需要时获取下一批（滚动、迭代）
- 保持内存使用可预测

**适用场景：**
- 列表视图（table/collection view）
- 大型数据集
- 可滚动内容

### 3. 设置 Fetch Limit

当你只需要特定数量的结果时：

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.fetchLimit = 1 // 只获取一个结果
```

**常见用例：**
```swift
// 获取最新文章
fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
fetchRequest.fetchLimit = 1

// 获取浏览量前 10
fetchRequest.sortDescriptors = [NSSortDescriptor(key: "views", ascending: false)]
fetchRequest.fetchLimit = 10
```

### 4. 仅获取对象 ID

用于计数或检查存在性时，只获取 ID：

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.resultType = .managedObjectIDResultType

let objectIDs = try context.fetch(fetchRequest) as! [NSManagedObjectID]
```

**好处：**
- 最小内存使用
- 非常快
- 无 fault 开销

**用途：**
- 计数对象
- 检查存在性
- 批量操作
- 验证

## 排序描述符

始终指定排序描述符以获得可预测的结果：

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.sortDescriptors = [
    NSSortDescriptor(key: "creationDate", ascending: false)
]
```

### 多重排序描述符

```swift
fetchRequest.sortDescriptors = [
    NSSortDescriptor(key: "category.name", ascending: true),
    NSSortDescriptor(key: "name", ascending: true)
]
```

### 大小写不敏感排序

```swift
let sortDescriptor = NSSortDescriptor(
    key: "name",
    ascending: true,
    selector: #selector(NSString.caseInsensitiveCompare(_:))
)
fetchRequest.sortDescriptors = [sortDescriptor]
```

### 本地化排序

```swift
let sortDescriptor = NSSortDescriptor(
    key: "name",
    ascending: true,
    selector: #selector(NSString.localizedStandardCompare(_:))
)
fetchRequest.sortDescriptors = [sortDescriptor]
```

## 谓词

使用谓词过滤结果：

### 基本谓词

```swift
// 精确匹配
fetchRequest.predicate = NSPredicate(format: "name == %@", "SwiftLee")

// 包含
fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", "swift")
// [c] = 大小写不敏感, [d] = 变音符号不敏感

// 开头是
fetchRequest.predicate = NSPredicate(format: "name BEGINSWITH[c] %@", "Swift")

// 大于
fetchRequest.predicate = NSPredicate(format: "views > %d", 100)

// 日期范围
let startDate = Calendar.current.startOfDay(for: Date())
let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
fetchRequest.predicate = NSPredicate(
    format: "creationDate >= %@ AND creationDate < %@",
    startDate as NSDate,
    endDate as NSDate
)
```

### 复合谓词

```swift
// AND
let predicate1 = NSPredicate(format: "views > %d", 100)
let predicate2 = NSPredicate(format: "category.name == %@", "Swift")
fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])

// OR
fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicate1, predicate2])

// NOT
fetchRequest.predicate = NSCompoundPredicate(notPredicateWithSubpredicate: predicate1)
```

### 关系谓词

```swift
// 特定分类的文章
fetchRequest.predicate = NSPredicate(format: "category.name == %@", "Swift")

// 有任何附件的文章
fetchRequest.predicate = NSPredicate(format: "attachments.@count > 0")

// 超过 5 个附件的文章
fetchRequest.predicate = NSPredicate(format: "attachments.@count > 5")

// 使用 ANY
fetchRequest.predicate = NSPredicate(format: "ANY attachments.size > %d", 1000000)

// 使用 ALL
fetchRequest.predicate = NSPredicate(format: "ALL attachments.isDownloaded == YES")
```

### IN 谓词

```swift
let names = ["Swift", "iOS", "Core Data"]
fetchRequest.predicate = NSPredicate(format: "name IN %@", names)
```

## NSFetchedResultsController

对于 table 和 collection view，使用 `NSFetchedResultsController` 获取自动更新：

```swift
class ArticlesViewController: UIViewController {
    var fetchedResultsController: NSFetchedResultsController<Article>!
    
    func setupFetchedResultsController() {
        let fetchRequest = Article.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        fetchRequest.fetchBatchSize = 20
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: "ArticlesCache"
        )
        
        fetchedResultsController.delegate = self
        
        try? fetchedResultsController.performFetch()
    }
}
```

### 带分区

```swift
fetchedResultsController = NSFetchedResultsController(
    fetchRequest: fetchRequest,
    managedObjectContext: viewContext,
    sectionNameKeyPath: "category.name", // 按分类分组
    cacheName: "ArticlesByCategoryCache"
)
```

### 代理方法（UITableView）

```swift
extension ArticlesViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                   didChange anObject: Any,
                   at indexPath: IndexPath?,
                   for type: NSFetchedResultsChangeType,
                   newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .automatic)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        case .update:
            if let indexPath = indexPath {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                tableView.deleteRows(at: [indexPath], with: .automatic)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
        @unknown default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
```

## Diffable Data Source（iOS 13+）

使用 `NSDiffableDataSourceSnapshot` 的现代方法：

```swift
class ArticlesViewController: UICollectionViewController {
    private var dataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!
    private var fetchedResultsController: NSFetchedResultsController<Article>!
    
    func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<String, NSManagedObjectID>(
            collectionView: collectionView
        ) { collectionView, indexPath, objectID in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ArticleCell",
                for: indexPath
            ) as! ArticleCell
            
            if let article = try? self.viewContext.existingObject(with: objectID) as? Article {
                cell.configure(with: article)
            }
            
            return cell
        }
    }
    
    func setupFetchedResultsController() {
        let fetchRequest = Article.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
    }
}

extension ArticlesViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                   didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        let snapshot = snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}
```

## 使用 NSExpression 进行聚合查询

用于统计和聚合：

### 计数

```swift
// 简单计数
let count = try context.count(for: Article.fetchRequest())

// 带谓词的计数
let fetchRequest = Article.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "views > %d", 100)
let count = try context.count(for: fetchRequest)
```

### 求和、平均值、最小值、最大值

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.resultType = .dictionaryResultType

// 浏览量总和
let sumExpression = NSExpression(format: "@sum.views")
let sumDescription = NSExpressionDescription()
sumDescription.name = "totalViews"
sumDescription.expression = sumExpression
sumDescription.expressionResultType = .integer64AttributeType

fetchRequest.propertiesToFetch = [sumDescription]

let results = try context.fetch(fetchRequest) as! [[String: Any]]
if let totalViews = results.first?["totalViews"] as? Int {
    print("总浏览量: \(totalViews)")
}
```

### 按分组聚合

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.resultType = .dictionaryResultType

// 分类名称
let categoryExpression = NSExpression(forKeyPath: "category.name")
let categoryDescription = NSExpressionDescription()
categoryDescription.name = "categoryName"
categoryDescription.expression = categoryExpression
categoryDescription.expressionResultType = .stringAttributeType

// 每个分类的浏览量总和
let sumExpression = NSExpression(format: "@sum.views")
let sumDescription = NSExpressionDescription()
sumDescription.name = "totalViews"
sumDescription.expression = sumExpression
sumDescription.expressionResultType = .integer64AttributeType

fetchRequest.propertiesToFetch = [categoryDescription, sumDescription]
fetchRequest.propertiesToGroupBy = ["category.name"]
fetchRequest.sortDescriptors = [NSSortDescriptor(key: "categoryName", ascending: true)]

let results = try context.fetch(fetchRequest) as! [[String: Any]]
for result in results {
    let category = result["categoryName"] as? String ?? "Unknown"
    let views = result["totalViews"] as? Int ?? 0
    print("\(category): \(views) 浏览量")
}
```

### 每组计数

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.resultType = .dictionaryResultType

let categoryExpression = NSExpression(forKeyPath: "category.name")
let categoryDescription = NSExpressionDescription()
categoryDescription.name = "categoryName"
categoryDescription.expression = categoryExpression
categoryDescription.expressionResultType = .stringAttributeType

let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "objectID")])
let countDescription = NSExpressionDescription()
countDescription.name = "count"
countDescription.expression = countExpression
countDescription.expressionResultType = .integer64AttributeType

fetchRequest.propertiesToFetch = [categoryDescription, countDescription]
fetchRequest.propertiesToGroupBy = ["category.name"]

let results = try context.fetch(fetchRequest) as! [[String: Any]]
```

## 使用 Managed 协议的类型化 Fetch Request

创建协议以实现类型安全的 fetch request：

```swift
protocol Managed: NSManagedObject {
    static var entityName: String { get }
}

extension Managed {
    static var entityName: String {
        return String(describing: self)
    }
    
    static func fetchRequest<T: NSManagedObject>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: entityName)
    }
}

// 让你的实体遵循协议
extension Article: Managed {}

// 使用
let fetchRequest: NSFetchRequest<Article> = Article.fetchRequest()
```

## 异步获取

对于大型数据集，异步获取：

```swift
let fetchRequest = Article.fetchRequest()
let asyncFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { result in
    guard let articles = result.finalResult else { return }
    
    DispatchQueue.main.async {
        // 用 articles 更新 UI
    }
}

try? context.execute(asyncFetchRequest)
```

## Fault 控制

### 预取关系

```swift
let fetchRequest = Article.fetchRequest()
fetchRequest.relationshipKeyPathsForPrefetching = ["category", "attachments"]
```

**好处：**
- 减少数据库访问次数
- 提高访问关系时的性能
- 防止 N+1 查询问题

### 返回 Fault

```swift
fetchRequest.returnsObjectsAsFaults = false
```

**适用场景：**
- 你知道会立即访问所有属性
- 小结果集
- 大数据集避免使用（内存占用高）

## 常见模式

### 按 ID 获取单个对象

```swift
func fetchArticle(withID id: NSManagedObjectID) -> Article? {
    return try? context.existingObject(with: id) as? Article
}
```

### 获取或创建

```swift
func fetchOrCreateArticle(withName name: String) -> Article {
    let fetchRequest = Article.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", name)
    fetchRequest.fetchLimit = 1
    
    if let existing = try? context.fetch(fetchRequest).first {
        return existing
    }
    
    let article = Article(context: context)
    article.name = name
    return article
}
```

### 检查存在性

```swift
func articleExists(withName name: String) -> Bool {
    let fetchRequest = Article.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", name)
    fetchRequest.fetchLimit = 1
    fetchRequest.resultType = .countResultType
    
    let count = (try? context.count(for: fetchRequest)) ?? 0
    return count > 0
}
```

## 性能提示

### ❌ 不要获取所有内容

```swift
// 错误：获取所有属性、所有对象
let articles = try context.fetch(Article.fetchRequest())
let count = articles.count
```

### ✅ 使用计数请求

```swift
// 正确：只计数，不获取对象
let count = try context.count(for: Article.fetchRequest())
```

### ❌ 不要在循环中访问关系

```swift
// 错误：每个 article 都触发 fault
for article in articles {
    print(article.category?.name) // Fault！
}
```

### ✅ 预取关系

```swift
// 正确：一次预取所有 category
let fetchRequest = Article.fetchRequest()
fetchRequest.relationshipKeyPathsForPrefetching = ["category"]
let articles = try context.fetch(fetchRequest)

for article in articles {
    print(article.category?.name) // 无 fault！
}
```

### ❌ 不要在循环中获取

```swift
// 错误：多次 fetch request
for name in names {
    let fetchRequest = Article.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", name)
    let articles = try? context.fetch(fetchRequest)
}
```

### ✅ 使用 IN 谓词

```swift
// 正确：单次 fetch request
let fetchRequest = Article.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "name IN %@", names)
let articles = try context.fetch(fetchRequest)
```

## 调试 Fetch Request

### 启用 SQL 调试

添加启动参数：
```
-com.apple.CoreData.SQLDebug 1
```

**输出：**
```sql
CoreData: sql: SELECT Z_PK, ZNAME, ZVIEWS FROM ZARTICLE WHERE ZVIEWS > ? ORDER BY ZCREATIONDATE DESC LIMIT 20
```

### 测量 Fetch 性能

```swift
let startTime = CFAbsoluteTimeGetCurrent()
let articles = try context.fetch(fetchRequest)
let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
print("Fetch 耗时 \(timeElapsed) 秒")
```

## 总结

1. **使用 `propertiesToFetch`** 限制获取的属性
2. **设置 `fetchBatchSize`** 用于大型数据集（通常 20-50）
3. **使用 `fetchLimit`** 当你只需要少量结果时
4. **始终指定排序描述符** 以获得可预测的结果
5. **使用谓词** 在数据库层过滤
6. **使用 `NSFetchedResultsController`** 用于列表视图
7. **预取关系** 以避免 N+1 查询
8. **使用计数请求** 而非获取对象来计数
9. **使用聚合表达式** 进行统计
10. **启用 SQL 调试** 以理解查询性能
