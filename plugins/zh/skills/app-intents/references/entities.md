# App entity

`AppEntity` 是系统理解你领域对象的方式。Entity 让用户通过语音、在 Shortcuts 中点击或在 Spotlight 中选择来将文章、书签、播放列表、房间等作为参数选择。

## sendability 规则

`AppEntity` 遵循 `AppValue` 并要求 `Sendable`。SwiftData `@Model` 类、Core Data `NSManagedObject` 和任何其他引用类型数据模型**不是** sendable 的。它们不能是 `AppEntity`。

```swift
// 错误 - 在 Swift 6 下无法编译，早期版本产生 sendability 警告
@Model
class Article { ... }
extension Article: AppEntity { ... }   // conformance of 'Article' to 'Sendable' unavailable
```

修复是创建一个单独的 `struct` entity，**映射**你想暴露给系统的字段，然后在查询边界进行转换。

```swift
struct ArticleEntity: AppEntity {
    var id: UUID
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(summary)",
            image: .init(systemName: "doc.text")
        )
    }
}
```

在底层 model 中，添加一个计算属性以低成本生成 entity：

```swift
@Model
final class Article {
    var id = UUID()
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    var entity: ArticleEntity {
        ArticleEntity(
            id: id,
            title: title,
            summary: summary,
            publishedAt: publishedAt,
            thumbnailURL: thumbnailURL
        )
    }

    init(...) { ... }
}
```

现在加载 entity 意味着加载 model 并用 `\.entity` 映射：

```swift
try modelContext.fetch(descriptor).map(\.entity)
```

## 必需成员

`AppEntity` 必须提供：

| 成员 | 用途 |
|---|---|
| `var id: some Hashable & Sendable` | 稳定的唯一标识符。`UUID` 很好。 |
| `static let typeDisplayRepresentation: TypeDisplayRepresentation` | 类型级名称（"Article"）。在选择器和 Siri 中使用。 |
| `static let defaultQuery: some EntityQuery` | 系统在需要填充参数时如何加载 entity。 |
| `var displayRepresentation: DisplayRepresentation` | 在选择器、通知、Spotlight 卡片中显示的每实例标签。 |

`typeDisplayRepresentation` 在该类型的所有 entity 间共享；`displayRepresentation` 是每实例的。不要混淆它们。

## Entity 属性包装器

系统应通过 Shortcuts 选择器、参数摘要、Find intent 和 Spotlight attribute set 暴露的字段需要被包装。普通存储属性对你的代码可见但对 App Intents 框架不可见。

### `@Property` - 暴露的存储属性

```swift
struct ArticleEntity: AppEntity {
    var id: UUID

    @Property var name: String
    @Property(title: "Region") var regionDescription: String
    @Property var trailLength: Measurement<UnitLength>

    // 未暴露（系统无法查询或排序）
    var imageName: String
    var currentConditions: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Trail"
    static let defaultQuery = TrailEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(regionDescription)",
                              image: DisplayRepresentation.Image(named: imageName))
    }
}
```

`@Property` 包装器让你能够：

- 在 `parameterSummary` 键路径中使用字段（`Summary("...\(\.$name)...")`）
- 在 `EntityPropertyQuery`（自动生成的 Find intent）中使用它
- 在 `SortableBy(\.$name)` 中引用它
- 通过 `@ComputedProperty(indexingKey:)` 映射到 Spotlight 索引键

title 默认为变量名；提供 `@Property(title: "Region")` 以自定义。

### `@ComputedProperty` - 暴露的计算属性

将计算属性映射到暴露面：

```swift
struct LandmarkEntity: IndexedEntity {
    var landmark: Landmark
    var modelData: ModelData

    @ComputedProperty(indexingKey: \.displayName)
    var name: String { landmark.name }

    // 将 description 变量映射到 Spotlight 索引键 `contentDescription`。
    @ComputedProperty(indexingKey: \.contentDescription)
    var description: String { landmark.description }

    // 将 continent 变量映射到自定义 Spotlight 索引键。
    @ComputedProperty(
        customIndexingKey: CSCustomAttributeKey(
            keyName: "com_example_LandmarkEntity_continent"
        )!
    )
    var continent: String { landmark.continent }
}
```

