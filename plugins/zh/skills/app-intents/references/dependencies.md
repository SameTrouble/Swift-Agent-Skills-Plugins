# 依赖和数据流

Intent 没有 SwiftUI `@Environment`。它们不能使用 `@Query`。它们通过 **`@Dependency`** 获取协作者，后者从 App 填充的全局注册表读取。

## 模式

1. 在 `App.init()` 中构建数据控制器（或服务、导航器、网络客户端）。
2. 用 `AppDependencyManager.shared.add(dependency:)` 注册它。
3. 在需要它的任何 intent 或 entity-query 中声明 `@Dependency var x: X`。

```swift
import AppIntents
import SwiftData
import SwiftUI

@main
struct ReaderApp: App {
    @State private var store: DataStore
    @State private var modelContainer: ModelContainer

    init() {
        let modelContainer: ModelContainer

        do {
            modelContainer = try ModelContainer(for: Article.self)
        } catch {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: Article.self, configurations: config)
        }

        self._modelContainer = .init(initialValue: modelContainer)

        let store = DataStore(modelContainer: modelContainer)
        self._store = .init(initialValue: store)

        AppDependencyManager.shared.add(dependency: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .modelContainer(modelContainer)
    }
}
```

```swift
struct RefreshFeedIntent: AppIntent {
    @Dependency var store: DataStore

    static let title: LocalizedStringResource = "Refresh feed"

    func perform() async throws -> some IntentResult {
        try await store.refresh()
        return .result()
    }
}
```

`@Dependency` 查找其类型的第一个注册实例。没有层级或作用域——它是一个扁平注册表。注册一次。

## `App.init()` 对 intent 也运行

当快捷方式触发时，OS 启动 App 进程并运行 `App.init()`，即使从未创建 UI。这是以下操作的窗口：

- 创建 `ModelContainer`。
- 注册依赖。
- 接线 intent 将读取的任何其他设置。

**不**运行的：`.task`、`.onAppear`、视图内部的 `@StateObject` init 闭包。如果你依赖这些进行 intent 所需的设置，intent 会崩溃或看到过时状态。

### 进程边界：App vs 扩展

当 `AppShortcutsProvider` 在主 App target 中时，intent 在主 App 进程中运行（在 `App.init()` 之后）。当它在 App Intents 扩展中时（iOS 17+，参见下文"共享框架提取"），intent 在单独的、更轻的扩展进程中运行：

- 扩展进程**不**与主 App 共享内存。主 App UI 中构建的单例状态对扩展不可见。
- 扩展进程仍运行自己的 `App.init()` 或扩展主体初始化器，因此 `@Dependency` 接线在该进程内以相同方式工作。
- 对共享存储（App Group `UserDefaults`、App Group 文件 URL、指向 App Group URL 的 `ModelContainer`）的写入对两个进程都可见。

实际影响：将每个 intent 的协作者视为每次调用重新初始化。不要在静态变量中缓存昂贵对象期望它们在 intent 运行间持久——扩展是短命的，可能在调用间被销毁。优先通过 `@Dependency` 注册新实例并让平台管理生命周期。

## 数据控制器骨架

数据控制器将所有 SwiftData（或网络）访问集中在一处，这样 intent 不必重新发明查询：

```swift
import Foundation
import SwiftData

@Observable @MainActor
final class DataStore {
    var modelContext: ModelContext
    var path: [Article] = []
    var searchText = ""

    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
    }

    func articles(
        matching predicate: Predicate<Article> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Article>] = [SortDescriptor(\.publishedAt, order: .reverse)],
        limit: Int? = nil
    ) throws -> [Article] {
        var descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: sortBy)
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func articleEntities(
        matching predicate: Predicate<Article> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Article>] = [SortDescriptor(\.publishedAt, order: .reverse)],
        limit: Int? = nil
    ) throws -> [ArticleEntity] {
        try articles(matching: predicate, sortBy: sortBy, limit: limit).map(\.entity)
    }

    func articleCount(
        matching predicate: Predicate<Article> = #Predicate { _ in true }
    ) throws -> Int {
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
}
```

关键约定：

- **绑定到 main-actor。** 控制器驱动 UI；固定它使 SwiftData 访问序列化并消除 sendability 噪音。
- **两种返回形态** - 一种返回 `[Article]`（用于修改和 UI），一种返回 `[ArticleEntity]`（sendable；可安全跨 actor 传递给 intent）。
- **默认值参数**以便调用者可以为常见情况说 `store.articles()`。

## `ModelContainer` vs `ModelContext` sendability

只有 `ModelContainer` 是 `Sendable`。`ModelContext` 不是。

- 跨 actor 传递 `ModelContainer`。在需要它的每个 actor 内部创建本地 `ModelContext(modelContainer)`。
- 如果你将 intent 的 `perform()`（或数据控制器）固定到 `@MainActor`，可以直接使用 `modelContainer.mainContext`。

```swift
// 可以 - main-actor perform 读取 main context
@MainActor
func perform() async throws -> some IntentResult {
    let recent = try store.articles(limit: 5)
    ...
    return .result()
}

// 可以 - 通过新的本地 context 跨 actor 访问
func perform() async throws -> some IntentResult {
    let container = try ModelContainer(for: Article.self)
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Article>(predicate: #Predicate { _ in true })
    let count = try context.fetchCount(descriptor)
    ...
    return .result()
}
```

当 `DataStore` 上已存在共享 `ModelContainer` 时，避免从 `perform()` 内部创建临时 `ModelContainer`。它可以工作但浪费容器设置并产生泄漏的代码路径。

