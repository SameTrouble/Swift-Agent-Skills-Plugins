---
name: swiftui-pro
description: 全面审查 SwiftUI 代码的现代 API 使用、可维护性和性能最佳实践。在阅读、编写或审查 SwiftUI 项目时使用。
license: MIT
metadata:
  author: Paul Hudson
  version: "1.1"
---

审查 Swift 和 SwiftUI 代码的正确性、现代 API 使用情况，以及是否符合项目规范。仅报告真实存在的问题——不要吹毛求疵或凭空捏造问题。

审查流程：

1. 使用 `references/api.md` 检查是否使用了已弃用的 API。
1. 使用 `references/views.md` 检查视图、修饰符和动画是否已优化编写。
1. 使用 `references/data.md` 验证数据流配置是否正确。
1. 使用 `references/navigation.md` 确保导航方式是最新的且性能良好。
1. 使用 `references/design.md` 确保代码采用了符合 Apple《人机交互指南》的无障碍设计。
1. 使用 `references/accessibility.md` 验证无障碍合规性，包括 Dynamic Type、VoiceOver 和 Reduce Motion。
1. 使用 `references/performance.md` 确保代码能够高效运行。
1. 使用 `references/swift.md` 对 Swift 代码进行快速验证。
1. 使用 `references/hygiene.md` 进行最终的代码规范检查。

如果是部分审查，只需加载相关的参考文件即可。


## 核心说明

- iOS 26 已经发布，是新应用的默认部署目标。
- 目标为 Swift 6.2 或更高版本，使用现代 Swift 并发。
- 作为 SwiftUI 开发者，用户会希望避免使用 UIKit，除非有明确要求。
- 在未事先询问的情况下，不要引入第三方框架。
- 将不同类型拆分到不同的 Swift 文件中，而不是将多个结构体、类或枚举放在同一个文件里。
- 使用一致的项目结构，文件夹布局由应用功能决定。


## 输出格式

按文件组织审查结果。对于每个问题：

1. 说明文件和相关的行号。
2. 指出被违反的规则（例如"使用 `foregroundStyle()` 而非 `foregroundColor()`"）。
3. 展示简要的修改前/修改后代码修复方案。

跳过没有问题的文件。最后按优先级总结最应该优先执行的改动。

输出示例：

### ContentView.swift

**第 12 行：使用 `foregroundStyle()` 而非 `foregroundColor()`。**

```swift
// Before
Text("Hello").foregroundColor(.red)

// After
Text("Hello").foregroundStyle(.red)
```

**第 24 行：仅含图标的按钮对 VoiceOver 不友好——应添加文本标签。**

```swift
// Before
Button(action: addUser) {
    Image(systemName: "plus")
}

// After
Button("Add User", systemImage: "plus", action: addUser)
```

**第 31 行：避免在视图 body 中使用 `Binding(get:set:)`——应改用 `@State` 配合 `onChange()`。**

```swift
// Before
TextField("Username", text: Binding(
    get: { model.username },
    set: { model.username = $0; model.save() }
))

// After
TextField("Username", text: $model.username)
    .onChange(of: model.username) {
        model.save()
    }
```

### 总结

1. **无障碍（高）：** 第 24 行的添加按钮对 VoiceOver 不可见。
2. **已弃用 API（中）：** 第 12 行的 `foregroundColor()` 应改为 `foregroundStyle()`。
3. **数据流（中）：** 第 31 行的手动绑定脆弱且难以维护。

示例结束。


## 参考资料

- `references/accessibility.md` - Dynamic Type、VoiceOver、Reduce Motion 等无障碍要求。
- `references/api.md` - 更新代码以使用现代 API，以及它所替换的已弃用代码。
- `references/design.md` - 构建符合 Apple《人机交互指南》的无障碍应用的指导。
- `references/hygiene.md` - 使代码干净编译并长期可维护。
- `references/navigation.md` - 使用 `NavigationStack`/`NavigationSplitView` 进行导航，以及提醒、确认对话框和表单。
- `references/performance.md` - 优化 SwiftUI 代码以获得最佳性能。
- `references/data.md` - 数据流、共享状态和属性包装器。
- `references/swift.md` - 编写现代 Swift 代码的技巧，包括有效使用 Swift 并发。
- `references/views.md` - 视图结构、组合和动画。
