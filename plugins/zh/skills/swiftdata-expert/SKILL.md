---
name: swiftdata-expert-skill
description: 为 Swift 和 SwiftUI 应用中 SwiftData 持久化的设计、实现、迁移和调试提供专家级指导。适用于处理 @Model schema、@Relationship/@Attribute 规则、Query 或 FetchDescriptor 数据访问、ModelContainer/ModelContext 配置、CloudKit 同步、SchemaMigrationPlan/history API、ModelActor 并发隔离，或从 Core Data 迁移到 SwiftData 及二者共存等场景。
---

# SwiftData 专家技能

## 概览

使用此技能来构建、审查和加固 SwiftData 持久化架构，采用 Apple 文档记录的模式（从 iOS 17 到最新更新）。优先保证数据完整性、迁移安全性、同步正确性以及可预测的并发行为。

## 代理行为契约（遵循以下规则）

1. 在推荐 API 之前先确认最低部署目标（尤其是 `#Index`、`#Unique`、`HistoryDescriptor`、`DataStore`、继承相关示例）。
2. 在调试数据问题之前，先确认应用已有真实的 `ModelContainer` 接线；缺少它，插入会失败，查询会返回空。
3. 区分主 actor 上的 UI 操作与后台持久化操作；不要假设一个上下文能同时适用两者。
4. 将 schema 变更视为迁移变更：先评估轻量级迁移，需要时再使用 `SchemaMigrationPlan`。
5. 对于启用 CloudKit 的应用，在提出模型变更前先验证 schema 兼容性约束。
6. 优先使用确定性的查询定义（共享谓词、显式排序、有界抓取），而非在视图中临时过滤。
7. 读取跨进程变更时使用持久化历史令牌；删除过期历史以避免存储膨胀。
8. 在代码审查中，优先关注数据丢失风险、意外批量删除、同步分叉以及上下文隔离缺陷，而非代码风格问题。

## 分析命令（尽早使用）

- 搜索容器设置：
  - `rg "modelContainer\\(|ModelContainer\\(" -n`
- 搜索模型定义：
  - `rg "^@Model|#Unique|#Index|@Relationship|@Attribute|@Transient" -n`
- 搜索上下文使用：
  - `rg "modelContext|mainContext|ModelContext\\(" -n`
- 搜索迁移和历史：
  - `rg "SchemaMigrationPlan|VersionedSchema|MigrationStage|fetchHistory|deleteHistory|historyToken" -n`
- 搜索 CloudKit 和 App Group：
  - `rg "cloudKitDatabase|iCloud|CloudKit|groupContainer|AppGroup|NSPersistentCloudKitContainer" -n`

## 项目摸底（提供建议之前）

- 确定部署目标：iOS、iPadOS、macOS、watchOS 和 visionOS。
- 定位容器设置：`.modelContainer(...)` 修饰符或手动 `ModelContainer(...)`。
- 确认是否期望自动保存，以及是否需要显式 `save()`。
- 检查是否启用了撤销（`isUndoEnabled`），以及操作发生在 `mainContext` 还是自定义上下文上。
- 检查 CloudKit 能力及所选容器策略（`automatic`、`.private(...)`、`.none`）。
- 检查是否需要 App Group 存储。
- 检查 Core Data 共存是否在范围内。
- 检查 schema 变更是否需要与现有用户数据向后兼容。

## 工作流决策树

1. 需要新模型或 schema 形态：
   - 阅读 `references/modeling-and-schema.md`。
2. 需要创建、更新、删除行为或上下文正确性：
   - 阅读 `references/model-context-and-lifecycle.md`。
3. 需要过滤、排序或动态列表行为：
   - 阅读 `references/querying-and-fetching.md`。
4. 需要关系建模或继承：
   - 阅读 `references/relationships-and-inheritance.md`。
5. 需要迁移规划、版本升级或变更追踪：
   - 阅读 `references/migrations-and-history.md`。
6. 需要 iCloud 同步或 CloudKit 兼容性：
   - 阅读 `references/cloudkit-sync.md`。
7. 需要从 Core Data 增量迁移：
   - 阅读 `references/core-data-adoption.md`。
8. 需要后台隔离或基于 actor 的持久化：
   - 阅读 `references/concurrency-and-actors.md`。
9. 需要快速诊断或 API 可用性检查：
   - 阅读 `references/troubleshooting-and-updates.md`。
10. 需要具体任务的端到端执行手册：
    - 阅读 `references/implementation-playbooks.md`。

## 分诊优先手册（常见问题 -> 下一步行动）

- 插入失败或查询始终为空：
  - 确认 `.modelContainer(...)` 已挂载到应用或窗口根，且模型类型已包含在内。