`indexingKey:` 将属性映射到标准 `CSSearchableItemAttributeSet` 键之一（`\.displayName`、`\.contentDescription`、`\.keywords`、...）。`customIndexingKey:` 使用你声明的自定义 Spotlight attribute 键。两者都自动馈送 Spotlight——这些字段无需单独的 `attributeSet` 代码。

### `@DeferredProperty` - 惰性异步属性

对于计算昂贵或需要异步访问的字段，不要急切加载：

```swift
@DeferredProperty
var crowdStatus: Int {
    get async throws {
        await modelData.getCrowdStatus(self)
    }
}
```

系统仅在消费者（快捷方式、Siri、Spotlight）实际需要时物化值。当值涉及网络往返、模型推理或昂贵数据库聚合时使用 `@DeferredProperty`。

### 同义词使快捷方式缓存失效

当 entity 的用户可见标题变化——通过重命名、添加条目或更改 `displayRepresentation.synonyms`——调用 `YourShortcutsProvider.updateAppShortcutParameters()` 让系统刷新建议缓存。参见 `shortcuts-and-siri.md`。

## 复数化类型名称和同义词

`TypeDisplayRepresentation` 接受可选的 `numericFormat` 用于复数化，`DisplayRepresentation` 接受 `synonyms` 使 Siri 接受替代表述：

```swift
static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(
        name: LocalizedStringResource("Trail", table: "AppIntents"),
        numericFormat: LocalizedStringResource("\(placeholder: .int) trails", table: "AppIntents")
    )
}

var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
        title: "Workout Summary",
        subtitle: "\(calories) calories",
        image: DisplayRepresentation.Image(systemName: "figure.hiking"),
        synonyms: ["Activity Summary", "Session Summary"]
    )
}
```

## 瞬态 entity

并非所有 intent 返回的数据都有持久化标识符。摘要、聚合统计或请求范围的包装器不应遵循 `AppEntity`——它需要一个无意义的 `EntityQuery`。改用 `TransientAppEntity`：

```swift
struct ActivityStatisticsSummary: TransientAppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Summary")

    @Property var summaryStartDate: Date
    @Property var workoutsCompleted: Int
    @Property var caloriesBurned: Measurement<UnitEnergy>
    @Property var distanceTraveled: Measurement<UnitLength>

    init() {
        summaryStartDate = Date()
        workoutsCompleted = 0
        caloriesBurned = Measurement(value: 0, unit: .calories)
        distanceTraveled = Measurement(value: 0, unit: .meters)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Workout Summary",
                              subtitle: "You burned \(caloriesBurned.formatted()) calories.",
                              synonyms: ["Activity Summary"])
    }
}
```

无 `id`，无 `defaultQuery`——Shortcuts 不会尝试枚举或查找它们。但 `@Property` 仍适用，因此快捷方式中的下游操作可以将 `distanceTraveled` 或 `caloriesBurned` 作为类型化输入链式传递。

对即时计算且仅存在于该 intent 调用的返回数据使用 `TransientAppEntity`。

## 文件支撑的 entity：`FileEntity`

对于*就是*文件的 entity（扫描文档、录制的语音备忘、你的 App 生成的图像），`FileEntity` 替代了"通过 Transferable 导出为文件的 entity"的尴尬模式。iOS 18+。

```swift
import AppIntents
import UniformTypeIdentifiers

struct ScanEntity: FileEntity {
    static let supportedContentTypes: [UTType] = [.pdf, .png]

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Scan"
    static let defaultQuery = ScanEntityQuery()

    var id: FileEntityIdentifier   // 从 URL 或草稿标识符构建
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
```

`FileEntityIdentifier` 包装一个具体的文件 URL（带书签数据用于持久化）或用于尚不存在文件的*草稿标识符*。系统的文件处理机制可以直接对 entity 操作——"旋转此扫描"、"将此扫描附加到消息"——无需 Transferable 转换。

