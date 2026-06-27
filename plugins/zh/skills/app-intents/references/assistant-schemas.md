# Assistant schema（Apple Intelligence）

普通的 `AppEntity` / `AppIntent` 让 Siri 理解*你的*概念。**Assistant schema** 让 Siri 以*共享的跨 App 类别*来理解你的概念——日记条目、邮件消息、浏览器书签、照片资产、电子表格单元格。这是让 Apple Intelligence 跨 App 组合的层（"把我最近在信息中分享的三张照片拿来写一篇关于它们的日记条目"）。

大多数 schema 需要 iOS 18.2+；某些日记、邮件和电子表格 schema 需要 18.4+。*消费*这些 schema 的功能可用性正在缓慢推出——采纳 schema 使你的数据合格，但不保证它会被使用。

## App Intent 领域

Schema 按**领域**分组——每个 App 类别一个，Apple 已在其上预训练 Siri/Apple Intelligence。每个领域附带 `create`、`open`、`update`、`delete` 和 `search` schema 变体，整个系列有约 100 个预训练 intent。

目前已发布的领域：

- `.books` - 阅读位置、标注、书库
- `.browser` - 标签页、书签、历史
- `.calendar` - 事件、日历、参与者（`.calendar.event`、`.calendar.calendar`、`.calendar.attendee`、`createEvent`、`updateEvent`、`deleteEvent`、...）
- `.camera` - 拍摄流程
- `.files` - 文档操作
- `.journal` - 条目编写和搜索
- `.mail` - 编写、回复、搜索（`sendMessage` 与 `draftMessage` 配对——参见下文"schema 可以要求其兄弟"）
- `.messages` - 发送/草拟消息
- `.photos` - 资产、相簿、人物
- `.presentations` - 幻灯片、演示文稿
- `.spreadsheets` - 单元格、范围、模板
- `.system` - 搜索（`.system.searchInApp`）、分享、打印、`.system.open`
- `.systemSearch` - 搜索查询和建议
- `.visualIntelligence` - 语义内容搜索
- （其他在后续 iOS 发布中推出。）

下面自动补全驱动的代码片段是权威列表——Apple 在小版本 OS 发布中添加领域和 schema。在代码跟随工作流中，你输入领域前缀（`calendar_`、`photos_`、...），Xcode 提供该领域中每个 schema。

采纳最匹配你 App 的具体领域。阅读类 App 用 `.books`；markdown 笔记 App 用 `.journal`；扫描类 App 用 `.files` + `.photos`。

## 采纳 schema

在 entity 类型上使用 `@AssistantEntity(schema:)`：

```swift
import AppIntents
import CoreLocation

@AssistantEntity(schema: .journal.entry)
struct JournalEntryEntity: IndexedEntity {
    var id: UUID

    // 这些名称和类型由 schema 规定——你不能重命名它们
    var title: String?
    var message: AttributedString?
    var mediaItems: [IntentFile]
    var entryDate: Date?
    var location: CLPlacemark?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Journal entry"
    static let defaultQuery = JournalEntryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title ?? "Untitled")")
    }
}
```

关键后果：

- **规定的属性名称和类型。** `message` 必须是 `AttributedString?`，不是 `String`。`entryDate` 是 `Date?`，可选。`location` 是 `CLPlacemark?`。宏验证这些，如果你偏离则发出不透明的编译器错误。
- **比你预期更多的可选性。** 许多 schema 必需的字段是可选的，即使你的真实数据总是有它们。在初始化器或显示表示中提供合理的回退。
- 为任何携带位置的 schema **导入 `CoreLocation`**。

### 便利初始化器

因为宏将存储属性重写为私有的 `_entityProperty` 包装版本，合成的 init 很丑。为内部使用提供你自己的 `init`：

```swift
init(id: UUID, title: String?, body: String, createdAt: Date?, location: CLPlacemark? = nil) {
    self.id = id
    self.title = title
    self.message = AttributedString(body)
    self.mediaItems = []
    self.entryDate = createdAt
    self.location = location
}
```

## 采纳 intent schema

与 entity 对称。使用 `@AssistantIntent(schema:)` 或较新的 `@AppIntent(schema:)` 形式：

