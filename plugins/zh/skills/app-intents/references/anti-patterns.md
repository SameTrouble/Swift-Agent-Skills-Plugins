# 反模式：常见 App Intents 错误

App Intents 在 iOS 16、17 和 18 间快速演进。大多数 LLM 训练数据早于框架的现代形态，因此模型经常生成旧模式的代码（SiriKit、Swift 6 之前的 SwiftData、NSUserActivity）。这些是需要捕获的错误。

## SwiftData `@Model` 遵循 `AppEntity`

这是最常见的单一错误。

```swift
// 错误 - @Model 不是 Sendable，AppEntity 要求 Sendable
@Model
final class Article { ... }

extension Article: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    ...
}
// Error: "Conformance of 'Article' to 'Sendable' unavailable"
```

修复：创建一个单独的**映射结构体**遵循 `AppEntity`，并在查询边界进行 model → entity 的映射。

```swift
// 正确
struct ArticleEntity: AppEntity {
    var id: UUID
    var title: String
    // ... 只暴露你想暴露的字段
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

@Model
final class Article {
    var entity: ArticleEntity {
        ArticleEntity(id: id, title: title)
    }
}
```

## 在 intent 中使用 SwiftUI `@Query`

`@Query` 是一个只在 `View` 内部工作的属性包装器。在 intent 中它默默无效果。

```swift
// 错误 - @Query 在这里没有效果
struct CountArticlesIntent: AppIntent {
    @Query var articles: [Article]   // 不会填充

    func perform() async throws -> some IntentResult {
        let count = articles.count   // 总是 0
        ...
    }
}

// 正确 - 使用 FetchDescriptor 或集中式数据控制器
struct CountArticlesIntent: AppIntent {
    @Dependency var store: DataStore

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let count = try store.articleCount()
        return .result(value: count)
    }
}
```

## Siri 短语缺少 `\(.applicationName)`

```swift
// 错误 - 构建错误："Every app shortcut phrase needs to contain the applicationName"
AppShortcut(
    intent: RefreshFeedIntent(),
    phrases: ["Refresh my feed"],
    shortTitle: "Refresh Feed",
    systemImageName: "arrow.clockwise"
)

// 正确
AppShortcut(
    intent: RefreshFeedIntent(),
    phrases: ["Refresh my feed in \(.applicationName)"],
    shortTitle: "Refresh Feed",
    systemImageName: "arrow.clockwise"
)
```

由宏在编译时强制执行。绝不要将 App 名称硬编码为字符串——`\(.applicationName)` 在重命名后仍然有效。

## 定义了 intent 但从未注册

编写 `AppIntent` 类型只是第一步。没有 `AppShortcutsProvider` 列出它，intent 对 Shortcuts、Siri 建议、操作按钮选择器和 focus filters 都不可见。

```swift
// Intent 存在但没人注册它 - 用户永远不会看到它
struct RefreshFeedIntent: AppIntent { ... }

// 缺少的部分
struct ReaderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshFeedIntent(),
            phrases: ["Refresh my feed in \(.applicationName)"],
            shortTitle: "Refresh Feed",
            systemImageName: "arrow.clockwise"
        )
    }
}
```

每个 App 恰好有一个 `AppShortcutsProvider`。仅用于小组件或内部用途的 intent 不需要注册。

## 在 `perform()` 中创建 `ModelContainer` / `ModelContext`

可以工作，但浪费且将 SwiftData 关注点泄漏到每个 intent。

```swift
// 错误（重复；难以维护）
func perform() async throws -> some IntentResult & ReturnsValue<Int> {
    let container = try ModelContainer(for: Article.self)
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Article>()
    let count = try context.fetchCount(descriptor)
    return .result(value: count)
}

// 正确 - 在 App.init() 中注入一次，到处使用
struct CountArticlesIntent: AppIntent {
    @Dependency var store: DataStore

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let count = try store.articleCount()
        return .result(value: count)
    }
}
```

## 跨 actor 传递 `ModelContext`

只有 `ModelContainer` 是 `Sendable`。`ModelContext` 不是。

