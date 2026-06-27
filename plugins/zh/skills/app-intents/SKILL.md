---
name: app-intents
description: 编写和审查 Swift App Intents 代码，将 App 的操作和数据暴露给 Siri、Shortcuts、Spotlight、小组件、控制中心和 Apple Intelligence。在添加 AppIntent、AppEntity、OpenIntent、AppShortcutsProvider、EntityQuery、Focus Filters、AssistantEntity/AssistantIntent schema、屏幕感知、LongRunningIntent/CancellableIntent、EntityCollection、SyncableEntity、AppIntentsTesting，或将 SwiftData/网络数据接入 intent 时使用。
license: MIT
metadata:
  author: Anton Novoselov
  version: "1.2.0"
---

编写和审查通过 App Intents 框架暴露 App 功能的 Swift 代码，确保正确的协议遵循、安全的数据流和地道的可发现性接入。

审查流程：

1. 使用 `references/fundamentals.md` 检查 intent 基础（协议、`perform()`、返回类型、对话）。
2. 使用 `references/parameters.md` 验证参数和参数选项。
3. 使用 `references/entities.md` 验证 entity 类型、显示表示和查询。
4. 使用 `references/shortcuts-and-siri.md` 检查 `AppShortcutsProvider` 注册和可发现性 UI。
5. 使用 `references/open-and-snippet-intents.md` 验证 `OpenIntent` 导航和 snippet 视图返回类型。
6. 使用 `references/dependencies.md` 检查依赖注入和数据控制器模式。
7. 使用 `references/spotlight.md` 验证通过 `IndexedEntity`、`IndexedEntityQuery` 和 attribute set 进行的 Spotlight 索引。
8. 使用 `references/assistant-schemas.md` 检查 `@AssistantEntity` / `@AssistantIntent` schema 采纳。
9. 使用 `references/siri-intelligence.md` 验证 Siri / Apple Intelligence 集成（查找内容、自定义响应、捐赠、确认、所有权）。
10. 使用 `references/onscreen-awareness.md` 检查屏幕感知和内容传递（视图标注、`IntentValueRepresentation`、系统集成标注）。
11. 对于运行超过 30 秒、需要处理取消或针对特定进程的 intent，使用 `references/long-running-and-execution.md`。
12. 如果正在编写或审查 intent 的测试，使用 `references/testing-intents.md`（涵盖新的 `AppIntentsTesting` 框架）。
13. 使用 `references/anti-patterns.md` 捕获常见错误。

如果是部分工作，只加载相关的参考文件。


## 按任务路由

将用户目标与阅读顺序匹配。只加载你需要的。

### "创建我的第一个 App Intent"
1. `references/fundamentals.md` - 协议、`perform()`、返回类型
2. `references/shortcuts-and-siri.md` - 注册使其显示出来

### "添加用户在 Shortcuts 中选择的参数"
1. `references/parameters.md` - `@Parameter`、提示、消歧
2. `references/entities.md` - 如果参数是领域 entity

### "让我的 App 数据可从 Siri / Spotlight 搜索"
1. `references/entities.md` - `AppEntity`、`IndexedEntity`、`@Property`
2. `references/spotlight.md` - 索引策略、attribute set
3. `references/shortcuts-and-siri.md` - 灵活匹配、短语规则

### "Siri 运行我的 intent 时显示摘要/交互视图"
1. `references/open-and-snippet-intents.md` - 内联 vs 间接 snippet、`SnippetIntent`、`Button(intent:)`
2. `references/fundamentals.md` - 返回类型和 snippet 设计规则

### "从 Siri / Shortcuts 在我的 App 中打开特定内容"
1. `references/open-and-snippet-intents.md` - `OpenIntent`、`URLRepresentableIntent`、`TargetContentProvidingIntent`
2. `references/dependencies.md` - 导航器/场景路由

### "将我的 App 内容和操作带给 Siri / Apple Intelligence"
1. `references/siri-intelligence.md` - 集成模型、查找内容（语义索引/结构化搜索/App 内搜索）、自定义响应、捐赠、确认/所有权
2. `references/assistant-schemas.md` - schema 宏、领域、多 schema 要求、Xcode 代码片段
3. `references/onscreen-awareness.md` - 视图标注、内容传递、系统集成标注

