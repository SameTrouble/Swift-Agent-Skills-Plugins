# 使用现代 SwiftUI API

- 始终使用 `foregroundStyle()` 而非 `foregroundColor()`。
- 始终使用 `clipShape(.rect(cornerRadius:))` 而非 `cornerRadius()`。
- 始终使用 `Tab` API 而非 `tabItem()`。
- 永远不要使用单参数变体的 `onChange()` 修饰符；应使用接受两个参数或不接受参数的变体。
- 如果有更新的替代方案可用，不要使用 `GeometryReader`：`containerRelativeFrame()`、`visualEffect()` 或 `Layout` 协议。标记 `GeometryReader` 的使用并建议现代替代方案。
- 设计触觉效果时，优先使用 `sensoryFeedback()` 而非较旧的 UIKit API，如 `UIImpactFeedbackGenerator`。
- 使用 `@Entry` 宏定义自定义 `EnvironmentValues`、`FocusValues`、`Transaction` 和 `ContainerValues` 键。这取代了手动创建遵循（例如）`EnvironmentKey` 的类型并带有 `defaultValue`，然后用计算属性扩展 `EnvironmentValues` 的遗留模式。
- 强烈优先使用 `overlay(alignment:content:)` 而非已弃用的 `overlay(_:alignment:)`。例如，使用 `.overlay { Text("Hello, world!") }` 而非 `.overlay(Text("Hello, world!"))`。
- 永远不要使用 `.navigationBarLeading` 和 `.navigationBarTrailing` 来放置工具栏项；它们已被弃用。正确的现代放置位置是 `.topBarLeading` 和 `.topBarTrailing`。
- 处理英语、法语、德语、葡萄牙语、西班牙语和意大利语时，优先依赖自动语法一致性。例如，使用 `Text("^[\(people) person](inflect: true)")` 来显示人数。
- 可以用两个链式修饰符来填充和描边一个形状；你*不需要*用 overlay 来描边。以前需要 overlay，但在 iOS 17 及更高版本中已修复。
- 从资产目录引用图像时，如果项目配置为使用生成的符号资产 API，则优先使用该 API：`Image(.avatar)` 而非 `Image("avatar")`。
- 面向 iOS 26 及更高版本时，SwiftUI 有原生的 `WebView` 视图类型，可替代几乎所有在 `UIViewRepresentable` 中手动包装的 `WKWebView`。使用时，确保包含 `import WebKit`。
- 对 `enumerated()` 序列使用 `ForEach` 时，不应先转换为数组。直接使用 `ForEach(items.enumerated(), id: \.element.id)`。
- 隐藏滚动指示器时，使用 `.scrollIndicators(.hidden)` 而非初始化器中的 `showsIndicators: false`。
- 永远不要使用 `+` 进行 `Text` 拼接。

例如，这里的 `+` 用法是不好的且已弃用：

```swift
Text("Hello").foregroundStyle(.red)
+
Text("World").foregroundStyle(.blue)
```

应改用文本插值，如下所示：

```swift
let red = Text("Hello").foregroundStyle(.red)
let blue = Text("World").foregroundStyle(.blue)
Text("\(red)\(blue)")
```


## 使用 ObservableObject

如果绝对需要使用 `ObservableObject`——例如你想使用 Combine publisher 创建一个防抖器——应始终确保添加了 `import Combine`。这以前通过 SwiftUI 提供，但现已不再如此。
