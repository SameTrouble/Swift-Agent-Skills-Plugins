# 并发与 Actor

## 隔离模型

- UI 绑定的操作使用 `mainContext`。
- 后台持久化工作使用专用隔离。
- 避免在 UI 上下文中直接混用长时间运行的写入流程。

## 模型 Actor

`@ModelActor` 有助于创建具有互斥访问的 actor 隔离持久化服务。

优点：

- 对模型操作的串行化访问，
- 更安全的后台处理，
- 减少意外的上下文共享。

模式：

```swift
@ModelActor
actor TripStore {
    func saveTrip(_ trip: Trip) throws {
        modelContext.insert(trip)
        try modelContext.save()
    }
}
```

## 上下文边界

- 不要在隔离边界间随意传递可变模型实例。
- 传递标识符（`persistentModelID`），并在接收上下文中按需重新抓取。
- 在服务边界保持上下文归属显式。

## 撤销与并发

- 自动撤销/重做集成与主上下文保存流程绑定。
- 后台上下文并非启用撤销的用户编辑的直接替代品。

## 与并发写入者的历史

- 在有用时为不同写入者设置 `modelContext.author`。
- 按令牌和作者过滤抓取的历史，以区分信号与噪声。

## 主要文档

- https://developer.apple.com/documentation/swiftdata/concurrencysupport
- https://developer.apple.com/documentation/swiftdata/modelactor()
- https://developer.apple.com/documentation/swiftdata/modelactor
- https://developer.apple.com/documentation/swiftdata/modelexecutor
- https://developer.apple.com/documentation/swiftdata/defaultserialmodelexecutor
