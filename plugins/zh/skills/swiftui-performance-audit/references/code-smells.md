# 常见代码异味和修复模式

## 用途

在代码优先审查期间，使用此参考将可见的 SwiftUI 模式映射到可能的运行时开销和更安全的修复指导。

## 高优先级异味

### `body` 中的昂贵格式化器

```swift
var body: some View {
    let number = NumberFormatter()
    let measure = MeasurementFormatter()
    Text(measure.string(from: .init(value: meters, unit: .meters)))
}
```

优先使用模型或专用辅助方法中的缓存格式化器：

```swift
final class DistanceFormatter {
    static let shared = DistanceFormatter()
    let number = NumberFormatter()
    let measure = MeasurementFormatter()
}
```

### 重度计算属性

```swift
var filtered: [Item] {
    items.filter { $0.isEnabled }
}
```

优先在模型/辅助方法中每次有意义的输入变更时派生一次，或仅当视图真正拥有转换生命周期时才存储视图自有的派生状态。

### 在 `body` 内排序或过滤

```swift
List {
    ForEach(items.sorted(by: sortRule)) { item in
        Row(item)
    }
}
```

优先在渲染工作开始前完成排序：

```swift
let sortedItems = items.sorted(by: sortRule)
```

### `ForEach` 内的内联过滤

```swift
ForEach(items.filter { $0.isEnabled }) { item in
    Row(item)
}
```

优先使用具有稳定标识的预过滤集合。

### 标识不稳定

```swift
ForEach(items, id: \.self) { item in
    Row(item)
}
```

对于非稳定值或会重新排序的集合，避免使用 `id: \.self`。使用稳定的领域标识符。

### 顶层条件视图切换

```swift
var content: some View {
    if isEditing {
        editingView
    } else {
        readOnlyView
    }
}
```

优先使用一个稳定的基础视图，并将条件局部化到各个区块或修饰符。这能减少根标识抖动并降低 diff 成本。

### 主线程上的图片解码

```swift
Image(uiImage: UIImage(data: data)!)
```

优先在主线程之外进行解码和降采样，然后存储处理后的图片。

## 观察扇出

### iOS 17+ 上的广泛 `@Observable` 读取

```swift
@Observable final class Model {
    var items: [Item] = []
}

var body: some View {
    Row(isFavorite: model.items.contains(item))
}
```

如果许多视图读取同一个广泛集合或根模型，小变更会扇出为广泛的失效。优先使用更窄的派生输入、更小的可观察面，或更靠近叶子视图的逐项状态。

### iOS 16 及更早版本上的广泛 `ObservableObject` 读取

```swift
final class Model: ObservableObject {
    @Published var items: [Item] = []
}
```

同样的警告适用于旧版观察机制。当许多后代只需要一个派生字段时，避免让它们观察同一个大型共享对象。

## 修复说明

### `@State` 不是通用缓存

`@State` 用于视图自有状态和有意属于视图生命周期的派生值。不要将任意昂贵计算移入 `@State`，除非你也定义了它何时以及为何更新。

更好的替代方案：
- 在模型或存储中预计算
- 响应特定输入变更来更新派生状态
- 在专用辅助方法中记忆化
- 渲染前在后台任务中预处理

### `equatable()` 是有条件的指导

仅当以下条件满足时才使用 `equatable()`：
- 相等性比较比重新计算子树更廉价，且
- 视图输入具备值语义，足够稳定以进行有意义的相等性检查

不要将 `equatable()` 作为所有重绘的万能修复。

## 分诊顺序

当多个异味同时出现时，按以下顺序优先处理：
1. 广泛失效和观察扇出
2. 标识不稳定和列表抖动
3. 渲染期间的主线程工作
4. 图片解码或缩放开销
5. 布局和动画复杂度
