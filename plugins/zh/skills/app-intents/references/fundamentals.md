# 基础

App Intents 的核心是 `AppIntent` 协议。每个暴露的 App 操作都遵循它或其子协议之一（`OpenIntent`、`AudioPlaybackIntent`、`VideoCallIntent`、`ForegroundContinuableIntent`、...）。

## 最小 intent

```swift
import AppIntents

struct RefreshFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh feed"

    func perform() async throws -> some IntentResult {
        .result()
    }
}
```

三个必需部分：

- `static let title: LocalizedStringResource` - 人类可读标题；显示在 Shortcuts、Siri、focus filter 选择器中。
- `func perform() async throws -> some IntentResult` - 工作。总是 `async throws`；除非你选择加入，否则在 main actor 之外运行。
- `.result()` - 一个空 `IntentResult`，意为"完成，无需返回"。

`LocalizedStringResource` 与字符串目录和 SwiftUI 的本地化管道集成，因此本地化字符串在 App Intents 显示它们的任何地方都有效。

## 可选静态元数据

更多静态属性微调 intent 的呈现：

```swift
struct RefreshFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh feed"
    static let description = IntentDescription(
        "Pulls the latest articles from all your subscribed sources.",
        categoryName: "Reading",
        searchKeywords: ["refresh", "sync", "fetch"],
        resultValueName: "Articles"
    )
    static let isDiscoverable: Bool = true   // 默认
    static let openAppWhenRun: Bool = false  // 默认

    func perform() async throws -> some IntentResult { .result() }
}
```

- `description: IntentDescription` - 在 Shortcuts 中操作标题下显示的长篇说明。接受可选的 `categoryName:`（Shortcuts 库类别）、`searchKeywords:`（Shortcuts 匹配的额外搜索标记）和 `resultValueName:`（当此 intent 的输出绑定到另一个操作时使用的标签，如"Use Articles from Refresh Feed"中的"Articles"）。每当 intent 返回可链式值时包含这些。
- `isDiscoverable` - 为 `false` 时，intent 在 Shortcuts 库和 Siri 建议中不可见。用于仅作为小组件按钮、snippet 按钮或其他 intent 后盾的辅助 intent。保持面向用户的库干净。
- `openAppWhenRun` - 在 `perform()` 完成后打开 App。对于用户可见导航优先使用 `OpenIntent`；仅在打开是更大操作的副作用时使用此选项。

## 常见 intent 子协议

`AppIntent` 是基线。多个子协议专门化行为；选择最匹配的具体一个：

| 协议 | 用途 |
|---|---|
| `AppIntent` | 通用操作。 |
| `OpenIntent` | 打开 App 到特定 entity（`target: MyEntity` 参数）。参见 `open-and-snippet-intents.md`。 |
| `SnippetIntent` | 仅渲染 snippet 视图——无业务逻辑。与 `ShowsSnippetIntent` 结果配对。 |
| `ForegroundContinuableIntent` | 可通过 `needsToContinueInForegroundError(...)` 在 perform 中途将 App 带到前台。用于需要 UI 的流程（登录、权限）。 |
| `DeleteIntent` | 删除一个或多个 entity；系统可能自动提示确认。 |
| `ShowInAppSearchResultsIntent` | 将搜索查询路由到 App 自己的搜索 UI。 |
| `AudioPlaybackIntent` / `AudioStartingIntent` | 播放音频；与锁屏、CarPlay 集成。 |
| `VideoCallIntent` | 发起视频通话。 |
| `CameraCaptureIntent` | 发起相机拍摄流程。 |
| `ProgressReportingIntent` | 报告长时间运行任务的进度；Shortcuts 自动显示进度条。设置 `totalUnitCount`，在 `perform()` 期间推进 `completedUnitCount`。(iOS 17+) |
| `LongRunningIntent` | 通过 `performBackgroundTask` 运行超过 30 秒后台预算；呈现 Live Activity；支持后台 GPU。改进 `ProgressReportingIntent`。(iOS 27+ - 参见 `long-running-and-execution.md`) |
| `CancellableIntent` | 通过 `withIntentCancellationHandler` 用取消*原因*优雅清理。(iOS 26.4+ - 参见 `long-running-and-execution.md`) |
| `URLRepresentableIntent` | 让系统通过通用链接 URL 打开 App 而不运行你的 `perform()`。与 `URLRepresentableEntity` 配对。参见 `open-and-snippet-intents.md`。 |
| `TargetContentProvidingIntent` | iOS 上的标记协议——告诉系统此 intent 产生用户导航到的 App 场景。视觉智能路由回 App 所需。 |
| `WidgetConfigurationIntent` | 仅用作小组件配置的 intent 的标记协议。参数查询驱动配置选择器；无用户可调用操作。(iOS 17+ 通过 WidgetKit 的 `AppIntentConfiguration`) |
| `ControlConfigurationIntent` | 同上，但用于控制中心控件（iOS 18+）。一个 intent 可以同时是控件的配置和其点击操作。 |
| `PredictableIntent` | 系统从先前调用学习并主动建议 intent；根据参数值动态定制描述。(iOS 26+) |

