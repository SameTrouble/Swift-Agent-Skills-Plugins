# 测试 App Intents

有两个互补层：

1. **直接结构体单元测试** - App Intents 是普通 Swift 结构体；实例化它们、设置 `@Parameter`、调用 `perform()`、断言。快速、可在主机测试（macOS）、适合 `perform()` *内部逻辑*和隔离查询。下文先覆盖。
2. **`AppIntentsTesting`**（iOS 27+，新框架）- 通过完整 App Intents 栈**在设备/模拟器上进程外**运行你的真实 intent，与 Siri 和 Shortcuts 命中的相同代码路径。这是你覆盖 entity 查询、Spotlight 索引、视图标注和多 intent 组合端到端的方式，在 CI 中，无需 Siri。下文在专门章节覆盖。

两者都用：结构体测试用于可在任何地方运行的纯逻辑；`AppIntentsTesting` 用于只在设备上行为正确的集成面。

## 单元测试 intent

实例化 intent、分配 `@Parameter` 值、调用 `perform()`：

```swift
import Testing
import AppIntents
@testable import MyApp

@Suite
struct RefreshFeedIntentTests {
    @Test
    func refreshReturnsCount() async throws {
        var intent = RefreshFeedIntent()
        intent.folder = FolderEntity(id: UUID(), name: "Morning Reads")

        let result = try await intent.perform()

        #expect(result.value == 42)   // 链式返回值
    }
}
```

关键点：

- `@Parameter` 包装的属性在测试代码中可从结构体外部写入。直接分配（`intent.folder = ...`）。
- `perform()` 是 `async throws`。用 `#expect(throws:)` 测试错误路径。
- 不要在单元测试中运行完整 intent 验证（Siri 短语匹配、元数据提取）。那是系统的工作；你的测试覆盖 `perform()` *内部行为*。

## Mock 依赖

`AppDependencyManager` 与生产代码使用的注册表相同。在测试套件顶部注册测试替身：

```swift
protocol FeedStoreType: Sendable {
    func refresh() async throws -> Int
}

final class MockFeedStore: FeedStoreType {
    var refreshCallCount = 0
    func refresh() async throws -> Int {
        refreshCallCount += 1
        return 7
    }
}

@Suite
struct RefreshFeedIntentTests {
    init() {
        AppDependencyManager.shared.add { MockFeedStore() as FeedStoreType }
    }

    @Test
    func callsStoreExactlyOnce() async throws {
        let intent = RefreshFeedIntent()
        _ = try await intent.perform()

        // 通过以 intent 相同方式解析依赖读回 mock
        let store = AppDependencyManager.shared.resolve(FeedStoreType.self) as! MockFeedStore
        #expect(store.refreshCallCount == 1)
    }
}
```

将依赖设计为*协议*，而非具体类。intent 声明 `@Dependency var store: FeedStoreType`；生产注册真实 store；测试注册 mock。无需子类化或桩闭包。

通过在 `init()` 中重新注册在测试间重置——注册表替换先前绑定：

```swift
@Suite
struct RefreshFeedIntentTests {
    init() {
        AppDependencyManager.shared.add { MockFeedStore() as FeedStoreType }
    }
}
```

## 测试 entity 和查询

Entity 创建：

```swift
@Test
func entityMapsFromModel() {
    let article = Article(id: UUID(), title: "Hello", summary: "World")
    let entity = ArticleEntity(article: article)

    #expect(entity.id == article.id)
    #expect(entity.title == "Hello")
}
```

`EntityQuery` 查找：

```swift
@Test
func queryById() async throws {
    AppDependencyManager.shared.add { MockArticleStore() as ArticleStore }

    let query = ArticleEntityQuery()
    let ids = [fixtures.articleA.id, fixtures.articleB.id]
    let results = try await query.entities(for: ids)

    #expect(results.count == 2)
    #expect(Set(results.map(\.id)) == Set(ids))
}

@Test
func queryByString() async throws {
    AppDependencyManager.shared.add { MockArticleStore() as ArticleStore }

    let query = ArticleEntityQuery()
    let results = try await query.entities(matching: "swift")

    #expect(results.contains { $0.title.contains("Swift") })
}
```

`EnumerableEntityQuery`：

