# Core Data 术语表

Core Data 术语快速参考。

## 核心概念

**Core Data**
Apple 的对象图管理和持久化框架。

**Persistent Store（持久化存储）**
数据保存的底层存储（通常是 SQLite 数据库）。

**Managed Object Model（托管对象模型）**
描述你的数据 schema（实体、属性、关系）。

**Entity（实体）**
数据模型中的类定义（类似于数据库表）。

**Attribute（属性）**
实体的属性（类似于数据库列）。

**Relationship（关系）**
实体之间的连接（一对一、一对多、多对多）。

## 栈组件

**NSPersistentContainer**
封装 Core Data 栈（模型、协调器、上下文）。

**NSPersistentCloudKitContainer**
扩展 NSPersistentContainer，增加 CloudKit 同步能力。

**NSPersistentStoreCoordinator**
管理一个或多个持久化存储并协调访问。

**NSManagedObjectContext**
用于操作托管对象的工作区。变更在保存前不会持久化。

**NSManagedObject**
Core Data 对象的基类。表示数据库表中的一行。

**NSManagedObjectID**
托管对象的唯一、不可变标识符。线程安全。

## 上下文类型

**View Context**
用于 UI 操作的主队列上下文。运行在主线程。

**Background Context**
用于繁重任务的私有队列上下文。运行在后台线程。

**Child Context（子上下文）**
有父上下文的上下文。保存将变更推送到父上下文，不写入磁盘。

## 获取

**NSFetchRequest**
描述对持久化存储中对象的搜索。

**NSFetchedResultsController**
为 table/collection view 管理 fetch 结果，提供自动更新。

**Predicate（谓词）**
fetch request 的过滤条件（类似于 SQL WHERE 子句）。

**Sort Descriptor（排序描述符）**
定义 fetch 结果的排序（类似于 SQL ORDER BY）。

**Faulting（Fault 机制）**
延迟加载机制。对象数据仅在访问时加载。

**Prefetching（预取）**
急切加载相关对象以避免 fault。

## 操作

**Save（保存）**
将变更从上下文持久化到持久化存储。

**Fetch（获取）**
从持久化存储检索对象。

**Insert（插入）**
在上下文中创建新对象。

**Delete（删除）**
标记对象为删除。保存时移除。

**Refresh（刷新）**
从持久化存储重新加载对象，丢弃内存中的变更。

**Reset（重置）**
清除上下文中所有对象，释放内存。

**Rollback（回滚）**
丢弃上下文中所有未保存的变更。

## 批量操作

**NSBatchInsertRequest**
在 SQL 层级插入多个对象（iOS 14+）。

**NSBatchDeleteRequest**
在 SQL 层级删除多个对象。

**NSBatchUpdateRequest**
在 SQL 层级更新多个对象。

## 高级功能

**Persistent History Tracking（持久化历史跟踪）**
将所有变更记录在事务日志中，用于跨上下文同步。

**Derived Attribute（派生属性）**
存储在数据库中的计算属性（例如 `articles.@count`）。

**Transformable**
使用 value transformer 存储的自定义类型。

**Constraint（约束）**
确保属性唯一性（需要合并策略）。

**Merge Policy（合并策略）**
决定保存时如何解决冲突。

## 迁移

**Lightweight Migration（轻量级迁移）**
针对简单模型变更的自动迁移。

**Staged Migration（分阶段迁移）**
将复杂迁移分解为步骤（iOS 17+）。

**Deferred Migration（延迟迁移）**
延迟清理工作以获得更好性能（iOS 14+）。

**Composite Attribute（复合属性）**
单个属性内的结构化数据（iOS 17+）。

**Mapping Model（映射模型）**
描述如何从一个模型版本迁移到另一个。

**Version Hash（版本哈希）**
标识特定模型版本的校验和。

## 线程

**perform**
在上下文的队列上异步执行块。

**performAndWait**
在上下文的队列上同步执行块（阻塞调用线程）。

**Thread Confinement（线程限制）**
每个上下文只能从其队列访问。

**automaticallyMergesChangesFromParent**
上下文自动接收来自父上下文的变更。

## 验证

**validateForInsert**
插入对象前调用。

**validateForUpdate**
更新对象前调用。

**validateForDelete**
删除对象前调用。

## 生命周期

**awakeFromInsert**
对象首次插入时调用一次。

**awakeFromFetch**
从存储加载对象时调用。

**willSave**
每次保存前调用。

**didSave**
保存完成后调用。

**prepareForDeletion**
对象被标记为删除时调用。

## CloudKit

**Container Identifier（容器标识符）**
CloudKit container 的唯一 ID（例如 `iCloud.com.example.app`）。

**Development Environment（开发环境）**
用于测试的 CloudKit 环境（schema 可变）。

**Production Environment（生产环境）**
用于已发布应用的 CloudKit 环境（schema 不可变）。

**Schema Initialization（Schema 初始化）**
首次运行时从 Core Data 模型创建 CloudKit schema。

**Event Notification（事件通知）**
CloudKit 同步事件发生时发送的通知。

## 调试

**SQL Debug**
记录 SQL 查询的启动参数：`-com.apple.CoreData.SQLDebug 1`

**Concurrency Debug**
捕获线程违规的启动参数：`-com.apple.CoreData.ConcurrencyDebug 1`

**Migration Debug**
记录迁移步骤的启动参数：`-com.apple.CoreData.MigrationDebug 1`

## 常见缩写

**CD** - Core Data
**MOC** - Managed Object Context（NSManagedObjectContext）
**MO** - Managed Object（NSManagedObject）
**FRC** - Fetched Results Controller（NSFetchedResultsController）
**PSC** - Persistent Store Coordinator（NSPersistentStoreCoordinator）
**MOD** - Managed Object Model（NSManagedObjectModel）

## 快速参考

**线程安全：** NSManagedObjectID、NSPersistentStoreCoordinator
**非线程安全：** NSManagedObject、NSManagedObjectContext
**仅主线程：** View context 操作
**后台线程：** Background context 操作
**自动：** 轻量级迁移（使用 NSPersistentContainer）
**手动：** 分阶段迁移、自定义映射模型