## 前台延续

Intent 有时需要在 perform 中途将 App 带到前台——登录、授予权限或完成只有 UI 能处理的事。三种机制，按 iOS 版本选择。

### `ForegroundContinuableIntent` + `needsToContinueInForegroundError`（iOS 17+）

抛出错误，停止 intent，在用户点击继续时运行闭包：

```swift
struct SuggestArticlesIntent: ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Suggest articles"
    @Dependency var account: AccountManager
    @Dependency var navigation: NavigationModel

    @Parameter var topic: String?

    func perform() async throws -> some IntentResult & ReturnsValue<[ArticleEntity]> {
        if !account.loggedIn {
            let dialog = IntentDialog("You aren't logged in. Tap Continue to sign in.")
            throw needsToContinueInForegroundError(dialog) {
                navigation.route = .signIn
            }
        }

        let articles = try await account.suggestions(for: topic)
        return .result(value: articles)
    }
}
```

### `requestToContinueInForeground`（iOS 17+，非抛出）

相同想法但返回值，使 intent 可以在前台化后继续执行而非从头重启：

```swift
let result = try await requestToContinueInForeground(dialog) {
    await navigation.presentSignIn()  // 返回用户选择的账户
}
// result 是闭包返回的任何东西；intent 继续运行
```

在前台步骤产生完成工作所需数据时使用。

### `supportedModes` + `continueInForeground`（iOS 26+）

现代形式。声明 intent 支持哪些执行模式，然后在 `perform()` 内动态决定：

```swift
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start workout"
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Dependency var workoutManager: WorkoutManager

    func perform() async throws -> some IntentResult {
        if workoutManager.needsPermission {
            try await continueInForeground(alwaysConfirm: false)
        }
        try await workoutManager.start()
        return .result()
    }
}
```

模式：

- `.background` - 无 UI 运行。
- `.foreground(.immediate)` - 总是前台化 App。
- `.foreground(.dynamic)` - 可根据 `continueInForeground()` 调用前台化。
- `.foreground(.deferred)` - 在 `perform()` 完成后前台化。

`continueInForeground(alwaysConfirm:)` 打开 App；`alwaysConfirm: false` 在设备最近活动时跳过确认提示（将近况视为隐式同意）。

在 iOS 26 上优先使用 `supportedModes` + `continueInForeground`。`ForegroundContinuableIntent` / `needsToContinueInForegroundError` 保留用于向后兼容。

## 无场景的后台启动

当 intent 以 `openAppWhenRun = false` 运行时，系统启动你的 App 进程但**不**调出场景——UI 层次结构未构建，无 `body` 属性运行。只有 `App.init()` 执行。

两个后果：

- 任何 intent 相关设置必须位于 `App.init()` 中（参见 `dependencies.md`）。
- 如果 intent 后来决定需要 UI（如通过 `continueInForeground`），系统会在那时创建场景。

后台启动比场景启动快得多。尽可能保持 `openAppWhenRun = false`。

## 执行时间和目标

另外两个生命周期事实，都在 27 发布中扩展（完整细节在 `long-running-and-execution.md`）：

