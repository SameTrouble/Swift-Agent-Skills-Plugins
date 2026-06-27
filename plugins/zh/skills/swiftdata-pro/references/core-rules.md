# 核心规则

- SwiftData 最初发布时，会积极地自动保存模型上下文。此后，自动保存的频率降低且变得难以预测，因此许多开发者更倾向于在正确性至关重要时显式调用 `save()`。
- 保存前无需检查 `modelContext.hasChanges`；直接调用 `save()` 即可。
- `ModelContext` 和模型实例绝不能跨越 actor 边界。模型容器和持久化标识符*是* Sendable 的，因此如果需要将模型实例跨 actor 传递，应传递其标识符，并在目标上下文中重新获取。如需 Swift 并发方面的更多帮助，建议参考 [Swift Concurrency Pro agent skill](https://github.com/twostraws/swift-concurrency-agent-skill)。
- 使用 `@Relationship` 定义从一个模型到另一个模型的关系时，仅将宏放在关系的一侧。尝试在两侧同时使用会导致循环引用。
- 持久化标识符在首次保存之前是临时的。临时 ID 以小写字母 "t" 开头，模型在首次保存后会获得一个新的 ID。因此，在依赖对象 ID 之前必须先保存该对象。
- 不要在任何 `@Model` 类中尝试使用 `description` 作为属性名；这是明确禁止的。
- 不要尝试在 `@Model` 类中添加属性观察者；它们会被静默忽略。
- `@Attribute(.externalStorage)` 是一个*建议*，而非*要求*，且仅适用于 `Data` 类型的属性——SwiftData 会自行判断最佳处理方式。
- `@Transient` 属性不会被持久化，且必须有默认值。当对象从存储中取出时，它们会重置为该默认值。如果值是从其他存储属性派生而来，使用计算属性通常是更好的选择——仅当值的计算成本较高时才使用 `@Transient`。
- 几乎总是应该准备好特定的迁移模式，即使项目只涉及轻量级迁移。
- 几乎总是应该为关系设置显式的删除规则。最常见的是 `@Relationship(deleteRule: .cascade)`，但也有其他选项。默认值是 `.nullify`，即当父对象被删除时，将相关模型的引用设为 nil。这可能导致孤立对象，或者如果属性是非可选型的则会崩溃。
- 不要尝试在 SwiftUI 视图之外使用 `@Query`；它专为在视图*内部*工作而设计，在外部无法正常运行。如需 SwiftUI 方面的更多帮助，建议参考 [SwiftUI Pro agent skill](https://github.com/twostraws/swiftui-agent-skill)。
- 如果只需要匹配查询的项的数量，考虑使用 `ModelContext.fetchCount()` 配合 fetch descriptor。当数据发生变化时，它*不会*实时更新，除非有其他东西触发了更新（例如 `@Query`），因此应谨慎使用。
- 使用 `FetchDescriptor` 时，有时设置 `relationshipKeyPathsForPrefetching` 属性是有益的。它默认为空数组，但如果知道某些关系会被使用，预先获取它们会更高效。
- 类似地，你应该考虑设置 `propertiesToFetch`，这样只会实际获取被使用的属性。（默认获取所有属性。）
- SwiftData 经常在反向关系上出错，因此通过在 `@Relationship` 宏中指定确切的反向关系来显式声明几乎总是个好主意。
- 不要对每个模型编写多次 `#Unique`；每个模型只能有一个，放置在模型类内部。如果需要多个唯一性约束，在单个 `#Unique` 中将它们作为独立的键路径数组传入，例如 `#Unique<Foo>([\.email], [\.username])`。
- 存储在模型中的枚举属性必须遵循 `Codable`。有些 agent 会坚持认为带有关联值的枚举不受支持，但这是错误的——它们完全可以正常工作。
