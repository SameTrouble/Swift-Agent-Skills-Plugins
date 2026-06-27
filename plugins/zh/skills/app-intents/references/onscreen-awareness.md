# 屏幕感知和内容传递

两个能力将"用户正在看什么"变成 Siri / Apple Intelligence 可以操作的东西：

- **屏幕感知** - 告诉系统*哪些 entity*可见及*在哪里*，这样用户可以说"编辑这个"、"第三个"、"这个事件里的人"而不用命名任何东西。
- **内容传递** - 将你的 entity 导出为其他 App 理解的类型，并导入其他 App 交给你的内容。这是让"把这段对话发给我妻子"或"导航到此地标"跨越 App 边界的方式。

两者都建立在 `AppEntity` 上。系统已从像素知道屏幕上的原始文本；标注添加*结构化*层——每个 UI 部分代表哪个 entity，以及哪些属性和操作适用。需要 iOS 18.2+；下面的集合和自定义画布改进随 27 发布（WWDC 2026）到来。

## 四个屏幕感知 API

按可见 entity 数量和绘制方式选择。

### 1. `NSUserActivity` - 一个主要项目

当屏幕专用于单一事物（文档、当前播放的曲目、一个事件的详情视图）时使用。附加 `.userActivity` 并设置其 `appEntityIdentifier`：

```swift
struct EventDetailView: View {
    let event: EventEntity

    var body: some View {
        DetailLayout(event: event)
            .userActivity("com.example.CometCal.ViewingEvent", element: event) { event, activity in
                activity.title = "Viewing an event"
                activity.appEntityIdentifier = EntityIdentifier(for: event)
            }
    }
}
```

Siri 将"这个事件"/"什么时候？"/"在哪里？"解析为屏幕上恰好那一个。`NSUserActivity` 也是较新标注修饰符不可用的旧 OS 版本的向后兼容路径。

### 2. 视图 entity 标注 - 少数中的一个

当屏幕显示小固定 entity 集合（几张卡片、作为离散视图渲染的短列表）时，将 `.appEntityIdentifier(_:)` 附加到代表 entity 的每个视图：

```swift
ForEach(events) { event in
    EventRow(event: event)
        .appEntityIdentifier(EntityIdentifier(for: event))
}
```

系统现在知道哪个视图映射到哪个 entity。"给第二个里的人发邮件"被解析。

### 3. 集合标注 - 多个 entity，惰性

每行 `.appEntityIdentifier` 适用于少数，但为长列表中的*每一*行附加一个是浪费的，且标注在行滚出视图层次结构的瞬间消失。对于列表和集合，标注**容器**并让系统惰性获取标识符：

```swift
List(selection: $selection) {
    ForEach(tracks) { track in
        TrackRow(track: track)
    }
}
.appEntityIdentifier(forSelectionType: Track.ID.self) { selectionID in
    EntityIdentifier(for: TrackEntity.self, identifier: selectionID)
}
```

相比每行标注的优势：

- 系统**按需**获取标识符，而非为每个可见行预先获取。
- 它可以发现用户**选择然后滚出屏幕**的 entity——每行标注已经消失了。

对于任何可能持有超过少数项目的 `List` / 集合使用此方法。

### 4. 自定义画布标注 - 非标准绘制

当内容绘制在单个 `Canvas`、`CALayer` 或其他非每-entity-视图的表面中时，没有视图可附加标识符。通过带 `.appEntityUIElements(_:)` 的闭包提供 entity：

```swift
Canvas { context, size in
    notes.forEach { context.fill(Path(roundedRect: $0.frame, cornerSize: .zero), with: .color($0.colorFill)) }
}
.appEntityUIElements { context in
    notes.compactMap { note in
        let wanted = context.requests.contains { request in
            switch request {
            case .visible(let rect): return note.frame.intersects(rect)
            case .selected:          return note.isSelected
            @unknown default:        return false
            }
        }
        guard wanted else { return nil }
        return AppEntityUIElement(
            identifier: EntityIdentifier(for: StickyNote.self, identifier: note.id),
            bounds: note.frame,
            state: .init(isSelected: note.isSelected)
        )
    }
}
```