```swift
// 错误 - Swift 6 严格并发会失败
actor Indexer {
    func index(context: ModelContext) async { ... }
}

// 正确 - 传递 container，在 actor 内部创建本地 context
actor Indexer {
    let container: ModelContainer

    func index() async {
        let context = ModelContext(container)
        ...
    }
}
```

## 返回错误的 `IntentResult` 形状

声明的返回类型必须与 `.result(...)` 实际返回的匹配。不匹配在运行时崩溃，而非编译时。

```swift
// 错误 - 声明 ProvidesDialog 但返回空结果
func perform() async throws -> some IntentResult & ProvidesDialog {
    return .result()   // 运行时："missing dialog"
}

// 错误 - 声明 ReturnsValue<Int> 但返回 value: String
func perform() async throws -> some IntentResult & ReturnsValue<Int> {
    return .result(value: "five")   // 运行时：类型不匹配
}

// 正确
func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
    return .result(value: 5, dialog: "You have 5 items.")
}
```

在调用点强制你拓宽之前，保持类型狭窄。

## 使用 `String(format:)` 或手动复数逻辑生成对话

```swift
// 错误
let s = count == 1 ? "item" : "items"
return .result(dialog: "You have \(count) \(s).")

// 错误 - 缺少语言环境
return .result(dialog: String(format: "%d items", count))

// 正确 - Foundation 语法一致性
let message = AttributedString(localized: "You have ^[\(count) item](inflect: true).")
return .result(dialog: "\(message)")
```

语法一致性适用于英语、法语、德语、意大利语、西班牙语和葡萄牙语（两种变体）。其他语言环境回退到基本形式。

## 在查询中省略 `entities(for:)`

`entities(for identifiers:)` 是强制的。没有它，参数解析会默默中断——选择器显示结果，但 Shortcuts 在重新评估时无法重新加载它们。

```swift
// 错误 - 只有 EnumerableEntityQuery 的一半
struct FolderEntityQuery: EnumerableEntityQuery {
    func allEntities() async throws -> [FolderEntity] { ... }
    // 缺少 entities(for:) - 不遵循
}

// 正确
struct FolderEntityQuery: EnumerableEntityQuery {
    func allEntities() async throws -> [FolderEntity] { ... }

    func entities(for identifiers: [FolderEntity.ID]) async throws -> [FolderEntity] {
        try await store.folderEntities(matching: #Predicate { identifiers.contains($0.id) })
    }
}
```

## 在视图修饰符中设置依赖

`App.init()` 对 intent 运行；`.onAppear` 和 `.task` 不运行（intent 触发时不创建 UI）。

```swift
// 错误 - intent 在无 UI 运行时依赖未注册
var body: some Scene {
    WindowGroup {
        ContentView()
            .onAppear {
                AppDependencyManager.shared.add(dependency: store)
            }
    }
}

// 正确 - 在 init 中注册，在任何 intent 运行前
init() {
    let store = DataStore(...)
    self._store = .init(initialValue: store)
    AppDependencyManager.shared.add(dependency: store)
}
```

## 对新功能使用 `NSUserActivity` 或旧版 `SiriKit`

旧模式：捐赠 `NSUserActivity`、使用 `INIntent` 和 `INExtension` target、子类化 `INExtension` 处理 Siri 响应。这些在某些情况下仍然有效，但不是现代路径。

对任何新功能使用 App Intents。`NSUserActivity` 仍然是处理 handoff 的方式；你可以将 `AppEntity` 与现有的 `NSUserActivity` 关联，但不要在 `SiriKit` 之上构建新的 Siri 集成。

## 在 `perform()` 中过度认证

```swift
// 错误 - 阻止 Siri 响应于无法在那里显示的认证表单
func perform() async throws -> some IntentResult {
    let token = try await showSignInSheet()
    ...
}

// 正确 - 用友好对话退出；用户下次打开 App 时登录
func perform() async throws -> some IntentResult & ProvidesDialog {
    guard store.isAuthenticated else {
        return .result(dialog: "Please sign in first.")
    }
    ...
}
```