```swift
@Test
func allFoldersReturnsFullList() async throws {
    let query = FolderEntityQuery()
    let all = try await query.allEntities()
    #expect(all.count == 5)
}
```

`EntityPropertyQuery`（谓词+排序）：

```swift
@Test
func articlesSortedByDate() async throws {
    let query = ArticleEntityQuery()
    let predicates: [Predicate<ArticleEntity>] = [
        #Predicate { $0.title.contains("iOS") }
    ]
    let sorted = try await query.entities(
        matching: predicates,
        mode: .and,
        sortedBy: [EntityQuerySort(by: \.$publishedAt, order: .descending)],
        limit: 10
    )

    #expect(sorted.first?.publishedAt ?? .distantPast >= sorted.last?.publishedAt ?? .distantFuture)
}
```

## 测试错误路径

`throws` 路径用 `#expect(throws:)`：

```swift
@Test
func missingFolderThrows() async throws {
    AppDependencyManager.shared.add { EmptyStore() as ArticleStore }

    var intent = OpenArticleIntent()
    intent.target = ArticleEntity(id: UUID(), title: "")   // 无法解析的 id

    await #expect(throws: ArticleIntentError.notFound) {
        _ = try await intent.perform()
    }
}
```

优先使用具体错误类型而非 `Error.self`——断言实际验证 intent 抛出了正确错误，而非*任何*错误。

## 测试 `AppShortcutsProvider`

你无法测试短语匹配（那是系统），但可以验证 provider 的形状：

```swift
@Test
func providerExposesExpectedIntents() {
    let shortcuts = ReaderShortcuts.appShortcuts
    let titles = shortcuts.map { $0.shortTitle }

    #expect(titles.contains("Refresh Feed"))
    #expect(titles.contains("Open Article"))
    #expect(shortcuts.count <= 10)   // 硬性限制
}
```

用作防止重构期间有人意外移除快捷方式的守护。

## 测试 snippet intent

`SnippetIntent.perform()` 应该是纯净的——完美适合单元测试。调用它，通过 `result.view` 检查返回的视图：

```swift
@Test
func snippetRendersCurrentCount() async throws {
    AppDependencyManager.shared.add {
        MockDashboardStore(unreadCount: 42) as DashboardStore
    }

    let intent = DashboardSnippetIntent()
    let result = try await intent.perform()

    // 返回的视图是 SwiftUI View；验证它无错误构造。
    // 断言驱动视图的数据，而非 SwiftUI 内部。
    let store = AppDependencyManager.shared.resolve(DashboardStore.self) as! MockDashboardStore
    #expect(store.unreadCount == 42)
}
```

**不要**试图断言 SwiftUI 视图层次结构——使用依赖观察到的状态作为代理。

## `AppIntentsTesting`：官方集成框架（iOS 27+）

`AppIntentsTesting` **进程外**运行你的真实 intent，在设备或模拟器上，通过完整 App Intents 栈——无 mock、无桩、与 Siri 和 Shortcuts 使用的相同路径。这是对结构体单元测试无法到达的集成面（查询、Spotlight、视图标注）进行回归测试的方式。

如何接线：

- 测试位于 **UI Testing bundle（XCUITest）** 中——创建一个（或添加到你现有 UI 测试）。它们在自己的进程中运行；你的 App 在单独进程中执行 intent 在设备上。运行者跨进程边界传递结果。
- 测试 target **从不导入你的 App 代码**——你传递 bundle 标识符并按字符串寻址一切。因此你的测试不编译 App 代码，并在发布间保持稳定（不依赖 UI，你的或系统的）。
- 运行者和 App 必须使用**相同的开发团队**进行代码签名。
- CI 像任何 XCUITest 一样自动拾取它。

### 第一个测试：运行 intent

```swift
import XCTest
import AppIntentsTesting

final class IntentExecutionTests: XCTestCase {
    func testCreateCalendar() async throws {
        let definitions = IntentDefinitions(bundleIdentifier: "com.example.CometCal")

        // 按名称查找 intent；制作填充实例。
        let intent = definitions.intents["CreateCalendarIntent"]
            .makeIntent(name: "Occupy Saturn", color: "red")   // AppEnum：传其原始字符串值

        // 在 App 中跨进程边界执行它。
        let result = try await intent.run()

        // result.value 是 perform() 返回值；动态成员查找读取其属性。
        XCTAssertEqual(result.value.title, "Occupy Saturn")
    }
}
```

