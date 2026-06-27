# 项目审计（Core Data）

使用此清单快速发现项目如何使用 Core Data 以及适用的约束（平台可用性、CloudKit、历史跟踪等）。

## 确定平台约束

- 查找部署目标（iOS/macOS 版本）。许多建议取决于此（例如分阶段迁移和复合属性需要 iOS 17+/macOS 14+）。
- 注意项目是否启用 Swift 6 / 严格并发（Sendable 和隔离警告会改变建议）。

## 检查数据模型

- 打开模型 XML（`*.xcdatamodeld/*/contents`）并检查：
  - 实体、属性、关系、约束
  - 版本管理设置（多个模型版本）
  - 重命名标识符（用于轻量级迁移）
  - 复合属性（iOS 17+）

## 识别栈配置

搜索：

- `NSPersistentContainer` vs `NSPersistentCloudKitContainer`
- `loadPersistentStores` 配置
- `persistentStoreDescriptions`（迁移选项、历史跟踪、CloudKit 选项）
- `viewContext` 配置（合并策略、`automaticallyMergesChangesFromParent`、query generation）
- background context 创建（`newBackgroundContext`、`performBackgroundTask`）

然后参考：

- `stack-setup.md` 了解推荐的默认值和合并策略
- `cloudkit-integration.md` 如果启用了 CloudKit

## 检查持久化历史跟踪（某些流程需要）

搜索：

- `NSPersistentHistoryTrackingKey`
- `NSPersistentStoreRemoteChangeNotificationPostOptionKey`
- 远程变更通知和历史处理/合并

然后参考：

- `persistent-history.md` 了解 Observer/Fetcher/Merger/Cleaner 模式

## 发现有风险的并发模式

搜索：

- 跨线程访问托管对象（查找将 `NSManagedObject` 传递到 async 任务/闭包中）
- `performAndWait` 使用（死锁/UI 阻塞风险）
- 对 Core Data 类型应用 `@unchecked Sendable`（通常隐藏真实问题）

然后参考：

- `threading.md` 和 `concurrency.md`

## 有用的调试标志（仅用于复现构建）

- `-com.apple.CoreData.ConcurrencyDebug 1`（线程违规）
- `-com.apple.CoreData.SQLDebug 1`（SQL 日志）
