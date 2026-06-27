# Spotlight 索引

Spotlight 在系统搜索 UI 中呈现 App entity 并将点击路由回 `OpenIntent`。设置是三个小步骤。

## 1. 遵循 `IndexedEntity`

`IndexedEntity` 是 `AppEntity` 的子协议，添加 Spotlight 行为。无额外必需成员——entity 的 `displayRepresentation` 用于构建 Spotlight 卡片。

```swift
import AppIntents
import CoreSpotlight

struct ArticleEntity: IndexedEntity {
    var id: UUID
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: "doc.text"))
    }
}
```

## 2. 将 entity 发送到 `CSSearchableIndex`

索引是异步的并在 UI 之外发生。将你的 entity 交给 `CSSearchableIndex.default().indexAppEntities(_:)`。

```swift
import CoreSpotlight

guard CSSearchableIndex.isIndexingAvailable() else {
    return
}
try await CSSearchableIndex.default().indexAppEntities(entities)
```

`isIndexingAvailable()` 在不支持 Spotlight 索引的平台/配置（某些 watchOS 设置、用户禁用）上返回 `false`。守护避免虚假错误日志。

这就是整个 API。你传递 `IndexedEntity` 实例；系统提取显示表示、attribute set 和 id。

## 3. 决定何时索引

没有唯一正确答案——根据你内容的可变性选择。

### 视图出现时完整重新索引

简单，对小数据集（几百条目）可以：

```swift
struct ArticleList: View {
    @Query private var articles: [Article]

    var body: some View {
        List(articles) { article in
            NavigationLink(article.title, value: article)
        }
        .task(indexAll)
    }

    @Sendable func indexAll() async {
        try? await CSSearchableIndex.default().indexAppEntities(articles.map(\.entity))
    }
}
```

优点：正确性优先，无变更跟踪。
缺点：对大数据集或很少变化的内容浪费工作。

### 变更时每 entity 重新索引

当特定字段变化时索引一个项目。与防抖任务一起使用，这样你不在每次按键时重新索引：

```swift
struct ArticleEditor: View {
    @Bindable var article: Article
    @State private var indexingTask: Task<Void, Error>?

    var body: some View {
        Form {
            TextField("Title", text: $article.title)
            TextField("Body", text: $article.body, axis: .vertical)
        }
        .onChange(of: article.title,  scheduleIndex)
        .onChange(of: article.body,   scheduleIndex)
    }

    func scheduleIndex() {
        indexingTask?.cancel()
        indexingTask = Task {
            try await Task.sleep(for: .seconds(1))
            try await CSSearchableIndex.default().indexAppEntities([article.entity])
        }
    }
}
```
在睡眠前取消前一个任务意味着快速打字产生一次索引调用，而非二十次。

### 启动时批量索引

如果你的内容实际上是静态的（精选目录、预设库），在 `App.init()` 或首次启动时索引一切，不必费心每变更跟踪。

Apple 的明确建议（WWDC24）是在 `App.init()` 内部执行初始索引——这保证索引在任何 intent、小组件或 Siri 调用可以呈现过时或缺失 entity 之前运行。对于可变内容，将启动索引与每变更更新配对（见前两个策略）。

## Spotlight 是 Siri 的语义索引

从 27 发布起，索引到 Spotlight 是 **Siri 检索你内容的主要方式**——根据 App Intents 领域，它提供**语义搜索**：Siri 按*含义*匹配，而非仅关键字（"messages about movies"找到提到电影标题的消息），理解 entity 间关系，并可以回答内容问题。采纳 `IndexedEntity` 并保持索引当前；这是解锁最佳 Siri 体验的方式。对于无法提前索引的内容（大、服务端或易变），回退到 `IntentValueQuery`——参见 `siri-intelligence.md`。同一索引也可被设备端 LLM 查询：一旦索引，你的内容可通过 Foundation Models 框架中的 `SpotlightSearchTool` 搜索（WWDC 2026 Session 246），这是 Foundation Models 主题而非 App Intents 主题。

## 支持重新索引：`IndexedEntityQuery`（iOS 27+）

Spotlight 偶尔需要你的 App **重新索引**其内容（索引遇到问题或需要重建）。让你的 entity 查询遵循 `IndexedEntityQuery`——`EntityQuery` 对 `IndexedEntity` 类型的改进——系统在需要时调用你的重新索引方法：

```swift
struct PhotoEntityQuery: IndexedEntityQuery {
    @Dependency var photoStore: PhotoStore

    // ... entities(for:), suggestedEntities() 像往常 ...

    func reindexEntities(for identifiers: [PhotoEntity.ID],
                         indexDescription: CSSearchableIndexDescription) async throws {
        let photos = try await photoStore.fetch(ids: identifiers)
        try await CSSearchableIndex(name: "MyPhotosApp").indexAppEntities(photos)
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let all = try await photoStore.fetchAll()
        try await CSSearchableIndex(name: "MyPhotosApp").indexAppEntities(all)
    }
}
```

何时**不**必费心：如果你已通过 Core Spotlight 级 API 支持重新索引——即 `CSSearchableIndexDelegate`，或你通过 `CSSearchableItem` + `associateAppEntity` 捐赠——系统继续使用该路径，你不需要 `IndexedEntityQuery`。当你的索引通过 `indexAppEntities(_:)` 进行且你想要一等重新索引支持而无 delegate 时采纳它。