系统传递一个 context，其 `requests` 请求矩形中的**可见** entity 或**选中的**；你为每个匹配项返回一个 `AppEntityUIElement`（标识符+边界+选择状态）。这是自定义波形、钢琴卷帘、地图画布或自由画板参与屏幕感知的方式。

### UIKit / AppKit

所有四个 API 都有非 SwiftUI 等价物：

- **单个/每项：** 任何 responder 遵循 `AppEntityAnnotatable`——设置其 `appEntityIdentifier` 属性。
- **自定义绘制：** 设置视图的 `appEntityUIElementProvider` 闭包（与 `.appEntityUIElements` 相同的 `context.requests` 形状）。
- **集合：** 采纳 `UICollectionViewAppIntentsDataSource` / `UITableViewAppIntentsDataSource`（macOS 上的 `NS*` 变体），使数据源惰性提供 entity 标识符。

这些也为 UIKit App 中的上下文菜单项提供支持——参见 Apple 的"Modernize your UIKit app."

## 让屏幕理解快速：`displayRepresentations`

当屏幕显示许多 entity 时，Siri 必须*快速*理解它们以回答"播放第三个"——如果解析慢，它可能放弃、要求澄清或做错事。不要让它从你的数据库获取完整 entity 只为读标签。

在 entity 的查询上实现 `displayRepresentations` 方法，让 Siri 只拉取文本表示。接受 `requestedComponents` 参数，这样你只物化系统实际要求的部分——`.text` 用于普通标签，vs 完整标题/副标题/图像——并在只需文本时跳过加载艺术作品或运行查询：

```swift
extension TrackEntityQuery {
    func displayRepresentations(
        for identifiers: [TrackEntity.ID],
        requestedComponents: DisplayRepresentation.Components = .text
    ) async throws -> [TrackEntity.ID: DisplayRepresentation] {
        try await store.trackTitles(for: identifiers).mapValues {
            DisplayRepresentation(title: "\($0)")
        }
    }
}
```

现在解析屏幕内容在只需显示文本时跳过沉重的 `entities(for:)` 路径和数据库往返。根据 `requestedComponents` 分支以仅在系统请求时添加副标题或缩略图。值得添加到出现在可滚动列表中的任何 entity。

## 内容传递：导出和导入 entity

屏幕感知让 Siri *识别* entity。要将它实际移入另一个 App 的操作（"发这个"、"导航到此"、"总结此"），entity 必须可导出——要从另一个 App 接收内容，可导入。两者都通过 `Transferable`。

### 结构化系统类型：`IntentValueRepresentation`（iOS 26.4+）

`Transferable` 的 `FileRepresentation` / `DataRepresentation` 覆盖已知文件格式（PDF、图像、文本）。它们**不能**携带无文件格式的结构化类型——坐标、联系人、人名。地图无法导航到 `.plainText` blob；它需要 `PlaceDescriptor`。

`IntentValueRepresentation`（用 `ValueRepresentation` 构建器构建）将你的 `AppEntity` 桥接到**系统 intent 值**——`IntentPerson`、`PlaceDescriptor`（来自 GeoToolbox）、`PersonNameComponents` 和其他 `_SystemIntentValue` 类型——并支持导入和导出。将它添加到你其他表示旁边：