- 网络刷新后出现重复行：
  - 添加 `@Attribute(.unique)` 或 `#Unique` 约束，并依赖插入即 upsert 的行为。
- 删除时意外数据丢失：
  - 审查删除规则（`.cascade` vs `.nullify`）并检查无界 `delete(model:where:)`。
- 撤销或重做无效：
  - 确保设置 `isUndoEnabled: true`，且变更通过 `mainContext` 保存（而非仅后台上下文）。
- CloudKit 同步行为异常：
  - 检查能力、远程通知和 CloudKit schema 兼容性；存在多个容器时显式设置 `cloudKitDatabase`。
- Widget 或 App Intent 变更未反映：
  - 使用持久化历史（`fetchHistory`），配合令牌 + 作者过滤。
- 出现 `historyTokenExpired`：
  - 重置本地令牌策略，从安全点重新引导变更消费。
- 查询结果代价过高或不稳定：
  - 使用共享谓词构建器、显式排序和有界的 `FetchDescriptor` 设置。

## 反模式（默认拒绝）

- 在验证容器接线之前构建持久化逻辑。
- 未审查谓词并确认就执行广泛删除。
- 在没有隔离边界的情况下混用 UI 驱动编辑和后台写入流水线。
- 依赖内存中的临时过滤，而非存储端谓词。
- 未完成能力设置和 schema 兼容性检查就启用 CloudKit 同步。
- 未在现有用户数据上演练迁移就发布 schema 变更。
- 消费历史却没有令牌持久化和清理策略。

## 核心模式

### 应用级容器接线（SwiftUI）

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Trip.self, Accommodation.self])
    }
}
```

### 手动容器配置

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: false)
let container = try ModelContainer(
    for: Trip.self,
    Accommodation.self,
    configurations: config
)
```

### 视图初始化器中的动态查询设置

```swift
struct TripListView: View {
    @Query private var trips: [Trip]

    init(searchText: String) {
        let predicate = #Predicate<Trip> {
            searchText.isEmpty || $0.name.localizedStandardContains(searchText)
        }
        _trips = Query(filter: predicate, sort: \.startDate, order: .forward)
    }

    var body: some View { List(trips) { Text($0.name) } }
}
```

### 安全批量删除模式

```swift
do {
    try modelContext.delete(
        model: Trip.self,
        where: #Predicate { $0.endDate < .now },
        includeSubclasses: true
    )
    try modelContext.save()
} catch {
    // 处理删除和保存失败。
}
```

## 参考文件

- `references/modeling-and-schema.md`
- `references/model-context-and-lifecycle.md`
- `references/querying-and-fetching.md`
- `references/relationships-and-inheritance.md`
- `references/migrations-and-history.md`
- `references/cloudkit-sync.md`
- `references/core-data-adoption.md`
- `references/concurrency-and-actors.md`
- `references/troubleshooting-and-updates.md`
- `references/implementation-playbooks.md`

## 最佳实践总结

1. 将模型代码作为唯一事实来源；避免隐藏的 schema 假设。
2. 对大型或频繁查询的数据集应用显式的唯一性和索引策略。
3. 插入根模型，让 SwiftData 自动遍历关系图。
4. 通过显式谓词和排序描述符保持查询行为的确定性。
5. 对抓取设置边界（`fetchLimit`、偏移量、仅标识符抓取）以提升可扩展性。
6. 将删除规则视为业务规则；在 schema 变更时一并审查。
7. 使用 `ModelConfiguration` 实现环境特定行为（内存测试、CloudKit、App Group、只读存储）。
8. 将历史视为运维系统：令牌持久化、过滤和清理。
9. 对非 UI 持久化工作使用模型 actor 或隔离上下文。
10. 根据 API 可用性和部署目标来限制推荐建议。

## 验证清单（变更之后）

- 目标平台和最低部署版本构建成功。
- 使用真实存储和内存存储时 CRUD 测试通过。
- 关系删除行为符合预期（`cascade`、`nullify` 及其他）。
- 查询行为在真实数据集和排序/过滤组合下保持稳定。
- 迁移路径在已有数据上验证通过（不仅是全新安装）。
- CloudKit 行为在发布前于开发容器中验证。
- 跨进程变更（widget、intent、扩展）能被正确观察。
- 破坏性操作的错误路径和回滚行为已覆盖。

## 回应契约

- 对于审查任务，按严重程度报告发现，并附上确切文件路径和行号。
- 对于实现任务，描述：
  - 容器或上下文变更，
  - schema 或迁移变更，
  - 查询或性能变更，
  - 已运行的验证步骤及任何缺口。
- 如果部署目标阻碍了推荐的 API，提供与当前目标兼容的最佳回退方案。
