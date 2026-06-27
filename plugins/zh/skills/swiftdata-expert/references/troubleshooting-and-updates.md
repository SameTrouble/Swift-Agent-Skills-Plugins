# 故障排查与更新

## 常见失败模式

- `missingModelContext`：当前执行路径没有有效的容器接线。
- `modelValidationFailure`：保存时违反 schema/模型约束。
- `unsupportedPredicate` / `unsupportedSortDescriptor`：表达式不支持存储端求值。
- `includePendingChangesWithBatchSize`：无效的抓取配置组合。
- `historyTokenExpired`：历史令牌指向已被修剪的事务。
- `unknownSchema` / `backwardMigration`：迁移路径无效或不受支持。

## 实用调试序列

1. 确认容器和 schema 设置。
2. 确认部署目标支持所用 API。
3. 用最小 `FetchDescriptor` 且无可选过滤器复现。
4. 验证删除谓词和保存边界。
5. 验证历史令牌生命周期（加载、使用、持久化、清理）。
6. 验证 CloudKit 模式（`automatic`、显式容器或 `.none`）。

## API 可用性快照

- SwiftData 基础 API（`@Model`、`ModelContainer`、`ModelContext`、`Query`）：iOS 17+。
- 持久化历史描述符和许多历史/数据存储 API：iOS 18+。
- `#Unique` 和 `#Index` 宏：iOS 18+。
- 继承支持在 2025 年 6 月更新和 iOS 26 时代文档中重点提及；始终按部署目标限制。

## 版本感知建议

提供建议时：

- 避免对仅 iOS 17 的应用推荐 `#Unique` 或 `#Index`；
- 除非存在 iOS 26 时代工具链，否则避免依赖较新的历史排序特性；
- 为较旧的部署目标提供回退方案。

## 主要文档

- https://developer.apple.com/documentation/swiftdata/swiftdataerror
- https://developer.apple.com/documentation/swiftdata/datastoreerror
- https://developer.apple.com/documentation/updates/swiftdata
