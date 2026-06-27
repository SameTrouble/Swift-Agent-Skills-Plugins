# 参考索引

Core Data 主题快速导航。

## 基础

- `stack-setup.md`：NSPersistentContainer 配置、合并策略、上下文配置
- `saving.md`：条件保存、hasPersistentChanges、保存时机策略
- `glossary.md`：术语定义，便于快速查阅
- `project-audit.md`：发现项目 Core Data 配置和约束的清单

## 数据访问

- `fetch-requests.md`：查询优化、NSFetchedResultsController、聚合
- `threading.md`：NSManagedObjectID、perform vs performAndWait、并发
- `concurrency.md`：Swift Concurrency 集成、async/await、actor、Sendable
- `batch-operations.md`：NSBatchInsertRequest、NSBatchDeleteRequest、NSBatchUpdateRequest

## 模型与 Schema

- `model-configuration.md`：约束、派生属性、transformable、验证、生命周期
- `migration.md`：轻量级、分阶段和延迟迁移策略

## 高级主题

- `persistent-history.md`：历史跟踪配置、Observer/Fetcher/Merger/Cleaner 模式
- `cloudkit-integration.md`：NSPersistentCloudKitContainer、schema 设计、监控
- `performance.md`：Instruments 分析、内存管理、优化
- `testing.md`：内存存储、共享模型、数据生成器

## 按问题快速链接

### "我需要..."

- **配置 Core Data** → `stack-setup.md`
- **高效保存数据** → `saving.md`
- **获取并展示数据** → `fetch-requests.md`
- **在后台线程工作** → `threading.md`
- **在 Core Data 中使用 async/await** → `concurrency.md`
- **导入大型数据集** → `batch-operations.md`
- **配置模型** → `model-configuration.md`
- **迁移 schema** → `migration.md`
- **与 CloudKit 同步** → `cloudkit-integration.md`
- **优化性能** → `performance.md`
- **编写测试** → `testing.md`

### "我遇到了关于...的错误"

- **"NSPersistentStoreIncompatibleVersionHashError"** → `migration.md`
- **"Cannot delete objects in other contexts"** → `threading.md`
- **"NSMergeConflict"** → `stack-setup.md`（合并策略）、`model-configuration.md`（约束）
- **"Failed to find unique match for NSEntityDescription"** → `testing.md`（共享模型）
- **批量操作未更新 UI** → `persistent-history.md`
- **CloudKit 同步问题** → `cloudkit-integration.md`
- **内存无限增长** → `performance.md`、`fetch-requests.md`
- **验证错误** → `model-configuration.md`

### "我想要..."

- **优化查询** → `fetch-requests.md`、`performance.md`
- **处理关系** → `model-configuration.md`、`fetch-requests.md`
- **验证数据** → `model-configuration.md`
- **跨上下文跟踪变更** → `persistent-history.md`
- **调试性能问题** → `performance.md`
- **测试 Core Data 代码** → `testing.md`

## 文件统计

- `project-audit.md`：项目发现清单（部署目标、栈、历史跟踪、并发风险）
- `stack-setup.md`：NSPersistentContainer、合并策略、上下文配置
- `saving.md`：hasPersistentChanges、条件保存、错误处理
- `fetch-requests.md`：优化、NSFetchedResultsController、聚合、diffable data source
- `threading.md`：NSManagedObjectID、perform/performAndWait、传统线程
- `concurrency.md`：Swift Concurrency、async/await、actor、Sendable、@MainActor、DAO
- `batch-operations.md`：NSBatchInsertRequest、NSBatchDeleteRequest、NSBatchUpdateRequest
- `model-configuration.md`：约束、派生属性、transformable、验证、生命周期
- `migration.md`：轻量级、分阶段（iOS 17+）、延迟（iOS 14+）、复合属性
- `persistent-history.md`：Observer、Fetcher、Merger、Cleaner、批量操作集成
- `cloudkit-integration.md`：NSPersistentCloudKitContainer、schema 设计、监控、调试
- `performance.md`：Instruments 分析、内存管理、优化策略
- `testing.md`：内存存储、共享模型、数据生成器、XCTest 模式
- `glossary.md`：Core Data 术语与快速定义