```swift
@AppIntent(schema: .photos.createAssets)
struct CreateAssetsIntent: AppIntent {
    var files: [IntentFile]

    @Dependency
    var library: MediaLibrary

    @MainActor
    func perform() async throws -> some ReturnsValue<[AssetEntity]> {
        guard !files.isEmpty else { throw IntentError.noEntity }

        var result: [AssetEntity] = []
        for file in files {
            let asset = try await library.createAsset(from: file)
            result.append(asset.entity)
        }
        return .result(value: result)
    }
}

@AppIntent(schema: .photos.openAsset)
struct OpenAssetIntent: OpenIntent {
    var target: AssetEntity
    @Dependency var library: MediaLibrary
    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        let assets = library.assets(for: [target.id])
        guard let asset = assets.first else { throw IntentError.noEntity }
        navigation.openAsset(asset)
        return .result()
    }
}

@AppIntent(schema: .photos.updateAsset)
struct UpdateAssetIntent: AppIntent {
    var target: [AssetEntity]
    var name: String?
    var isHidden: Bool?
    var isFavorite: Bool?

    @Dependency var library: MediaLibrary

    func perform() async throws -> some IntentResult {
        let assets = await library.assets(for: target.map(\.id))
        for asset in assets {
            if let isHidden   { try await asset.setIsHidden(isHidden) }
            if let isFavorite { try await asset.setIsFavorite(isFavorite) }
        }
        return .result()
    }
}

@AppIntent(schema: .photos.deleteAssets)
struct DeleteAssetsIntent: DeleteIntent {
    static let openAppWhenRun = true

    var entities: [AssetEntity]

    @Dependency var library: MediaLibrary

    @MainActor
    func perform() async throws -> some IntentResult {
        let ids = entities.map(\.id)
        let assets = library.assets(for: ids)
        try await library.deleteAssets(assets)
        return .result()
    }
}

@AppIntent(schema: .photos.search)
struct SearchAssetsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.openSearch(with: criteria.term)
        return .result()
    }
}
```

schema 决定：

- 哪些参数是必需/可选的以及它们的名称必须是什么。
- intent 必须返回什么（通常是匹配 schema 类型的 entity）。
- 遵循哪个 intent 子协议（`.photos.openAsset` 用 `OpenIntent`，`.photos.deleteAssets` 用 `DeleteIntent`，`.photos.search` 用 `ShowInAppSearchResultsIntent`，...）。

`@AppIntent(schema:)` 是现代语法；`@AssistantIntent(schema:)` 也可以且等价。新代码应使用 `@AppIntent(schema:)`。

## schema 可以要求其兄弟（Xcode 强制执行）

某些 Siri 流程用单个 schema 不完整。如果你采纳了 `.messages.sendMessage` 但**没有** `.messages.draftMessage`，项目**构建失败**并给出诊断——通过 Siri 发送消息还需要草稿步骤（用于发送前确认）。这是在编译时而非运行时静默失败时呈现的有意设计提示。

点击错误，Xcode 提供**修复建议**，生成缺失 schema 的正确连接的桩采纳——intent 定义、必需参数和 `perform()` 桩。然后你填写 App 特定部分：连接 entity、注入依赖（`@Dependency`）、处理输入、打开正确的视图。如果操作修改 UI 状态，标记其 `perform()` 为 `@MainActor`。

将这些错误视为迈向完整、高质量集成的检查清单。构建系统告诉你缺少什么并帮助你搭建脚手架。

## 在 Apple Intelligence 到达用户前测试 schema intent

Assistant-schema intent 随着苹果逐步推出每个 schema 的消费者而逐渐在 Siri / Apple Intelligence 中点亮。在那之前，在 **Shortcuts App** 内测试它们：

- 在 Shortcuts 库中，按 **AssistantSchemas** 过滤以只看到遵循 schema 的 intent。
- 像任何其他操作一样手动配置和运行它们；执行路径与 Siri 调用时相同。
- 一旦消费的 Apple Intelligence 界面发布，无需代码更改——相同的 intent 自动变为 Siri 可寻址的。

这是 schema 仍在推出时的预期验证路径。

## Xcode schema 代码片段

Xcode 16+ 为每个 schema 附带代码片段。在编辑器中输入领域名称（`journal`、`photos`、`mail`）；补全提供每个 schema 的 intent、entity 和 enum 的预填充骨架——名称和类型已正确，因此你避免宏的隐晦"字段不匹配 schema"错误。

首次采纳时使用代码片段。仅从 API 文档手写 schema 类型容易出错，因为宏拒绝小偏差且无有用诊断。

### 浏览可用 schema

在宏参数中输入领域名称后跟点，Xcode 补全列出该领域中的每个 schema：