## SwiftData 修改缺少 `@MainActor`

在 `perform()` 内部修改 SwiftData `@Model` 对象而没有 main-actor 保证会产生 sendability 警告（Swift 6）或数据损坏（早期模式）。

```swift
// 当 intent 修改 model 对象时正确
@MainActor
func perform() async throws -> some IntentResult & ProvidesDialog {
    let first = try store.articles(limit: 1).first
    first?.lastOpened = .now
    try first?.modelContext?.save()
    return .result(dialog: "Done.")
}
```

或者，在自定义 `ModelActor` 中执行写入并从 intent 调用它。

## 在 `#Predicate` 中使用 entity 属性路径

SwiftData 的 `#Predicate` 宏无法穿透 entity 属性路径；先将 id 复制到本地变量。

```swift
// 错误 - 宏错误或错误结果
try store.articles(matching: #Predicate { $0.id == entity.id })

// 正确
let id = entity.id
try store.articles(matching: #Predicate { $0.id == id })
```

## snippet 视图中的交互式 SwiftUI 控件

snippet 视图像小组件一样渲染。任何需要活动 `UIViewController` 的东西（滚动视图、列表、文本字段、许多情况下的地图）要么不渲染要么渲染不正确。

```swift
// 错误 - ScrollView 是 snippet 内的平台视图
return .result(dialog: "\(entity.title)") {
    ScrollView {
        Text(entity.longSummary)
    }
}

// 正确 - 仅静态布局
return .result(dialog: "\(entity.title)") {
    VStack(alignment: .leading) {
        Text(entity.title).font(.headline)
        Text(entity.summary).font(.body)
    }
    .padding()
}
```

如果需要交互，使用 `OpenIntent` 打开 App。

## `OpenIntent` 上 `target` 参数重命名

`OpenIntent` 按确切名称匹配 `target`。

```swift
// 错误 - 协议的默认匹配查找 `target`
struct OpenArticleIntent: OpenIntent {
    @Parameter var article: ArticleEntity   // 错误的属性名
    ...
}

// 正确
struct OpenArticleIntent: OpenIntent {
    @Parameter var target: ArticleEntity
    ...
}
```

## 辅助 intent 污染 Shortcuts 库（缺少 `isDiscoverable = false`）

仅作为小组件按钮、snippet 按钮或其他 intent 后盾而存在的 intent 不应出现在用户的 Shortcuts 库中。

```swift
// 错误 - 即使是实现细节也出现在 Shortcuts 中
struct LogAmountIntent: AppIntent {
    static let title: LocalizedStringResource = "Log caffeine amount"
    @Parameter var amount: Int
    ...
}

// 正确
struct LogAmountIntent: AppIntent {
    static let title: LocalizedStringResource = "Log caffeine amount"
    static let isDiscoverable: Bool = false
    @Parameter var amount: Int
    ...
}
```

同样适用于通过 `ShowsSnippetIntent` 间接使用的 `SnippetIntent` 类型——它们始终是内部的，必须 `isDiscoverable = false`。

## `Button(intent:)` 没有匹配的 init

`Button(intent:)` 接受 intent *实例*。如果 intent 有参数，你需要接受参数的便利 init：

```swift
struct LogAmountIntent: AppIntent {
    static let title: LocalizedStringResource = "Log amount"
    static let isDiscoverable: Bool = false
    @Parameter var amount: Int
    ...
}

// 错误 - 没有额外 init 无法构造 LogAmountIntent(amount:)
Button(intent: LogAmountIntent(amount: 64)) { Text("Single") }   // 无法编译

// 修复：添加 init
extension LogAmountIntent {
    init(amount: Int) { self.amount = amount }
}
```

不要试图从外部构造后分配给 `@Parameter` 包装的属性；使用自定义 init。

## 在 `ShowsSnippetIntent` 更干净的地方使用 `ShowsSnippetView`

内联 `ShowsSnippetView` 可以工作，但它将 snippet 的 UI 绑定到业务 intent 的 `perform()`。如果 snippet 包含需要在触发后刷新视图的交互按钮（`Button(intent:)`），优先使用双 intent 模式：

