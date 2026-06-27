# 关系与继承

## 关系策略

- 对静态的、应用定义的分类使用枚举（`Codable`）。
- 对由用户或外部系统创建的动态数据使用模型间关系。

## `@Relationship` 要点

关键参数：

- `deleteRule`：拥有者删除时的行为（`nullify`、`cascade`、`deny`、`noAction`）。
- `inverse`：反向键路径，用于维护对象图一致性。
- `minimumModelCount` 和 `maximumModelCount`：可选的基数约束。
- `originalName`：为重命名的关系提供迁移映射支持。

默认删除规则为 `.nullify`。

重要细节：

- 如果关系属性是可选型，min/max 强制约束仅在属性非 `nil` 时生效。

## 删除规则指导

- 当关联数据没有独立价值时使用 `.cascade`。
- 当关联数据能在父对象之外存活时使用 `.nullify`。
- 当存在依赖对象时必须阻止父对象删除，使用 `.deny`。
- 发布前用测试验证删除行为。

## 继承指导

当存在强 IS-A 模型时使用继承：

- `BusinessTrip` 是一个 `Trip`。
- `PersonalTrip` 是一个 `Trip`。

在以下情况避免继承：

- 特化过于微小，更适合用字段/枚举表示；
- 查询模型纯粹是浅层的，只会针对子类查询并重复父类字段。

继承通常适合混合的深层 + 浅层查询需求。

## 跨层级查询

- 基类查询用于跨共享字段的广泛搜索。
- 类型过滤谓词用于仅子类型的视图：
  - `#Predicate { $0 is BusinessTrip }`
  - `#Predicate { $0 is PersonalTrip }`

## 主要文档

- https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes
- https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:)
- https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum
- https://developer.apple.com/documentation/swiftdata/adopting-inheritance-in-swiftdata