```swift
@AppIntent(schema: .photos.|)     // Xcode 显示 .asset, .album, .createAssets, .openAsset, ...
@AppEntity(schema: .journal.|)    // Xcode 显示 .entry, .entryLocation, ...
```

比搜索 Apple 文档快。将补全作为权威列表；Apple 在小版本 OS 发布中添加 schema 而不总是更新文档集索引。

## 采纳 schema 的 enum

enum 也可以声明 schema 采纳。宏强制允许的 case 名称：

```swift
@AppEnum(schema: .photos.assetType)
enum AssetType: String, AppEnum {
    case photo
    case video

    static let caseDisplayRepresentations: [AssetType: DisplayRepresentation] = [
        .photo: "Photo",
        .video: "Video"
    ]
}
```

`.photos.assetType` schema 要求恰好 `.photo` 和 `.video` case。在无 schema 支持的情况下添加 `.livePhoto` case 无法编译；你需要一个单独的非 schema enum。

## 采纳 schema 的 entity

将 entity 宏与照片 schema 结合使用：

```swift
@AppEntity(schema: .photos.asset)
struct AssetEntity: IndexedEntity {

    static let defaultQuery = AssetQuery()

    let id: String
    let asset: Asset

    @Property(title: "Title")
    var title: String?

    var creationDate: Date?
    var location: CLPlacemark?
    var assetType: AssetType?
    var isFavorite: Bool
    var isHidden: Bool
    var hasSuggestedEdits: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: title.map { "\($0)" } ?? "Unknown",
            subtitle: assetType?.localizedStringResource ?? "Photo"
        )
    }
}
```

schema 强制字段名称（`creationDate`、`location`、`isFavorite` 等）及其类型。如果你重命名或重新定义类型，宏会发出编译错误。

## schema 特定的 intent 协议

多个 intent 子协议针对特定 schema 行为：

### `DeleteIntent`

```swift
@AppIntent(schema: .photos.deleteAssets)
struct DeleteAssetsIntent: DeleteIntent {
    static let openAppWhenRun = true
    var entities: [AssetEntity]
    ...
}
```

将 intent 暴露为系统标准删除操作。系统可能在调用 `perform()` 前自动提示确认。

### `ShowInAppSearchResultsIntent`

```swift
@AppIntent(schema: .photos.search)
struct SearchAssetsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]
    var criteria: StringSearchCriteria
    ...
}
```

将系统搜索查询路由到 App 的 App 内搜索 UI。Siri / Spotlight / 视觉智能可以调用此 intent，使结果出现在 App 的原生搜索中而非外部卡片。

`.system.searchInApp` 是此 schema 的通用版本，任何 App 类型都可用。它是 iOS 17 引入的 `.system.search` schema 的**新名称**（27 发布）——如果你采纳了旧名称，更新引用。照片和邮件 App 使用领域特定变体（`.photos.search`、`.mail.search`）。无论你采纳哪些其他领域它都能工作，即使你不索引任何内容。

## 通过 Shortcuts 的 Apple Intelligence：Use Model 操作

iOS 26+。Shortcuts 附带**Use Model**操作，调用设备端、Private Cloud Compute 或 ChatGPT 模型，以 App Entity 作为输入和输出：

- **App entity 输入** - Shortcuts 运行时将 entity 序列化为 JSON（其显示表示、类型名称和暴露的 `@Property` 值）并作为上下文传递给模型。
- **输出** - 模型可以发出文本、字典、布尔值或你声明的类型的 App Entity。下游 intent 接收它作为类型化值。
- **后续轮次** - 该操作支持多轮对话，适用于 App 数据上的助手流程。

对于 intent 作者，两个影响：

### 文本参数接受 `AttributedString`，而非 `String`

当 intent 的文本参数可能接收模型输出时，声明为 `AttributedString`：

```swift
@Parameter(title: "Body")
var body: AttributedString
```

模型越来越多地生成富文本（粗体、斜体、列表、表格）。`String` 参数丢失格式；`AttributedString` 无损保留。内部需要纯文本时，使用 `String(body.characters[...])`。

### 通过 `@Property` 暴露模型应看到的字段

Use Model 操作发送给模型的 JSON 由你 entity 的 `@Property` 暴露字段构建（加上 `typeDisplayRepresentation` 和 `displayRepresentation`）。未标记 `@Property` 的字段对模型不可见。审查你的 entity 中任何用户友好的模型响应需要的字段。

