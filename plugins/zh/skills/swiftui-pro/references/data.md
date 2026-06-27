# 数据流、共享状态和属性包装器

将 SwiftUI 的 body 代码和逻辑代码分开是非常重要的，这样可以使代码更易于阅读、编写和维护。这通常意味着将代码放入方法中，而不是内联在 `body` 属性中，但也常常意味着将功能拆分到单独的 `@Observable` 类中。

这些规则有助于确保代码高效且长期运行良好。


## 共享状态

- 除非项目已配置 Main Actor 默认 Actor 隔离，否则 `@Observable` 类必须标记为 `@MainActor`。标记任何缺少此注解的 `@Observable` 类。
- 所有共享数据应使用 `@Observable` 类，配合 `@State`（用于所有权）和 `@Bindable` / `@Environment`（用于传递）。
- 强烈建议不要使用 `ObservableObject`、`@Published`、`@StateObject`、`@ObservedObject` 或 `@EnvironmentObject`，除非无法避免，或者它们存在于遗留/集成上下文中且更改架构会很复杂。


## 本地状态

- `@State` 应标记为 `private`，并且仅由创建它的视图所拥有。
- 如果视图存储了一个包含昂贵重新计算数据的类实例，例如 `CIContext`，即使它不是可观察对象，也可以使用 `@State` 存储。这实际上是将 `@State` 用作缓存——持久地存储某些内容，但因为它不是可观察对象，所以不会对其进行任何更改跟踪。


## 绑定

- 强烈建议避免在视图 body 代码中使用 `Binding(get:set:)` 创建绑定。使用 `@State`、`@Binding` 等提供的绑定要干净和简单得多，然后使用 `onChange()` 来触发任何效果。
- 如果用户需要在 `TextField` 中输入数字，请将 `TextField` 绑定到 `Int` 或 `Double` 等数值，然后使用其 `format` 初始化器，如下所示：`TextField("Enter your score", value: $score, format: .number)`。根据情况应用 `.keyboardType(.numberPad)`（用于整数）或 `.keyboardType(.decimalPad)`（用于浮点数）。仅使用修饰符是*不够的*。


## 处理数据

- 优先让结构体遵循 `Identifiable`，而不是在 SwiftUI 代码中使用 `id: \.someProperty`。
- 永远不要尝试在 `@Observable` 类内部使用 `@AppStorage`，即使标记了 `@ObservationIgnored`——当发生更改时，它*不会*触发视图更新。


## SwiftData

- 如果你只需要匹配查询的项目数量，可以考虑使用 `ModelContext.fetchCount()` 配合 fetch 描述符。除非有其他东西触发了更新（如 `@Query`），否则当数据更改时它*不会*实时更新，因此应谨慎使用。

如需更多 SwiftData 帮助，建议使用 [SwiftData Pro agent skill](https://github.com/twostraws/swiftdata-agent-skill)。

## 如果项目使用 SwiftData 配合 CloudKit

- 永远不要使用 `@Attribute(.unique)`。
- 模型属性必须始终具有默认值或标记为可选型。
- 所有关系必须标记为可选型。
