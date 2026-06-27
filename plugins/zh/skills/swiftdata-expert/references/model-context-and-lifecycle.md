# ModelContext 与生命周期

## 先设置容器

- 在应用、场景或顶层视图挂载 `.modelContainer(for: ...)`。
- 或者手动创建 `ModelContainer(...)` 并注入。
- 若未挂载容器，环境上下文为内存型且无 schema：
  - 插入会抛错，
  - 查询返回空。

## 上下文角色

- `container.mainContext`（或 `@Environment(\.modelContext)`）绑定到主 actor，专用于 UI 驱动的工作。
- 自定义 `ModelContext(container)` 适用于受控的后台或工具类工作。

## 自动保存与显式保存

- `mainContext` 由 SwiftData 配置为启用自动保存。
- 手动创建的上下文不会以同样方式隐式配置；如需要请设置 `autosaveEnabled`。
- 当操作边界必须确定性时，使用显式 `try context.save()`。
- 对分组变更后跟保存，使用 `transaction { ... }`。

## 插入、更新、删除

- 仅插入图根；SwiftData 会自动遍历关联模型。
- 对已知模型的更新会被自动追踪；无需显式更新 API。
- `delete(_:)` 删除特定实例。
- `delete(model:where:includeSubclasses:)` 可一次删除多个模型。
  - 警告：无谓词意味着删除该类型的所有模型。

## 撤销与通知

- 通过 `.modelContainer(..., isUndoEnabled: true)` 启用撤销。
- 自动撤销/重做支持适用于通过 `mainContext` 保存的变更。
- 观察 `ModelContext.willSave` 和 `ModelContext.didSave` 作为生命周期钩子。
- 始终将通知订阅限定到特定上下文对象。

## 选择与标识

- 使用 `persistentModelID` 作为 UI 中稳定的选择标识。
- 在删除所选对象前清除选择，避免引用过期。

## 安全操作模式

```swift
@Environment(\.modelContext) private var context

func removeExpiredTrips() {
    do {
        try context.delete(model: Trip.self, where: #Predicate { $0.endDate < .now })
        try context.save()
    } catch {
        // 报告并恢复。
    }
}
```

## 主要文档

- https://developer.apple.com/documentation/swiftdata/modelcontainer
- https://developer.apple.com/documentation/swiftdata/modelcontext
- https://developer.apple.com/documentation/swiftdata/modelcontext/autosaveenabled
- https://developer.apple.com/documentation/swiftdata/modelcontext/delete(model:where:includesubclasses:)
- https://developer.apple.com/documentation/swiftdata/deleting-persistent-data-from-your-app
- https://developer.apple.com/documentation/swiftdata/reverting-data-changes-using-the-undo-manager