```swift
struct ContactEntity: AppEntity, Transferable {
    var id: String
    @Property var name: String
    @Property var email: String
    // ... typeDisplayRepresentation, defaultQuery, displayRepresentation ...

    static var transferRepresentation: some TransferRepresentation {
        IntentValueRepresentation(
            exporting: { contact in
                IntentPerson(
                    identifier: .applicationDefined(contact.id),
                    name: .displayName(contact.name),
                    handle: .init(emailAddress: contact.email)
                )
            },
            importing: { person in
                guard case let .applicationDefined(id) = person.identifier?.value,
                      let handle = person.handle else { throw ConversionError.missingData }
                return ContactEntity(id: id, name: person.name.displayString, email: handle.value)
            }
        )
    }
}
```

现在"呼叫此联系人"（导出）和"将此人添加到我的 App"（导入）都跨 App 边界工作。

**键路径简写。** 如果 entity 已将系统类型存储为 `@Property`，跳过闭包：

```swift
struct LocationEntity: TransientAppEntity, Transferable {
    @Property var place: PlaceDescriptor

    static var transferRepresentation: some TransferRepresentation {
        ValueRepresentation(exporting: \.place)
    }
}
```

与导出闭包相同结果，代码少得多。导出 `PlaceDescriptor` 后，地标 entity 流入地图，用户获得方向——中间无文件转换。

### 解析为现有 vs. 导入为新

当内容到达**你的** App 时，你决定它指的是已存在的东西还是全新的东西：

- **解析为现有 entity → `IntentValueQuery`。** 概念上是限定于传入 intent 值的 entity 查询。"给定此 `IntentPerson`，它指的是我的哪个联系人？"当传入值应映射到你已有的数据时使用。
- **创建新 entity → `IntentValueRepresentation` `importing:`。** 将传入值转换为新 entity（上面的 `importing:` 闭包）。当内容尚未存在于你的 App 中时使用。

许多 App 两者都做：如果匹配现有数据则解析，如果不匹配则导入。`IntentValueQuery` 也是 Visual Intelligence（`SemanticContentDescriptor` 输入）和结构化 Siri 搜索的入口点——参见 `assistant-schemas.md` 和 `siri-intelligence.md`。

## 系统集成上的 entity 标注

屏幕内容不是用户遇到你的 entity 的唯一地方。标注你已采纳的系统集成，使 Siri 可以对通知背后的 entity、正在播放的曲目或响起的闹钟操作。到处相同想法：附加 entity 的 `EntityIdentifier`。

- **用户通知。** 发布时在 `UNMutableNotificationContent` 上设置 `appEntityIdentifier`。当通知在 AirPods 上播报时，用户可以回复它代表的消息/勾选它代表的提醒。
- **Now Playing。** 将 entity 添加到 `MPNowPlayingInfoCenter.nowPlayingInfo` 中的 `MPNowPlayingInfoPropertyAppEntityIdentifiers` 键下，**按最具体到最不具体排序**（歌曲，然后艺术家，然后播放列表）。这是"播放现场版"的方式——Siri 知道正在播放背后的歌曲 entity。
- **AlarmKit。** 创建闹钟或计时器时在 `AlarmConfiguration` 中传递 entity 的 `appEntityIdentifier`，这样用户可以对响起的闹钟操作（"贪睡它"）。

这些通过 `AppEntityAnnotatable` 协议。两个后果：

- **你不能在此使用 `TransientAppEntity`。** 瞬态 entity 没有持久化标识符，这些集成依赖 `EntityIdentifier`。使用真正的 `AppEntity`（或 `IndexedEntity`）。
- 向 Apple 未已声明的系统类型添加 `AppEntityAnnotatable` 遵循无效——只有 Apple 接线的类型（通知内容、正在播放信息、闹钟配置）传递上下文。

## 交叉引用

- `assistant-schemas.md` - schema 采纳、Visual Intelligence `IntentValueQuery` + `SemanticContentDescriptor`。
- `siri-intelligence.md` - 更广泛的 Siri/Apple Intelligence 集成：查找内容、自定义响应、捐赠、确认。
- `entities.md` - `Transferable`、`IntentPerson`、`SyncableEntity`、`ValueRepresentation` 在 entity 建模上下文中。
