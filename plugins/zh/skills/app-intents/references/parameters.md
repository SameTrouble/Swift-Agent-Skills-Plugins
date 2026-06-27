# 参数

Intent 参数用 `@Parameter` 声明，由系统自动解析——用户被提示、点击选择器或在 Shortcuts 中从另一个操作链式值。

## 声明参数

```swift
struct AppendToNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Append to note"

    @Parameter(title: "Text")
    var newText: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // newText 在此保证非 nil
        ...
    }
}
```

到 `perform()` 运行时，每个非可选 `@Parameter` 已填充。如果用户未提供，系统在调用 `perform()` 前通过 Siri 语音、文本字段或选择器询问。

在 Xcode 16+ 上，`title:` 是可选的。如果省略，系统从属性名自动生成本地化标题（`newText` → "New Text"）。仅当你想要与派生形式不同的东西时指定 `title:`。

## 必需 vs 可选参数

设计指导：保持参数**可选**，除非 intent 没有它确实无用。

- 可选参数让 intent 以合理默认值立即运行；用户仅在未显式提供值时获得后续提示。
- 必需参数总是在 `perform()` 运行前触发提示——即使在 Shortcuts 中用户刚配置了快捷方式且知道他们想要什么。

对于布尔参数，设置反映常见情况的默认值（`default: true`）。对于切换 intent，默认为切换最终到达的值——如"设置勿扰"intent 默认 `enabled: true`。

### 更新 intent 中的可选："不改" vs "清除" via `valueState`

对于**更新** intent，可选参数为 `nil` 有歧义：`nil` 表示"不改这个字段"还是"显式清除它"？简单 `nil` 检查无法区分。`@AppIntent` 宏将每个参数包装在暴露 `valueState` 的 `IntentParameter` 中，区分三种情况：

```swift
struct UpdateEventIntent: AppIntent {
    @Parameter var event: EventEntity
    @Parameter var recurrence: Calendar.RecurrenceRule?
    // ...

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<EventEntity> {
        switch $recurrence.valueState {
        case .set(let rule?):  try store.setRecurrence(rule, on: event.id)   // 提供了新值
        case .set(nil):        try store.clearRecurrence(on: event.id)        // 显式清除
        case .unset:           break                                          // 不在请求中 - 不改
        }
        // ...
    }
}
```

`$parameter.valueState` 是 `.set(value)`（带非 nil 值 = 新值，带 `nil` = 显式清除）或 `.unset`（参数不在请求中）。在任何清除值是与不动它不同的有意义操作的可选参数上使用它——在基于 schema 的更新 intent（`calendar_updateEvent` 等）中典型，那里大多数参数是可选的。

## 支持的参数类型

基本类型：

- `String`、`Int`、`Double`、`Bool`、`Date`、`URL`、`Measurement`
- `IntentFile`、`IntentItem`、`IntentEnum`
- `Decimal`、`Data`
- `Duration`、`PersonNameComponents`（及更多）- **27 发布中添加的原生类型**
- 上述任何的可选或数组

领域类型：

- 任何 `AppEntity`（单个或 `[MyEntity]`）
- 任何 `AppEnum`
- `EntityCollection<MyEntity>`（仅标识符 - 见下文）
- `@UnionValue` enum（一个参数，多种 entity 类型 - 见 `entities.md`）

### 原生类型免费获得选择器

当参数类型是系统理解的之一时，声明它就是你要做的全部——系统提供**原生选择器、Siri 理解和本地化**，无需自定义 UI。27 发布将内置支持扩展到更多类型：用 `Duration` 代替手摇时间选择器，用 `PersonNameComponents` 代替普通 `String` 进行结构化名称输入。每个都在 intent 工作的任何地方工作——Siri、Shortcuts、小组件。

## 参数选项

`@Parameter` 接受塑造面向用户提示的选项：

```swift
@Parameter(
    title: "Tag",
    description: "Tag applied to the bookmark.",
    requestValueDialog: "Which tag should I use?",
    default: "reading"
)
var tag: String

@Parameter(
    title: "Priority",
    default: .normal,
    requestDisambiguationDialog: "Which priority?"
)
var priority: PriorityLevel  // 一个 AppEnum

@Parameter(title: "Attachment", supportedTypeIdentifiers: ["public.image", "public.pdf"])
var attachment: IntentFile
```