## 将属性映射到索引键：`@ComputedProperty(indexingKey:)`

如果你已用 `@ComputedProperty` 声明 entity 计算属性（参见 `entities.md`），你可以直接将它们映射到 Spotlight attribute-set 键，无需编写任何 `attributeSet` 代码：

```swift
struct LandmarkEntity: IndexedEntity {
    @ComputedProperty(indexingKey: \.displayName)
    var name: String { landmark.name }

    @ComputedProperty(indexingKey: \.contentDescription)
    var description: String { landmark.description }

    @ComputedProperty(
        customIndexingKey: CSCustomAttributeKey(
            keyName: "com_example_LandmarkEntity_continent"
        )!
    )
    var continent: String { landmark.continent }
}
```

标准索引键（`\.displayName`、`\.contentDescription`、`\.keywords`、`\.addedDate`、...）对应 `CSSearchableItemAttributeSet` 上的字段。自定义键用于不适合任何标准的领域特定属性；通过 `CSCustomAttributeKey(keyName:)` 声明一次并一致引用。

这是为大多数 entity 馈送 Spotlight 的最精简方式。仅当你需要无法从单个计算属性映射的字段（如从多个输入构造的图像 URL）时下降到显式 `attributeSet` 计算属性。

## 将 Spotlight 项目与 entity 关联：`associateAppEntity`

某些 App 已有围绕 `CSSearchableItem` 构建的成熟 Spotlight 索引管道——非 entity 的 `Trail` 或 `Document` 类型，带精心调整的 `CSSearchableItemAttributeSet`。与其重写索引以通过 `IndexedEntity` 进行，不如将现有 `CSSearchableItem` 与匹配的 `AppEntity` 关联：

```swift
import CoreSpotlight

func updateSpotlightIndex() async {
    guard CSSearchableIndex.isIndexingAvailable() else { return }

    let searchableItems = trails.map { trail in
        let item = CSSearchableItem(
            uniqueIdentifier: String(trail.id),
            domainIdentifier: nil,
            attributeSet: trail.searchableAttributes
        )

        let isFavorite = favoritesCollection.members.contains(trail.id)
        let priority = isFavorite ? 10 : 1
        let entity = TrailEntity(trail: trail)

        // 将 Spotlight 项目链接到对应 AppEntity。
        // 必须在项目添加到索引前发生。
        item.associateAppEntity(entity, priority: priority)
        return item
    }

    try? await CSSearchableIndex.default().indexSearchableItems(searchableItems)
}
```

为什么重要：

- App 现有的 `CSSearchableItem` 管道继续不变工作。
- 当用户点击 Spotlight 结果时，系统知道 `AppEntity` 与之关联，并通过匹配的 `OpenIntent` 路由点击（参见 `open-and-snippet-intents.md`）而非仅打开 App。
- `priority:` 推动排名——收藏/固定项目获得更大数字并更早出现。

每个 entity 选一种方法：要么 `indexAppEntities([entity])`（用于新 App 和简单情况），要么带 `item.associateAppEntity(entity, priority:)` 的 `indexSearchableItems([item])`（当你已有详细 attribute-set 管道时）。

## 用 `attributeSet` 丰富 Spotlight 卡片

在你的 `IndexedEntity` 上覆盖 `var attributeSet: CSSearchableItemAttributeSet` 以添加超出默认显示表示的内容。从 `defaultAttributeSet` 开始，不要从零构建：

```swift
import CoreSpotlight

struct ArticleEntity: IndexedEntity {
    var id: UUID
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: "doc.text"))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.contentDescription = summary
        set.addedDate = publishedAt
        set.thumbnailURL = thumbnailURL
        set.keywords = ["article", "reading"]
        return set
    }
}
```

有用的 `CSSearchableItemAttributeSet` 字段（还有更多——自动补全是你的朋友）：

- `contentDescription` - Spotlight 搜索的正文文本。
- `addedDate`、`contentCreationDate`、`contentModificationDate`、`dueDate`、`startDate`、`completionDate`。
- `thumbnailURL`、`thumbnailData`。
- `keywords` - 权重高于正文的字符串数组。
- `authors`、`contributors`（`CSPerson` 数组）。
- `artist`、`album`（用于音频）。
- `latitude`、`longitude`、`namedLocation`（用于地理标记内容）。

系统的排名算法不透明；更多信号通常有帮助。不要滥用语义负载字段（`dueDate`、`startDate`）用于无关数据——Siri 可能字面解释它们（"什么快到期？"呈现无关项目）。

## 点击打开

点击 Spotlight 结果通过匹配的 `OpenIntent` 落入你的 App（参见 `open-and-snippet-intents.md`）。匹配是：结果 entity 类型 → `target` 参数是该 entity 类型的 `OpenIntent`。无额外注册。

## 清理

App 卸载时系统自动移除你的索引。如果项目在 App 内被删除：

```swift
try await CSSearchableIndex.default().deleteAppEntities(
    identifiedBy: [deletedID],
    ofType: ArticleEntity.self
)
```

## 调试

在模拟器的开发者菜单中有两个值得知道的切换：

- **Display Recent Shortcuts** - 显示缓存的快捷方式建议，确认它们到达系统。
- **Display Donations on Lock Screen** - 显示 intent 捐赠，在接线预测快捷方式时有帮助。

模拟器中 Spotlight 索引的可靠性明显比设备上差；如果搜索"找不到任何东西"，在假设代码 bug 前尝试设备。
