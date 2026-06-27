# 实现手册

## 1) 添加新的持久化功能

1. 定义或扩展 `@Model` 类。
2. 在需要的地方显式添加关系和删除规则语义。
3. 添加唯一性和索引策略（如果部署目标支持）。
4. 通过 `@Query` 或 `FetchDescriptor` 接通 UI 抓取。
5. 在真实数据量上验证 CRUD 和列表行为。
6. 验证删除和回滚行为。

交付物：

- 模型变更，
- 查询变更，
- 迁移影响说明。

## 2) 准备 Schema 升级发布

1. 在模型代码中对比当前与下一版 schema。
2. 将变更分类为轻量级或自定义迁移候选。
3. 需要时引入 `VersionedSchema` 和 `SchemaMigrationPlan`。
4. 在已有存储快照上演练迁移。
5. 验证向后兼容性假设和失败行为。

交付物：

- 迁移阶段计划，
- 演练结果，
- 回滚和恢复说明。

## 3) 调试 CloudKit 同步分叉

1. 验证能力和远程通知。
2. 确认 SwiftData 容器选择（`automatic`、显式 private 或 `.none`）。
3. 检查 schema 兼容性约束。
4. 验证源设备写入和目标设备读取。
5. 检查历史和上下文保存流程，找出遗漏的写入。

交付物：

- 根因总结，
- 配置变更，
- 至少来自两台设备/模拟器的验证证据。

## 4) 处理跨进程更新（Widget/Intent/App Extension）

1. 设置上下文作者策略。
2. 使用令牌 + 谓词抓取历史。
3. 按模型类型和变更属性过滤相关变更。
4. 更新 UI 状态并持久化最新令牌。
5. 在所有消费者处理后安全删除过期历史。

交付物：

- 令牌持久化路径，
- 历史过滤逻辑，
- 清理策略。

## 5) 改善查询性能

1. 识别缓慢的用户可见查询。
2. 将谓词和排序描述符与索引对齐。
3. 添加抓取限制、偏移量或仅标识符抓取。
4. 消除视图代码中的重复过滤逻辑。
5. 在大型数据集上对比变更前后的行为。

交付物：

- 前后查询策略，
- 测量或观察到的 UX 影响，
- 剩余风险。

## 主要文档

- https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches
- https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data
- https://developer.apple.com/documentation/swiftdata/schemamigrationplan
- https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
- https://developer.apple.com/documentation/swiftdata/fetching-and-filtering-time-based-model-changes