### 在 Shortcuts 中自动链式：`inputConnectionBehavior`

当 intent 可能在 Shortcuts 工作流中*在*另一个操作*之后*运行时，声明参数应自动连接到前一个结果：

```swift
@Parameter(
    title: "Image",
    supportedTypeIdentifiers: ["public.image"],
    inputConnectionBehavior: .connectToPreviousIntentResult
)
var image: IntentFile
```

当用户将此操作放入工作流时，Shortcuts 会将字段默认为"Image from [previous action]"。用户仍可覆盖；属性只是选择更好的默认值。

对于通常是前一操作输出的参数（"调整图像大小" intent 的图像、"标记为收藏" intent 的 entity）使用 `.connectToPreviousIntentResult`。对于预期手动配置的参数保留默认值。

### 使用 `IntentFile` 参数

`IntentFile` 暴露三个访问路径：

```swift
func perform() async throws -> some IntentResult {
    // 磁盘上的路径 - 对可写或大文件操作最常见
    if let url = image.fileURL {
        try await processor.convert(fileAt: url)
    } else {
        // 内存中的数据 - 当文件来自瞬态源时
        let data = try image.data(contentType: .image)
        try await processor.process(data: data)
    }
    return .result()
}
```

- `fileURL: URL?` - 当文件位于磁盘上时设置（文档选择器、文件 App）。瞬态数据时为 `nil`。
- `data(contentType:)` - 获取底层字节；可能从磁盘或内存加载。
- `filename: String` - 文件的显示名称。

存在 `fileURL` 时优先使用它以避免将大文件双重加载到内存。

## Entity 参数

任何 `AppEntity` 可以是参数。系统使用 entity 的 `defaultQuery` 填充选择器并将用户语音解析为特定 entity：

```swift
struct OpenBookmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open bookmark"

    @Parameter(title: "Bookmark")
    var bookmark: BookmarkEntity

    func perform() async throws -> some IntentResult {
        ...
    }
}
```

给定 `BookmarkEntity.defaultQuery`，Shortcuts 会显示带从查询填充的选择器的"Bookmark"字段。在 Siri 中，用户说"open bookmark Weather"，系统针对查询的 `EntityStringQuery`（如果遵循）解析"Weather"或回退到消歧对话。

## `@AppEnum`

对于固定集合参数，声明 `AppEnum`：

```swift
enum PriorityLevel: String, AppEnum {
    case low, normal, high

    static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Priority")
    static let typeDisplayName: LocalizedStringResource = "Priority"
    static let caseDisplayRepresentations: [PriorityLevel: DisplayRepresentation] = [
        .low: "Low",
        .normal: "Normal",
        .high: "High"
    ]
}
```

`typeDisplayRepresentation` 和 `typeDisplayName` 看起来相似但服务不同界面：

- `typeDisplayRepresentation` - 在任何显示带标签和可选图像的 entity/enum 类型的地方使用（选择器、参数卡片）。
- `typeDisplayName` - 短 `LocalizedStringResource`；在仅适合普通标签的内联上下文中使用（Siri 语音提示、参数摘要）。

在任何将面向用户的 enum 或 entity 上提供两者。初始化器简写 `.init(name: "Priority")` 等价于直接构造 `TypeDisplayRepresentation`。

enum 在 Shortcuts 中显示为漂亮选择器，可被 Siri 说出，并可在自动化中链式。

## 参数摘要

通过实现 `parameterSummary` 给 Shortcuts 一行摘要：

```swift
struct MoveArticleIntent: AppIntent {
    static let title: LocalizedStringResource = "Move article"

    @Parameter(title: "Article") var article: ArticleEntity
    @Parameter(title: "Folder") var folder: FolderEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$article) to \(\.$folder)")
    }

    func perform() async throws -> some IntentResult { .result() }
}
```

这在 Shortcuts 编辑器中渲染为"Move [Article] to [Folder]"。

对于有多个参数的 intent，`When`/`Switch` 条件为输入定制摘要：

```swift
static var parameterSummary: some ParameterSummary {
    Switch(\.$action) {
        Case(.archive) { Summary("Archive \(\.$article)") }
        Case(.delete)  { Summary("Delete \(\.$article)") }
    }
}
```

