# 模型配置

Core Data 的数据模型提供了超越基本属性和关系的强大配置选项。本指南涵盖约束、派生属性、transformable、验证和生命周期事件。

## 约束

约束确保属性值的唯一性。配合正确的合并策略，Core Data 会自动处理重复项。

### 设置约束

在 Xcode 的 Data Model Editor 中：
1. 选择你的实体
2. 在 Data Model Inspector 中，找到 "Constraints"
3. 点击 "+" 并添加属性名称

**示例：** 在 `Category` 实体中使 `name` 唯一。

### 必需的合并策略

```swift
viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
```

**没有此合并策略，约束冲突会导致应用崩溃。**

### 约束如何工作

```swift
// 第一次保存
let category1 = Category(context: context)
category1.name = "Swift"
try context.save() // 保存成功

// 尝试重复
let category2 = Category(context: context)
category2.name = "Swift" // 相同名称
try context.save() // 使用正确的合并策略：保留第一个，丢弃第二个
```

### 多重约束

```swift
// 对多个属性的约束
// 在模型中：constraints = ["email", "username"]

// 两者都必须唯一
user1.email = "test@example.com"
user1.username = "testuser"
```

### 复合约束

```swift
// 属性的唯一组合
// 在模型中：constraints = ["firstName,lastName"]

// 这些是不同的（唯一组合）
person1.firstName = "John"
person1.lastName = "Doe"

person2.firstName = "John"
person2.lastName = "Smith" // 不同的组合，允许
```

## 派生属性

派生属性从其他属性或关系计算而来并存储在数据库中。它们在保存或刷新时计算。

### 好处

- 无需手动更新计算值
- 比访问关系性能更好
- 针对查询优化

### 常见派生方式

#### 1. 关系计数

```swift
// 在 Data Model Editor 中：
// 派生属性：articlesCount
// 派生表达式：articles.@count
```

**为什么这比 `articles.count` 更好：**
- 不会触发 fault
- 更快的查询
- 保存后始终最新

#### 2. 相关对象属性

```swift
// 派生属性：categoryName
// 派生表达式：category.name
```

**用例：** 在显示列表视图时避免触发 fault。

#### 3. 当前时间戳

```swift
// 派生属性：lastModified
// 派生表达式：now()
```

**每次保存时自动更新。**

#### 4. 规范字符串（搜索优化）

```swift
// 派生属性：searchName
// 派生表达式：canonical:(name)
```

**作用：**
- 转换为小写
- 去除变音符号
- 非常适合大小写不敏感、变音符号不敏感的搜索

**示例：**
```swift
// name = "Café"
// searchName = "cafe"

// 搜索查询
fetchRequest.predicate = NSPredicate(format: "searchName CONTAINS %@", "cafe")
// 匹配 "Café"、"CAFE"、"café" 等
```

#### 5. 相关值求和

```swift
// 派生属性：totalViews
// 派生表达式：@sum.articles.views
```

### 重要说明

- 派生属性在**保存时**或**刷新时**计算
- 内存中的变更在保存前不会更新派生属性
- 不能手动设置（它们是计算得出的）

### 使用示例

```swift
class Article: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var category: Category?
    
    // 从 category.name 派生
    @NSManaged var categoryName: String?
    
    // 从 canonical:(name) 派生
    @NSManaged var searchName: String?
}

// 使用
article.name = "Core Data Best Practices"
try context.save()

// 保存后，派生属性已更新
print(article.searchName) // "core data best practices"
print(article.categoryName) // "Swift"
```

## Transformable

Transformable 允许存储 Core Data 原生不支持的自定义类型。

### 创建 Value Transformer

```swift
import UIKit

@objc(ColorTransformer)
class ColorTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let color = value as? UIColor else { return nil }
        
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: color,
                requiringSecureCoding: true
            )
            return data
        } catch {
            print("Failed to transform color: \(error)")
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        
        do {
            let color = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: UIColor.self,
                from: data
            )
            return color
        } catch {
            print("Failed to reverse transform color: \(error)")
            return nil
        }
    }
}
```

### 注册 Transformer