### "集成 Apple Intelligence"
1. `references/assistant-schemas.md` - schema 宏、领域、Use Model 操作、屏幕内容
2. `references/entities.md` - `@Property`、`Transferable`（多个 schema 必需）

### "让 Siri 理解屏幕上的内容"
1. `references/onscreen-awareness.md` - 4 个标注 API、内容传递、`displayRepresentations` 快速路径、通知/Now Playing/AlarmKit 上的标注
2. `references/siri-intelligence.md` - 屏幕上下文如何融入更大的 Siri 故事

### "让我的 intent 运行超过 30 秒或针对特定进程"
1. `references/long-running-and-execution.md` - `LongRunningIntent`、`CancellableIntent`、`allowedExecutionTargets`、后台 GPU
2. `references/fundamentals.md` - `ProgressReportingIntent`、`supportedModes`

### "高效处理大量 entity / 跨设备同步"
1. `references/parameters.md` - `EntityCollection`（仅标识符参数）
2. `references/entities.md` - `SyncableEntity` 用于跨设备身份、`RelevantEntities` 用于主动建议

### "支持 Visual Intelligence / 图像搜索"
1. `references/assistant-schemas.md` - `IntentValueQuery`、`SemanticContentDescriptor`、`@UnionValue`
2. `references/entities.md` - `Transferable` + `OpenIntent` 配对

### "构建交互式小组件或控制中心控件"
1. `references/open-and-snippet-intents.md` - `Button(intent:)`、`WidgetConfigurationIntent`、`ControlConfigurationIntent`、`ControlWidgetButton`
2. `references/dependencies.md` - App Group 共享存储、进程边界

### "围绕 App Intents 组织我的 App"
1. `references/fundamentals.md` - intent 作为规范操作层
2. `references/dependencies.md` - `@Dependency`、跨模块 `AppIntentsPackage`
3. `references/entities.md` - entity 作为桥接的模式

### "测试我的 App Intents"
1. `references/testing-intents.md` - `AppIntentsTesting` 框架（进程外集成）、直接结构体单元测试、mock `@Dependency`、仅测试 intent、无法测试的内容

### "遇到构建错误或运行时 bug"
1. `references/anti-patterns.md` - 35+ 个捕获点及修改前后修复


## 决策树

当你知道任务但不确定正确的 API 时的快速定位。

### 我应该遵循哪个 intent 协议？

```
通用操作？
  → AppIntent

打开 App 到特定 entity？
  → OpenIntent（iOS 上 + TargetContentProvidingIntent）

只渲染交互视图，没有业务逻辑？
  → SnippetIntent

需要有条件地将 App 带到前台？
  → AppIntent with supportedModes (iOS 26+)
  → 或 ForegroundContinuableIntent (iOS 17-18)

运行超过 30 秒（上传、同步、推理）？
  → LongRunningIntent + performBackgroundTask (iOS 27+)

需要在取消时优雅清理（带原因）？
  → CancellableIntent + withIntentCancellationHandler (iOS 26.4+)

删除 entity 并带标准确认？
  → DeleteIntent

将搜索查询路由到 App 中？
  → ShowInAppSearchResultsIntent

支撑小组件配置？
  → WidgetConfigurationIntent（空遵循，无 perform）

支撑控制中心控件？
  → ControlConfigurationIntent

有通用链接 URL 表示？
  → URLRepresentableIntent + OpenIntent（无需 perform）

匹配 Apple Intelligence 领域？
  → AppIntent + @AppIntent(schema: .domain.action)
```

### 我应该使用哪种 entity 类型？

```
编译时已知的固定集合？
  → AppEnum

有持久化 id 的动态数据？
  → AppEntity

Entity 必须出现在 Spotlight？
  → AppEntity + IndexedEntity

Entity 就是文件（扫描、语音备忘、导出图像）？
  → FileEntity

无稳定 id 的计算/聚合数据？
  → TransientAppEntity

需要 Apple Intelligence schema 感知？
  → AppEntity + @AppEntity(schema: .domain.type)

支持跨 App 分享？
  → AppEntity + Transferable
```