## 从 intent 修改 model 对象

要从 intent 修改 `@Model` 对象，在 main actor 上、同一 main context 上进行：

```swift
struct AppendNoteIntent: AppIntent {
    @Dependency var store: DataStore

    @Parameter(title: "Text")
    var newText: String

    static let title: LocalizedStringResource = "Append to latest note"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let recent = try store.articles(limit: 1)

        guard let first = recent.first else {
            return .result(dialog: "You haven't saved anything yet.")
        }

        first.body.append(" \(newText)")
        try first.modelContext?.save()

        return .result(dialog: "Added.")
    }
}
```

两件事使这工作：

1. intent 的 `perform()` 和数据控制器都是 `@MainActor`。不跨 actor 发送非 sendable 数据。
2. `first` 是实际的 `Article` 实例，不是 `ArticleEntity` 副本——因此修改持久化。

建议显式调用 `try first.modelContext?.save()`。SwiftData 的自动保存从 intent 不可靠，因为 App 可能在下一个运行循环前被销毁。

## 不要在 `perform()` 内认证

如果你的 App 要求登录，假设用户已登录。如果没有，用 `ProvidesDialog` 提前返回：

```swift
guard store.isAuthenticated else {
    return .result(dialog: "Sign in to the app first.")
}
```

不要从 intent 呈现认证表单——你会在 Siri 或 Shortcuts 中困住用户。

## 共享框架提取

较大的 App 将 intent 拆分为单独的 target。只要依赖在 `App.init()` 中注册，`@Dependency` 解析跨框架工作。三种分发机制，取决于 iOS 最低版本：

### `AppIntentsPackage` 协议（iOS 17+）

用 `AppIntentsPackage` 声明导出元数据的 target，使编译器递归地将其 intent 重新导出到主 App：

```swift
// 在 intent 框架中
import AppIntents

public struct ReaderIntentsPackage: AppIntentsPackage { }
```

```swift
// 在主 App 中
import AppIntents
import ReaderIntents   // 框架

struct ReaderApp: App, AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [ReaderIntentsPackage.self]
    }
    ...
}
```

主 App 的 package 列出应注册的框架。iOS 17+ 支持动态框架。

### Swift Packages 和静态库（iOS 26+）

iOS 26 将 `AppIntentsPackage` 支持扩展到 Swift Packages 和静态库 target。相同协议，相同 `includedPackages` 声明。当你想从 swift-package 依赖发布 intent 而无二进制框架 target 时有用。

### `AppShortcutsProvider` 在 App Intents 扩展中（iOS 17+）

以前，`AppShortcutsProvider` 必须位于主 App bundle 中，这导致每次快捷方式触发时都启动 App。在 iOS 17+ 上，provider 可以位于 App Intents 扩展 target 中——快捷方式在扩展的更轻进程中运行，更快且不唤醒主 App。

## 框架定义的 entity

iOS 18+ 允许框架中定义的 `AppEntity` 被主 App 中的 intent 参数化。早期版本要求 intent 和 entity 在同一模块中。通过 `AppIntentsPackage` 注册框架就足够；提取工具跨模块边界传递 entity 元数据。

外部（非 Apple）库源仍不支持——仅第一方 `AppIntentsPackage` 遵循者。

## UIKit 生命周期：`UISceneAppIntent` 和 `AppIntentSceneDelegate`

iOS 26+。对于 UIKit App（或基于 UIKit-scene 的 Catalyst / iPad App），两个协议给 intent 一流的场景感知：

### `UISceneAppIntent`

当 intent 应接收触发它的 `UIScene` 时让其遵循此协议，这样 `perform()` 可以路由场景特定行为：

```swift
struct OpenInNewWindowIntent: AppIntent, UISceneAppIntent {
    static let title: LocalizedStringResource = "Open in new window"

    @Parameter var target: NoteEntity

    func perform() async throws -> some IntentResult {
        let scene = try currentScene   // 由 UISceneAppIntent 提供
        // 路由到特定场景
        return .result()
    }
}
```

### `AppIntentSceneDelegate`

让场景代理感知 intent 激活，以便它可以在 intent 触发前配置窗口状态：

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate, AppIntentSceneDelegate {
    func windowScene(_ scene: UIWindowScene, performActionFor intent: any AppIntent) async {
        // 为传入 intent 准备 UI
    }
}
```

在 SwiftUI 生命周期 App 上，这是不需要的——`App.init()` / `@Dependency` 模式覆盖了它。

## `TargetContentProvidingIntent` 的场景路由

iOS 26+。当 `TargetContentProvidingIntent` 运行时，系统需要知道 App 的*哪个*场景应处理它。两种机制：

### `contentIdentifier` + `handlesExternalEvents`

intent 声明 `contentIdentifier`；每个场景声明它接受哪些标识符：

```swift
extension OpenNoteIntent: TargetContentProvidingIntent {
    var contentIdentifier: String { "note-detail" }
}

// 在 SwiftUI 中
WindowGroup {
    NoteDetailView(...)
}
.handlesExternalEvents(matching: ["note-detail"])
```

系统选择其 `handlesExternalEvents` 匹配 intent 标识符的场景。

### 每视图条件

对于动态条件（如只有当前显示特定 entity 的场景应处理 intent），将 `.handlesExternalEvents` 附加到子视图而非 `WindowGroup`。

当省略 `contentIdentifier` 时，它默认为 intent 的类型名称。