```swift
// 在栈配置中，加载存储之前
ValueTransformer.setValueTransformer(
    ColorTransformer(),
    forName: NSValueTransformerName("ColorTransformer")
)
```

### 在数据模型中配置

1. 选择属性
2. 将 Type 设置为 "Transformable"
3. 将 "Custom Class" 设置为你的类型（例如 `UIColor`）
4. 将 "Transformer" 设置为你的 transformer 名称（例如 `ColorTransformer`）

### 使用 Transformable 属性

```swift
class Article: NSManagedObject {
    @NSManaged var color: UIColor?
}

// 使用
article.color = .systemBlue
try context.save()

// 检索
let color = article.color // UIColor
```

### NSSecureCoding 要求

现代 Core Data 要求使用 secure coding：

```swift
// 让你的自定义类型遵循 NSSecureCoding
extension CustomType: NSSecureCoding {
    static var supportsSecureCoding: Bool { return true }
    
    func encode(with coder: NSCoder) {
        // 编码属性
    }
    
    required init?(coder: NSCoder) {
        // 解码属性
    }
}
```

## 验证

Core Data 提供内置验证，在保存前运行。

### 模型级验证

在 Data Model Editor 中设置：

**字符串验证：**
- 最小长度
- 最大长度
- 正则表达式

**数值验证：**
- 最小值
- 最大值

**示例：**
```
属性：name
类型：String
最小长度：3
最大长度：100
```

### 代码级验证

在你的 `NSManagedObject` 子类中重写验证方法：

```swift
class Article: NSManagedObject {
    @NSManaged var name: String?
    
    // 插入前验证
    override func validateForInsert() throws {
        try super.validateForInsert()
        try validateName()
    }
    
    // 更新前验证
    override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateName()
    }
    
    // 删除前验证
    override func validateForDelete() throws {
        try super.validateForDelete()
        
        // 示例：有相关对象时不能删除
        if let attachments = attachments, !attachments.isEmpty {
            throw NSError(
                domain: "ArticleValidation",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Cannot delete article with attachments"]
            )
        }
    }
    
    // 自定义验证
    private func validateName() throws {
        guard let name = name, !name.isEmpty else {
            throw NSError(
                domain: "ArticleValidation",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"]
            )
        }
        
        // 检查受保护的名称
        let protectedNames = ["Admin", "System", "Root"]
        if protectedNames.contains(name) {
            throw NSError(
                domain: "ArticleValidation",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "'\(name)' is a protected name"]
            )
        }
    }
}
```

### 属性级验证

```swift
class Article: NSManagedObject {
    @NSManaged var name: String?
    
    override func validateName(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        guard let name = value.pointee as? String, !name.isEmpty else {
            throw NSError(
                domain: "ArticleValidation",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"]
            )
        }
    }
}
```

### 处理验证错误

```swift
do {
    try context.save()
} catch let error as NSError {
    if error.domain == NSCocoaErrorDomain {
        switch error.code {
        case NSValidationStringTooShortError:
            print("字符串太短")
        case NSValidationStringTooLongError:
            print("字符串太长")
        case NSManagedObjectValidationError:
            print("验证失败")
        default:
            print("其他错误: \(error.localizedDescription)")
        }
    }
}
```

## 生命周期事件

重写生命周期方法以在对象生命周期的特定节点执行操作。

### awakeFromInsert()

对象首次插入上下文时调用一次。

```swift
override func awakeFromInsert() {
    super.awakeFromInsert()
    
    // 设置默认值
    setPrimitiveValue(Date(), forKey: #keyPath(Article.creationDate))
    setPrimitiveValue(Date(), forKey: #keyPath(Article.lastModified))
    setPrimitiveValue(0, forKey: #keyPath(Article.views))
}
```

**使用 `setPrimitiveValue` 以避免：**
- KVO 通知
- 将对象标记为已变更
- 无限循环

### willSave()

每次保存前调用。用于更新修改日期或清理。

```swift
override func willSave() {
    super.willSave()
    
    // 更新修改日期
    setPrimitiveValue(Date(), forKey: #keyPath(Article.lastModified))
    
    // 如果对象被删除，删除本地文件
    if isDeleted, let localResource = localResourceURL {
        try? FileManager.default.removeItem(at: localResource)
    }
}
```