```swift
// 可以，但死板 - 适合静态摘要
func perform() async throws -> some IntentResult & ShowsSnippetView {
    .result { SummaryView(data: ...) }
}

// 当 snippet 内部有 Button(intent:) 时更好
func perform() async throws -> some IntentResult & ReturnsValue<Int> & ShowsSnippetIntent {
    .result(value: count, snippetIntent: DashboardSnippet())
}
```

双 intent 形式允许 snippet 在按钮触发时就地重新渲染；内联形式不能。

## entity 变化后忘记 `updateAppShortcutParameters()`

引用 entity 参数的快捷方式短语（例如 `"Open \(\.$folder) in \(.applicationName)"`）会缓存候选列表。当文件夹被重命名或添加新文件夹时，Siri 建议的短语可能显示过时或缺失的值。

```swift
// 在影响参数候选列表的任何变化后添加
func createFolder(_ name: String) {
    store.insert(Folder(name: name))
    try? modelContext.save()
    ReaderShortcuts.updateAppShortcutParameters()   // 刷新短语缓存
}
```

也在 `App.init()` 中调用一次以在首次启动时播种缓存。

## 小组件触发 intent 写入非共享存储

小组件中的 `Button(intent:)` 触发在 *App* 进程中运行的 intent。小组件视图位于*小组件扩展*进程中。它们既不共享内存也不共享标准 `UserDefaults`。

```swift
// 错误 - 小组件永远看不到新值；TimelineProvider 读取旧数据
struct IncrementIntent: AppIntent {
    static let title: LocalizedStringResource = "Increment"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        let count = UserDefaults.standard.integer(forKey: "count")
        UserDefaults.standard.set(count + 1, forKey: "count")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// 正确 - 两个进程读写同一个 suite
enum SharedCounter {
    private static let defaults = UserDefaults(suiteName: "group.com.example.myapp")!

    static var current: Int { defaults.integer(forKey: "count") }
    static func increment() { defaults.set(current + 1, forKey: "count") }
}

struct IncrementIntent: AppIntent {
    static let title: LocalizedStringResource = "Increment"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        SharedCounter.increment()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

需要在主 App target 和小组件扩展 target 上添加相同的 App Group 能力。参见 `open-and-snippet-intents.md` 了解完整模式，包括共享 SwiftData 存储。

## 在小组件触发 intent 中使用 `@Dependency`

`@Dependency` 从 `AppDependencyManager` 读取，后者在 `App.init()` 中填充。当小组件触发 intent 时，App 的 `init()` 已运行（OS 启动 App 进程），因此 `@Dependency` 有效——但仅对 App 进程状态。任何仅存储在内存中的（视图上的 `@State`、view-model 上的 `@Published`）不与扩展中运行的小组件时间线提供者共享。

如果小组件需要显示 intent 修改的状态，该状态必须持久化在两个进程都能看到的地方——App Group `UserDefaults`、共享文件或 URL 在 App Group 共享容器内的 `ModelContainer`。不要试图通过 `@Dependency` 将 App 专用状态"注入"小组件侧。

## intent 写入后缺少 `WidgetCenter.reloadAllTimelines()`

如果写入数据的 intent 不请求重新加载，小组件会持续显示旧数据直到下次计划刷新。

```swift
// 错误 - 小组件在下次计划刷新前过时
@MainActor
func perform() async throws -> some IntentResult {
    try store.log(amount)
    return .result()
}

// 正确
@MainActor
func perform() async throws -> some IntentResult {
    try store.log(amount)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
}
```

对于有多个小组件类型的 App，使用 `reloadTimelines(ofKind:)` 避免不必要的工作。

## 没有 `@Property` 的 entity 字段不可查询

`AppEntity` 上的普通存储或计算属性对你的代码可见，但对 Shortcuts、Find intent 和参数摘要不可见。如果用户合理地想按字段过滤或排序，用 `@Property`（或派生值用 `@ComputedProperty`）标记它：

```swift
// 错误 - `trailLength` 永远无法在 Shortcuts、Find intent 或参数摘要中使用
struct TrailEntity: AppEntity {
    @Property var name: String
    var trailLength: Measurement<UnitLength>   // 普通 - 系统不可见
    ...
}

