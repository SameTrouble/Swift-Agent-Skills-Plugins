# Open intent 和 snippet 视图

"将东西带给用户"的三种形态：

- `OpenIntent` - **启动 App 并导航到东西**。当用户想交互（编辑、回复、继续阅读）时好用。
- `AppIntent & ShowsSnippetView` - **直接在那里显示摘要**，snippet 视图从 `perform()` 直接返回。适用于自包含的一次性答案。
- `AppIntent & ShowsSnippetIntent` + 单独的 `SnippetIntent` - **显示保持活跃且可重新触发的摘要**。业务 intent 返回值；配对的 `SnippetIntent` 渲染 UI。这是带交互内容（触发更多 intent 的按钮）的 snippet 的现代模式。

它们可以共存；按用例选择。

## `OpenIntent`

`OpenIntent` 是 `AppIntent` 的子协议。它要求 `target` 参数（被打开的 entity）并在 intent 完成时自动打开 App：

```swift
import AppIntents

struct OpenArticleIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open article"

    @Dependency var navigator: AppNavigator

    @Parameter(title: "Article")
    var target: ArticleEntity     // 必须命名为 `target`

    func perform() async throws -> some IntentResult {
        try await navigator.navigate(to: target)
        return .result()
    }
}
```

`target` 属性名是必需的；协议以此键控。App 在 `perform()` 返回*后*自动打开——你在 `perform()` 中的工作是更新导航状态，以便 App 到前台时正确的屏幕在顶部。

### 导航接线

大多数 App 通过驱动 `NavigationStack` 的 main-actor 绑定控制器路由导航：

```swift
@Observable @MainActor
final class AppNavigator {
    var path: [Article] = []

    func navigate(to entity: ArticleEntity) async throws {
        let id = entity.id
        let results = try await store.articles(matching: #Predicate { $0.id == id })
        if let article = results.first {
            path = [article]
        }
    }
}
```

```swift
struct ContentView: View {
    @Bindable var navigator: AppNavigator

    var body: some View {
        NavigationStack(path: $navigator.path) {
            ArticleList()
                .navigationDestination(for: Article.self, destination: ArticleEditor.init)
        }
    }
}
```

通过 `@Dependency` 注入 `AppNavigator`，使 intent 可以到达它。参见 `dependencies.md`。

### 当 App 未运行时

`OpenIntent` 即使 App 从未启动也工作。App 进程启动，`App.init()` 运行（注册依赖），intent 触发，导航状态设置，然后窗口出现在屏幕上已在正确位置。这就是为什么**所有跨 intent 设置属于 `App.init()`**——而非 `.onAppear`，非视图修饰符。

## Snippet 视图（内联）：`ShowsSnippetView`

snippet 视图是系统响应 intent 渲染的紧凑 SwiftUI 场景。用户不离开当前上下文；他们只看到答案。

内联形式从业务 intent 的 `perform()` 直接返回视图：

```swift
import AppIntents
import SwiftUI

struct SummarizeArticleIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize article"

    @Parameter(title: "Article")
    var article: ArticleEntity

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        .result(dialog: "\(article.title)") {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                Text(article.title).font(.headline)
                Text(article.summary).font(.body)
            }
            .padding()
        }
    }
}
```

snippet 像小组件一样编码和传输。不要使用 `List`、`ScrollView` 或任何需要活动 `UIViewController` 的交互控件——它们要么不渲染要么行为怪异。坚持静态布局：`VStack`、`HStack`、`Text`、`Image`、`Label`、`Spacer`、背景、padding。

## Snippet intent（间接）：`ShowsSnippetIntent` + `SnippetIntent`

现代模式拆分关注点：业务 intent 返回可链式值；配对的 `SnippetIntent` 渲染 UI。这在以下情况是正确形态：

- snippet 包含 `Button(intent:)`（见下文），因此它可以重新触发并刷新自身。
- 你想让 intent 返回 Shortcuts 可链式的值，*同时*显示 snippet。
- snippet 将从多个业务 intent 复用。