当东西*就是*文件时使用 `FileEntity`。当东西是有文件表示（除其他外）的领域对象时使用带 `Transferable` 的 `AppEntity`。

## `@UnionValue` 参数：接受多种 entity 类型

当参数合理地可以是多种 entity 类型中的任何一种（路线*或*保存的位置；文章*或*书签），将联合声明为 enum：

```swift
@UnionValue
enum DestinationValue {
    case route(RouteEntity)
    case savedLocation(SavedLocationEntity)
}

struct NavigateIntent: AppIntent {
    @Parameter var destination: DestinationValue

    func perform() async throws -> some IntentResult {
        switch destination {
        case .route(let r):         try await navigator.go(to: r)
        case .savedLocation(let s): try await navigator.go(to: s)
        }
        return .result()
    }
}
```

每个 `@UnionValue` case 恰好有一个关联值，且该值是不同类型。Shortcuts 显示组合选择器；Siri 问消歧问题。比写两个仅在参数类型上不同的兄弟 intent 更可取。

用 `typeDisplayRepresentation`（联合类型的标签）和 `caseDisplayRepresentations`（每个 case 的标签）自定义联合在选择器中的显示方式——宏生成其余部分（类型信息、case 元数据、选择器支持）：

```swift
@UnionValue
enum PhotoSource {
    case landmarkCollection(LandmarkCollectionEntity)
    case photoAlbum(PhotoAlbumEntity)

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Photo Source")
    static let caseDisplayRepresentations: [PhotoSource: DisplayRepresentation] = [
        .landmarkCollection: "Landmark Collection",
        .photoAlbum: "Photo Album"
    ]
}
```

`@UnionValue` 参数在 intent 工作的所有地方工作——Shortcuts、Siri **和小组件**（一个小组件配置支撑两种 entity 类型）。相同的宏用于 `IntentValueQuery` 结果（参见 `assistant-schemas.md` 中的视觉智能示例）。

## 可传输的 entity

让 `AppEntity` 遵循 `Transferable` 使其可与其他 App 分享，并作为具体数据（图像、PDF、文本、RTF）转发给 Siri / Apple Intelligence：

```swift
extension LandmarkEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { @MainActor landmark in
            // 渲染 PDF 并返回 SentTransferredFile(url)
        }

        DataRepresentation(exportedContentType: .image) {
            try $0.imageRepresentationData
        }

        DataRepresentation(exportedContentType: .plainText) {
            """
            Landmark: \($0.name)
            Description: \($0.description)
            """.data(using: .utf8)!
        }
    }
}
```

当 Siri 或系统分享面板请求 entity 的内容时，它们使用此表示。顺序重要：把更丰富的表示放前面；系统选择消费者接受的第一个。

`Transferable` 对于期望可导出内容的 schema（如 `.photos.asset`）是必需的。它也是让"发送此到邮件"或"总结此"在 entity 是当前屏幕内容时工作的方式。

### `ProxyRepresentation` 用于单字段导出

当 entity 的导出内容只是其一个存储属性时，跳过 `DataRepresentation` 闭包，用 `ProxyRepresentation(exporting:)` 加键路径：

```swift
extension JournalEntryEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.entryText)
    }
}
```

比闭包形式短；适用于任何类型本身是 `Transferable` 的属性（`String`、`Data`、`URL`、另一个 entity）。导出内容类型来自属性的类型。

对简单传递使用 `ProxyRepresentation`；当导出字节从多个字段计算或需要格式化时下降到 `DataRepresentation` / `FileRepresentation` 闭包。

### `IntentValueRepresentation` / `ValueRepresentation` 用于结构化系统类型（iOS 26.4+）

`FileRepresentation` 和 `DataRepresentation` 只携带已知*文件格式*（PDF、图像、文本）。坐标、联系人或人名没有文件格式——地图无法导航到 `.plainText` blob，它需要 `PlaceDescriptor`。`IntentValueRepresentation`（用 `ValueRepresentation` 构建器构建）将你的 entity 桥接到**系统 intent 值**——`IntentPerson`、`PlaceDescriptor`（GeoToolbox）、`PersonNameComponents`——并支持导入和导出。将它添加到你其他表示旁边：

