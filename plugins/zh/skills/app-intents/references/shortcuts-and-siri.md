# Shortcuts 和 Siri

编写 `AppIntent` 类型不够。系统通过 `AppShortcutsProvider` 发现 intent。未在那里列出的任何东西对 Shortcuts、Siri 建议、操作按钮选择器和大多数自动化界面不可见。

## `AppShortcutsProvider`

```swift
import AppIntents

struct ReaderShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshFeedIntent(),
            phrases: [
                "Refresh my feed in \(.applicationName)",
                "Get new articles in \(.applicationName)"
            ],
            shortTitle: "Refresh Feed",
            systemImageName: "arrow.clockwise"
        )

        AppShortcut(
            intent: OpenArticleIntent(),
            phrases: [
                "Open an article in \(.applicationName)"
            ],
            shortTitle: "Open Article",
            systemImageName: "doc.text"
        )
    }
}
```

每个 App 恰好一个 `AppShortcutsProvider`。它是静态声明并在构建时扫描。

## `\(.applicationName)` 规则

每个短语必须某处包含 `\(.applicationName)`：

```swift
// 错误 - 构建错误："Every app shortcut phrase needs to contain the applicationName"
phrases: ["Refresh my feed"]

// 正确
phrases: ["Refresh my feed in \(.applicationName)"]
```

这由宏在编译时强制执行。原因：没有 App 名称，短语与其他 App 的命令冲突。"Set a timer for 5 minutes"属于时钟 App；你的 App 不能劫持它。

没有绕过此的方式——绝不硬编码名称字符串。插值展开为 bundle 的显示名称，在 App 重命名后仍有效。

## 短语覆盖

在 iOS 17+ 上，Siri 有**灵活匹配**——构建时语义相似性索引匹配接近的释义（"Tell me the summary of my groceries list" → "Summarize my groceries list"）。用 Xcode 15+ 构建时默认开启；如需仅精确匹配，通过 `Enable App Shortcuts Flexible Matching` 构建设置禁用。

即使有灵活匹配，也提供多种措辞。索引匹配含义；提供多样表述使其更可能为模糊语音收敛到你的 intent。

```swift
AppShortcut(
    intent: AppendNoteIntent(),
    phrases: [
        "Append to my latest note in \(.applicationName)",
        "Add to my most recent note in \(.applicationName)",
        "Save this to \(.applicationName)"
    ],
    shortTitle: "Append to Latest Note",
    systemImageName: "plus"
)
```

简短、自然的形态胜过长、正式的。想想用户实际会大声说什么。

## 标题 vs 短标题

`AppIntent.title` 和 `AppShortcut.shortTitle` 不同且都显示：

- `title` 出现在用户构建多操作快捷方式的 Shortcuts 操作列表中（如"Refresh feed"）。
- `shortTitle` 出现在 Shortcuts 主页的操作按钮磁贴中、App 的快捷方式库中，以及 Siri 的"我能在这里做什么"sheet 中。

开发期间给它们足够不同的措辞（"Count Recent Dreams" vs "Recent Dream Count"）以看到哪个界面是哪个；发布前确定一致措辞。

## 参数化 `AppShortcut`

`AppShortcut` 可由 intent 的 `@Parameter` 配置——这让一个 intent 呈现几个现成短语：

```swift
AppShortcut(
    intent: SearchArticlesIntent(),
    phrases: [
        "Search \(\.$query) in \(.applicationName)",
        "Find \(\.$query) in \(.applicationName)"
    ],
    shortTitle: "Search",
    systemImageName: "magnifyingglass"
)
```

`\(\.$query)` 是参数键路径——用户的语音填充它。

### 刷新参数驱动短语：`updateAppShortcutParameters()`

当短语使用到 entity 参数的键路径（如 `\(\.$folder)`）时，系统缓存它将显示的候选值列表。当你的底层 entity 数据变化——添加新文件夹、书签重命名——调用 `updateAppShortcutParameters()` 使缓存失效：

```swift
@main
struct ReaderApp: App {
    init() {
        ReaderShortcuts.updateAppShortcutParameters()

        let store = DataStore(...)
        self._store = .init(initialValue: store)
        AppDependencyManager.shared.add(dependency: store)
    }
    ...
}
```