注意：

- `makeIntent(...)` 填充参数。因为测试不针对你的 App 构建，**参数名/类型不自动补全**——按 intent 声明手动正确填写。大多数类型从其 Swift 值转换；`AppEnum` 作为其**原始字符串值**传递；自定义参数类型见 `IntentValueConvertibleWrapper`。
- `.run()` 返回 `ResolvedIntentResult`；`result.value` 加动态成员查找（`result.value.title`）读取返回 entity 的属性。

### 测试 entity 查询（字符串、标识符、建议）

```swift
let events = definitions.entities["EventEntity"]
let matches = try await events.entities(matching: "Cosmic Ray")   // 在设备上运行 EntityStringQuery
XCTAssertEqual(matches.count, 1)
XCTAssertEqual(matches.first?.title, "Cosmic Ray Calibration")    // 动态成员查找
```

`AppEntityDefinition` 暴露 `entities(matching:)`、`entities(identifiers:)`、`allEntities()`、`suggestedEntities()` 和 `makeReference(identifier:)`。这正是 Shortcuts/Siri 解析参数时命中的面——测试驱动查询开发的好目标（写失败的 `entities(matching:)` 测试，然后实现 `EntityStringQuery`）。

### 组合 intent（链式，像 Shortcuts）

将一个运行返回的 entity 直接传给下一个——镜像人们构建快捷方式的方式：

```swift
let created = try await definitions.intents["CreateEventIntent"]
    .makeIntent(title: "Asteroid Dodgeball", startDate: date, calendar: "Deep Space")  // 字符串自动解析为 CalendarEntity
    .run()

let updated = try await definitions.intents["UpdateEventIntent"]
    .makeIntent(event: created.value, title: "Asteroid Dodgeball - Rules")             // 直接传返回的 entity
    .run()

XCTAssertEqual(updated.value.title, "Asteroid Dodgeball - Rules")
```

当参数期望 entity（`CalendarEntity`）时你可以传普通字符串；运行时调用该 entity 的 `EntityStringQuery` 并填充第一个匹配。

### 测试 Spotlight 索引

`spotlightQuery(_:)` 查询真实 Spotlight 索引，使你可以防范经典的"我注释掉了索引调用且从未注意"回归：

```swift
let events = definitions.entities["EventEntity"]
XCTAssertTrue(try await events.spotlightQuery("Dark Matter Symposium").isEmpty)   // 尚未创建

_ = try await definitions.intents["CreateEventIntent"].makeIntent(title: "Dark Matter Symposium", /* ... */).run()

let indexed = try await events.spotlightQuery("Dark Matter Symposium")
XCTAssertEqual(indexed.count, 1)
XCTAssertEqual(indexed.first?.title, "Dark Matter Symposium")
```

### 测试视图标注（屏幕感知）

`viewAnnotations()` 返回系统当前报告为屏幕上的 entity——使你可以在导航后证明"Siri 知道哪个事件在屏幕上"：

```swift
_ = try await definitions.intents["OpenEventIntent"].makeIntent(target: someEventReference).run()
// （因为这是 XCUITest bundle，你也可以在这里用 XCUIApplication 驱动/断言 UI。）

let annotations = try await definitions.entities["EventEntity"].viewAnnotations()
XCTAssertEqual(annotations.count, 1)
XCTAssertEqual(annotations.first?.entity.title, "Meteor Shower Watch Party")
```

`ViewAnnotation` 有 `.entity`（带动态成员查找）和 `.isSelected`。这是你如何捕获如将错误 `EntityIdentifier`（如日历 id 而非事件 id）传入 `.appEntityIdentifier` 修饰符的 bug。

### 仅测试 intent

因为这些测试运行真实栈，每个测试必须**自包含**。仅测试 intent 使这实际：仅存在以支持测试的小 intent。

- **播种/重置数据** - 如 `SeedSampleEventsIntent` 清除 App 数据并插入已知集合，从 `setUp()` 运行。无残留，无不稳定。
- **跳转到任何视图**而无需 UI 导航——经受屏幕重新设计。
- **包装你尚未暴露为 intent 的功能** - 内部导航、数据管理、状态操作——使其可从 `AppIntentsTesting` 到达。