// 正确
struct TrailEntity: AppEntity {
    @Property var name: String
    @Property var trailLength: Measurement<UnitLength>
    ...
}
```

问自己："用户会想构建一个按此字段过滤或排序的快捷方式吗？"如果会，包装它。

## 仅用 `EntityQuery` 而本可用 `EntityPropertyQuery` 自动生成 Find intent

当 entity 有多个用户可能过滤的 `@Property` 字段时，让查询遵循 `EntityPropertyQuery` 会自动在 Shortcuts 中给用户一个"Find [Entity]"操作，带完整谓词构建和排序。你不必编写那个 UI。

```swift
// 可以但留下了功能没用
struct TrailEntityQuery: EntityQuery {
    func entities(for identifiers: [TrailEntity.ID]) async throws -> [TrailEntity] { ... }
    func suggestedEntities() async throws -> [TrailEntity] { ... }
}

// 更好 - 用户自动获得"Find Trail"操作
extension TrailEntityQuery: EntityPropertyQuery {
    static let properties = QueryProperties {
        Property(\TrailEntity.$name) {
            ContainsComparator { ... }
            EqualToComparator { ... }
        }
        Property(\TrailEntity.$trailLength) {
            LessThanOrEqualToComparator { ... }
        }
    }
    static let sortingOptions = SortingOptions {
        SortableBy(\TrailEntity.$name)
        SortableBy(\TrailEntity.$trailLength)
    }
    func entities(matching: [Predicate<TrailEntity>], mode: ComparatorMode,
                  sortedBy: [EntityQuerySort<TrailEntity>], limit: Int?) async throws -> [TrailEntity] { ... }
}
```

仅当数据集真正可枚举（小、固定）时跳过 `EntityPropertyQuery`——这种情况优先用 `EnumerableEntityQuery`。

## 在 `URLRepresentableIntent` 上实现 `perform()`

如果 entity 遵循 `URLRepresentableEntity` 且 intent 遵循 `OpenIntent` 和 `URLRepresentableIntent`，系统通过 App 的通用链接处理器自动打开 URL。编写 `perform()` 体*替换*该自动化——你失去了 URL 路由路径。

```swift
// 错误 - perform() 运行而非 URL 路由；重复通用链接逻辑
struct OpenTrail: OpenIntent, URLRepresentableIntent {
    @Parameter var target: TrailEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.route = .trail(target.id)   // 重复了 .onOpenURL 已做的事
        return .result()
    }
}

// 正确 - 无 perform()，系统使用 urlRepresentation
struct OpenTrail: OpenIntent, URLRepresentableIntent {
    @Parameter var target: TrailEntity
    // 无 perform()
}
```

选择一种路由机制。如果 App 有成熟的通用链接处理，使用 URL 路径。如果没有，实现 `perform()` 而不遵循 `URLRepresentableIntent`。

## 将计算/聚合数据作为 `AppEntity` 返回而非 `TransientAppEntity`

`AppEntity` 要求持久化标识符和有效的 `EntityQuery`。计算摘要（今天总步数、当前天气、聚合锻炼统计）没有 id 且无法按 id 查找——它们每次请求重新计算。对它们使用 `AppEntity` 会强制一个只能返回一个"当前"值的尴尬 `EntityQuery`。

```swift
// 错误 - 无真实 id，EntityQuery 无意义
struct WorkoutSummary: AppEntity {
    var id: UUID   // 总是 .init()，无意义
    @Property var totalSteps: Int
    static let defaultQuery = DummyQuery()   // 尴尬
    ...
}

