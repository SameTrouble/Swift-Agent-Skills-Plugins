# 迁移与历史

## Schema 演进策略

1. 从自动（轻量级）迁移预期开始。
2. 如果变更超出轻量级能力，定义 `SchemaMigrationPlan`。
3. 用 `VersionedSchema` 显式声明模型版本。
4. 在版本之间使用 `MigrationStage.lightweight(...)` 或 `MigrationStage.custom(...)`。

使用 `originalName`，并在需要时使用 `hashModifier`，为重命名的属性保留连续性。

## 迁移计划骨架

```swift
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
```

## 持久化历史使用

当需要跨进程或基于时间的变更追踪（widget、intent、扩展、后台写入者）时使用历史。

- 使用 `HistoryDescriptor` 按令牌和/或作者抓取。
- 成功处理后存储最新令牌。
- 将事务变更过滤为仅相关的模型类型和属性。
- 删除过期事务以回收磁盘空间。

## 删除墓碑

如果已删除的模型需要保持外部可识别：

- 用 `@Attribute(.preserveValueOnDeletion)` 标记关键字段，
- 从删除变更墓碑中读取保留的值。

## 运维风险

- `historyTokenExpired` 意味着请求的历史已被删除。
- 在清理或保留窗口变更后重建令牌基线。
- 确保清理策略不会在所有消费者处理完之前删除历史。

## 需关注的发布说明

- 2024 更新：`#Unique`、`#Index`、历史 API、自定义数据存储协议。
- 2025 更新：继承支持和历史排序改进。

## 主要文档

- https://developer.apple.com/documentation/swiftdata/schemamigrationplan
- https://developer.apple.com/documentation/swiftdata/versionedschema
- https://developer.apple.com/documentation/swiftdata/migrationstage
- https://developer.apple.com/documentation/swiftdata/fetching-and-filtering-time-based-model-changes
- https://developer.apple.com/documentation/swiftdata/historydescriptor
- https://developer.apple.com/documentation/updates/swiftdata
