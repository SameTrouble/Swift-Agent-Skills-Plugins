# Siri 和 Apple Intelligence 集成

随着 27 发布（WWDC 2026），Siri——由 Apple Intelligence 驱动——可以通过 App Intents 对你的 App 做三件新事：

1. **访问你的 entity** - 通过读取 App 中的真实内容回答"我的下一个会议什么时候在哪里？"
2. **采取行动** - "把我的最新报告发给 Mary"运行你的 intent；Siri 处理语言，你的 App 做工作。
3. **理解屏幕上下文** - "解释这个"、"给这个事件里的人发邮件"针对可见内容解析。

此文件是该集成层的地图。机制位于邻近文件：

- schema 采纳（`@AppEntity(schema:)`、`@AppIntent(schema:)`、领域、Xcode 代码片段）→ `assistant-schemas.md`。
- 屏幕感知和内容传递 → `onscreen-awareness.md`。
- 测试 → `testing-intents.md`。

## 其形态

一切都从 `AppEntity` 开始——你已有内容（消息、事件、照片）的结构化描述。Entity 描述*东西是什么*、*如何识别*以及*哪些属性重要*。它不是新数据模型；它是你现有模型的透镜。

仅 entity 不足以让 Siri 推理它。让其遵循 **App schema**，使 Siri 知道*类别*（`messages`、`calendar`、`photos`、...）并可以共享术语推理，而非将你的 App 视为黑盒。然后暴露**操作**为 `AppIntent`；让 Siri 应执行的遵循 schema intent（`@AppIntent(schema: .messages.sendMessage)`），Siri 可以从自然语言运行它们而无需你编写短语。

```
AppEntity            → 描述你的内容
  + AppSchema        → Siri 理解它是什么类别
AppIntent            → 向整个系统暴露操作
  + AppSchema        → Siri 可以从语音执行操作
```

## 查找内容：三条路径

在 Siri 可以对内容操作前，它必须*找到*它。按 entity 类型选择——你可以在 App 间混合。

### 1. 语义索引（首选）：`IndexedEntity`

遵循 `IndexedEntity` 并用 `CSSearchableIndex.default().indexAppEntities(_:)` 捐赠到 Spotlight。这填充**语义索引**，给 Siri 基于含义的匹配、entity 间关系，以及回答内容问题的能力——而非仅精确字符串检索。

```swift
// "Show the messages with Flare about movies" - 语义的，非字符串匹配。
struct MessageEntity: IndexedEntity {
    @ComputedProperty(indexingKey: \.contentDescription)
    var body: String { message.body }
    // ...
}
```

保持索引活跃：创建时索引、显示表示中使用的属性变化时重新索引、移除时删除。参见 `spotlight.md` 了解索引策略和新的 `IndexedEntityQuery` 重新索引协议。

这是 Siri 检索你内容的**主要**方式。除非不能，否则采纳它。

### 2. 结构化搜索：`IntentValueQuery`

当数据集太大、服务端或太易变无法提前索引时，实现 `IntentValueQuery`。它像 `EntityQuery`，有两个区别：系统给你**结构化搜索输入**，且你可以返回**多种 entity 类型**（通过 `@UnionValue`）。

```swift
struct AudioEntityQuery: IntentValueQuery {
    @Dependency var library: MusicLibrary

    func values(for input: AudioSearch) async throws -> [AudioEntity] {
        switch input.criteria {
        case .searchQuery(let term):
            return try await library.search(term)          // 说的相关部分
        case .unspecified:
            return try await library.likedSongs()           // "Play CosmoTune" - 只播放东西
        case .url(let url):
            return try await library.item(at: url)          // "Play that playlist Glow sent me"
        @unknown default:
            return []
        }
    }
}

@UnionValue
enum AudioEntity {
    case song(SongEntity)
    case playlist(PlaylistEntity)
}
```

`AudioSearch.criteria`（和每领域搜索输入类型）携带结构化查询。处理对你领域有意义的 case；查看文档了解完整标准集。

### 3. App 内搜索：`.system.searchInApp`

当用户想*查找*而非操作（"show me running playlists in CosmoTune"），Siri 的默认是通用结果列表。要将结果路由到你自己的搜索 UI，采纳系统搜索 schema：

```swift
@AppIntent(schema: .system.searchInApp)
struct SearchInAppIntent: ShowInAppSearchResultsIntent {
    var criteria: StringSearchCriteria
    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.openSearch(with: criteria.term)
        return .result()
    }
}
```

`.system.searchInApp` 是 iOS 17 引入的 `.system.search` schema 的**新名称**。它位于 System app-schema 领域中，无论你采纳哪些其他领域都工作，即使你不索引任何内容。

## 塑造 Siri 的响应

默认 Siri 自己组合响应。你为个性和清晰度自定义。

- **让 Siri 处理。** 返回空 `IntentResult`，Siri 编写响应。
- **自定义对话。** 添加 `ProvidesDialog` 并返回 `IntentDialog(full:supporting:)`。Siri 在仅语音设备（AirPods、HomePod）上**读取 `full` 字符串**，并与 UI 一起**显示 `supporting` 字符串**。`full` 字符串必须作为口头语言独立成立。（参见 `fundamentals.md` 了解对话和语法一致性。）
- **运行中澄清问题。** 在完成前用 `$param.requestValue(...)` 询问值——如当一个计时器已在运行时要求用户命名新计时器。谨慎询问；每个问题都是摩擦。（参见 `parameters.md`。）
- **视觉。** Entity 的 `DisplayRepresentation`（标题+副标题+图像）到处复用——响应、相似 entity 间消歧、问题答案、Spotlight、Shortcuts、*以及确认对话框*。一次投入。对于完全自定义结果卡片，返回 `ShowsSnippetView`（参见 `open-and-snippet-intents.md`）。

