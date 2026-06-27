# SwiftUI 视图

- 强烈建议避免使用返回 `some View` 的计算属性或方法来拆分视图 body，即使使用了 `@ViewBuilder` 也应如此。应将它们提取为单独的 `View` 结构体，并将每个放入各自的文件中。
- 标记过长的 `body` 属性；应将它们拆分为提取的子视图。
- 如果用户为提高结构性可读性创建了少量小型的私有辅助 `some View` 属性，且它们与 `body` 属于同一关注点，内联后能以可接受的长度放入 `body` 中，则可以保留。否则，应将它们提取为新的 `View` 结构体。
- 按钮操作应从视图 body 提取到单独的方法中，以避免混合布局和逻辑。
- 同样，通用业务逻辑不应内联在 `task()`、`onAppear()` 或 `body` 中的其他地方。
- 优先将视图逻辑放入视图模型或类似结构中，以便进行测试。如需更多测试帮助，建议使用 [Swift Testing Pro agent skill](https://github.com/twostraws/swift-testing-agent-skill)。
- 每个类型（结构体、类、枚举）都应在自己的 Swift 文件中。标记包含多个类型定义的文件。
- 除非需要全屏编辑体验，否则优先使用带 `axis: .vertical` 的 `TextField` 而非 `TextEditor`，因为它支持占位文本。如果 `TextField` 需要特定的最小高度，使用类似 `lineLimit(5...)` 的方式。
- 如果按钮操作可以直接作为 `action` 参数提供，就应这样做。例如：`Button("Label", systemImage: "plus", action: myAction)` 优先于 `Button("Label", systemImage: "plus") { action() }`。
- 将 SwiftUI 视图渲染为图像时，强烈优先使用 `ImageRenderer` 而非 `UIGraphicsImageRenderer`。
- 预览应使用 `#Preview`，而非遗留的 `PreviewProvider` 协议。
- 使用 `TabView(selection:)` 时，使用绑定到存储枚举的属性，而非整数或字符串。例如，`Tab("Home", systemImage: "house", value: .home)` 优于 `Tab("Home", systemImage: "house", value: 0)`。
- 强烈建议避免使用返回 `some View` 的计算属性或方法来拆分视图 body，即使使用了 `@ViewBuilder` 也应如此。应将它们提取为单独的 `View` 结构体，并将每个放入各自的文件中。（是的，这里重复了，但这一点太重要了，需要提及两次。）


## 视图动画

- 强烈优先使用 `@Animatable` 宏而非手动创建 `animatableData`——该宏会自动添加对 `Animatable` 协议的遵循，并创建正确的 `animatableData` 属性。如果某些属性不应或不能被动画化（如布尔值、整数等），将它们标记为 `@AnimatableIgnored`。
- 永远不要使用 `animation(_ animation: Animation?)`；始终提供一个要观察的值，如 `.animation(.bouncy, value: score)`。
- 链式动画必须使用传递给 `withAnimation()` 的 `completion` 闭包来完成，而非尝试使用延迟执行多个 `withAnimation()` 调用。

例如：

```swift
Button("Animate Me") {
    withAnimation {
        scale = 2
    } completion: {
        withAnimation {
            scale = 1
        }
    }
}
```
