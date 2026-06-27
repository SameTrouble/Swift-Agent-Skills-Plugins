---
name: swiftui-ui-patterns
description: 构建 SwiftUI 视图与组件的最佳实践和示例驱动指南，涵盖导航层级、自定义视图修饰符，以及基于栈和网格的响应式布局。在创建或重构 SwiftUI UI、设计 TabView 标签页架构、用 VStack/HStack 组合屏幕、管理 @State 或 @Binding、构建声明式 iOS 界面，或需要组件级模式与示例时使用。
---

# SwiftUI UI 模式

## 快速开始

根据你的目标选择一条路线：

### 现有项目

- 识别功能或屏幕及其主要交互模式（列表、详情、编辑器、设置、标签页）。
- 在仓库中用 `rg "TabView\("` 等命令查找相近示例，然后阅读最接近的 SwiftUI 视图。
- 遵循本地约定：优先使用 SwiftUI 原生状态，尽可能保持状态局部化，并通过环境注入共享依赖。
- 从 `references/components-index.md` 中选择相关组件参考并遵循其指引。
- 如果交互方式是通过拖拽或滚动主内容来露出次要内容，在手动实现手势之前先阅读 `references/scroll-reveal.md`。
- 用小型、聚焦的子视图和 SwiftUI 原生数据流来构建视图。

### 新项目脚手架

- 从 `references/app-wiring.md` 开始，连接 TabView + NavigationStack + sheets。
- 基于提供的骨架添加一个最小的 `AppTab` 和 `RouterPath`。
- 根据你首先需要的 UI（TabView、NavigationStack、Sheets）选择下一个组件参考。
- 随着新屏幕的添加，扩展路由和 sheet 枚举。

## 通用规则

- 使用现代 SwiftUI 状态（`@State`、`@Binding`、`@Observable`、`@Environment`），避免不必要的视图模型。
- 如果部署目标包含 iOS 16 或更早版本，且无法使用 iOS 17 引入的 Observation API，则回退到 `ObservableObject`：根所有权用 `@StateObject`，注入观察用 `@ObservedObject`，`@EnvironmentObject` 仅用于真正共享的应用级状态。
- 优先使用组合；保持视图小型且聚焦。
- 使用 async/await 配合 `.task` 和显式的加载/错误状态。关于重启、取消和防抖的指引，阅读 `references/async-state.md`。
- 将共享的应用服务放在 `@Environment` 中，但对于功能局部依赖和模型，优先使用显式初始化器注入。关于根连接模式，阅读 `references/app-wiring.md`。
- 优先选择适合部署目标的最新 SwiftUI API，并在某个模式依赖某版本时注明最低 OS 要求。
- 仅在编辑遗留文件时保留现有遗留模式。
- 遵循项目的格式化工具和风格指南。
- **Sheets**：当状态表示一个选中的模型时，优先使用 `.sheet(item:)` 而非 `.sheet(isPresented:)`。避免在 sheet body 内部使用 `if let`。Sheet 应自己持有其操作，并在内部调用 `dismiss()`，而不是转发 `onCancel`/`onConfirm` 闭包。
- **滚动驱动的露出**：优先从滚动偏移量派生一个归一化的进度值，并从这一单一数据源驱动视觉状态。除非单独滚动无法表达该交互，否则避免并行的手势状态机。

## 状态所有权总结

使用与所有权模型匹配的最窄状态工具：

| 场景 | 首选模式 |
| --- | --- |
| 由一个视图拥有的局部 UI 状态 | `@State` |
| 子视图修改父视图拥有的值类型状态 | `@Binding` |
| iOS 17+ 上根视图拥有的引用类型模型 | `@State` 配合 `@Observable` 类型 |
| iOS 17+ 上子视图读取或修改注入的 `@Observable` 模型 | 作为存储属性显式传入 |
| 共享的应用服务或配置 | `@Environment(Type.self)` |
| iOS 16 及更早版本上的遗留引用类型模型 | 根视图用 `@StateObject`，注入时用 `@ObservedObject` |

先确定所有权位置，再选择包装器。当普通值类型状态足够时，不要引入引用类型模型。

## 横切参考

- `references/navigationstack.md`：导航所有权、每个标签页的历史记录和枚举路由。
- `references/sheets.md`：集中式模态展示和枚举驱动的 sheets。
- `references/deeplinks.md`：URL 处理以及将外部链接路由到应用目标。
- `references/app-wiring.md`：根依赖图、环境使用和应用外壳连接。
- `references/async-state.md`：`.task`、`.task(id:)`、取消、防抖和异步 UI 状态。
- `references/previews.md`：`#Preview`、测试夹具、mock 环境和隔离的预览设置。
- `references/performance.md`：稳定标识、观察范围、惰性容器和渲染成本护栏。

## 反模式

- 巨型视图将布局、业务逻辑、网络请求、路由和格式化混在一个文件中。
- 用多个布尔标志表示互斥的 sheets、alerts 或导航目标。
- 在 `body` 驱动的代码路径中直接进行实时服务调用，而不是使用视图生命周期钩子或注入的模型/服务。
- 用 `AnyView` 绕过本应通过更好的组合来解决的类型不匹配问题。
- 在没有明确所有权理由的情况下，将每个共享依赖默认放到 `@EnvironmentObject` 或全局路由器中。

## 新 SwiftUI 视图的工作流

1. 在编写 UI 代码之前，定义视图的状态、所有权位置和最低 OS 假设。
2. 识别哪些依赖属于 `@Environment`，哪些应保持为显式初始化器输入。
3. 勾勒视图层级、路由模型和展示点；将重复部分提取为子视图。对于复杂导航，阅读 `references/navigationstack.md`、`references/sheets.md` 或 `references/deeplinks.md`。**在继续之前构建并验证无编译器错误。**
4. 用 `.task` 或 `.task(id:)` 实现异步加载，并在需要时添加显式的加载和错误状态。当工作依赖于变化的输入或取消时，阅读 `references/async-state.md`。
5. 为主次状态添加预览，并在 UI 可交互时添加无障碍标签或标识符。当视图需要测试夹具或注入的 mock 依赖时，阅读 `references/previews.md`。
6. 通过构建来验证：确认无编译器错误，检查预览能无崩溃地渲染，确保状态变化正确传播，并合理检查列表标识和观察范围不会导致可避免的重新渲染。如果屏幕较大、滚动密集或频繁更新，阅读 `references/performance.md`。对于常见的 SwiftUI 编译错误——缺少 `@State` 注解、歧义的 `ViewBuilder` 闭包，或不匹配的泛型类型——在更新调用点之前先解决它们。**如果构建失败：**仔细阅读错误信息，修复已识别的问题，然后重新构建后再继续下一步。如果预览崩溃，隔离有问题的子视图，确认其状态初始化有效，并在继续之前重新运行预览。

## 组件参考

使用 `references/components-index.md` 作为入口。每个组件参考应包含：
- 意图和最适配的场景。
- 遵循本地约定的最小用法模式。
- 陷阱和性能注意事项。
- 当前仓库中已有示例的路径。

## 添加新的组件参考

- 创建 `references/<component>.md`。
- 保持简短且可操作；链接到当前仓库中的具体文件。
- 在 `references/components-index.md` 中用新条目更新。