通过标记 `isDiscoverable: false`（使系统从不呈现它）并用 `#if DEBUG` 包装（使其不出现在任何发布构建中）使任何 intent 仅测试：

```swift
#if DEBUG
struct SeedSampleEventsIntent: AppIntent {
    static let title: LocalizedStringResource = "Seed Sample Events"
    static let isDiscoverable: Bool = false

    @Dependency var store: CalendarManager

    @MainActor
    func perform() async throws -> some IntentResult {
        try store.resetAndSeedSampleEvents()
        return .result()
    }
}
#endif
```

### 适合位置

推荐进展：构建基本类型 → 用 `AppIntentsTesting` 作为**单元测试**覆盖它们 → 集成更深（标注视图、捐赠到 Spotlight、传递内容）→ 将那些覆盖为**集成测试** → 最后在 Shortcuts 和 Siri 中手动练习真实事物。框架进程外自动化测试 intent、entity、enum、查询和系统集成；手动 Siri/Shortcuts 测试仍是自然语言体验的最后一步。

## 无法单元测试的内容

这些需要设备（或特定测试工具）且不适用于直接 `@Test` 结构体调用。多个现在可用 `AppIntentsTesting`（上文）到达：

- **Siri 短语识别。** 语音识别与 OS 集成。使用 Xcode 的 App Shortcuts Preview 工具（macOS Sonoma + Xcode 15+）无语音练习短语匹配；对于语音，在真实设备上测试。
- **Spotlight 索引。** entity 是否*已*索引现在可用 `AppIntentsTesting` 的 `spotlightQuery(_:)`（设备上）测试。语义索引内的*排名*仍不透明——无编程排名 API。
- **视图标注/屏幕感知。** 现在可用 `AppIntentsTesting` 的 `viewAnnotations()` 测试——断言系统报告哪个 entity 在屏幕上。（针对那些标注的短语解析仍需要 Siri。）
- **snippet 作为系统叠加层渲染。** 测试可验证视图已构造；只有 snippet 宿主视觉上显示叠加层。
- **Apple Intelligence 调用。** 大多数 assistant-schema 界面逐步推出。用 `AppIntentsTesting` 或通过 Shortcuts App（按"AssistantSchemas"过滤）测试 intent 本身，直到 Siri 消费界面发布。
- **Visual Intelligence 像素缓冲区匹配。** 需要相机/截图上下文。在边界桩 `IntentValueQuery.values(for:)` 并单元测试桩函数；在设备上集成测试。
- **小组件+控件重绘周期。** 测试 intent 的修改；小组件的视觉刷新需要设备或小组件模拟器。

## 通过 Shortcuts 集成测试

Shortcuts App 本身是最好的零代码集成工具：

1. 在设备或模拟器上构建+运行。
2. 打开 Shortcuts → 点 `+` → 搜索你的 intent。
3. 配置参数、运行。
4. 验证对话、返回值、snippet。

对于 assistant-schema intent，按"AssistantSchemas"过滤 Shortcuts 库以只看到遵循 schema 的子集。

对于视觉智能，在真实设备上调用系统的 Visual Intelligence 流程并确认你的 `IntentValueQuery` 返回结果。

## 固定数据和测试数据

保持带预制 entity 的 `Fixtures` 命名空间：

```swift
enum Fixtures {
    static let articleA = ArticleEntity(
        id: UUID(),
        title: "Dive into App Intents",
        summary: "..."
    )
    static let articleB = ArticleEntity(
        id: UUID(),
        title: "Getting Started with SwiftData",
        summary: "..."
    )
}
```

对于内存 mock，每次测试运行使用新 UUID 可以。当测试依赖排序或多个测试共享 mock store 时使用稳定 UUID（源中硬编码）。

## 运行测试

除非你特别需要设备端 API，测试在主机平台（macOS）运行。App Intents 的核心协议、宏和属性包装器在 macOS 测试构建下工作，因此大多数单元测试面可在主机测试。

对于仅设备功能（Spotlight API、依赖 `UIApplication` 的流程），用 `@available(iOS ..., *)` 守护测试并在 CI 中使用物理设备。
