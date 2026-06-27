# 迁移到 Swift 6 和严格并发

使用本文件当：

- 你正在将现有代码库迁移到 Swift 6 或更严格的并发检查。
- 编译器诊断依赖于语言模式、默认隔离或 upcoming features。
- 你需要最小安全迁移序列而非完整架构重写。

跳过本文件如果：

- 你已经知道确切诊断且只需要局部修复。从 `actors.md`、`sendable.md` 或 `threading.md` 开始。
- 你正在寻找 debounce、流组合或 FRP 操作符替代方案。使用 `async-algorithms.md`。

跳转到：

- 工程设置
- 六个迁移习惯
- 逐步迁移
- 迁移工具
- 将闭包重写为 Async/Await
- 从 Combine/RxSwift 迁移
- 并发安全通知（iOS 26+）
- 反模式

---

## 为什么迁移到 Swift 6？

Swift 6 不会从根本上改变 Swift Concurrency 的工作方式——它**更严格地强制现有规则**：

- **编译时安全**：在编译时而非运行时捕获数据竞争和线程问题
- **警告变为错误**：许多 Swift 5 警告在 Swift 6 语言模式中变为硬错误
- **面向未来**：新的并发功能将基于这个更严格的基础构建
- **更好的可维护性**：代码变得更安全且更容易推理

> **重要**：你可以在仍然在 Swift 5 下编译的同时逐步采用严格并发检查。你不需要立即切换 Swift 6 开关。

