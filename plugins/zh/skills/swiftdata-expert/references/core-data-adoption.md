# Core Data 迁移采纳

## 采纳路径

使用三种迁移模式之一：

1. 从 Core Data 全量转换为 SwiftData。
2. 按功能/模块增量迁移。
3. 共存（例如宿主应用用 Core Data，widget 用 SwiftData）。

根据发布风险和集成约束选择。

## 模型映射指导

- 增量迁移时保持实体名、关键属性和关系对齐。
- 使用 `@Model` 类作为 SwiftData 模型层。
- 迁移期间保持关系和删除规则语义等价。

## 共存实践

当 Core Data 与 SwiftData 共存时：

- 使用带命名空间的 Core Data 类（`CDTrip` 等）以避免类名冲突。
- 当需要共享持久化时，将两个栈指向同一存储 URL。
- 在 Core Data 栈中启用持久化历史追踪（`NSPersistentHistoryTrackingKey`）以匹配 SwiftData 预期。

## 跨进程变更检测

对于宿主应用与 widget 工作流：

- 优先消费 SwiftData 持久化历史，而非重复的"未读"字段或旁路存储。
- 追踪历史令牌进度，仅处理相关的模型更新。

## 迁移清单

- 验证 App Group 容器和共享存储路径。
- 在相同数据集上验证两个栈。
- 验证跨两个栈的删除和关系行为。
- 验证主应用 UI 中由扩展驱动的更新。
- 验证历史令牌过期时的回退行为。

## 主要文档

- https://developer.apple.com/documentation/coredata/adopting-swiftdata-for-a-core-data-app
- https://developer.apple.com/documentation/swiftdata/fetching-and-filtering-time-based-model-changes