// 正确
struct WorkoutSummary: TransientAppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Summary")
    @Property var totalSteps: Int
    init() { totalSteps = 0 }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Workout Summary", subtitle: "\(totalSteps) steps")
    }
}
```

经验法则：如果你无法回答"`entities(for: [id])` 在这里做什么？"，你需要 `TransientAppEntity`。

## 屏幕上使用的 entity 缺少 `Transferable` 遵循

对于通过 `userActivity(_:element:)` 暴露的 entity，Siri / Apple Intelligence 可以*识别* entity 但无法对其*内容*做任何有用的事，除非 entity 遵循 `Transferable`。没有它，"我能用这个做什么？"返回空。

```swift
// Siri 可见但不透明
struct PhotoEntity: AppEntity { ... }

// Siri 可用（可作为图像/PDF/文本转发）
struct PhotoEntity: AppEntity { ... }

extension PhotoEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { entity in try await entity.pngData() }
        DataRepresentation(exportedContentType: .plainText) { entity in entity.caption.data(using: .utf8)! }
    }
}
```

对于采纳了 schema 的 entity（如 `.photos.asset`），`Transferable` 遵循实际上是必需的——多个消费功能假设它存在。

## 在 `SnippetIntent.perform()` 中修改 App 状态

iOS 26 的 snippet 刷新周期在每次用户交互中多次调用 snippet intent 的 `perform()`——首次显示、每次按钮点击后、深色模式切换时、`SnippetIntent.reload()` 时。如果 `perform()` 有副作用，它们会重复运行。

```swift
// 错误 - 每次 snippet 重新渲染都记录分析事件
struct DashboardSnippetIntent: SnippetIntent {
    @Dependency var analytics: Analytics
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        analytics.log("dashboard_viewed")   // 每次刷新都触发，不只是打开
        return .result(view: DashboardView(data: store.current))
    }
}

// 正确 - 纯视图构造；副作用属于按钮的 intent
struct DashboardSnippetIntent: SnippetIntent {
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: DashboardView(data: store.current))
    }
}
```

snippet intent 的 `perform()` 应该读取状态、组装视图并返回。写入和副作用存在于*按钮的* intent 中。

## `SnippetIntent.perform()` 中的昂贵工作

同理，慢操作使 snippet 感觉无响应——用户看到旋转器而非内容。延迟网络调用、模型推理和重数据库聚合；呈现缓存值并在路径外触发刷新。

```swift
// 错误 - 每次刷新时的网络调用阻塞叠加层
func perform() async throws -> some IntentResult & ShowsSnippetView {
    let latest = try await api.fetchDashboard()
    return .result(view: DashboardView(data: latest))
}

// 正确 - 读取缓存，在后台启动刷新
func perform() async throws -> some IntentResult & ShowsSnippetView {
    Task.detached { try await api.refreshDashboardCache() }
    return .result(view: DashboardView(data: store.cachedDashboard))
}
```

## 每个变体一个 intent 而非灵活 intent

当操作仅在参数值上不同时，不要将它们拆分为单独的 intent：

```swift
// 错误
struct CreateWorkReminderIntent: AppIntent { ... }
struct CreatePersonalReminderIntent: AppIntent { ... }
struct CreateShoppingReminderIntent: AppIntent { ... }

// 正确
struct CreateReminderIntent: AppIntent {
    @Parameter var list: ReminderListEntity
    @Parameter var text: String
    @Parameter var dueDate: Date?
    ...
}
```

一个灵活的 intent 在 Shortcuts 中组合得更好，覆盖更多 Siri 措辞。将单独的 intent 保留给真正不同的操作。

## 将 UI 级操作暴露为 intent

intent 应该代表用户关心的任务，而非他们可能点击的 UI 按钮：

```swift
// 错误 - 绑定到特定 UI 布局
struct TapCancelButtonIntent: AppIntent { ... }