```swift
import AppIntents
import SwiftUI

// 1. 业务 intent：返回值并引用 snippet intent
struct GetCaffeineIntent: AppIntent {
    static let title: LocalizedStringResource = "Get caffeine intake"
    static let description = IntentDescription("Shows how much caffeine you've had today.")

    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ShowsSnippetIntent {
        let amount = await store.amountIngested
        return .result(
            value: amount,
            snippetIntent: ShowCaffeineIntakeSnippetIntent()
        )
    }
}

// 2. Snippet intent：不可发现，仅渲染 UI
struct ShowCaffeineIntakeSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Caffeine snippet"
    static let isDiscoverable: Bool = false

    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: CaffeineIntakeSnip(store: store))
    }
}

// 3. 视图可包含交互 intent
struct CaffeineIntakeSnip: View {
    let store: DataStore

    var body: some View {
        VStack(alignment: .leading) {
            Text("Today's caffeine").font(.subheadline).foregroundStyle(.secondary)
            Text(store.formattedAmount())
                .font(.title)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

            Text("Quick log").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Button(intent: LogAmountIntent(amount: 64))  { Text("Single") }
                Spacer()
                Button(intent: LogAmountIntent(amount: 128)) { Text("Double") }
                Spacer()
                Button(intent: LogAmountIntent(amount: 192)) { Text("Triple") }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground).gradient)
        .clipShape(.containerRelative)
    }
}
```

当用户点击一个 `Button(intent:)` 按钮时，系统触发 `LogAmountIntent`，然后重新运行 `ShowCaffeineIntakeSnippetIntent` 以就地刷新 snippet。用户从不离开 Siri/Shortcuts。

关键规则：

- 用 `isDiscoverable = false` 标记 `SnippetIntent` 类型。它们是实现细节；不要污染 Shortcuts 库。
- snippet intent 的 `perform()` 返回 `some IntentResult & ShowsSnippetView`。它返回的视图通过与内联 snippet 相同的"小组件样式"渲染管道。
- `.result(value:snippetIntent:)` 接受 snippet intent *实例*，而非类型——每次创建新的。

## SwiftUI 中的 `Button(intent:)`

SwiftUI 附带接受 `AppIntent` 并在点击时触发的 `Button` 初始化器。在以下位置工作：

- 小组件视图（主屏、锁屏、StandBy、控制中心）。
- App Intent snippet 视图。
- Live Activity。
- 普通 App 视图（方便；在该上下文中与基于闭包的普通按钮行为相同）。

```swift
Button(intent: LogAmountIntent(amount: 64)) {
    Text("Single")
}
```

intent 上的要求：

1. 它是 `AppIntent`（或子协议）。
2. 它有匹配的便利初始化器，使你可以构造参数化的它：

```swift
extension LogAmountIntent {
    init(amount: Int) { self.amount = amount }
}
```

3. 对于 snippet/小组件内的按钮，标记 `isDiscoverable = false`，除非你也想让它在 Shortcuts 库中。

intent 的 `perform()` 在 App 的 intent 扩展上下文中运行，而非小组件的；写入到共享数据存储。它返回后，宿主（小组件/snippet）重新渲染。

### snippet 内的按钮样式

应用于 `Button(intent:)` 的 SwiftUI 按钮样式与普通视图中一样工作。自定义样式正确动画，包括按下/缩放效果：

```swift
struct IntentScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.8), .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(.easeInOut(duration: 0.24), value: configuration.isPressed)
    }
}
```

### 仅 snippet 导入

生成 snippet 的文件需要两个框架：

```swift
import AppIntents
import SwiftUI
```

### 交互式小组件：App Group 共享模式

当 `Button(intent:)` 位于**小组件**视图（非 snippet）中时，intent 在 App 的进程中运行，而小组件视图位于小组件扩展进程中。它们不共享内存——内存中的 `@Dependency` 实例只对一侧可见，intent 的普通 `UserDefaults.standard` 写入对小组件的时间线提供者不可见。

用 App Group 和 `UserDefaults(suiteName:)` 桥接它们：

1. 在主 App target 和小组件扩展 target 上添加相同的 App Group 能力。
2. 通过读写 suited `UserDefaults` 的助手限制共享状态。
3. 让 intent 通过它写入；让小组件的 `TimelineProvider` 通过它读取。
4. 当小组件需要刷新时从 intent 重新加载时间线。