### 我的 entity 应该使用哪种查询？

```
小固定集合，可枚举？
  → EnumerableEntityQuery（同时获得基本 Find intent）

大数据集，按名称可搜索？
  → EntityQuery + EntityStringQuery

多个可查询属性，用户应该构建谓词？
  → EntityPropertyQuery（自动生成带比较器+排序的 Find intent）

简单仅 id 查找，无搜索？
  → UniqueIDEntityQuery

在 Spotlight 中索引并希望重建索引支持？
  → IndexedEntityQuery (iOS 27+)

无法提前索引的结构化 Siri 搜索？
  → IntentValueQuery（结构化输入，通过 @UnionValue 返回 1+ 种 entity 类型）

视觉智能/图像搜索？
  → IntentValueQuery + SemanticContentDescriptor
```

### Siri 应该如何查找我的内容？

```
内容是本地的且可索引？
  → IndexedEntity + indexAppEntities（语义索引）- 主要路径
  → 添加 IndexedEntityQuery 获得重建索引支持 (iOS 27+)

太大/服务端/太易变无法索引？
  → IntentValueQuery（结构化搜索输入）

用户想在你自己的 UI 中搜索？
  → @AppIntent(schema: .system.searchInApp) + ShowInAppSearchResultsIntent

没人找到或使用过但现在相关的内容？
  → RelevantEntities.updateEntities(_:for:) (iOS 27+)

教系统人们如何使用 App（模式）？
  → IntentDonationManager（捐赠 UI 交互）
```

### 我应该在 entity 字段上使用哪个属性包装器？

```
存储在 entity 结构体上，应出现在 Shortcuts/Find/摘要中？
  → @Property

从底层 model 对象派生（计算成本低）？
  → @ComputedProperty（比 @Property 更适合包装 model）

派生且应在 Spotlight 中索引？
  → @ComputedProperty(indexingKey: \.keyName)

计算成本高（网络、ML 推理、重查询）？
  → @DeferredProperty（异步 getter，仅在系统询问时运行）

Entity 内部，不在任何地方显示？
  → 普通存储属性（无包装器）
```


## 核心指令

