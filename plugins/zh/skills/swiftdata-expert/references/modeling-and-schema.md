# 建模与 Schema

## 核心规则

- 用 `@Model` 标注可持久化的类。
- 将模型代码视为 schema 的唯一事实来源。
- 当类型受支持时，非计算型存储属性默认会被持久化。
- 使用原始类型和 `Codable` 值类型作为持久化属性。
- 计算属性实际上等同于 transient。

## 属性设计

在需要时使用 `@Attribute(...)` 覆盖默认行为：

- `.unique`：对单个属性强制唯一性。
- `.preserveValueOnDeletion`：删除后在历史墓碑中保留选定的值。
- `.spotlight`、`.allowsCloudEncryption`、`.externalStorage`：仅在产品需求证明其合理性时使用。
- `originalName`：为重命名的属性建立映射以保持迁移连续性。
- `hashModifier`：用于迁移场景的高级 schema 哈希覆盖。

仅在行为与默认值不同时才使用显式标注。

## 唯一性与索引宏（iOS 18+）

对于 iOS 18+ 目标，优先在模型作用域使用独立宏：

- `#Unique<Model>([\.id], [\.name, \.date])` 用于单一或复合唯一性约束。
- `#Index<Model>([\.date], [\.status, \.date])` 用于面向查询的二进制索引。
- `#Index<Model>(...)` 使用带类型的索引变体以支持高级索引模式。

注意：

- `#Unique` 支持 to-one 关系属性，不支持关联模型数组。
- 保持索引定义与实际查询谓词和排序键对齐。

## 关系即 Schema

- 当数据是动态的且属于另一个模型时，使用 `@Relationship(...)`。
- 当关联数据是静态的且由应用定义时，使用枚举（`Codable`）。
- 在需要清晰表达时显式设置 `inverse`。
- 将删除规则视为领域规则，而非实现细节。

## Transient 数据

对仅运行时使用、不可存储的状态使用 `@Transient`。

- 对于非可选型 transient 属性，提供一个默认值。
- 将网络/加载/UI 标志保持为 transient。

## Schema 可用性与规划

- 基础 SwiftData 模型宏从 iOS 17 起可用。
- `#Unique` 和 `#Index` 从 iOS 18 起可用。
- 继承支持出现在较新的更新和示例中（在共享代码路径中采用前请检查部署目标）。

## 示例模式

```swift
@Model
final class Trip {
    #Unique<Trip>([\.externalID])
    #Index<Trip>([\.startDate], [\.destination, \.startDate])

    @Attribute(.unique) var externalID: String
    var destination: String
    var startDate: Date

    @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
    var activities: [Activity] = []

    @Transient var isExpanded = false
}
```

## 主要文档

- https://developer.apple.com/documentation/swiftdata/model()
- https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:)
- https://developer.apple.com/documentation/swiftdata/unique(_:)
- https://developer.apple.com/documentation/swiftdata/index(_:)-74ia2
- https://developer.apple.com/documentation/swiftdata/index(_:)-7d4z0
- https://developer.apple.com/documentation/swiftdata/transient()