**注意：** 不要在 `willSave()` 中调用 `save()` - 会无限循环！

### didSave()

保存完成后调用。

```swift
override func didSave() {
    super.didSave()
    
    // 发送通知、更新缓存等
    NotificationCenter.default.post(
        name: .articleDidSave,
        object: self
    )
}
```

### prepareForDeletion()

对象被标记为删除时调用（保存前）。

```swift
override func prepareForDeletion() {
    super.prepareForDeletion()
    
    // 取消正在进行的操作
    downloadTask?.cancel()
    
    // 不要在这里删除文件！改用 willSave()
    // （即使保存被回滚，prepareForDeletion 也会被调用）
}
```

**重要：** 不要在 `prepareForDeletion()` 中删除文件。删除可能被回滚，导致数据不一致。

### awakeFromFetch()

从存储中获取对象时调用。

```swift
override func awakeFromFetch() {
    super.awakeFromFetch()
    
    // 初始化临时属性
    setupObservers()
}
```

### 完整生命周期示例

```swift
class Article: NSManagedObject {
    @NSManaged var name: String?
    @NSManaged var creationDate: Date?
    @NSManaged var lastModified: Date?
    @NSManaged var localResourceURL: URL?
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // 只设置一次创建日期
        setPrimitiveValue(Date(), forKey: #keyPath(Article.creationDate))
        setPrimitiveValue(Date(), forKey: #keyPath(Article.lastModified))
    }
    
    override func willSave() {
        super.willSave()
        
        // 每次保存时更新修改日期
        if !isDeleted && changedValues().keys.contains("name") {
            setPrimitiveValue(Date(), forKey: #keyPath(Article.lastModified))
        }
        
        // 删除时清理文件
        if isDeleted, let url = localResourceURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    override func prepareForDeletion() {
        super.prepareForDeletion()
        
        // 取消正在进行的操作
        // 不要在这里删除文件！
    }
}
```

## 常见陷阱

### ❌ 使用约束时未设置合并策略

```swift
// 约束冲突会崩溃
let category = Category(context: context)
category.name = "Duplicate"
try context.save() // 崩溃！
```

### ❌ 手动设置派生属性

```swift
// 派生属性是只读的
article.categoryName = "Swift" // 被忽略！
```

### ❌ 在生命周期事件中使用 KVO 方法

```swift
override func awakeFromInsert() {
    super.awakeFromInsert()
    
    // ❌ 触发 KVO，标记为已变更
    self.creationDate = Date()
    
    // ✅ 使用 primitive value
    setPrimitiveValue(Date(), forKey: #keyPath(Article.creationDate))
}
```

### ❌ 在 prepareForDeletion 中删除文件

```swift
override func prepareForDeletion() {
    super.prepareForDeletion()
    
    // ❌ 错误：删除可能被回滚
    try? FileManager.default.removeItem(at: fileURL)
}
```

### ✅ 正确做法

```swift
// 设置合并策略
viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

// 让派生属性自行计算
article.name = "New Name"
try context.save()
print(article.searchName) // 自动更新

// 在生命周期事件中使用 primitive value
setPrimitiveValue(Date(), forKey: #keyPath(Article.creationDate))

// 在 willSave 中当 isDeleted 时删除文件
override func willSave() {
    super.willSave()
    if isDeleted {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
```

## 总结

1. **使用约束确保唯一性** - 需要 NSMergeByPropertyStoreTrumpMergePolicy
2. **使用派生属性** - 比访问关系性能更好
3. **使用 canonical: 进行搜索** - 大小写和变音符号不敏感
4. **使用 transformable 存储自定义类型** - 配合 NSSecureCoding
5. **在代码中验证** - 用于复杂业务规则
6. **使用 awakeFromInsert 设置默认值** - 创建时调用一次
7. **使用 willSave 进行更新** - 每次保存前调用
8. **使用 setPrimitiveValue** - 在生命周期事件中避免 KVO
9. **在 willSave 中删除文件** - 当 isDeleted 为 true 时
10. **不要在 willSave 中调用 save** - 会导致无限循环
