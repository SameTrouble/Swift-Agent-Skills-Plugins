# 性能

- 在切换修饰符值时，优先使用三元表达式而非 if/else 视图分支，以避免 `_ConditionalContent`，保持结构一致性，并避免重复重建底层平台视图。
- 除非绝对必要，否则避免使用 `AnyView`。改用 `@ViewBuilder`、`Group` 或泛型。
- 如果 `ScrollView` 具有不透明的、静态且纯色的背景，优先使用 `scrollContentBackground(.visible)` 来提高滚动边缘渲染效率。
- 将视图拆分为专用的 SwiftUI 视图比将它们放入计算属性或方法中更高效。在属性或方法上使用 `@ViewBuilder` 不能解决此问题；强烈建议拆分视图。
- 始终确保视图初始化器保持尽可能小而简单，避免任何非简单的工作。标记任何可以移入 `task()` 修饰符以在视图显示时运行的工作。
- 同样，假设每个视图的 `body` 属性会被频繁调用——如果排序或过滤等逻辑可以轻松移出，就应该移出。
- 避免创建属性来存储 `DateFormatter` 等格式化器，除非确实需要。更自然的方法是使用带格式的 `Text`，如下所示：`Text(Date.now, format: .dateTime.day().month().year())` 或 `Text(100, format: .currency(code: "USD"))`。
- 避免在 `List`/`ForEach` 初始化器中进行频繁重复的昂贵内联转换（如 `items.filter { ... }`）。
- 优先使用 `let` 从数据源派生转换后的数据，或缓存在 `@State` 中。但是，除非你也拥有显式的失效逻辑以避免 UI 过时，否则不要将派生的集合缓存在 `@State` 中。
- 对于 `ScrollView` 中的大型数据集，使用 `LazyVStack`/`LazyHStack`；标记拥有大量子视图的非惰性栈。
- 执行异步工作时，优先使用 `task()` 而非 `onAppear()`，因为它会在视图消失时自动取消。
- 尽可能避免在视图上存储逃逸的 `@ViewBuilder` 闭包；应存储构建后的视图结果。

示例：

```swift
// 反模式：在视图上存储逃逸闭包。
struct CardView<Content: View>: View {
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
    }
}

// 推荐：存储构建后的视图值；合成的初始化器会负责调用 builder。
struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
    }
}
```