```swift
static var transferRepresentation: some TransferRepresentation {
    // 当 entity 已将系统类型存储为 @Property 时用键路径形式：
    ValueRepresentation(exporting: \.place)        // place: PlaceDescriptor

    // 或导出+导入的闭包形式：
    ValueRepresentation(
        exporting:  { contact in IntentPerson(name: .displayName(contact.name)) },
        importing:  { person in ContactEntity(name: person.name.displayString) }
    )
}
```

这是让"导航到此地标"和"呼叫此联系人"跨越 App 边界的方式。完整处理——包括解析现有（`IntentValueQuery`）vs. 导入为新——在 `onscreen-awareness.md` 中。

## `DisplayRepresentation` 结构

```swift
var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
        title: "\(title)",
        subtitle: "\(summary)",
        image: .init(systemName: "doc.text")
    )
}
```

### 缩略图图像

iOS 17+ 添加了接受多种支撑源的图像字段：

```swift
// 打包的图像资源
DisplayRepresentation(title: "\(name)", image: DisplayRepresentation.Image(named: "trail-hero"))

// 系统图像
DisplayRepresentation(title: "\(name)", image: .init(systemName: "doc.text"))

// 远程 URL（系统获取并缓存）
DisplayRepresentation(title: "\(name)", image: DisplayRepresentation.Image(url: thumbnailURL))

// 原始数据（缩略图在运行时派生时有用）
DisplayRepresentation(title: "\(name)", image: .init(data: try entity.thumbnailData))
```

变体：

```swift
// 最小
DisplayRepresentation(title: "\(title)")

// 标题 + 副标题
DisplayRepresentation(title: "\(title)", subtitle: "\(summary)")

// 带 URL 支撑图像（缩略图）
DisplayRepresentation(
    title: "\(title)",
    image: DisplayRepresentation.Image(url: thumbnailURL)
)

// 带 SF Symbol
DisplayRepresentation(
    title: "\(title)",
    image: .init(systemName: "book.closed")
)

// 带着色符号
DisplayRepresentation(
    title: "\(title)",
    image: .init(systemName: "book.closed", tintColor: .systemBlue)
)
```

## Entity 查询

系统无法猜测如何加载你的 entity。你必须提供查询。

### `EnumerableEntityQuery`（小、可加载集合）

当整个集合小且枚举成本低时使用——文件夹、标签列表、起始预设。

```swift
struct FolderEntityQuery: EnumerableEntityQuery {
    @Dependency var store: DataStore

    func allEntities() async throws -> [FolderEntity] {
        try await store.folderEntities()
    }

    func entities(for identifiers: [FolderEntity.ID]) async throws -> [FolderEntity] {
        try await store.folderEntities(matching: #Predicate {
            identifiers.contains($0.id)
        })
    }
}
```

`allEntities()` 和 `entities(for:)` 都是必需的。`entities(for:)` 在系统已知 id 需要解析回 entity 时调用——在 Shortcuts 重新评估期间常见。

### `EntityQuery`（大、可搜索集合）

当可能有数千条目时使用。添加 `EntityStringQuery` 以支持按字符串搜索（Siri 语音查找、Shortcuts"Find…"）。

```swift
struct ArticleEntityQuery: EntityQuery {
    @Dependency var store: DataStore

    func entities(for identifiers: [ArticleEntity.ID]) async throws -> [ArticleEntity] {
        try await store.articleEntities(matching: #Predicate {
            identifiers.contains($0.id)
        })
    }

    func suggestedEntities() async throws -> [ArticleEntity] {
        // 显示在选择器顶部；返回最近或固定的项目。
        try await store.articleEntities(sortBy: [.init(\.publishedAt, order: .reverse)], limit: 10)
    }
}

extension ArticleEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ArticleEntity] {
        try await store.articleEntities(matching: #Predicate { article in
            article.title.localizedStandardContains(string)
        })
    }
}
```

### `UniqueIDEntityQuery`

用于你恰好有一个标识符列和简单按 id 查找的常见情况的便利。