### 嵌套 `Switch` / `Case` / `When` / `otherwise`

真实参数摘要经常在多个轴上分支。嵌套条件；系统选择第一个匹配的分支：

```swift
static var parameterSummary: some ParameterSummary {
    Switch(\.$activity) {
        Case(.biking) {
            When(\.$location, .hasAnyValue) {
                Summary("Show \(\.$activity) ideas within \(\.$searchRadius) of \(\.$location)")
            } otherwise: {
                When(\.$trailCollection, .hasAnyValue) {
                    Summary("Show \(\.$activity) ideas from \(\.$trailCollection)")
                } otherwise: {
                    Summary("Show \(\.$activity) ideas from \(\.$trailCollection) or near \(\.$location)")
                }
            }
        }
        DefaultCase {
            When(\.$location, .hasAnyValue) {
                Summary("Suggest \(\.$activity) trails within \(\.$searchRadius) of \(\.$location)")
            } otherwise: {
                Summary("Suggest \(\.$activity) trails from \(\.$trailCollection) or near \(\.$location)")
            }
        }
    }
}
```

`When` 内的谓词：

- `.hasAnyValue` - 参数已设置（非 nil，对于可选参数）
- `.equalTo(value)`、`.notEqualTo(value)`、`.lessThan(value)`、`.greaterThan(value)` - 比较
- `.hasValue(.someEnumCase)` - enum case 匹配

使用 `DefaultCase` 覆盖 `Case` 未显式列出的值。

## 上下文感知选项提供者：`IntentParameterDependency`

`DynamicOptionsProvider` 或 `EntityQuery` 可以通过用 `@IntentParameterDependency` 声明同一 intent 的*其他*参数来读取它们。选项列表在上游参数变化时重新计算：

```swift
struct TrailsInRegionProvider: DynamicOptionsProvider {
    @IntentParameterDependency<SuggestTrailsIntent>(\.$region)
    var region

    func results() async throws -> [String] {
        guard let region else { return [] }
        return store.trailNames(in: region)
    }
}
```

用于级联选择器：国家 → 地区 → 城市；文件夹 → 笔记；播放列表 → 歌曲。没有 `IntentParameterDependency`，选项提供者孤立运行，看不到兄弟参数。

iOS 17+。一个提供者可依赖多个参数和多个父 intent。

## 数组参数大小声明

数组参数可按小组件族声明大小限制，使配置 UI 请求恰好正确数量的项目：

```swift
@Parameter(title: "Featured Routes", size: [
    .systemSmall: 1,
    .systemMedium: 3,
    .systemLarge: 5
])
var routes: [RouteEntity]
```

在 `WidgetConfigurationIntent` 内，这使单个 intent 支撑多种小组件尺寸。iOS 17+。

## 小组件族条件参数摘要

`parameterSummary` 可按正在配置的小组件族分支：

```swift
static var parameterSummary: some ParameterSummary {
    When(.widgetFamily, .equalTo, .systemLarge) {
        Summary("Show \(\.$routes) detailed routes")
    } otherwise: {
        Summary("Show \(\.$route)")
    }
}
```

当大小组件暴露小组件不需要的额外参数时有用。iOS 17+。

## perform 中途请求值

当参数是可选的且你需要它继续时，有两种机制。

### `requestValue` - 内联询问和接收

提示用户并 `await` 结果而无需重新进入 `perform()`：

```swift
@Parameter(title: "Shots") var shots: EspressoShot?

func perform() async throws -> some IntentResult & ProvidesDialog {
    if shots == nil {
        shots = try await $shots.requestValue("How many shots?")
    }

    // shots 在此保证非 nil
    try store.log(shots!)
    return .result(dialog: "Done.")
}
```

这是当你需要值在更大流程中途时的最干净选项。提示内联发生，用户回答，执行继续。

### `needsValueError` - 退出并让系统重新调用

抛出以信号"没有这个我无法继续"；系统重新提示并从头调用 `perform()`：

```swift
@Parameter(title: "Folder") var folder: FolderEntity?

func perform() async throws -> some IntentResult {
    guard let folder else {
        throw $folder.needsValueError("Which folder should the article go in?")
    }
    ...
}
```

