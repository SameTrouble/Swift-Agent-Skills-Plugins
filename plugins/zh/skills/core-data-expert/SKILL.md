---
name: core-data-expert
description: 'Core Data 专家级指导（iOS/macOS）：栈配置、fetch request 与 NSFetchedResultsController、保存与合并冲突、线程与 Swift Concurrency、批量操作与持久化历史跟踪、迁移、性能优化，以及 NSPersistentCloudKitContainer/CloudKit 同步。'
---
# Core Data Expert

快速、面向生产环境的指导，帮助你构建**正确**、**高性能**的 Core Data 栈，并修复常见崩溃。

## 代理行为契约（遵循这些规则）

1. 当建议取决于 API 可用性时（iOS 14+/17+ 特性等），先确定 OS/部署目标。
2. 在提出修复方案之前，先识别上下文类型：**view context（UI）** 还是 **background context（繁重任务）**。
3. 推荐使用 `NSManagedObjectID` 进行跨上下文/跨任务通信；**切勿跨上下文传递 `NSManagedObject` 实例**。
4. 尽可能优先使用轻量级迁移；复杂变更使用分阶段迁移（iOS 17+）。
5. 推荐批量操作时，确认已启用持久化历史跟踪（通常是 UI 更新的必要条件）。
6. 涉及 CloudKit 集成时，提醒开发者 **Production schema 是不可变的**。
7. 谨慎引用 WWDC/外部资源；优先使用本技能的 `references/`。

## 前 60 秒（分诊模板）

- **明确目标**：配置、修 bug、迁移、性能、CloudKit？
- **收集最小必要信息**：
  - 平台 + 部署目标
  - 存储类型（SQLite / 内存存储）以及是否启用 CloudKit
  - 涉及的上下文（view vs background）以及是否使用 Swift Concurrency
  - 确切的错误信息 + 堆栈跟踪/日志
- **立即分支**：
  - 线程/崩溃 → 关注上下文隔离 + `NSManagedObjectID` 传递
  - 迁移错误 → 识别模型版本 + 迁移策略
  - 批量操作未更新 UI → 持久化历史跟踪 + 合并管道

## 路由表（快速选择正确的参考文档）

- **栈配置 / 合并策略 / 上下文** → `references/stack-setup.md`
- **保存模式** → `references/saving.md`
- **Fetch request / 列表更新 / 聚合** → `references/fetch-requests.md`
- **传统线程（perform/performAndWait、对象 ID）** → `references/threading.md`
- **Swift Concurrency（async/await、actor、Sendable、DAO）** → `references/concurrency.md`
- **批量插入/删除/更新** → `references/batch-operations.md`
- **持久化历史跟踪 + "批量操作未更新 UI"** → `references/persistent-history.md`
- **模型配置（约束、验证、派生/复合属性、transformable）** → `references/model-configuration.md`
- **Schema 迁移（轻量级/分阶段/延迟）** → `references/migration.md`
- **CloudKit 集成与调试** → `references/cloudkit-integration.md`
- **性能分析与内存** → `references/performance.md`
- **测试模式** → `references/testing.md`
- **术语表** → `references/glossary.md`

## 常见错误 → 最佳下一步

- **"Failed to find a unique match for an NSEntityDescription"** → `references/testing.md`（共享的 `NSManagedObjectModel`）
- **`NSPersistentStoreIncompatibleVersionHashError`** → `references/migration.md`（版本管理 + 迁移）
- **跨上下文/线程异常**（例如从错误上下文删除/更新）→ `references/threading.md` 和/或 `references/concurrency.md`（使用 `NSManagedObjectID`）
- **Core Data 相关的 Sendable / actor 隔离警告** → `references/concurrency.md`（不要用 `@unchecked Sendable` "掩盖"问题）
- **`NSMergeConflict` / 约束冲突** → `references/model-configuration.md` + `references/stack-setup.md`（约束 + 合并策略）
- **批量操作未更新 UI** → `references/persistent-history.md` + `references/batch-operations.md`
- **CloudKit schema/同步问题** → `references/cloudkit-integration.md`
- **fetch 期间内存增长** → `references/performance.md` + `references/fetch-requests.md`

## 验证清单（修改 Core Data 代码时）

- 确认上下文与任务匹配（UI vs background）。
- 确保 `NSManagedObject` 实例不跨上下文；改用 `NSManagedObjectID` 传递。
- 如果使用批量操作，确认持久化历史跟踪 + 合并管道。
- 如果使用约束，确认合并策略和冲突解决策略。
- 如果涉及性能，使用 Instruments 分析并验证 fetch 的批处理/限制。

## 参考文件

- `references/_index.md`（导航）
- `references/stack-setup.md`
- `references/saving.md`
- `references/fetch-requests.md`
- `references/threading.md`
- `references/concurrency.md`
- `references/batch-operations.md`
- `references/persistent-history.md`
- `references/model-configuration.md`
- `references/migration.md`
- `references/cloudkit-integration.md`
- `references/performance.md`
- `references/testing.md`
- `references/glossary.md`