这是一个直接的、低仪式的与 Apple Intelligence 的集成点，不需要 schema 采纳——任何具有良好形态 entity 的 `AppIntent` 都自动参与。

## 视觉智能：`IntentValueQuery` + `@UnionValue`

在 iOS 18.4+ 上，系统的**视觉智能**功能让用户圈选一个对象（在相机视图中或屏幕上）以跨 App 搜索。App 通过实现一个接受 `SemanticContentDescriptor`（携带像素缓冲区）并返回匹配 entity 的 `IntentValueQuery` 来参与。

用 `@UnionValue` 声明结果类型集合：

```swift
#if canImport(VisualIntelligence)
import AppIntents
import VideoToolbox
import VisualIntelligence

@UnionValue
enum VisualSearchResult {
    case landmark(LandmarkEntity)
    case collection(CollectionEntity)
}

struct LandmarkIntentValueQuery: IntentValueQuery {

    @Dependency var modelData: ModelData

    func values(for input: SemanticContentDescriptor) async throws -> [VisualSearchResult] {

        guard let pixelBuffer: CVReadOnlyPixelBuffer = input.pixelBuffer else {
            return []
        }

        let landmarks = try await modelData.search(matching: pixelBuffer)
        return landmarks
    }
}
#endif
```

`@UnionValue` 让一个查询返回多种 entity 类型；系统将它们显示为统一结果列表。每种 entity 类型一个 case。

要在用户选择结果后将其路由回 App，将查询与采纳 schema 的 intent 配对：

```swift
#if canImport(VisualIntelligence)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct ShowSearchResultsIntent {
    static let title: LocalizedStringResource = "Image Search"
    var semanticContent: SemanticContentDescriptor
}

extension ShowSearchResultsIntent: TargetContentProvidingIntent {}
#endif
```

如果你支持功能存在之前的 OS 版本，用 `#if canImport(VisualIntelligence)` 守护视觉智能界面。

### 现在也在 iPad 和 macOS 上

从 27 发布起，Visual Intelligence 在 **iOS、iPadOS 和 macOS** 上运行——相同的 `IntentValueQuery`、entity 和 `OpenIntent` 在所有三个平台上工作，无需代码更改。需要处理的平台差异：

- **入口点。** iOS 是相机优先（物理对象——黑胶、海报）；macOS 和 iPad 是截图优先（数字媒体）。确保你的搜索能很好地处理两种输入。
- **图像大小。** 在 Mac 上，输入像素缓冲区可能比 iPhone 上大得多；考虑在喂给匹配器前调整大小。

### 结果显示和延续

- `DisplayRepresentation` 是首先显示的——大约**三行文本**（标题+副标题）加缩略图。把最具识别性的信息放前面。提供**缩略图大小**的图像，而非全分辨率资产（加载更快，在双列布局中合适）。如果你返回单个结果，该图像占满 sheet 的整个宽度。
- **快速且按排名**返回结果；限制数量以保持相关性；无良好匹配时返回空数组（系统显示空状态）。
- `OpenIntent` 在 App 前台时运行——保持轻量；做导航，延迟重加载直到视图出现后。复用现有的 `OpenIntent`；你不需要视觉智能专用的。
- 通过 `.visualIntelligence.semanticContentSearch` schema 提供进入你**完整** App 内搜索的方式（"更多结果"按钮）。系统提供 `SemanticContentDescriptor`；从中预填充你的搜索视图而非空白开始。

### 从 Visual Intelligence 接收数据：系统存储

还有第二个方向。除了通过图像搜索*提供*结果外，你的 App 可以*接收* Visual Intelligence 写入共享**系统存储**的数据——如果你已经从它们读取，则是自动的：

- 通过 EventKit（`EKEventStore`）的**事件** - 例如从海报捕获的音乐会出现在你的日历读取中。
- 通过 Contacts（`CNContactStore`）的**联系人** - 例如从名片捕获的联系人。
- 通过 HealthKit（`HKHealthStore`）的**医疗设备读数** - 例如从显示器捕获的血压/血糖/体重读数。

添加通知观察者（如 `EKEventStoreChanged`）使新捕获的项目——包括 Visual Intelligence 创建的——在 App 中呈现而无需手动输入。此侧不需要 App Intents 代码；如果你的 App 已经读取这些存储，这是免费获得的收益。

## 让屏幕内容对 Siri 可用