当没有值做任何工作都无意义时使用。抛出前做的任何事在重新调用时被丢弃。

`requestValue` 更新且通常人机工程学更好。`needsValueError` 更旧但仍有效，且是你想让系统将提示记录为 Shortcuts 自动化中一等"需要输入"步骤时的唯一选项。

### `needsValueError` 重新运行 intent

当 `needsValueError(...)` 抛出时，系统提示用户然后**从头调用 `perform()`**——它不从抛出点恢复。你在抛出前执行的任何副作用运行两次。将副作用工作移到参数验证*之后*，或用幂等性检查守护。

`requestValue` 和 `requestConfirmation` 不重启；它们内联挂起和恢复。

## 多选项的 `requestChoice`

iOS 26+。当你想向用户提供多个备选选择（非确认/取消）时，使用 `requestChoice`：

```swift
let options: [IntentChoice<Route>] = routes.map {
    IntentChoice(title: "\($0.name)", style: .default, value: $0)
}

let selected = try await requestChoice(
    actionName: .select,
    between: options,
    dialog: "Which route should we take?"
)

try await navigator.go(to: selected)
```

返回选择的选项或用户取消时抛出。在 Shortcuts/Siri UI 中渲染为按钮行。选项接受 `style: .destructive` 用于删除样式选择。

## 消歧

当参数有多个合理匹配（如两个名称相似的 entity），呈现消歧：

```swift
throw $folder.needsDisambiguationError(among: candidates, dialog: "Which folder?")
```

保持消歧列表小（约 5 项以下）。仅语音上下文（HomePod、CarPlay）朗读每个选项——20 项列表不可用。

## 建议值的 `requestConfirmation`

当用户提供接近但不完全匹配且你想在继续前确认时，使用 `$parameter.requestConfirmation(for:dialog:)`：

```swift
if let location {
    let uniqueLocations = store.uniqueLocations
    if !uniqueLocations.contains(location) {
        let suggestedMatches = uniqueLocations.filter { $0.contains(location) }

        if suggestedMatches.count == 1 {
            let suggestion = suggestedMatches.first!
            let dialog = IntentDialog("Did you mean \(suggestion)?")
            let confirmed = try await $location.requestConfirmation(for: suggestion, dialog: dialog)
            if confirmed {
                self.location = suggestion
            } else {
                throw $location.needsValueError()
            }
        } else if suggestedMatches.count < 5 {
            let dialog = IntentDialog("Multiple locations match \(location). Did you mean one of these?")
            throw $location.needsDisambiguationError(among: suggestedMatches.sorted(), dialog: dialog)
        } else {
            throw $location.needsValueError(IntentDialog("No matches for \(location)."))
        }
    }
}
```

三个层级：确认一个接近匹配、消歧小集合、从头再问。按候选数量模式匹配选择正确 UX。

## 基本参数的 `DynamicOptionsProvider`

`AppEnum` 处理固定集合。`AppEntity` 处理带查询的可识别事物。那么一个参数是普通 `String` 但应从运行时计算的列表中提取——如从用户自己数据加载的位置名称集合呢？

提供 `DynamicOptionsProvider`：

```swift
struct LocationOptionsProvider: DynamicOptionsProvider {
    @Dependency var store: DataStore

    func results() async throws -> [String] {
        store.uniqueLocations.sorted(using: KeyPathComparator(\.self, comparator: .localizedStandard))
    }
}
```

将其附加到参数：

```swift
@Parameter(requestValueDialog: "Where would you like to go?",
           optionsProvider: LocationOptionsProvider())
var location: String?
```

Shortcuts 现在显示由 `results()` 填充的选择器。用户仍可输入任意字符串（参数类型是 `String`，非 enum）——在 `perform()` 内验证其输入并用 `requestConfirmation` / 消歧从近似匹配恢复。

`DynamicOptionsProvider` 在以下情况正确：

- 值是受限列表，非开放式字符串。
- 列表从 App 状态计算（用户创建的标签、保存的位置、最近收件人）。
- 值不是可识别的 entity（仅字符串）。

对于可识别的领域对象，改用带 `EntityQuery` 的 `AppEntity`。

