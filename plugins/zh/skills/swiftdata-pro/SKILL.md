---
name: swiftdata-pro
description: 编写、审查和改进 SwiftData 代码，使用现代 API 和最佳实践。在读取、编写或审查使用 SwiftData 的项目时使用。
license: MIT
metadata:
  author: Paul Hudson
  version: "1.0"
---

编写和审查 SwiftData 代码，确保其正确性、现代 API 使用以及对项目约定的遵循。仅报告真实存在的问题——不要吹毛求疵或凭空捏造问题。

审查流程：

1. 使用 `references/core-rules.md` 检查 SwiftData 核心问题。
1. 使用 `references/predicates.md` 检查谓词是否安全且受支持。
1. 如果项目使用 CloudKit，使用 `references/cloudkit.md` 检查 CloudKit 特有的约束。
1. 如果项目目标为 iOS 18+，使用 `references/indexing.md` 检查索引优化机会。
1. 如果项目目标为 iOS 26+，使用 `references/class-inheritance.md` 检查类继承模式。

如果只做部分工作，仅加载相关的参考文件。


## 核心说明

- 目标为 Swift 6.2 或更高版本，使用现代 Swift 并发。
- 用户强烈倾向于全面使用 SwiftData。除非是 SwiftData 无法解决的功能，否则不要建议使用 Core Data。
- 未经询问，不要引入第三方框架。
- 使用一致的项目结构，文件夹布局由应用功能决定。


## 输出格式

如果用户要求审查，按文件组织发现的问题。对于每个问题：

1. 说明文件和相关的行号。
2. 指出被违反的规则。
3. 展示简短的修改前后代码对比。

跳过没有问题的文件。最后给出一个按优先级排列的总结，列出最应优先处理的影响最大的改动。

如果用户要求你编写或改进代码，遵循上述相同规则，但直接进行修改，而不是返回问题报告。

示例输出：

### Destination.swift

**第 8 行：为关系添加显式的删除规则。**

```swift
// 修改前
var sights: [Sight]

// 修改后
@Relationship(deleteRule: .cascade, inverse: \Sight.destination) var sights: [Sight]
```

**第 22 行：不要在谓词中使用 `isEmpty == false`——它会在运行时崩溃。请改用 `!`。**

```swift
// 修改前
#Predicate<Destination> { $0.sights.isEmpty == false }

// 修改后
#Predicate<Destination> { !$0.sights.isEmpty }
```

### DestinationListView.swift

**第 5 行：`@Query` 只能在 SwiftUI 视图内部使用。**

```swift
// 修改前
class DestinationStore {
    @Query var destinations: [Destination]
}

// 修改后
class DestinationStore {
    var modelContext: ModelContext

    func fetchDestinations() throws -> [Destination] {
        try modelContext.fetch(FetchDescriptor<Destination>())
    }
}
```

### 总结

1. **数据丢失（高）：** Destination.swift 第 8 行缺少删除规则，意味着删除目的地时景点将成为孤立对象。
2. **崩溃（高）：** 第 22 行的 `isEmpty == false` 会在运行时崩溃——请改用 `!isEmpty`。
3. **行为错误（高）：** DestinationListView.swift 第 5 行的 `@Query` 仅在 SwiftUI 视图内部有效。

示例结束。


## 参考文件

- `references/core-rules.md` - 自动保存、关系、删除规则、属性限制和 FetchDescriptor 优化。
- `references/predicates.md` - 受支持的谓词操作、会在运行时崩溃的危险模式，以及不受支持的方法。
- `references/cloudkit.md` - CloudKit 特有的约束，包括唯一性、可选性和最终一致性。
- `references/indexing.md` - iOS 18+ 的数据库索引，包括单属性索引和复合属性索引。
- `references/class-inheritance.md` - iOS 26+ 的模型子类化，包括 `@available` 要求、模式设置和谓词过滤。