- App Intents 最低支持 iOS 16+ / macOS 13+。`IndexedEntity`、`OpenIntent`、focus filters 和控制小组件需要 iOS 16+；`@AssistantEntity` / `@AssistantIntent` schema 需要 iOS 18.2+；锚定相对日期样式和许多 assistant schema 需要 iOS 18.4+。**27 发布**（WWDC 2026，iOS 27 / macOS 27）增加了 `LongRunningIntent`、`EntityCollection`、`SyncableEntity`、`RelevantEntities`、`IndexedEntityQuery`、`OwnershipProvidingEntity`、`allowedExecutionTargets`、`AppIntentsTesting` 框架和原生 `Duration`/`PersonNameComponents` 参数；`CancellableIntent` 和 `IntentValueRepresentation` 为 iOS 26.4+；`supportedModes` 为 iOS 26+。Apple 对 WWDC 2026 一代的官方称呼是"the 27 releases"——使用这个说法，而非 "iOS 19"。
- **绝不**要让 SwiftData `@Model` 类或其他引用类型数据模型遵循 `AppEntity`。`AppEntity` 要求 `Sendable`；`@Model` 类不是 sendable 的。创建一个单独的 `struct` entity 来映射你想暴露的字段。
- **绝不**要跨 actor 边界传递 `ModelContext`。`ModelContext` 不是 sendable 的。传递 `ModelContainer`（它是 sendable 的），在需要它的 actor 内部创建本地 context。
- **绝不**要仅通过写出 intent 类型将其暴露给 Siri/Spotlight，始终通过 `AppShortcutsProvider` 注册。未在那里注册的类型不会出现在 Shortcuts、Siri 建议或操作按钮选择器中。
- **绝不**要写不带 `\(.applicationName)` 插值的 Siri 激活短语。App Intents 宏在编译时拒绝不含 App 名称的短语，因为不含 App 名称的短语会与其他 App 的命令冲突。
- **绝不**要从 intent 内部回退到 SwiftUI `@Query`。`@Query` 只在 `View` 内部工作。改为通过 `ModelContext` 运行一次性 `FetchDescriptor`，或通过集中式数据控制器路由。
- **绝不**要在 `perform()` 内部实例化服务、数据存储或认证管理器。通过 `@Dependency` 注入它们，并在 `App.init()` 中用 `AppDependencyManager.shared.add(dependency:)` 注册一次。
- **绝不**要使用 `String(format:)` 或手动拼接进行本地化 intent 对话。使用 `LocalizedStringResource`，并在 `AttributedString` 中使用 Foundation 的语法一致性 markdown（`^[\(count) item](inflect: true)`）进行复数化。
- 对于"带我去这个东西"的操作优先使用 `OpenIntent`，对于自包含的一次性摘要优先使用 `AppIntent & ShowsSnippetView`，当 snippet 包含 `Button(intent:)` 且需要在按钮触发后重新渲染时使用 `AppIntent & ShowsSnippetIntent` + 配对的 `SnippetIntent`。
- 始终在仅支撑小组件按钮、snippet 按钮或其他 intent 的辅助 intent 上设置 `static let isDiscoverable: Bool = false`——否则它们会污染用户的 Shortcuts 库。
- 当 intent 修改了小组件或控制小组件显示的数据时，在 `perform()` 内部返回前调用 `WidgetCenter.shared.reloadAllTimelines()`。
- 当 `Button(intent:)` 位于小组件视图中时，通过 App Group `UserDefaults(suiteName:)` 或共享 `ModelContainer` URL 在 intent（在 App 进程中运行）和小组件的时间线提供者（在扩展进程中运行）之间共享状态——绝不使用 `UserDefaults.standard` 或内存中的 `@Dependency` 状态。
- 当出现在快捷方式短语键路径中的 entity 数据发生变化（创建、重命名、删除）时，调用 `YourShortcutsProvider.updateAppShortcutParameters()` 使缓存的候选列表失效。
- 当整个集合小且加载成本低时优先使用 `EnumerableEntityQuery`；当数据集大或可搜索时实现 `EntityQuery` + `EntityStringQuery`；添加 `EntityPropertyQuery` 可免费获得系统生成的 Find intent。`entities(for identifiers:)` 在每个查询上都是强制的；没有它，参数解析会中断。
- 用 `@Property`（存储）或 `@ComputedProperty`（派生）标记用户可能在参数摘要中过滤、排序或引用的 entity 字段。普通存储属性对 App Intents 框架不可见。
- 对于即时计算返回的数据（摘要、聚合）使用 `TransientAppEntity`。不要试图用假 id 将其塞进 `AppEntity`。
- 当 entity 已有通用链接 URL 时，让其遵循 `URLRepresentableEntity` 并让 open intent 遵循 `URLRepresentableIntent`——系统通过你现有的链接处理器路由打开，无需 `perform()`。
- 对于屏幕上可见且 Siri 应能理解的 entity，将视图上的 `.userActivity(_:element:)` 与 entity 上的 `Transferable` 遵循结合使用。仅识别不够；Siri 需要可导出的内容。
- `SnippetIntent.perform()` 在每次用户交互中被多次调用（初始显示、每次按钮点击后、外观变化时、`reload()` 时）。保持其纯净：读取状态、组装视图、返回。绝不要在 snippet intent 的 `perform()` 中修改 App 状态或启动慢操作。
- 遵守硬性限制：每个 App 10 个 `AppShortcut`，总计 1000 个触发短语（包括参数展开）。每个快捷方式数组中的第一个短语是主要短语——它显示在 Shortcuts 主页磁贴上，并作为 Siri "我能用 X 做什么？"的答案。
- 每个 App Shortcut 至少包含一个非参数化短语，使其在首次启动前就可发现；参数化短语在 App 至少运行一次并填充参数缓存前不会出现在 Spotlight 中。
- 对于有条件带到前台的新代码，优先使用 `supportedModes` + `continueInForeground`（iOS 26+）而非 `ForegroundContinuableIntent` / `needsToContinueInForegroundError`。较新的形式允许一个 intent 声明它可以根据运行时状态在后台或前台运行。
- Snippet 视图有 340 点高度上限；超过这个值，滚动会破坏概览叠加模型。链接到完整 App 以获取深度内容，并保持 snippet 文本大于系统默认值以在阅读距离上清晰可读。
- 对于可能接收 Apple Intelligence Use Model 操作输入的文本参数，将类型声明为 `AttributedString` 而非 `String`，这样富格式（粗体、斜体、列表、表格）可以无损保留。
- App 的 `App` 结构体初始化器在 intent 运行时执行，即使 UI 从未出现。在 `init()` 内部完成所有 intent 相关设置（`ModelContainer` 创建、`AppDependencyManager.shared.add(...)`、日志管道），而非在 `.task` 或 `.onAppear` 等视图修饰符内部。
- `LocalizedStringResource` 是 App Intents 中所有字符串的标准字符串类型（标题、对话、参数提示）。它与 SwiftUI 共享字符串目录，因此本地化开箱即用。
- 语法一致性（`inflect: true`）在英语、法语、德语、意大利语、西班牙语和葡萄牙语（两种变体）中工作。对于其他语言环境，它回退到未修改的形式。
- 从系统界面触发的 intent 有约 30 秒时间（macOS 无硬性限制）。对于上传、同步、大文件操作或设备端推理，遵循 `LongRunningIntent` 并在 `performBackgroundTask { ... }` 内部完成工作——并**定期报告 `progress`**，因为沉默会让系统撤销运行时扩展。与 `CancellableIntent` 配对以用取消原因清理。不要试图用 detached `Task` 超越限制；非托管任务不受扩展覆盖。
- 对于可能持有大量 entity 且 `perform()` 主要需要 id 的参数，使用 `EntityCollection<Entity>` 代替 `[Entity]`——它在参数处理期间跳过完整 entity 解析。仅在需要完整对象时调用 `resolvedEntities()`。
- 在基于 schema 的**更新** intent 中，用 `$parameter.valueState`（`.set(value)` / `.set(nil)` / `.unset`）区分"不改"和"清除"，而非简单的 `nil` 检查——否则语音命令永远无法清除字段。
- 当 Siri 可能引用跨设备对话中的 entity 时，让其遵循 `SyncableEntity`。如果 id 已在各处一致（服务端 UUID、CloudKit 记录 id），只需采纳协议；否则用 `SyncableEntityIdentifier` 配对本地和稳定 id。
- 让可分享的 entity 遵循 `OwnershipProvidingEntity` 并保持其 `ownership`（`.shared` / `.public`）为最新，这样 Siri 在用户分享或发布的内容上会进行确认。默认 Siri 假设 entity 是私有的，可能跳过确认。
- 要传递其他 App 能理解的结构化类型（坐标、联系人、名称），通过 `ValueRepresentation` 构建器向 entity 的 `transferRepresentation` 添加 `IntentValueRepresentation`——`FileRepresentation`/`DataRepresentation` 只覆盖文件格式。当 entity 已存储系统类型时使用键路径形式（`ValueRepresentation(exporting: \.place)`）。
- 对于屏幕感知，按形状选择标注：`.userActivity` 用于一个主要项目，`.appEntityIdentifier(_:)` 用于少数中的一个，`List`/集合上的 `.appEntityIdentifier(forSelectionType:)` 用于多个（惰性），`.appEntityUIElements(_:)` 用于自定义 `Canvas`/`CALayer` 绘制。通知、Now Playing 和 AlarmKit 上的标注需要真正的 `AppEntity`——`TransientAppEntity` 没有持久化 id，不能在那里使用。添加 `displayRepresentations` 查询方法让 Siri 无需完整数据库获取即可解析屏幕上的 entity。
- 用 `IntentDonationManager` 捐赠 **UI** 交互（系统已捐赠 Siri/Shortcuts 运行）；在操作完成后捐赠，不要过度捐赠（系统会开始忽略你），并删除过时捐赠。
- 使用 `AppIntentsTesting` 框架（进程外，在 XCUITest bundle 中）测试集成面——intent、查询、`spotlightQuery()`、`viewAnnotations()`；使用仅测试 intent（`isDiscoverable = false` + `#if DEBUG`）播种数据并到达内部状态。保留直接 `perform()` 结构体测试用于纯逻辑。