## Measurement 参数选项

`Measurement` 参数接受单位和符号偏好：

```swift
@Parameter(defaultUnit: .kilometers, supportsNegativeNumbers: false)
var searchRadius: Measurement<UnitLength>?
```

- `defaultUnit:` - Shortcuts 初始选择的单位。用户仍可切换单位，但这是起点且未提供显式单位时存储的单位。
- `supportsNegativeNumbers:` - 当值领域上无意义时禁用减号切换（负半径、负持续时间）。

在 `perform()` 内显式转换——用户可能以一种单位配置快捷方式但你的内部数据可能以另一种存储：

```swift
if var searchRadius {
    searchRadius.convert(to: .meters)  // app 以米存储数据
    results = results.filter { $0.distanceToTrail.value <= searchRadius.value }
}
```

## `@Parameter` vs 普通属性

只有 `@Parameter` 注解的属性暴露给系统。普通属性对 `perform()` 内本地缓存没问题，但对 Shortcuts、Siri 和参数提示系统不可见。

## 内部 intent 上省略 `title:`

对于 `isDiscoverable = false` 的 intent（支撑按钮、snippet 或其他 intent 的辅助 intent），不带 `title:` 的 `@Parameter` 可以——没人会看到参数 UI：

```swift
struct LogAmountIntent: AppIntent {
    static let title: LocalizedStringResource = "Log caffeine amount"
    static let isDiscoverable: Bool = false

    @Parameter var amount: Int
    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult {
        try store.log(Double(amount))
        return .result()
    }
}

extension LogAmountIntent {
    init(amount: Int) {
        self.amount = amount
    }
}
```

尾随 `init(amount: Int)` 是让 SwiftUI 代码写 `Button(intent: LogAmountIntent(amount: 64))` 的东西（参见 `open-and-snippet-intents.md`）。始终为接受参数并支撑按钮的 intent 添加它——你无法以其他方式传递参数。

## Entity 间关系

参数本身可以是 `AppEntity` 数组用于批量操作：

```swift
@Parameter(title: "Articles") var articles: [ArticleEntity]
```

Shortcuts 将其渲染为多选列表；Siri 问"哪些文章？"并接受多个名称。

## 大 entity 参数的 `EntityCollection`（iOS 27+）

在 intent 运行前，系统**完全解析每个 entity 参数**——它调用你的查询填充所有属性，使 `perform()` 有它可能需要的一切。对于持有千张照片的 `[PhotoEntity]` 参数，这意味着即使你的代码只需要 **id** 来更新数据模型，也要解析千个 entity。大规模时，那很慢。

`EntityCollection<Entity>` 存储**标识符**而非解析的 entity。作为参数类型，它告诉系统*不要*在参数解析期间解析每个 id——它只给你 id：

```swift
struct TagPhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "Tag Photos"

    @Parameter(title: "Photos")
    var photos: EntityCollection<PhotoEntity>

    @Parameter(title: "Tag")
    var tag: String

    func perform() async throws -> some IntentResult {
        // 直接将标识符传给数据层 - 无 1,000 个 entity 的水合。
        try await photoStore.addTag(tag, toPhotosWith: photos.identifiers)
        return .result()
    }
}
```

- `photos.identifiers` 是 id 数组。当你真正需要完整 entity 时，调用 `await photos.resolvedEntities()`（它通过你的查询解析并缓存结果）。
- `EntityCollection` 遵循 `Collection` / `Sequence` / `ExpressibleByArrayLiteral`，带 `count`、`isEmpty`、`contains`、`append`、`remove` 和 `init(entities:)` / `init(identifiers:)`。

从 `[PhotoEntity]` 到 `EntityCollection<PhotoEntity>` 的更改很小；大选择上的加速很大。每当参数可能持有大量 entity 且你的 `perform()` 主要需要 id 时使用它。对于你使用其属性的少数 entity，普通 `[Entity]` 数组可以。

## 保持 perform() 类型化

始终将 perform 结果类型化为与你返回的完全匹配——`some IntentResult & ProvidesDialog & ReturnsValue<Int>` 必须匹配 `.result(...)` 调用，否则运行时崩溃。不确定时，返回更少（`some IntentResult`）并随着接线添加能力。