### `EntityPropertyQuery` - 自动生成的 Find intent

让你的查询遵循 `EntityPropertyQuery` 会自动向 Shortcuts App 添加一个 **Find intent**——对 entity 暴露的 `@Property` 字段的通用、用户可配置谓词搜索。用户可以构建"查找标题包含 X 且长度小于 Y 的文章，按日期排序"而无需你编写 UI。

```swift
extension TrailEntityQuery: EntityPropertyQuery {
    typealias ComparatorMappingType = Predicate<TrailEntity>

    static let properties = QueryProperties {
        Property(\TrailEntity.$name) {
            ContainsComparator { searchValue in
                #Predicate<TrailEntity> { $0.name.localizedStandardContains(searchValue) }
            }
            EqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.name == searchValue }
            }
            NotEqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.name != searchValue }
            }
        }

        Property(\TrailEntity.$trailLength) {
            LessThanOrEqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.trailLength <= searchValue }
            }
            GreaterThanOrEqualToComparator { searchValue in
                #Predicate<TrailEntity> { $0.trailLength >= searchValue }
            }
        }
    }

    static let sortingOptions = SortingOptions {
        SortableBy(\TrailEntity.$name)
        SortableBy(\TrailEntity.$trailLength)
    }

    static var findIntentDescription: IntentDescription? {
        IntentDescription("Search for trails matching complex criteria.",
                          categoryName: "Discover",
                          searchKeywords: ["trail", "location", "travel"],
                          resultValueName: "Trails")
    }

    func entities(matching comparators: [Predicate<TrailEntity>],
                  mode: ComparatorMode,
                  sortedBy: [EntityQuerySort<TrailEntity>],
                  limit: Int?) async throws -> [TrailEntity] {
        // 1. 针对谓词过滤 entity
        // 2. 按 `sortedBy` 排序
        // 3. 截断到 `limit`
    }
}
```

要求：

- `QueryProperties` 中引用的每个属性必须在 entity 上标记 `@Property`。
- 每个 `Property(...)` 块列出用户可应用的比较器（`ContainsComparator`、`EqualToComparator`、`LessThanOrEqualToComparator`、...）。只有对字段类型语义上有意义的比较器才有用。
- `sortingOptions` 列出哪些属性可排序。
- `findIntentDescription` 填充 Shortcuts App 中自动生成的 Find intent 的呈现。

`entities(matching:mode:sortedBy:limit:)` 函数接收闭包谓词；`mode` 是 `.and` 或 `.or`，取决于用户如何组合条件。循环、评估、排序、限制。

### `EnumerableEntityQuery` 也支持 Find intent

对于小固定集合，`EnumerableEntityQuery` 单独获得基本 Find intent（按名称过滤）而无需额外代码。添加 `findIntentDescription` 以自定义其呈现：

```swift
struct FeaturedCollectionEntityQuery: EnumerableEntityQuery {
    static var findIntentDescription: IntentDescription? {
        IntentDescription("Find a featured collection.",
                          categoryName: "Discover",
                          searchKeywords: ["collection", "featured"],
                          resultValueName: "Collections")
    }

    func allEntities() async throws -> [CollectionEntity] { ... }
    func entities(for identifiers: [CollectionEntity.ID]) async throws -> [CollectionEntity] { ... }
    func suggestedEntities() async throws -> [CollectionEntity] { ... }
}
```

选择查询遵循：

| 遵循 | Find intent? | 最适合 |
|---|---|---|
| `EntityQuery` | 否 | 任何 entity 类型（基线） |
| `EntityQuery + EntityStringQuery` | 否 | 大数据集带按名称搜索 |
| `EnumerableEntityQuery` | 基本（按名称过滤） | 小固定集合（文件夹、类别） |
| `EntityPropertyQuery` | 完整（谓词+排序） | 大数据集带多个可查询字段 |

App 可以在同一查询上采纳多个遵循（Apple 的 `LandmarkEntityQuery` 同时是 `EntityQuery`、`EntityStringQuery` 和 `EnumerableEntityQuery`）。每个遵循启用不同的系统面向能力。

## 谓词陷阱：id 的本地副本

