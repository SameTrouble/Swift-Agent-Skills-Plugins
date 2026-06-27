# 查询与抓取

## 选择 API

- 在 SwiftUI 视图中使用 `@Query` 实现自动刷新并与 UI 简单绑定。
- 在视图之外或需要显式控制时使用 `FetchDescriptor` + `modelContext.fetch(...)`。
- 仅需计数时使用 `fetchCount(...)`。
- 仅需 ID 时使用 `fetchIdentifiers(...)`。

## 确定性查询设计

- 将谓词构造集中到辅助函数中。
- 在相关视图间（例如列表 + 地图）复用同一谓词以防止不一致。
- 对用户可见的列表始终显式定义排序顺序。
- 将动态查询参数放在视图初始化器中，以强制可预测的查询重建。

## 动态查询模式

```swift
init(searchText: String, date: Date) {
    let predicate = Quake.predicate(searchText: searchText, searchDate: date)
    _quakes = Query(filter: predicate, sort: \.magnitude, order: .reverse)
}
```

## FetchDescriptor 控制

使用以下项配置 `FetchDescriptor<T>`：

- `predicate`：过滤条件。
- `sortBy`：一个或多个排序描述符。
- `fetchLimit`：限制结果数量。
- `fetchOffset`：分页偏移量。
- `includePendingChanges`：在匹配中包含未保存的变更。
- `relationshipKeyPathsForPrefetching`：减少关系延迟加载开销。
- `propertiesToFetch`：仅选择所需属性。

## 性能指导

- 将索引策略与实际查询键对齐。
- 避免对高基数模型进行无界的广泛查询。
- 预检查时优先使用计数或标识符抓取。
- 对面向用户的界面使用显式抓取限制。
- 避免在 `body` 中重复临时过滤；将过滤编码进查询谓词。

## 常见失败

- `unsupportedPredicate` 或 `unsupportedSortDescriptor`：将谓词/排序简化为受支持的表达式。
- 视图间 UI 不一致：未复用共享谓词。
- 列表渲染缓慢：频繁使用的排序/过滤属性缺少索引。

## 主要文档

- https://developer.apple.com/documentation/swiftdata/query
- https://developer.apple.com/documentation/swiftdata/query()
- https://developer.apple.com/documentation/swiftdata/additionalquerymacros
- https://developer.apple.com/documentation/swiftdata/fetchdescriptor
- https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data