- **30 秒预算。** 从任何系统界面触发的 intent 有约 30 秒完成（macOS 无硬性限制）。超过则被杀死。对于上传、同步、大文件操作或设备端推理，遵循 `LongRunningIntent` 并将工作包装在 `performBackgroundTask` 中；对于取消时优雅清理，遵循 `CancellableIntent`。
- **执行目标。** 当 intent 位于 App *和*扩展都导入的共享包中时，系统通过启发式选择进程。用 `allowedExecutionTargets` 类型属性（`IntentExecutionTargets`）覆盖它——如将数据修改 intent 固定到主 App，使只读小组件扩展永远不写共享存储。

## 硬性限制和字符上限

App Intents 有几个值得了解的具体上限：

- **每个 App 10 个 App Shortcut。** `AppShortcutsProvider.appShortcuts` 数组上限为 10。选择最习惯的操作。
- **总计 1,000 个触发短语。** 包括所有参数展开。一个如 `"Open \(\.$folder) in \(.applicationName)"` 的短语带 20 个文件夹列表算作 20 个短语。
- **第一个短语是主要短语。** `phrases:` 中的第一个条目成为 Shortcuts 主页上的磁贴标签，以及 Siri 被问"我能用 X 做什么？"时回答的短语。

以主要优先规则规划短语数组。

## 字符串文件位置

App Intents 元数据在构建时由 Swift 编译器提取。intent 标题、描述、对话和参数提示的本地化字符串必须位于引用它们的 intent 类型**同一模块**中的 `.strings` 文件或 String Catalog 中——框架不能为别处定义的 intent 持有字符串。

在 iOS 17+ 上，为快捷方式短语使用专用的 `AppShortcuts` String Catalog（参见 `shortcuts-and-siri.md`）——它消除了以前适用于 Swift 声明短语的每语言环境短语计数限制。

## Intent 作为 App 的规范操作层

除了 Siri / Shortcuts / Spotlight 暴露外，intent 还很适合作为 App 的内部操作词汇。当每个面向用户的操作都通过 intent 时，相同类型驱动：

- Siri 和 Shortcuts 调用。
- 小组件 `Button(intent:)` 点击。
- 控制中心控件。
- Live Activity 按钮。
- 深度链接路由（通过 `OpenIntent` + `URLRepresentableIntent`）。
- App 内 SwiftUI `Button(intent:)`，在方便的视图中。

单一 intent 定义覆盖所有这些，无需重复的操作处理代码。即使标记为 `isDiscoverable = false` 的 intent（对 Shortcuts 库中的用户不可见）也值得做，因为小组件、控件和 App 内按钮可以调用它们。

这是设计选择，不是框架要求——但当你采纳它时，重构变得更容易：你将一个操作移入 intent 一次，需要该操作的每个界面都使用相同代码路径。

## "一切都应是 App Intent"

Apple 的设计指导在 WWDC24 转变：不是只暴露一两个最习惯的操作，而是将 App 做的每件有意义的事视为潜在 intent。注意事项：

- 不要为同一任务的每个变体创建一个 intent（一个带参数的灵活 intent 比许多近似副本更好）。
- 不要将 UI 级操作暴露为 intent（"保存草稿"，而非"点击保存按钮"）。
- 参数摘要必须对每种值组合都读起来像自然句子。
- 从习惯操作开始；稍后扩展覆盖。

App shortcuts 数组上的限制（10）仍然迫使对 Siri / 操作按钮 / Shortcuts 主页界面有选择性。但 intent 目录本身可以大得多——未设上限的 intent 仍出现在 Shortcuts 编辑器和下游组合中。

## 返回类型组合

`some IntentResult` 是基础。用 `&` 组合额外能力：

| 遵循 | 含义 |
|---|---|
| `IntentResult` | 基线——intent 完成。 |
| `ProvidesDialog` | 将语音/显示对话附加到结果。 |
| `ReturnsValue<T>` | 返回可在 Shortcuts 中链式的类型化值。 |
| `ShowsSnippetView` | 附加 SwiftUI snippet 视图（小组件样式）。 |
| `ShowsSnippetImage` | 附加单个图像。 |
| `OpensIntent` | intent 完成时打开 App。 |

示例：