在 UIKit 生命周期 App 中，改从 `application(_:didFinishLaunchingWithOptions:)` 调用：

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        ReaderShortcuts.updateAppShortcutParameters()
        return true
    }
}
```

调用它：

- 启动时一次（SwiftUI 中 `App.init()`，UIKit 中 `didFinishLaunching`）以播种当前集合。
- 每当出现在快捷方式短语键路径中的 entity 变化时（创建、重命名、删除）。

没有此，Siri 建议的短语可能指向过时 entity 名称或提供已删除的项目。

### 否定短语（iOS 17+）

当灵活匹配产生误报时，添加**不应**触发快捷方式的短语：

```swift
AppShortcut(
    intent: DeleteFolderIntent(),
    phrases: [
        "Delete folder in \(.applicationName)"
    ],
    negativePhrases: [
        "Delete folder permanently in \(.applicationName)",
        "Empty trash in \(.applicationName)"
    ],
    shortTitle: "Delete Folder",
    systemImageName: "trash"
)
```

捕获语义索引否则会标记的常见近似匹配。保持列表短——每个否定短语消耗你 1,000 个总短语槽之一。

## `AppShortcuts` String Catalog

本地化 Swift 声明的短语过去受限：每个语言环境必须有与 Swift 源相同数量的短语。iOS 17+ 添加了专用的 **AppShortcuts** String Catalog 类型，取消此限制——不同语言环境可有不同措辞计数，且可按语言环境添加新短语而无需碰 Swift 代码。

Xcode 的迁移助手将现有 `AppShortcuts.strings` 文件转换为目录格式。所有新项目应从目录开始。

## 在 Xcode 中预览快捷方式

Xcode 15+（macOS Sonoma）有 `Product > App Shortcuts Preview`，让你无需重建、对 Siri 说话或离开 IDE 即可测试短语匹配和灵活匹配行为。它支持切换语言环境，因此你可以就地验证翻译。

调整短语时大量使用它——比模拟器往返快得多。

## Spotlight 和 Shortcuts 的强调色

iOS 17+ 让你通过两个 `Info.plist` 键设置 App 在 Spotlight 卡片和 Shortcuts 库中的外观：

- `NSAppIconActionTintColorName` - 主色调，应用于图标和按钮。
- `NSAppIconComplementingColorNames` - 最多两种互补色数组，系统可分层到背景中。

两个值都引用 App 资产目录中的颜色名称。系统根据上下文选择使用哪种互补色。

## `shortcutTileColor`

```swift
static let shortcutTileColor: ShortcutTileColor = .navy
```

选项：`.grayBlue`、`.red`、`.orange`、`.yellow`、`.green`、`.teal`、`.blue`、`.indigo`、`.purple`、`.pink`、`.navy`、`.lightBlue`、`.gray`、`.lime`。颜色由 Shortcuts App 用于 App 的磁贴。

## App 内可发现性

两个 SwiftUI 助手在 App 内直接引导用户使用快捷方式。

### `ShortcutsLink`

直接打开 App 在 Shortcuts App 中的页面：

```swift
import AppIntents

var body: some View {
    Section {
        ...
    } footer: {
        ShortcutsLink()
    }
}
```

一行。无参数。放在设置屏幕、引导 sheet 或列表页脚中都可以。

### `SiriTipView`

为你的一个 intent 建议特定 Siri 短语：

```swift
@AppStorage("suggest.refreshFeed") var showTip = true

SiriTipView(intent: RefreshFeedIntent(), isVisible: $showTip)
```

当 `isVisible` 绑定时，提示有"x"关闭——通过 `@AppStorage` 持久化关闭，使其不重新出现。显示的短语从 intent 注册的 `AppShortcut` 短语读取。

### "我能在这里做什么？"

在真实设备上，对 Siri 说"我能在这里做什么？"要求 OS 扫描当前 App 注册的 intent 并显示它们。一旦你的 `AppShortcutsProvider` 注册，这自动工作——无需额外代码。对于已知道 Siri 存在的用户，这是强大的可发现性杠杆。

## 呈现 intent 参数

`AppShortcut` 接受可选的 `parameterPresentation` 以更改 Shortcuts 如何为该特定短语渲染参数选择器。用于预填充参数标签或示例值。文档稀少；仅在默认渲染不足时使用。

## 在模拟器中调试

模拟器中的 Siri 语音激活明显不可靠。如果昨天工作的短语今天停止工作：

- **擦除并重新安装。** 设备 → 擦除所有内容和设置通常清除过时的缓存短语注册。
- **重试几次。** 模拟器上的语音识别即使在正确配置时也可能在第一次或第二次尝试失败。
- **切换到打字 Siri。** 设置 → 辅助功能 → Siri → Type to Siri。完全绕过语音识别；证明问题是语音还是 intent 接线。
- **使用 Xcode 的 App Shortcuts Preview 工具**（macOS Sonoma + Xcode 15+）。它直接测试短语匹配，无语音路径。
- **检查 App Shortcuts Preview 元数据警告。** 工具报告短语何时未通过 `\(.applicationName)` 验证或其他宏强制规则。

端到端 Siri 测试在设备上通常比模拟器更可靠。当模拟器行为不一致而设备上有效时，信任设备。

## 平台特定行为

### watchOS

来自配对 iPhone 的 App Shortcut **不**同步到 Apple Watch。watchOS App 必须单独安装并声明自己的 `AppShortcutsProvider`。灵活匹配在 Watch 上不可用——短语是精确匹配。iOS 16+ / watchOS 9.2+ 用于基本支持。

### HomePod

iOS 16.2+ / HomePod Software 16.2+。仅语音——无屏幕，因此 intent 返回的任何结果都被说出。`IntentDialog(full:supporting:)` 模式在这里特别重要：

```swift
let dialog = IntentDialog(
    full: "You have 3 reminders due this afternoon: call Alex, buy milk, pay electric bill.",
    supporting: "3 reminders due today."
)
```

HomePod 说出 `full` 字符串；有屏幕能力的设备将 `supporting` 字符串与任何 snippet 一起渲染。当 intent 可能在 HomePod 上运行时始终提供两者。

仅语音设备不会启动 App，即使 `openAppWhenRun = true`。*必须*打开 App 才能成功的 intent 会在 HomePod 上可听地失败——对此进行守护或记录限制。

## 什么不应注册

- 不要注册你只想用作小组件配置的 intent。小组件配置 intent（`WidgetConfigurationIntent`）通过 widget kit 解析，而非通过 `AppShortcutsProvider`。
- 不要注册仅作为其他 intent 构建块的 intent——保持内部。
- 如果 intent 应只在你自己的 App 代码中运行（如从按钮），你完全不必注册它。注册是向系统其余部分的发布步骤。