> **课程深入**：此主题在 [Lesson 12.2: The impact of Swift 6 on Swift Concurrency](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 影响并发行为的工程设置

在解释诊断或选择修复之前，确认目标/模块设置。这些设置可以实质性地改变代码执行方式和编译器强制的内容。

### 快速矩阵

| 设置 / 功能 | 在哪里检查 | 为什么重要 |
|---|---|---|
| Swift 语言模式（Swift 5.x vs Swift 6） | Xcode 构建设置（`SWIFT_VERSION`）/ SwiftPM `// swift-tools-version:` | Swift 6 将许多警告变为错误并启用更严格的默认值。 |
| 严格并发检查 | Xcode: Strict Concurrency Checking（`SWIFT_STRICT_CONCURRENCY`）/ SwiftPM: 严格并发标志 | 控制 Sendable + 隔离规则的强制程度。 |
| 默认 actor 隔离 | Xcode: Default Actor Isolation（`SWIFT_DEFAULT_ACTOR_ISOLATION`）/ SwiftPM: `.defaultIsolation(MainActor.self)` | 更改声明的默认隔离；可以减少迁移噪音但改变行为和要求。 |
| `NonisolatedNonsendingByDefault` | Xcode upcoming feature / SwiftPM `.enableUpcomingFeature("NonisolatedNonsendingByDefault")` | 更改非隔离异步函数的执行方式（可以继承调用方的 actor，除非显式标记 `@concurrent`）。 |
| Approachable Concurrency | Xcode 构建设置 / SwiftPM 启用底层 upcoming features | 捆绑多个 upcoming features；建议先逐个功能迁移。 |

## 并发兔子洞

常见的迁移体验：

1. 启用严格并发检查
2. 看到 50+ 错误和警告
3. 修复其中一部分
4. 重新构建并看到 80+ 新错误出现

**为什么会发生**：在一处修复隔离通常会在其他地方暴露问题。这是正常的，使用正确的策略可以管理。

> **课程深入**：此主题在 [Lesson 12.1: Challenges in migrating to Swift Concurrency](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 成功的六个迁移习惯

### 1. 不要恐慌——一切都是关于迭代

将迁移分解为小的、可管理的块：

```swift
// 第 1 天：启用严格并发，修复几个警告
// Build Settings → Strict Concurrency Checking = Complete

// 第 2 天：修复更多警告

// 第 3 天：如果需要，回退到 minimal 检查
// Build Settings → Strict Concurrency Checking = Minimal
```

每天给自己 30 分钟逐步迁移。对于大型项目不要期望几天内完成。

### 2. 新代码默认 Sendable

编写新类型时，从一开始就使其 `Sendable`：

```swift
// ✅ 好：新代码为 Swift 6 准备
struct UserProfile: Sendable {
    let id: UUID
    let name: String
}

// ❌ 避免：创建技术债务
class UserProfile {  // 稍后需要迁移
    var id: UUID
    var name: String
}
```

预先为并发设计比事后改造更容易。

### 3. 新项目和包使用 Swift 6

对于新项目、包或文件：
- 从一开始就启用 Swift 6 语言模式
- 使用 Swift Concurrency 功能（async/await、actor）
- 在技术债务累积之前减少它

你可以在 Swift 5 项目中为单个文件启用 Swift 6 以防止范围蔓延。

### 4. 抵制重构冲动

**仅专注于并发更改**。不要将迁移与以下内容结合：
- 架构重构
- API 现代化
- 代码风格改进

为非并发重构创建单独的工单，稍后处理。

### 5. 专注于最小更改

- 制作小的、聚焦的拉取请求
- 一次迁移一个类或模块
- 快速合并更改以创建检查点
- 避免难以审查的大型 PR

### 6. 不要对所有东西都加 @MainActor

不要盲目添加 `@MainActor` 来修复警告。考虑：
- 这是否确实应该在 main actor 上运行？
- 自定义 actor 是否更合适？
- `nonisolated` 是否是正确选择？

**例外**：对于 app 工程（非框架），考虑启用**默认 actor 隔离**为 `@MainActor`，因为大多数 app 代码需要主线程访问。

> **课程深入**：此主题在 [Lesson 12.3: The six migration habits for a successful migration](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 逐步迁移过程

### 1. 找到隔离的代码片段

从以下开始：
- 依赖最少的独立包
- 包内的单个 Swift 文件
- 不在整个项目中大量使用的代码

**原因**：更少的依赖 = 更少的陷入并发兔子洞的风险。

### 2. 更新相关依赖

启用严格并发之前：

```swift
// 将第三方包更新到最新版本
// 例如：Vapor、Alamofire 等
```

在继续并发更改之前，在单独的 PR 中应用这些更新。

### 3. 添加 Async 替代方案

为现有基于闭包的 API 提供 async/await 包装器：

```swift
// 原始基于闭包的 API
@available(*, deprecated, renamed: "fetchImage(urlRequest:)", 
           message: "Consider using the async/await alternative.")
func fetchImage(urlRequest: URLRequest, 
                completion: @escaping @Sendable (Result<UIImage, Error>) -> Void) {
    // ... 现有实现
}

// 新 async 包装器
func fetchImage(urlRequest: URLRequest) async throws -> UIImage {
    return try await withCheckedThrowingContinuation { continuation in
        fetchImage(urlRequest: urlRequest) { result in
            continuation.resume(with: result)
        }
    }
}
```

**好处**：
- 同事可以立即开始使用 async/await
- 你可以在重写实现之前迁移调用方
- 测试可以先更新为 async/await

**提示**：使用 Xcode 的 **Refactor → Add Async Wrapper** 自动生成这些。

### 4. 更改默认 Actor 隔离（Swift 6.2+）

对于 app 工程，将默认隔离设置为 `@MainActor`：

**Xcode 构建设置**：
```
Swift Concurrency → Default Actor Isolation = MainActor
```

**Swift Package Manager**：
```swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .defaultIsolation(MainActor.self)
    ]
)
```

这大幅减少了大多数类型需要主线程访问的 app 代码中的警告。

### 5. 启用严格并发检查

**Xcode 构建设置**：搜索 "Strict Concurrency Checking"

三个可用级别：

- **Minimal**：仅检查显式采用并发的代码（`@Sendable`、`@MainActor`）
- **Targeted**：检查所有采用并发的代码，包括 `Sendable` 一致性
- **Complete**：检查整个代码库（匹配 Swift 6 行为）

**Swift Package Manager**：
```swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency=targeted")
    ]
)
```

**策略**：从 Minimal → Targeted → Complete 开始，在每个级别修复错误。

### 6. 添加 Sendable 一致性

即使编译器不抱怨，也为将跨越隔离域的类型添加 `Sendable`：

```swift
// ✅ 为未来使用做准备
struct Configuration: Sendable {
    let apiKey: String
    let timeout: TimeInterval
}
```

这防止了稍后类型在并发上下文中使用时出现警告。

### 7. 启用 Approachable Concurrency（Swift 6.2+）

**Xcode 构建设置**：搜索 "Approachable Concurrency"

一次启用多个 upcoming features：
- `DisableOutwardActorInference`
- `GlobalActorIsolatedTypesUsability`
- `InferIsolatedConformances`
- `InferSendableFromCaptures`
- `NonisolatedNonsendingByDefault`

**⚠️ 警告**：不要为现有项目直接翻转此开关。使用迁移工具（见下文）先逐个功能迁移。

> **课程深入**：此主题在 [Lesson 12.5: The Approachable Concurrency build setting (Updated for Swift 6.2)](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 8. 启用 Upcoming Features

**Xcode 构建设置**：搜索 "Upcoming Feature"

逐个启用功能：

**Swift Package Manager**：
```swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InferIsolatedConformances")
    ]
)
```

在 Swift Evolution 提案中查找功能键（例如 `ExistentialAny` 的 SE-335）。

### 9. 更改为 Swift 6 语言模式

**Xcode 构建设置**：
```
Swift Language Version = Swift 6
```

**Swift Package Manager**：
```swift
// swift-tools-version: 6.0
```

如果你已完成所有前面的步骤，应该有最少的新错误。

> **课程深入**：此主题在 [Lesson 12.4: Steps to migrate existing code to Swift 6 and Strict Concurrency Checking](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## Upcoming Features 迁移工具

Swift 6.2+ 包含 upcoming features 的**半自动迁移**。

### Xcode 迁移

1. 转到 Build Settings → 找到 upcoming feature（例如 "Require Existential any"）
2. 设置为 **Migrate**（临时设置）
3. 构建项目
4. 警告出现并带有 **Apply** 按钮
5. 为每个警告点击 Apply

**示例警告**：
```swift
// ⚠️ 使用协议 'Error' 作为类型必须写为 'any Error'
func fetchData() throws -> Data  // 之前
func fetchData() throws -> any Data  // 应用修复后
```

### 包迁移

使用 `swift package migrate` 命令：

```bash
# 迁移所有目标
swift package migrate --to-feature ExistentialAny

# 迁移特定目标
swift package migrate --target MyTarget --to-feature ExistentialAny
```

**输出**：
```
> Applied 24 fix-its in 11 files (0.016s)
> Updating manifest
```

工具自动：
- 应用所有 fix-its
- 更新 `Package.swift` 以启用功能

**可用迁移**（截至 Swift 6.2）：
- `ExistentialAny`（SE-335）
- `InferIsolatedConformances`（SE-470）
- 随着时间推移会有更多功能添加迁移支持

> **课程深入**：此主题在 [Lesson 12.6: Migration tooling for upcoming Swift features](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

**额外资源**：[Migration Tooling Video](https://youtu.be/FK9XFxSWZPg?si=2z_ybn1t1YCJow5k)

---

## 将闭包重写为 Async/Await

### 使用 Xcode 重构

三个重构选项可用：

1. **Add Async Wrapper**：包装现有基于闭包的方法（推荐的第一步）
2. **Add Async Alternative**：将方法重写为 async，保留原始
3. **Convert Function to Async**：完全替换方法

**⚠️ 已知问题**：重构在 Xcode 中可能不稳定。如果遇到 "Connection interrupted" 错误：
- 清理构建文件夹
- 清除 derived data
- 重启 Xcode
- 简化复杂方法（简写的 if 语句可能导致失败）

### 手动重写示例

**之前**（基于闭包）：
```swift
func fetchImage(urlRequest: URLRequest, 
                completion: @escaping @Sendable (Result<UIImage, Error>) -> Void) {
    URLSession.shared.dataTask(with: urlRequest) { data, _, error in
        do {
            if let error = error { throw error }
            guard let data = data, let image = UIImage(data: data) else {
                throw ImageError.conversionFailed
            }
            completion(.success(image))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}
```

**之后**（async/await）：
```swift
func fetchImage(urlRequest: URLRequest) async throws -> UIImage {
    let (data, _) = try await URLSession.shared.data(for: urlRequest)
    guard let image = UIImage(data: data) else {
        throw ImageError.conversionFailed
    }
    return image
}
```

**好处**：
- 更少代码需要维护
- 更容易推理
- 无嵌套闭包
- 自动错误传播

> **课程深入**：此主题在 [Lesson 12.7: Techniques for rewriting closures to async/await syntax](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 使用 @preconcurrency

抑制来自你无法控制的模块的 `Sendable` 警告。

### 何时使用

```swift
// ⚠️ 第三方库尚不支持 Swift Concurrency
@preconcurrency import SomeThirdPartyLibrary

actor DataProcessor {
    func process(_ data: LibraryType) {  // 无 Sendable 警告
        // ...
    }
}
```

### 风险

- **无编译时安全**：你负责确保线程安全
- **隐藏真实问题**：库可能根本不是线程安全的
- **技术债务**：容易忘记稍后重新审视

### 最佳实践

1. **默认不使用**：仅在编译器建议时添加
2. **先检查更新**：库可能有支持并发的新版本
3. **记录原因**：添加注释解释为什么需要
4. **定期重新审视**：设置提醒检查库是否已更新

```swift
// TODO: 当 SomeLibrary 添加 Sendable 支持时移除 @preconcurrency
// 最后检查：2026-01-07（版本 2.3.0）
@preconcurrency import SomeLibrary
```

如果 `@preconcurrency` 未使用，编译器会警告：
```
'@preconcurrency' attribute on module 'SomeModule' is unused
```

> **课程深入**：此主题在 [Lesson 12.8: How and when to use @preconcurrency](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 从 Combine/RxSwift 迁移

### 观察替代方案

Swift 6 将包含**事务性观察**（SE-475）：

```swift
// 未来 API（尚未实现）
let names = Observations { person.name }

Task.detached {
    for await name in names {
        print("Name updated to: \(name)")
    }
}
```

**当前替代方案**：
- 为 SwiftUI 使用 `@Observable` 宏
- 为自定义观察使用 `AsyncStream`
- 考虑 [AsyncExtensions](https://github.com/sideeffect-io/AsyncExtensions) 包

### Debounce 示例

**Combine**：
```swift
$searchQuery
    .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
    .sink { [weak self] query in
        self?.performSearch(query)
    }
    .store(in: &cancellables)
```

**Swift Concurrency**：
```swift
func search(_ query: String) {
    currentSearchTask?.cancel()
    
    currentSearchTask = Task {
        do {
            try await Task.sleep(for: .milliseconds(500))
            performSearch(query)
        } catch {
            // 搜索被取消
        }
    }
}
```

**SwiftUI 集成**：
```swift
struct SearchView: View {
    @State private var searchQuery = ""
    @State private var searcher = ArticleSearcher()
    
    var body: some View {
        List(searcher.results) { result in
            Text(result.title)
        }
        .searchable(text: $searchQuery)
        .onChange(of: searchQuery) { _, newValue in
            searcher.search(newValue)
        }
    }
}
```

### 思维转变

**不要用 Combine 管道的思维思考**。许多问题在没有 FRP 时更简单：

```swift
// ❌ 寻找复杂 Combine 管道的 AsyncSequence 等价物
somePublisher
    .debounce(for: .seconds(0.5))
    .removeDuplicates()
    .flatMap { ... }
    .sink { ... }

// ✅ 用 Swift Concurrency 重新思考问题
Task {
    var lastValue: String?
    for await value in stream {
        guard value != lastValue else { continue }
        lastValue = value
        try await Task.sleep(for: .seconds(0.5))
        await process(value)
    }
}
```

**对于复杂操作符**：查看 [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) 包。

### ⚠️ 关键：Combine 的 Actor 隔离

**问题**：`sink` 闭包在编译时不尊重 actor 隔离。

```swift
@MainActor
final class NotificationObserver {
    private var cancellables: [AnyCancellable] = []
    
    init() {
        NotificationCenter.default.publisher(for: .someNotification)
            .sink { [weak self] _ in
                self?.handleNotification()  // ⚠️ 如果从后台发布可能崩溃
            }
            .store(in: &cancellables)
    }
    
    private func handleNotification() {
        // 期望在 main actor 上运行
    }
}
```

**为什么崩溃**：通知观察者在与发布者相同的线程上运行。如果从后台线程发布，`@MainActor` 方法在 main actor 之外被调用。

**解决方案**：

1. **迁移到 Swift Concurrency**（推荐）：
```swift
Task { [weak self] in
    for await _ in NotificationCenter.default.notifications(named: .someNotification) {
        await self?.handleNotification()  // ✅ 编译时安全
    }
}
```

2. **使用 Task 包装器**（临时）：
```swift
.sink { [weak self] _ in
    Task { @MainActor in
        self?.handleNotification()
    }
}
```

> **课程深入**：此主题在 [Lesson 12.9: Migrating away from Functional Reactive Programming like RxSwift or Combine](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 何时使用 AsyncAlgorithms

从 Combine 或 RxSwift 迁移时，你有多种处理异步模式的选项：

### 使用 AsyncAlgorithms 用于：

- **基于时间的操作**：debounce、throttle、计时器
- **组合多个异步序列**：merge、combineLatest、zip
- **多消费者场景**：AsyncChannel 用于背压
- **复杂操作符链**：Swift Concurrency 中的 FRP 类模式
- **特定操作符**：removeDuplicates、chunks、adjacentPairs、compacted

### 使用标准库用于：

- **桥接回调**：AsyncStream 足够
- **简单迭代**：for await in sequence
- **单值操作**：async/await
- **基本转换**：map、filter、contains

### 使用 SwiftUI 用于：

- **UI 观察**：@Observable 宏
- **状态管理**：@State、@Published 属性
- **用户交互**：onChange、onReceive 修饰符

> **参见**：[async-algorithms.md](async-algorithms.md) 获取详细的 AsyncAlgorithms 使用示例。

---

## 真实世界迁移示例

### 示例：带 AsyncAlgorithms 的 ArticleSearcher

**之前：手动 Debounce**

```swift
final class ArticleSearcher {
    @MainActor private(set) var results: [Article] = []
    private var currentSearchTask: Task<Void, Never>?

    func search(_ query: String) {
        currentSearchTask?.cancel()

        currentSearchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
                await MainActor.run {
                    self.results = []
                }
                self.results = await APIClient.searchArticles(query)
            } catch {
                // 搜索被取消
            }
        }
    }
}

// SwiftUI 集成
struct SearchView: View {
    @State private var searchQuery = ""
    @State private var searcher = ArticleSearcher()

    var body: some View {
        List(searcher.results) { result in
            Text(result.title)
        }
        .searchable(text: $searchQuery)
        .onChange(of: searchQuery) { _, newValue in
            searcher.search(newValue)
        }
    }
}
```

**之后：AsyncAlgorithms Debounce**

```swift
import AsyncAlgorithms

@Observable
final class ArticleSearcher {
    @MainActor private(set) var results: [Article] = []
    private var searchQueryContinuation: AsyncStream<String>.Continuation?

    private lazy var searchQueryStream: AsyncStream<String> = {
        AsyncStream { continuation in
            searchQueryContinuation = continuation
        }
    }()

    func search(_ query: String) {
        searchQueryContinuation?.yield(query)
    }

    func startDebouncedSearch() {
        Task { @MainActor in
            for await query in searchQueryStream.debounce(for: .milliseconds(500)) {
                self.results = []
                self.results = await APIClient.searchArticles(query)
            }
        }
    }
}

// SwiftUI 集成
struct SearchView: View {
    @State private var searchQuery = ""
    @State private var searcher = ArticleSearcher()

    var body: some View {
        List(searcher.results) { result in
            Text(result.title)
        }
        .searchable(text: $searchQuery)
        .onChange(of: searchQuery) { _, newValue in
            searcher.search(newValue)
        }
        .onAppear {
            searcher.startDebouncedSearch()
        }
    }
}
```

**使用 AsyncAlgorithms 的好处**：
- 新值到达时自动取消
- 背压处理（生产者尊重消费者速度）
- 比手动 Task.sleep 管理更干净的代码
- 无需手动跟踪和取消任务

### 示例：通知流迁移

**之前：Combine Publisher**

```swift
import Combine

final class NotificationObserver: ObservableObject {
    @Published private(set) var notifications: [AppNotification] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .compactMap { notification in
                notification.object as? AppNotification
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$notifications)
    }
}
```

**之后：标准库通知**

```swift
@Observable
final class NotificationObserver {
    @MainActor private(set) var notifications: [AppNotification] = []

    func startObserving() {
        Task {
            for await notification in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                if let appNotification = notification.object as? AppNotification {
                    notifications.append(appNotification)
                }
            }
        }
    }
}
```

**何时使用每种方法**：
- 标准系统通知使用 `notifications(named:)`
- 自定义多消费者通知场景使用 `AsyncChannel`
- UI 状态更新使用 `@Observable` + SwiftUI

### 示例：多源数据加载

**之前：Combine Merge**

```swift
import Combine

final class MultiSourceLoader: ObservableObject {
    @Published private(set) var items: [Item] = []
    private var cancellables = Set<AnyCancellable>()

    func loadFromAllSources() {
        let source1 = APIClient.fetchItems(from: .source1)
        let source2 = APIClient.fetchItems(from: .source2)
        let source3 = APIClient.fetchItems(from: .source3)

        Publishers.Merge3(source1, source2, source3)
            .flatMap { items in
                Just(items)
                    .delay(for: .seconds(0.1), scheduler: DispatchQueue.main)
            }
            .scan([]) { accumulated, new in
                accumulated + new
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$items)
            .store(in: &cancellables)
    }
}
```

**之后：AsyncAlgorithms Merge + TaskGroup**

```swift
import AsyncAlgorithms

@Observable
final class MultiSourceLoader {
    @MainActor private(set) var items: [Item] = []

    func loadFromAllSources() async {
        let sources = [
            APIClient.fetchItems(from: .source1),
            APIClient.fetchItems(from: .source2),
            APIClient.fetchItems(from: .source3)
        ]

        Task { @MainActor in
            for await stream in sources.map { $0.values }.merge() {
                for await newItems in stream {
                    self.items.append(contentsOf: newItems)
                }
            }
        }
    }

    // 替代方案：使用 TaskGroup 进行并行执行
    func loadFromAllSourcesParallel() async {
        await withTaskGroup(of: [Item].self) { group in
            group.addTask {
                await APIClient.fetchItems(from: .source1)
            }
            group.addTask {
                await APIClient.fetchItems(from: .source2)
            }
            group.addTask {
                await APIClient.fetchItems(from: .source3)
            }

            for await newItems in group {
                await MainActor.run {
                    self.items.append(contentsOf: newItems)
                }
            }
        }
    }
}
```

**关键区别**：
- Combine `merge()` 合并发布者；AsyncAlgorithms `merge()` 合并序列
- 对于并行执行，使用 `TaskGroup` 而非 `flatMap`
- 状态更新可以使用 `@MainActor` 而非 `.receive(on:)`

---

## 要避免的反模式

### ❌ 不要使用 Task.sleep 进行 Debounce

```swift
// ❌ 坏：无背压的手动 debounce
func search(_ query: String) {
    Task {
        try? await Task.sleep(for: .milliseconds(500))
        await performSearch(query)
    }
}
```

**问题**：每次按键派生新任务。如果用户快速输入，多个任务在 500ms 后同时执行，导致结果乱序和浪费 API 调用。

**解决方案**：使用 AsyncAlgorithms 的 `debounce()` 实现自动背压和取消。

### ❌ 不要手动组合值

```swift
// ❌ 坏：无操作符的手动组合
actor FormValidator {
    private var currentUsername: String = ""
    private var currentEmail: String = ""
    private var currentPassword: String = ""

    func updateUsername(_ username: String) {
        currentUsername = username
        checkForm()
    }

    func updateEmail(_ email: String) {
        currentEmail = email
        checkForm()
    }

    func updatePassword(_ password: String) {
        currentPassword = password
        checkForm()
    }

    private func checkForm() {
        let state = validate(
            username: currentUsername,
            email: currentEmail,
            password: currentPassword
        )
        // 更新 UI 或发出验证状态
    }
}
```

**问题**：
- 更多状态管理
- 每个字段的样板代码
- 更难添加新字段
- 无流组合好处

**解决方案**：使用 `combineLatest()` 实现更干净的、可组合的验证。

### ❌ 不要在没有 AsyncChannel 的情况下共享流

```swift
// ❌ 坏：多个消费者共享同一流
let stream = AsyncStream<Int> { continuation in
    for i in 1...10 {
        continuation.yield(i)
    }
    continuation.finish()
}

Task {
    for await value in stream {
        print("Consumer 1: \(value)")
    }
}

Task {
    for await value in stream {
        print("Consumer 2: \(value)")
    }
}
```

**问题**：值在消费者之间不可预测地分割。每个值只去一个消费者。

**解决方案**：使用 `AsyncChannel` 实现带背压的真正多消费者场景。

---

---

## 并发安全通知（iOS 26+）

Swift 6.2 引入了**类型化、线程安全的通知**。

### MainActorMessage

对于应该在 main actor 上投递的通知：

```swift
// 旧方式
NotificationCenter.default.addObserver(
    forName: UIApplication.didBecomeActiveNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.handleDidBecomeActive()  // ⚠️ 并发警告
}

// 新方式（iOS 26+）
token = NotificationCenter.default.addObserver(
    of: UIApplication.self,
    for: .didBecomeActive
) { [weak self] message in
    self?.handleDidBecomeActive()  // ✅ 无警告，保证 main actor
}
```

**关键区别**：观察者闭包保证在 `@MainActor` 上运行。

### AsyncMessage

对于在任意隔离上异步投递的通知：

```swift
struct RecentBuildsChangedMessage: NotificationCenter.AsyncMessage {
    typealias Subject = [RecentBuild]
    let recentBuilds: Subject
}

// 启用静态成员查找
extension NotificationCenter.MessageIdentifier 
where Self == NotificationCenter.BaseMessageIdentifier<RecentBuildsChangedMessage> {
    static var recentBuildsChanged: NotificationCenter.BaseMessageIdentifier<RecentBuildsChangedMessage> {
        .init()
    }
}
```

**发布**：
```swift
let builds = [RecentBuild(appName: "Stock Analyzer")]
let message = RecentBuildsChangedMessage(recentBuilds: builds)
NotificationCenter.default.post(message)
```

**观察**：
```swift
// 旧方式：不安全转换
NotificationCenter.default.addObserver(forName: .recentBuildsChanged, object: nil, queue: nil) { notification in
    guard let builds = notification.object as? [RecentBuild] else { return }
    handleBuilds(builds)
}

// 新方式：强类型，线程安全
token = NotificationCenter.default.addObserver(
    of: [RecentBuild].self,
    for: .recentBuildsChanged
) { message in
    handleBuilds(message.recentBuilds)  // ✅ 直接访问，无需转换
}
```

**好处**：
- 强类型（无 `Any` 转换）
- 编译时线程安全
- 清晰的隔离保证

> **课程深入**：此主题在 [Lesson 12.10: Migrating to concurrency-safe notifications](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 常见挑战

### "工作量太大"

分解它：
- 一次迁移一个包
- 使用 30 分钟每日会话
- 用小型 PR 创建检查点
- 庆祝增量进展

### "我的团队还没准备好"

从小处开始：
- 仅对新文件启用 Swift 6
- 新类型默认 `Sendable`
- 在团队会议中分享学习
- 在棘手迁移上结对编程

### "依赖项还没准备好"

选项：
- 先更新到最新版本
- 临时使用 `@preconcurrency`
- 为开源依赖贡献修复
- 用你自己的并发安全层包装第三方 API

### "我一直在兜圈子"

这就是"并发兔子洞"：
- 休息一下，稍后重新审视
- 临时禁用严格检查以在其他地方取得进展
- 一次专注于一个模块
- 不要试图一次修复所有东西

> **课程深入**：此主题在 [Lesson 12.11: Frequently Asked Questions (FAQ) around Swift 6 Migrations](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

---

## 代理常犯的错误

- **一刀切 `@MainActor`**：不要为了消除错误而对所有东西加 `@MainActor`。询问代码是否确实需要 main-actor 隔离。
- **将迁移与无关重构混合**：仅专注于并发更改。架构改进属于单独的 PR。
- **将 `@unchecked Sendable` 作为第一响应**：优先使用不可变值类型或 actor。将逃生舱保留给文档化的、临时例外。
- **在未检查活动功能集的情况下给出 Swift 6.2 之前的执行建议**：`nonisolated async` 行为取决于是否启用了 `NonisolatedNonsendingByDefault`。
- **在未先逐个功能迁移的情况下使用 Approachable Concurrency**：在完整捆绑包之前启用单独的 upcoming features 以了解每个更改的影响。

## 总结

迁移到 Swift 6 是一段旅程，不是冲刺：

1. **从小处开始**：找到依赖最少的隔离代码
2. **增量进行**：使用三个严格并发级别（Minimal → Targeted → Complete）
3. **使用工具**：利用 Xcode 重构和 `swift package migrate`
4. **创建检查点**：可以快速合并的小型、聚焦 PR
5. **保持积极**：并发兔子洞是真实的，但用正确的习惯可以管理
6. **不同思考**：放弃线程思维；信任编译器

结果是**编译时线程安全**、更可维护的代码和面向未来的代码库。

**额外资源**：
- [Approachable Concurrency Video](https://youtu.be/y_Qc8cT-O_g?si=y4C1XQDGtyIOLW81)
- [Migration Tooling Video](https://youtu.be/FK9XFxSWZPg?si=2z_ybn1t1YCJow5k)
- [Swift Concurrency Course](https://www.swiftconcurrencycourse.com) 获取深入迁移策略