屏幕感知故事（使用哪个视图标注 API、用 `Transferable` / `IntentValueRepresentation` 进行内容传递、通知 / Now Playing / AlarmKit 上的 entity 标注）现在有自己的参考：**`onscreen-awareness.md`**。下面旧版 `userActivity(_:element:)` 模式仍然是单个主要屏幕项目和旧 OS 版本的正确选择。

## 让屏幕内容对 Siri 可用：`userActivity(_:element:)`

当 entity 在你的 UI 中可见时，如果 App 声明了一个将可见视图链接到 entity 的 `NSUserActivity`，Siri / Apple Intelligence 可以引用它（"我能用这张照片做什么？"）。

```swift
import SwiftUI

struct AssetDetailView: View {
    let asset: Asset

    var body: some View {
        MediaView(image: asset.image)
            .userActivity(
                "com.example.MyApp.ViewingPhoto",
                element: asset.entity
            ) { element, activity in
                activity.title = "Viewing a photo"
                activity.appEntityIdentifier = EntityIdentifier(for: element)
            }
    }
}
```

两个必需部分：

- `element:` - 视图代表的 `AppEntity` 实例。
- `activity.appEntityIdentifier = EntityIdentifier(for: element)` - 这是让系统将"屏幕上的东西"与你 App 理解的特定 entity 关联的方式。

要让 Siri 实际转发 entity 的*内容*（而非仅引用），entity 还必须遵循 `Transferable`（参见 `entities.md`）。文本、图像和 PDF 表示是最常用的有用形式。

典型设置：

1. 用 `@AppEntity(schema:)` 或普通 `AppEntity` 声明 entity。
2. 让其遵循 `Transferable` 以获得可导出内容。
3. 当视图可见时用 `.userActivity(_:element:)` 注册屏幕活动。

三者都就位后，Siri 可以回答"这是什么？"、将内容转发给用户点击的第三方服务，或将其用作另一个 intent 的输入——全部由上下文驱动而非显式命令。

## 可用 schema（代表性）

类别（非详尽）：

- `.books.*` - 书籍、有声书、书库
- `.browser.*` - 书签、窗口、标签页
- `.files.*` - 文件
- `.journal.*` - entry、entryLocation、createEntry、updateEntry、searchEntries
- `.mail.*` - message、account、composition
- `.photos.*` - asset、assetType、album、person、createAssets、openAsset、updateAsset、deleteAssets、search
- `.presentations.*` - 幻灯片演示文稿、幻灯片
- `.spreadsheets.*` - 工作表、单元格、范围、模板
- `.systemSearch.*` - 搜索查询、搜索建议
- `.visualIntelligence.*` - semanticContentSearch（用于视觉智能集成）

Xcode 16+ 附带代码片段。在编辑器中输入 `journal` 或 `mail`，补全菜单提供每个 schema 的 intent 和 entity 骨架；鉴于宏的严格性，这是到目前为止采纳 schema 最快的方式。

## 采纳能让你获得什么

原则上：

- 你的数据参与系统搜索（"找到我提到柏林的笔记"）。
- 跨 App 组合（"拿这篇日记条目并在邮件中分享"）。
- Siri 理解领域动词（"将此追加到我上一篇日记条目"）而无需你为每个短语接线。

实际上，截至 2026 年初，消费 assistant schema 的功能界面正在不均匀地推出。在 schema 密切匹配你领域的地方采纳，但将实际行为视为移动目标——在当前 iOS 发布上验证，而非在 WWDC24 公告上。

## 何时不采纳

- 你的数据真正新颖，不适合任何 schema。不要为了匹配而扭曲你的 model；坚持普通 `AppEntity`。
- schema 强制失去保真度（如你有丰富的 markdown，而 schema 坚持 `AttributedString` 会丢失你的扩展）。权衡集成收益与建模成本。
- 你仍在 iOS 17 或更早版本——assistant schema 要求 18.2+。

## 版本控制注意事项

Xcode 在宏展开代码中嵌入 schema 版本（"journal entry 1.0.0"）。schema 预期会演进——Apple 选择宏正是为了在不破坏现有采纳者的情况下添加字段。将 schema 采纳视为任何平台 API：在需要更新的 schema 功能时提升最低部署目标，并预期初期有一些变动。

## 共存

你可以在同一个 App 中同时拥有普通 `AppEntity` 和采纳 schema 的 entity。某些流程需要原始类型；某些需要 schema 形态的。在需要的地方在它们之间映射，而非试图让一个 entity 兼顾两者。