在 `#Predicate` 内按 entity 的 id 过滤时，先将 id 复制到本地常量。宏不穿透 entity 类型上的属性路径：

```swift
// 错误 - 宏在此位置无法到达 entity.id
try store.articles(matching: #Predicate { $0.id == entity.id })

// 正确
let id = entity.id
try store.articles(matching: #Predicate { $0.id == id })
```

## 注册默认查询

Entity 通过 `defaultQuery` 引用其查询：

```swift
struct ArticleEntity: AppEntity {
    ...
    static let defaultQuery = ArticleEntityQuery()
    ...
}
```

没有 `defaultQuery`，参数选择器为空且 Siri 无法解析命名的 entity。

## 跨设备身份：`SyncableEntity`（iOS 27+）

Siri 可以跨设备继续对话（"添加一张照片"在 iPhone 上，"给那张照片打标签"在 iPad 上）。为此，同一 entity 必须在每台设备上有**相同的 id**。本地生成的 id（Core Data 行 id、每设备 UUID）破坏这一点——每台设备发明自己的。

`SyncableEntity` 声明 entity 的 id 在各处稳定。如果你的 id *已经*跨设备一致（服务端分配的 UUID、CloudKit 记录 id），只需采纳协议——无需其他更改：

```swift
struct Article: AppEntity, SyncableEntity {
    var id: UUID          // 已稳定（来自你的服务端）- 无需其他操作
    var title: String
    // ...
}
```

如果你在设备上使用**本地** id 但有单独的稳定 id，用 `SyncableEntityIdentifier` 配对。你的代码继续使用本地 id；系统使用稳定 id 跨设备引用 entity：

```swift
struct Photo: AppEntity, SyncableEntity {
    var id: SyncableEntityIdentifier<String, String>   // <本地, 稳定>
    var creationDate: Date

    init(localID: String, stableID: String, creationDate: Date) {
        self.id = SyncableEntityIdentifier(local: localID, stable: stableID)
        self.creationDate = creationDate
    }
}
```

在 Siri 可能引用可跨设备跳转的对话中的任何 entity 上采纳 `SyncableEntity`。

## 建议相关 entity：`RelevantEntities`（iOS 27+）

Spotlight 使内容**可找到**；交互捐赠教系统**模式**。两者都不帮助还没被搜索或使用过的内容——一个适合跑步的全新高节奏播放列表，但从未被播放过。`RelevantEntities` 让你*主动提示*在给定上下文中哪些 entity 相关，以便系统在正确时刻呈现它们（如作为健身中的建议锻炼播放列表）。

```swift
// 建议跑步播放列表；系统在正确的上下文中呈现它们。
let workoutContext = AppEntityContext.audio(.workout(activityType: .running))
try await RelevantEntities.shared.updateEntities(runningPlaylists, for: workoutContext)
```

- 用 `updateEntities(_:for:)` 一次提供完整集合——每次调用**替换**你对该上下文的先前建议（传 `[]` 以清除）。
- Entity 保持注册直到你移除它们：`removeEntities(_:from:)`、`removeAllEntities(for:)` 或 `removeAllEntities()`。如果 App 未启动，系统也在大约四周后自动过期建议。
- 从 `AppEntityContext` 构建上下文——如 `AppEntityContext.audio(.workout(activityType: .running))` 用于跑步锻炼。每个领域暴露其自己的嵌套上下文 case。

在三种发现机制间选择：**Spotlight** 当内容应可被 Siri 搜索/检索；**交互捐赠**教系统人们如何使用 App（参见 `siri-intelligence.md`）；**`RelevantEntities`** 提示哪些内容在特定情境中重要。

## 索引 entity（Spotlight）

`IndexedEntity` 是 `AppEntity` 的子协议，使 entity 可通过 Spotlight 搜索。参见 `spotlight.md`。

```swift
struct ArticleEntity: IndexedEntity { ... }   // 代替 AppEntity
```

无额外必需成员——entity 的 `displayRepresentation` 用于自动构建 Spotlight 卡片。覆盖 `attributeSet` 以丰富索引。