```swift
import AppIntents
import WidgetKit

enum SharedCounter {
    private static let defaults = UserDefaults(suiteName: "group.com.example.myapp")!

    static var current: Int {
        defaults.integer(forKey: "count")
    }

    static func increment() {
        defaults.set(current + 1, forKey: "count")
    }
}

struct IncrementCounterIntent: AppIntent {
    static let title: LocalizedStringResource = "Increment counter"
    static let description = IntentDescription("Increments the shared counter.")
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        SharedCounter.increment()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

在小组件中：

```swift
struct CounterProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = Entry(date: .now, count: SharedCounter.current)
        completion(Timeline(entries: [entry], policy: .never))
    }
    ...
}

struct CounterWidgetView: View {
    let entry: CounterProvider.Entry

    var body: some View {
        VStack {
            Text("Count: \(entry.count)")
            Button(intent: IncrementCounterIntent()) {
                Text("Increment")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

为什么这有效：

- 两个进程读写相同的 defaults suite。
- intent 内的 `WidgetCenter.shared.reloadAllTimelines()` 强制小组件重新查询提供者，后者获取新值。
- `@Dependency` 不能在小组件侧使用（没有 App 在小组件扩展启动前运行 `App.init()`），这就是为什么通过 suited `UserDefaults`（或 App Group 文件，或共享 SwiftData 存储）路由是强制的——而非可选。

当主 App 前台时，通过 `@Environment(\.scenePhase)` 重新读取共享状态，使 App 内视图跟上小组件触发的变化：

```swift
@Environment(\.scenePhase) private var phase
@State private var count = SharedCounter.current

var body: some View {
    Text("Count: \(count)")
        .onChange(of: phase) {
            count = SharedCounter.current
        }
}
```

对于更大的共享状态，将 `UserDefaults` 替换为 `ModelConfiguration` 指向 App Group 共享容器内 URL 的 `ModelContainer`——`dependencies.md` 中的相同 SwiftData sendability 规则仍然适用。

### 深色模式陷阱

Siri 渲染的 snippet 在用户*在 snippet 屏幕上时*切换深色模式时不会实时更新。关闭并再次触发会正确获取当前外观。

## Snippet 设计规则

snippet 是快速浏览的叠加层。Apple 的设计指导（WWDC25 #281）：

- **高度上限：340 点。** 超过此值需要滚动，破坏可浏览叠加模型。链接到完整 App 以获取深度内容。
- **字号高于系统默认。** snippet 经常从房间对面查看与近距离一样多；提高基本字号。
- **一致的外边距。** 使用 `ContainerRelativeShape` 作为背景，使外边距适应系统在 snippet 周围绘制的圆角矩形容器。
- **对比度高于标准比率。** snippet 叠加任意背景；普通 4.5:1 文本-背景对比度不够。在阅读距离测试。
- **无需对话即可理解。** snippet 应在屏幕上单独传达其含义。将对话视为补充音频，而非主要通道。不要在对话中重复每个 snippet 标签。

### 结果 vs 确认 snippet 类型

两种不同行为，每种带标准按钮模式：

- **结果 snippet。** 在 intent 已完成后显示。一个按钮：**完成**。用于报告状态（订单已下、消息已发送）。
- **确认 snippet。** 在 intent 运行*前*显示。需要动作动词按钮——**订购**、**发送**、**发布**、**播放**、**删除**、**确认**，或自定义动词。用户的点击是触发真正工作的。

```swift
// 确认流程
try await requestConfirmation(
    actionName: .order,   // "Order" 按钮标签
    snippetIntent: CoffeeRequestSnippetIntent(order: order)
)
try await orderService.submit(order)

// 确认后结果
return .result(
    snippetIntent: CoffeeResultSnippetIntent(order: order)
)
```

`actionName` 接受标准动词（`.order`、`.send`、`.play`、`.delete`、`.confirm`、`.search`）或自定义字符串；在适合时选择标准动词，使用户在跨 App 中看到一致语言。

## 选择正确形态

| 情况 | 选择 |
|---|---|
| 用户将阅读、交互、编辑 | `OpenIntent` |
| 一次性摘要，无重新触发，无链式值 | `AppIntent & ShowsSnippetView`（内联） |
| 带交互按钮的摘要，重新渲染 | `AppIntent & ShowsSnippetIntent` + `SnippetIntent` |
| 用户想要在 Shortcuts 链式的值 | `AppIntent & ReturnsValue<T>` |
| snippet *和*可链式值 | `AppIntent & ReturnsValue<T> & ShowsSnippetIntent` |
| 简单确认（"Done"） | `AppIntent & ProvidesDialog` |

对于"显示我最新的笔记"——snippet 通常更好，因为目的是阅读它，而非编辑它。对于"打开我最新的笔记以便继续写"——使用 `OpenIntent`。

对于"显示我的仪表板并让我从中记录"——使用双 intent snippet 模式，这样 snippet 中的按钮可以触发更多 intent 并就地刷新视图。

## 将 Spotlight 选择桥接到 `OpenIntent`

当用户在 Spotlight 结果中点击 App entity 时，系统查找 `target` 匹配该 entity 类型的 `OpenIntent` 并调用它。只要：

1. entity 遵循 `IndexedEntity`。
2. entity 已被索引（参见 `spotlight.md`）。
3. 存在 `target: YourEntity` 的 `OpenIntent`。

...点击 Spotlight 结果自动通过你的 `OpenIntent` 路由。无需额外接线。

在模拟器中，首次启动后有时需要几分钟才能可靠工作——索引在后台构建。在设备上通常更快。

## 返回 `OpenURLIntent` 在操作后打开 App

当 intent *创建*了东西（新笔记、扫描文档、预订的预约）且你想让用户落在 App 中查看结果时，返回从新 entity 的 URL 表示构建的 `OpenURLIntent`：

```swift
struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create note"

    @Parameter var body: String
    @Dependency var store: DataStore

    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity> & OpensIntent {
        let note = try store.createNote(body: body)
        return .result(
            value: note.entity,
            opensIntent: OpenURLIntent(URLRepresentation(entity: note.entity))
        )
    }
}
```

返回形状 `ReturnsValue<T> & OpensIntent` 既返回创建的 entity（可在 Shortcuts 中链式）*又*告诉系统打开 App 到该 entity 的通用链接。自然与 `URLRepresentableEntity` 配对。iOS 18+。

## iOS 26 snippet 交互性

`SnippetIntent` 在 iOS 26（WWDC25 #275）成为主要交互 snippet 机制。两个值得知道的改进：

### 交互刷新周期

当 snippet 视图内的按钮触发另一个 `AppIntent` 时，系统：

1. 运行按钮的 intent 到完成。
2. **重新获取拥有 snippet intent 的所有 `@Parameter` 值**（对于 entity 参数，这重新运行查询上的 `entities(for:)`）。
3. 再次调用 snippet intent 的 `perform()` 以重新渲染。
4. 在显示视图中动画差异。

这意味着 snippet intent 的 `perform()` 在单次用户交互中**被多次调用**——一次初始、每次按钮按下后、潜在地每次外观变化时。它必须纯净：获取状态、构建视图、返回。不要在 `SnippetIntent.perform()` 内修改 App 状态。

### 手动刷新：`SnippetIntent.reload()`

对于异步完成的长运行工作，你可以从 snippet 外部强制刷新：

```swift
// 在 App 中某处，当新数据到达时
MyDashboardSnippetIntent.reload()
```

如果当前 snippet 仍可见，系统重新调用 `perform()`。适用于推送通知驱动的仪表板或轮询后台进程的 intent。

### SwiftUI 动画

如果使用 SwiftUI 的标准过渡修饰符，snippet 视图修改自动动画：

```swift
Text(store.formattedAmount())
    .contentTransition(.numericText())

VStack { ... }
    .animation(.easeInOut, value: store.currentState)
```

## `URLRepresentableEntity` + `URLRepresentableIntent`

如果你的 App 已处理通用链接以显示特定 entity，不要在 `OpenIntent.perform()` 中写重复的导航代码。让系统通过你的通用链接处理器自动路由。

步骤 1 - 声明 entity 的 URL 表示：

```swift
extension TrailEntity: URLRepresentableEntity {
    static var urlRepresentation: URLRepresentation {
        // 使用带 entity 标识符的字符串插值
        "https://example.com/trail/\(.id)/details"
    }
}
```

步骤 2 - 让 open intent 同时遵循 `OpenIntent` 和 `URLRepresentableIntent`，并省略 `perform()`：

```swift
struct OpenTrail: OpenIntent, URLRepresentableIntent {
    static let title: LocalizedStringResource = "Open Trail"
    static let description = IntentDescription("Displays trail details in the app.")

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @Parameter(title: "Trail")
    var target: TrailEntity

    // 无 perform() - 系统从 TrailEntity.urlRepresentation 构建 URL
    // 并交给你的通用链接处理器。
}
```

intent 无 `perform()` 体编译并运行。当用户运行 intent 时，系统：

1. 询问 `TrailEntity.urlRepresentation` 获取 URL，插值 `\(.id)`。
2. 通过标准通用链接路径用该 URL 打开 App。
3. 你现有的 `.onOpenURL` / `UIApplication(_:continue:)` / `NSUserActivity` 处理器导航到正确场景。

不要混合模式：如果你提供 `perform()`，它运行而非 URL 路径。选一个。

`URLRepresentationConfiguration`（iOS 18+）让你定义命名片段并进一步配置行为；对于简单 App，字符串字面量 `URLRepresentation` 就够了。

## `TargetContentProvidingIntent`

iOS 上的标记协议，告诉系统"此 intent 的完成产生用户导航到的场景。"最常见的用例是让 `OpenIntent` 有资格作为视觉智能流程的最后一步（用户在相机中圈选东西、从你的 App 选择结果、系统运行你的 intent 将他们落到正确场景）：

```swift
struct OpenLandmarkIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Landmark"

    @Parameter(title: "Landmark", requestValueDialog: "Which landmark?")
    var target: LandmarkEntity
}

#if os(iOS)
extension OpenLandmarkIntent: TargetContentProvidingIntent {}
#endif
```

用 `#if os(iOS)` 守护——该协议仅 iOS。当你想让视觉智能能将用户落到你的 App 内时不要跳过遵循；没有它，系统将 intent 视为副作用操作而非导航端点。

## 小组件配置 intent

需要用户配置（选择日历、选择文件夹、选择股票代码）的小组件用 `WidgetConfigurationIntent` 支撑其配置：

```swift
struct FolderWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose folder"

    @Parameter(title: "Folder")
    var folder: FolderEntity?
}
```

与 WidgetKit 的 `AppIntentConfiguration`（iOS 17+，替代 `IntentConfiguration`）配对：

```swift
struct FolderWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FolderWidget", intent: FolderWidgetIntent.self, provider: FolderProvider()) { entry in
            FolderWidgetView(entry: entry)
        }
    }
}
```

`WidgetConfigurationIntent` 是空遵循标记——无 `perform()`。参数查询填充小组件的配置选择器。

## 控制配置 intent

iOS 18 的控制中心控件以相同方式使用 `ControlConfigurationIntent`。一个 intent 可以同时是控件的配置*和*其点击时执行的操作：

```swift
struct ToggleFocusIntent: ControlConfigurationIntent, AppIntent {
    static let title: LocalizedStringResource = "Toggle focus"

    @Parameter var mode: FocusMode

    func perform() async throws -> some IntentResult {
        try await focusManager.toggle(mode)
        return .result()
    }
}
```

当用户添加控件时，系统使用 `@Parameter` 作为配置选择器；当控件被点击时，`perform()` 以配置的值运行。

### `ControlWidgetButton(action:)`

在控件小组件的视图中，使用 `ControlWidgetButton` 在点击时触发 intent。它是 `Button(intent:)` 的控件小组件对应物：

```swift
struct FocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "focus-toggle") {
            ControlWidgetButton(action: ToggleFocusIntent(mode: .work)) {
                Label("Work Focus", systemImage: "briefcase")
            }
        }
    }
}
```

接受预配置的 intent 实例（因此 `Button(intent:)` 的相同便利 init 模式适用）。在 App 进程中运行 intent；遵守 `openAppWhenRun` 和所有常用生命周期规则。

### snippet 不在控制中心内渲染

控件小组件是与 App Intents snippet 不同的渲染表面。从 `ControlWidgetButton(action:)` 触发的 intent 可以返回对话并修改状态，但**它们无法在控件内显示 `ShowsSnippetView` / `ShowsSnippetIntent` 结果**。snippet UI 在控制中心不可用——WWDC 演示片段有时暗示相反，但发布行为是 snippet 仅从 Siri、Shortcuts 和 Spotlight 调用中出现。

如果 intent 需要呈现详细反馈，要么：

- 使用短对话（`.result(dialog: "Work focus on.")`）——控制中心将其显示为简短 toast。
- 当需要完整 snippet 类视图时通过 `openAppWhenRun = true` 或 `OpenURLIntent` 打开 App。
- 更新控件显示的状态并依赖控件自己的渲染来传达结果。

## 主动建议：`RelevantIntentManager`

iOS 17+。智能叠放（和 watchOS 复杂功能）可在上下文相关的时间呈现你的小组件。声明何时：

```swift
import AppIntents

let relevant = RelevantIntent(
    FolderWidgetIntent(folder: morningRoutineFolder),
    widgetKind: "FolderWidget",
    relevance: [
        .timeRange(morning),
        .location(home)
    ]
)

try await RelevantIntentManager.shared.updateRelevantIntents([relevant])
```

提供 intent 实例、小组件 kind 字符串和一个或多个 `RelevantContext` 谓词（时间、位置、焦点、Watch 的心率、...）。系统在构建智能叠放时在已注册 intent 中选择。用 Swift 友好的界面替代旧版 `INInteraction` / `INDailyRoutineRelevanceProvider` API。

当用户的习惯实质性变化时调用 `updateRelevantIntents`；系统缓存提交。

## 带 snippet intent 的多步交互确认

snippet intent 模式（见上文）可扩展为使用 `requestConfirmation(actionName:snippetIntent:)` 的多步交互流程。intent 暂停，系统显示用户可交互的 snippet（通过 `Button(intent:)` 配置参数），只有他们确认后 intent 才继续：

```swift
struct FindTicketsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Tickets"

    static var parameterSummary: some ParameterSummary {
        Summary("Find best ticket prices for \(\.$landmark)")
    }

    @Dependency var searchEngine: SearchEngine

    @Parameter var landmark: LandmarkEntity

    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let searchRequest = await searchEngine.createRequest(landmarkEntity: landmark)

        // 呈现允许人们更改票数的 snippet。
        try await requestConfirmation(
            actionName: .search,
            snippetIntent: TicketRequestSnippetIntent(searchRequest: searchRequest)
        )

        // 用户确认后，执行票务搜索。
        try await searchEngine.performRequest(request: searchRequest)

        // 显示结果 snippet。
        return .result(
            snippetIntent: TicketResultSnippetIntent(searchRequest: searchRequest)
        )
    }
}
```

请求 snippet 显示由辅助 intent 驱动的可配置字段：

```swift
struct ConfigureGuestsIntent: AppIntent {
    static let title: LocalizedStringResource = "Configure Guests"
    static let isDiscoverable: Bool = false   // 仅辅助

    @Dependency var searchEngine: SearchEngine

    @Parameter var searchRequest: SearchRequestEntity
    @Parameter var numberOfGuests: Int

    func perform() async throws -> some IntentResult {
        await searchEngine.setGuests(to: numberOfGuests, searchRequest: searchRequest)
        return .result()
    }
}
```

流程：主 intent 暂停 → 请求 snippet 显示 → 用户点击 `Button(intent: ConfigureGuestsIntent(...))` 更改值 → 用户点击"Search"（确认）→ 主 intent 恢复 → 结果 snippet 显示。全部不离开 Siri 或 Shortcuts 面板。

`actionName:` 是标记确认按钮的标准动词（`.search`、`.send`、`.play`、`.confirm`、`.delete`）。
