# 性能护栏

## 意图

当 SwiftUI 屏幕大、滚动密集、频繁更新或有不必重复计算风险时，使用这些规则。

## 核心规则

- 为 `ForEach` 和列表内容提供稳定标识。当集合可能重排或变化时，不要用不稳定索引作标识。
- 把昂贵的筛选、排序和格式化移出 `body`；当不简单时预计算或移入模型/辅助。
- 收窄观察范围，使只有读取变化状态的视图需要更新。
- 对较大滚动内容优先用惰性容器，当只有屏幕一部分频繁变化时提取子视图。
- 避免为小状态变化替换整个顶层视图树；保持稳定的根视图并变化局部区块或修饰符。

## 示例：稳定标识

```swift
ForEach(items) { item in
  Row(item: item)
}
```

当集合可能改变顺序时，优先用此而非基于索引的标识：

```swift
ForEach(Array(items.enumerated()), id: \.offset) { _, item in
  Row(item: item)
}
```

## 示例：把昂贵工作移出 body

```swift
struct FeedView: View {
  let items: [FeedItem]

  private var sortedItems: [FeedItem] {
    items.sorted(using: KeyPathComparator(\.createdAt, order: .reverse))
  }

  var body: some View {
    List(sortedItems) { item in
      FeedRow(item: item)
    }
  }
}
```

如果工作比小型派生属性更昂贵，把它移入更新频率更低的模型、store 或辅助。

## 何时进一步调查

- 长信息流或网格中的滚动卡顿
- 搜索或表单校验导致的输入延迟
- 一小块状态变化时过于宽泛的视图更新
- 带许多条件或重复格式化工作的大屏幕

## 陷阱

- 每次渲染都重新计算重度转换
- 当只关心一个字段时，许多后代观察一个大对象
- 当 `List`、`LazyVStack` 或 `LazyHGrid` 已经能解决问题时却自建滚动容器