## 输出格式

如果用户要求审查，按文件组织发现。对于每个问题：

1. 说明文件和相关行号。
2. 指出被替换的反模式。
3. 展示简短的修改前后代码修复。

跳过没有问题的文件。以优先级排序的总结结束，列出最有影响力的修改。

如果用户要求你编写或修复 intent 代码，直接进行修改，而非返回发现报告。

示例输出：

### RecentItemsIntent.swift

**第 18 行：SwiftData `@Model` 不能遵循 `AppEntity`（不是 `Sendable`）。**

```swift
// Before
extension Article: AppEntity { ... }

// After
struct ArticleEntity: AppEntity {
    var id: UUID
    var title: String
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
```

**第 42 行：Siri 短语缺少 `\(.applicationName)`——将无法构建。**

```swift
// Before
AppShortcut(intent: OpenArticleIntent(), phrases: ["Open an article"], ...)

// After
AppShortcut(intent: OpenArticleIntent(), phrases: ["Open an article in \(.applicationName)"], ...)
```

### 总结

1. **Sendability（高）：** `Article` 作为 `AppEntity` 在 Swift 6 上将无法编译；创建映射结构体。
2. **Siri 短语（高）：** `\(.applicationName)` 在每个短语中都是必需的。

示例结束。


## 参考