```swift
// 仅对话
func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: "Feed refreshed.")
}

// 对话 + 可链式值（Int, String, Bool, Double, Date, URL, AppEntity 或数组）
func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
    let count = try await service.unreadCount()
    let message = AttributedString(localized: "You have ^[\(count) unread article](inflect: true).")
    return .result(value: count, dialog: "\(message)")
}

// 对话 + SwiftUI snippet
func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    return .result(dialog: "\(entity.title)") {
        VStack {
            Image(systemName: "doc.text")
                .font(.largeTitle)
            Text(entity.summary)
        }
        .padding()
    }
}
```

运行时检查返回形状：如果你声明 `ProvidesDialog` 但返回不带对话的 `.result()`，它在调用点崩溃——而非编译时。将签名与调用完全匹配。

## perform 并发

`perform()` 是 `async throws` 且默认不是 main-actor。你接触的任何东西必须要么是 `Sendable` 要么跳到正确的 actor：

```swift
// 选项 A：将整个 perform 固定到 main actor（需要 UI 或 SwiftData main context 时好用）
@MainActor
func perform() async throws -> some IntentResult {
    let items = try service.recent()
    return .result()
}

// 选项 B：不留在 main actor；仅在需要时跳
func perform() async throws -> some IntentResult {
    let summary = try await service.fetchSummary()
    await MainActor.run { uiCoordinator.present(summary) }
    return .result()
}
```

当 intent 读写 SwiftData 或修改 UI 状态时，`perform()` 上的 `@MainActor` 是务实选择——这是 Apple 自己示例所做的。

## intent 对话

`IntentDialog` 由任何 `LocalizedStringResource` 或 `AttributedString` 的字符串插值构造：

```swift
return .result(dialog: "Saved \(count) items to \(folder.name).")
```

复数化使用 Foundation 的自动语法一致性（markdown 语法，`^[...](inflect: true)`）：

```swift
let count = 5
let message = AttributedString(localized: "Added ^[\(count) bookmark](inflect: true).")
return .result(dialog: "\(message)")
```

输出："Added 1 bookmark." / "Added 5 bookmarks." 自动一致性在英语、法语、德语、意大利语、西班牙语和葡萄牙语（两种变体）中工作。对于其他语言环境，文本按原样渲染，因此将单数形式写为基本形式。

你可以提供更丰富的对话变体：

```swift
let dialog: IntentDialog = IntentDialog(
    full: "You have \(count) unread articles in your saved feed.",
    supporting: "\(count) unread"
)
return .result(dialog: dialog)
```

Siri 根据上下文（语音 vs 屏幕、短 vs 长）选择使用哪个变体。

## 状态变化后刷新小组件和控件

当 `perform()` 修改小组件、控制小组件或 live activity 显示的数据时，返回前重新加载它们的时间线：

```swift
import AppIntents
import WidgetKit

struct AddBookmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Add bookmark"

    @Parameter(title: "URL") var url: URL
    @Dependency var store: DataStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try store.addBookmark(url: url)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Saved.")
    }
}
```

`WidgetCenter.shared.reloadAllTimelines()` 告诉系统每个注册的小组件都过时了。对于细粒度重新加载，使用带小组件 kind 字符串的 `reloadTimelines(ofKind:)`。在 `perform()` 内部、返回前执行此操作——否则小组件持续显示变化前状态直到下次刷新 tick。

## 错误

从 `perform()` 抛出以信号失败。任何 `Error` 都可以，但 App Intents 特别理解这些：

- `NeedsValueError(...)` - 请求用户未提供的参数。
- `RequestDisambiguationError(...)` - 要求用户在多个选项间选择。
- `ConfirmationRequiredError` - 要求用户确认破坏性操作。

```swift
throw $folder.needsValueError("Which folder should this go in?")
```

对于一般失败，抛出遵循 `CustomLocalizedStringResourceConvertible` 的普通 `Error`，使对话可本地化。

## 范围：intent 应该做什么

Apple 的指导（从 WWDC24 起）："你的 App 做的任何事都应是 App Intent。"实际解释：

- 暴露小的、离散的操作：refresh、create、append、mark-as-read、open-X、summarize-X。
- 不要在 intent 内认证；假设用户已登录，如果没登录则返回解释的 `ProvidesDialog` 结果。
- 不要从 intent 启动冗长的 UI 流程；要么返回 snippet、在正确位置打开 App（`OpenIntent`）、要么返回值。
- 保持 `perform()` 合理快；Siri 不会无限等待。