// 正确 - 代表真实任务
struct DiscardDraftIntent: AppIntent { ... }
```

UI 元素 intent 在你重新设计屏幕的那一刻就坏了；任务级 intent 能经受重构，并干净地转换为 Siri 短语和 Shortcuts 操作。

## 缺少 `perform()` 在 Mac 上破坏 Spotlight

在 macOS 上，没有 `perform()` 的 intent（如纯粹依赖 URL 路由的 `URLRepresentableIntent`）不会出现在 Spotlight 搜索结果中——Mac 的搜索索引器跳过无法直接调用的 intent。

如果 macOS Spotlight 可达性重要，实现一个调用与你的通用链接处理器相同的导航器的 `perform()`。在 iOS 上，省略 `perform()` 是可以的。

## 启动 App 的 intent 对 Spotlight 隐藏

只有能在*不*启动 App 的情况下完成的 intent 才有资格出现在 Spotlight 的快捷方式建议中。有 `openAppWhenRun = true`（或等效前台延续）的 intent 不会出现在那里。

设计混合：轻量只读 intent（获取计数、显示状态）可以由 Spotlight 呈现；更深的修改 intent 打开 App 进行完整交互。不要指望 Spotlight 是打开 App 操作的主要发现路径。

## 首次启动前显示参数化快捷方式短语

插值 entity 参数的快捷方式短语（`"Open \(\.$folder) in \(.applicationName)"`）在 App 至少启动一次且 `updateAppShortcutParameters()` 填充 entity 列表前不会出现在 Spotlight 或 Shortcuts 主页中。

为每个 App Shortcut 至少包含一个非参数化短语，这样用户在安装时能立即看到并调用它：

```swift
AppShortcut(
    intent: OpenFolderIntent(),
    phrases: [
        "Open folder in \(.applicationName)",                  // 首次启动时有效
        "Open \(\.$target) in \(.applicationName)"             // 填充后可用
    ],
    shortTitle: "Open Folder",
    systemImageName: "folder"
)
```

## Spotlight：从零修改 `CSSearchableItemAttributeSet`

从 `defaultAttributeSet` 开始——系统填充类型标识符、显示元数据和一堆你可能会忘记的默认值。

```swift
// 错误 - 丢失系统默认值
var attributeSet: CSSearchableItemAttributeSet {
    let set = CSSearchableItemAttributeSet(contentType: .item)
    set.contentDescription = summary
    return set
}

// 正确
var attributeSet: CSSearchableItemAttributeSet {
    let set = defaultAttributeSet
    set.contentDescription = summary
    set.addedDate = publishedAt
    return set
}
```

## 当你只需要 id 时解析数千个 entity

`[MyEntity]` 参数强制系统在 `perform()` 运行前完全解析每个 entity（运行查询、填充所有属性）。对于持有数百或数千个 entity 且你的代码只需要 **id** 的参数，那是大量无意义的开销。使用 `EntityCollection`（iOS 27+）。

```swift
// 错误 - 系统在 perform() 开始前解析 1,000 个 PhotoEntity 实例
struct TagPhotosIntent: AppIntent {
    @Parameter var photos: [PhotoEntity]
    func perform() async throws -> some IntentResult {
        try await store.addTag(tag, toPhotosWith: photos.map(\.id))   // 只需要 id
        return .result()
    }
}

// 正确 - 仅标识符；参数处理期间无解析
struct TagPhotosIntent: AppIntent {
    @Parameter var photos: EntityCollection<PhotoEntity>
    func perform() async throws -> some IntentResult {
        try await store.addTag(tag, toPhotosWith: photos.identifiers)
        return .result()
    }
}
```

当你真正需要完整 entity 时调用 `await photos.resolvedEntities()`。对于你读取属性的小选择，保留 `[Entity]`。

## `LongRunningIntent` 沉默（无进度）

`LongRunningIntent` 只有在你**报告进度**时才保持其扩展运行时授权。如果你在不更新 `progress` 的情况下工作，系统假设任务停滞并取消扩展——intent 像从未采纳协议一样死亡。

```swift
// 错误 - 无进度更新；运行时扩展在上传中途被撤销
func perform() async throws -> some IntentResult {
    try await performBackgroundTask {
        for chunk in chunks { await upload(chunk) }   // 沉默 - 系统认为停滞了
    }
    return .result()
}