- `references/fundamentals.md` - `AppIntent` 协议、`perform()`、返回类型（`IntentResult`、`ProvidesDialog`、`ReturnsValue`、`ShowsSnippetView`、`OpensIntent`）、intent 对话、语法一致性。
- `references/parameters.md` - `@Parameter`、基本类型 vs entity 参数、`@AppEnum`、对话选项、参数提示。
- `references/entities.md` - `AppEntity`、`IndexedEntity`、映射结构体模式、显示表示、entity 查询（`EnumerableEntityQuery`、`EntityQuery`、`EntityStringQuery`、`UniqueIDEntityQuery`）。
- `references/shortcuts-and-siri.md` - `AppShortcutsProvider`、短语（`\(.applicationName)` 规则）、`shortcutTileColor`、`SiriTipView`、`ShortcutsLink`、参数呈现。
- `references/open-and-snippet-intents.md` - `OpenIntent`、snippet 视图（`ShowsSnippetView`）、通过数据控制器的导航、何时使用哪个。
- `references/dependencies.md` - `@Dependency`、`AppDependencyManager`、数据控制器模式、`ModelContainer` vs `ModelContext` sendability、main-actor vs 本地 context 权衡。
- `references/spotlight.md` - `IndexedEntity`、`IndexedEntityQuery`（重建索引）、`CSSearchableIndex`、`attributeSet`、语义索引、启动时索引 vs 变更时索引、防抖重建索引。
- `references/assistant-schemas.md` - `@AssistantEntity`、`@AssistantIntent`、schema 采纳、多 schema 要求、`.system.searchInApp`、Visual Intelligence（iPad/macOS、系统存储）、Xcode 代码片段、注意事项。
- `references/siri-intelligence.md` - Siri / Apple Intelligence 集成模型：查找内容（语义索引/结构化搜索/App 内搜索）、自定义响应、交互捐赠、确认 + `OwnershipProvidingEntity`、验证流程。
- `references/onscreen-awareness.md` - 4 个屏幕标注 API、内容传递（`IntentValueRepresentation`、解析 vs 导入）、`displayRepresentations` 快速路径、通知 / Now Playing / AlarmKit 上的 entity 标注。
- `references/long-running-and-execution.md` - 30 秒预算、`LongRunningIntent` + `performBackgroundTask`、`CancellableIntent`、后台 GPU、`allowedExecutionTargets`。
- `references/testing-intents.md` - `AppIntentsTesting` 框架（进程外集成）、直接 `perform()` 单元测试、通过 `AppDependencyManager` mock `@Dependency`、仅测试 intent、无法单元测试的内容。
- `references/anti-patterns.md` - LLM 生成 App Intents 代码时的常见错误。
