# CloudKit 集成

`NSPersistentCloudKitContainer` 将 Core Data 与 CloudKit 同步，实现跨设备的无缝数据同步。

## 配置

### 基本配置

```swift
import CoreData
import CloudKit

let container = NSPersistentCloudKitContainer(name: "Model")

container.loadPersistentStores { description, error in
    if let error = error {
        fatalError("Failed to load store: \(error)")
    }
}
```

### 配置 CloudKit Container

在 Xcode 中：
1. 添加 CloudKit capability
2. 选择或创建 CloudKit container
3. 在 Core Data model 中启用 "Use CloudKit"

### Schema 设计限制

CloudKit 有 Core Data 没有的限制：

**不支持：**
- 实体上的唯一约束
- `Undefined` 属性类型
- `ObjectID` 属性类型
- 非可选关系（必须可选）
- 没有反向关系的关系
- Deny 删除规则

**支持：**
- 向记录类型添加新字段
- 添加新记录类型

**重要：** Production schema 是**不可变的**。仔细规划！

## Schema 初始化

### Development 环境

```swift
// 首次运行在 Development 中初始化 schema
container.loadPersistentStores { description, error in
    // Schema 自动创建
}
```

### 提升到 Production

1. 在 Development 中彻底测试
2. 打开 CloudKit Dashboard
3. 将 schema 部署到 Production
4. **部署后不能修改！**

## 监控同步

### 观察事件

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(storeDidChange),
    name: NSPersistentCloudKitContainer.eventChangedNotification,
    object: container
)

@objc func storeDidChange(_ notification: Notification) {
    guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else {
        return
    }
    
    switch event.type {
    case .setup:
        print("配置: \(event.succeeded ? "成功" : "失败")")
    case .import:
        print("导入: \(event.succeeded ? "成功" : "失败")")
    case .export:
        print("导出: \(event.succeeded ? "成功" : "失败")")
    @unknown default:
        break
    }
    
    if let error = event.error {
        print("错误: \(error)")
    }
}
```

### 测试同步

```swift
func testSync() {
    let expectation = XCTestExpectation(description: "导出")
    
    // 为导出创建期望
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
    
    // 进行变更
    let article = Article(context: container.viewContext)
    article.name = "Test"
    try? container.viewContext.save()
    
    wait(for: [expectation], timeout: 60)
    NotificationCenter.default.removeObserver(observer)
}
```

## 跨版本兼容性

### 策略 1：增量字段

添加新字段，保留旧字段：

```swift
// V1: name
// V2: name, subtitle（新增）
// 旧版本能看到记录但看不到 subtitle
```

### 策略 2：版本属性

```swift
// 添加版本属性
article.schemaVersion = 2

// 在 fetch request 中过滤
fetchRequest.predicate = NSPredicate(format: "schemaVersion <= %d", currentVersion)
```

### 策略 3：新 Container

```swift
let options = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.com.example.app.v2"
)

let description = NSPersistentStoreDescription(url: storeURL)
description.cloudKitContainerOptions = options
```

**注意：** 大数据集上传需要时间。

## 调试

### 系统日志

监控以下进程：
- **Application** - Core Data 活动
- **dasd** - 调度决策
- **cloudd** - CloudKit 操作
- **apsd** - 推送通知

### 使用 log stream

```bash
# 应用日志
log stream --predicate 'process == "YourApp"'

# CloudKit 日志
log stream --predicate 'process == "cloudd" AND message CONTAINS "your.container.id"'

# 推送通知
log stream --predicate 'process == "apsd"'

# 调度
log stream --predicate 'process == "dasd" AND message CONTAINS "YourApp"'
```

### CloudKit 日志 Profile

1. 从 [Apple Developer Portal](https://developer.apple.com/bug-reporting/profiles-and-logs/) 下载
2. 安装到设备
3. 重启设备
4. 复现问题
5. 收集 sysdiagnose

### 收集诊断信息

**sysdiagnose：**
- iOS：音量上 + 音量下 + 电源键（长按）
- macOS：Shift + Control + Option + Command + 句号

## 常见问题

### Schema 不匹配

**问题：** 本地 schema 与 CloudKit schema 不匹配。

**解决方案：**
1. 删除应用
2. 重新安装
3. 让 schema 重新初始化

### 同步不工作

**检查清单：**
- [ ] 已启用 CloudKit capability
- [ ] 已登录 iCloud
- [ ] 有网络连接
- [ ] 已配置 CloudKit container
- [ ] 已在 Development 中初始化 schema
- [ ] 已将 schema 提升到 Production

### 首次同步过大

**问题：** 首次同步时间太长。

**解决方案：**
- 使用后台获取
- 显示进度指示器
- 为测试实施数据生成器

## 最佳实践

1. **先在 Development 中测试** - Schema 可变
2. **仔细规划 schema** - Production 不可变
3. **使关系可选** - CloudKit 要求
4. **添加反向关系** - CloudKit 要求
5. **版本化你的数据** - 用于跨版本兼容
6. **监控同步事件** - 检测和处理错误
7. **用多设备测试** - 验证同步行为
8. **处理冲突** - 使用适当的合并策略
9. **收集诊断信息** - 用于调试同步问题
10. **考虑数据大小** - 大数据集同步需要时间

## 总结

- 使用 `NSPersistentCloudKitContainer` 进行 CloudKit 同步
- Schema 有限制（可选关系、无约束）
- Production schema 不可变
- 通过事件通知监控同步
- 在提升到 Production 前在 Development 中彻底测试
- 规划跨版本兼容性
- 使用系统日志调试
- 对复杂问题收集 sysdiagnose