// 正确 - 报告进度作为保持扩展存活的心跳
func perform() async throws -> some IntentResult {
    try await performBackgroundTask {
        progress.totalUnitCount = Int64(chunks.count)
        for (i, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            await upload(chunk)
            progress.completedUnitCount = Int64(i + 1)
        }
    }
    return .result()
}
```

相关地：不要试图通过生成 detached `Task` 来超越 30 秒限制——非托管任务不受后台执行扩展覆盖，在 App 后台时会被挂起。采纳 `LongRunningIntent`。

## 更新 intent 中用简单 `nil` 检查代替 `valueState`

在更新 intent 中，`nil` 的可选参数有歧义："不改这个字段"还是"清除它"？`nil` 检查将两者合并为一种行为——通常是一个 bug，用户永远无法通过语音清除字段。

```swift
// 错误 - 无法区分"不动 recurrence"和"移除 recurrence"
if let recurrence { store.setRecurrence(recurrence, on: event.id) }
// else: 什么都不做 - 所以"让这个不重复"默默什么也不做

// 正确 - valueState 区分三种情况
switch $recurrence.valueState {
case .set(let rule?): store.setRecurrence(rule, on: event.id)   // 新值
case .set(nil):       store.clearRecurrence(on: event.id)        // 显式清除
case .unset:          break                                      // 不在请求中
}
```

## 两个进程写入同一存储（缺少 `allowedExecutionTargets`）

当 intent 位于 App 和小组件扩展都链接的共享包中时，系统可能在*任一*进程中运行写入 intent。如果只有一个进程应该拥有写入（如小组件对存储有只读访问权），让 intent 在小组件扩展中运行会导致冲突。

```swift
// 错误 - "favorite" 可能在小组件扩展中运行并写入它不应该写的存储
struct FavoritePhotoIntent: AppIntent {
    @Parameter var photo: PhotoEntity
    func perform() async throws -> some IntentResult { try await library.toggleFavorite(photo.id); return .result() }
}

// 正确 - 将写入 intent 固定到拥有存储的进程 (iOS 27+)
struct FavoritePhotoIntent: AppIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { [.app] }
    @Parameter var photo: PhotoEntity
    func perform() async throws -> some IntentResult { try await library.toggleFavorite(photo.id); return .result() }
}
```

## 需要持久化标识符时使用 `TransientAppEntity`

多个 iOS 27 集成依赖 `EntityIdentifier`：屏幕视图标注和用户通知、Now Playing、AlarmKit 上的 entity 标注。`TransientAppEntity` **没有**持久化标识符，因此它们中任何一个都不能使用它。

```swift
// 错误 - 瞬态 entity 没有 EntityIdentifier 可标注
notificationContent.appEntityIdentifier = EntityIdentifier(for: summaryTransientEntity)   // 无 id

// 正确 - 用真正的 AppEntity / IndexedEntity 标注
notificationContent.appEntityIdentifier = EntityIdentifier(for: messageEntity)
```

`TransientAppEntity` 仅用于计算/返回值。系统需要*回溯引用*的任何内容（标注、可同步身份、所有权）必须是真正的 `AppEntity`。

## 过度捐赠交互

交互捐赠（`IntentDonationManager`）应反映**真实的、已完成的**用户操作，且仅是通过 App 自己的 UI 执行的操作（系统已捐赠 Siri/Shortcuts 运行）。在每次渲染、每次点击时捐赠，或重新捐赠系统运行的 intent 会淹没系统，系统随后可能**完全忽略你的捐赠**。

```swift
// 错误 - 在每次视图出现时捐赠，而非在完成的操作上
.onAppear { IntentDonationManager.shared.donate(intent: SendMessageIntent()) }

// 正确 - 在用户实际发送后捐赠一次，仅从 UI 路径
func sendFromUI(_ body: String, to contact: ContactEntity) async throws {
    let message = try await messenger.send(body, to: contact)
    var intent = SendMessageIntent(); intent.recipient = contact; intent.content = body
    IntentDonationManager.shared.donate(intent: intent, result: .resolved(value: message.entity))
}
```

当数据被移除或操作被撤销时，用 `deleteDonations(matching:)` 删除过时捐赠。