## 交互捐赠（`IntentDonationManager`）

系统已从用户通过 Siri 和 Shortcuts 运行的 intent 学习——那些自动捐赠。它**看不到**的是用户通过你 App 自己 UI 做相同操作。捐赠那些 UI 交互教 Apple Intelligence 用户的模式，以便它后来可以推断（例如）给定联系人用户偏好哪个消息 App。

干净模式：UI 和 schema intent 都调用一个共享助手；助手接受标志，因此它只捐赠 **UI** 路径。

```swift
func sendMessage(_ body: String, to contact: ContactEntity, donateInteraction: Bool) async throws {
    let message = try await messenger.send(body, to: contact)

    if donateInteraction {
        var intent = SendMessageIntent()
        intent.recipient = contact
        intent.content = body
        IntentDonationManager.shared.donate(intent: intent, result: .resolved(value: message.entity))
    }
}
```

- 在操作完成后捐赠，带尽可能多细节。当操作产生有趣内容时包含结果值。
- 仅捐赠 UI 交互——不要重新捐赠系统已为你捐赠的 intent。
- **不要过度捐赠。** 如果你的 App 淹没系统，它可能开始忽略你的捐赠。使捐赠反映真实、完成的用户行为。
- 当底层数据被移除或用户撤销操作时，用 `deleteDonations(matching:)` **删除过时捐赠**——它改善未来建议。

### 捐赠让 Siri 感知持续活动

某些 intent 启动或停止有状态活动。捐赠这些让 Siri 可以对*当前*那个操作。从你的 Maps 领域 App UI 启动的 `NavigationSession` 被捐赠，因此当用户上车说"add a stop on the way"，Siri 知道哪个会话是活跃的。时钟领域中的秒表同理（启动/停止/暂停/圈数）。捐赠启动和停止，使 Siri 可以针对活跃活动。

## 确认和所有权

大型语言模型可能失火，因此 Siri 在有有意义副作用的 intent 前——特别是破坏性或面向外的——**自动要求确认**。

默认 Siri 假设你的 entity 对用户**私有**，可能跳过对它们的确认（更新个人事件风险低）。但更新用户**分享或公开**的东西值得提示。通过遵循 `OwnershipProvidingEntity`（iOS 27+）告诉 Siri 哪些 entity 是那些：

```swift
@AppEntity(schema: .photos.album)
struct PhotoAlbumEntity: OwnershipProvidingEntity {
    let id = UUID()
    var isSharedWithFamily: Bool
    var isPublicAlbum: Bool
    // ... schema 属性 ...

    var ownership: EntityOwnership {
        var ownership: EntityOwnership = []
        if isSharedWithFamily { ownership.insert(.shared) }
        if isPublicAlbum      { ownership.insert(.public) }
        return ownership
    }
}
```

- **仅**向用户实际可以分享或发布的 entity 添加协议。
- 保持 `ownership` 为最新——系统在请求 entity 时读取它，并在决定是否及如何确认时使用它（加上 entity 的 `DisplayRepresentation`）。

关于更广泛的信任/风险故事，参见 Apple 的"Secure your app: Mitigate risks to agentic features."

## schema 可以要求其兄弟（Xcode 告诉你）

某些 Siri 流程需要多个 schema 才能完整。如果你采纳了 `.messages.sendMessage` 但没有 `.messages.draftMessage`，**构建失败**并给出诊断——通过 Siri 发送消息需要草稿步骤用于确认。这是在编译时而非运行时呈现的设计提示。点击错误，Xcode 提供**修复建议**，生成缺失 schema 的正确连接桩采纳；你填写 App 特定部分（连接 entity、注入依赖、处理输入、打开正确视图）。修改 UI 状态意味着标记该 `perform()` 为 `@MainActor`。

将这些构建错误视为完整集成的检查清单，而非障碍。

## 验证流程

按此顺序测试——先便宜和孤立，最后完整系统：

1. **`AppIntentsTesting`** - 进程外、无 Siri 涉及地执行 intent、entity 和查询。最快、最可靠；在 CI 中运行。参见 `testing-intents.md`。
2. **Shortcuts App** - 验证每个 intent 的*形状*：参数、输入、如何呈现。
3. **Spotlight** - 确认 entity 已索引、可发现且可链接，使 Siri 可以在操作前找到正确数据。
4. **Siri** - 完整端到端：自然语言、entity 解析、屏幕上下文、跨 App 工作流。在设备上测试。

## 入门检查清单

1. 将内容建模为 `AppEntity`；遵循匹配的 App schema。
2. 将 entity 索引到 Spotlight（`IndexedEntity`）；为无法索引的数据添加 `IntentValueQuery`。
3. 将操作暴露为 schema intent；让 Siri 驱动语言。
4. 采纳 `Transferable` / `IntentValueRepresentation` 用于跨 App 内容（参见 `onscreen-awareness.md`）。
5. 用 entity 标注视图和系统集成以提供上下文。
6. 向可分享 entity 添加 `OwnershipProvidingEntity`，使确认正确。
7. 一旦基础工作，捐赠 UI 交互。
8. 早期用 `AppIntentsTesting` 测试，然后 Shortcuts → Spotlight → Siri。
