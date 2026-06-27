# AsyncAlgorithms 包

使用本文件当：

- 你需要基于时间的操作符（debounce、throttle、计时器）。
- 你需要组合多个异步序列（merge、combineLatest、zip）。
- 你正在从 Combine 或 RxSwift 操作符迁移到 Swift Concurrency 等价物。

跳过本文件如果：

- 你需要用于回调或代理的基础 `AsyncStream` 桥接。使用 `async-sequences.md`。
- 你正在 `Task`、`async let` 或任务组之间做选择。使用 `tasks.md`。

跳转到：

- 快速开始
- 基于时间的操作符
- 组合操作符
- 多消费者场景
- Combine 迁移指南
- 最佳实践

---

## 快速开始

最常用的 5 个操作符：

```swift
import AsyncAlgorithms

// 1. 对快速输入进行 debounce
for await query in searchQueryStream.debounce(for: .milliseconds(500)) {
    await performSearch(query)
}

// 2. 对重复动作进行 throttle
for await _ in buttonClicks.throttle(for: .seconds(1)) {
    await performAction()
}

// 3. 合并多个独立流
for await message in chat1Messages.merge(chat2Messages) {
    display(message)
}

// 4. 组合依赖值
for await (username, email) in usernameStream.combineLatest(emailStream) {
    validateForm(username: username, email: email)
}

// 5. 配对操作 zip
for await (image, metadata) in imageStream.zip(metadataStream) {
    await cache(image: image, metadata: metadata)
}
```

> **参见**：[AsyncAlgorithms on GitHub](https://github.com/apple/swift-async-algorithms)

---

## 概述和安装

### 什么是 AsyncAlgorithms？

用基于时间的操作符、流组合工具和多消费者原语扩展 Swift 的 AsyncSequence。

**用于**：
- 基于时间的操作：debounce、throttle、计时器
- 组合流：merge、combineLatest、zip、chain
- 多消费者场景：AsyncChannel 用于背压
- 特定操作符：removeDuplicates、chunks、adjacentPairs、compacted

**使用标准库用于**：
- 桥接回调：AsyncStream
- 简单迭代：for await in sequence
- 单值操作：async/await

### 安装

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
]

targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
        ]
    )
]
```

导入：

```swift
import AsyncAlgorithms
```

---

## 基于时间的操作符

### debounce(for:tolerance:clock:)

在发出值之前等待不活动期。用于搜索字段等快速输入。

#### 示例：ArticleSearcher

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
```

**好处**：自动取消、背压、比手动 Task.sleep 更干净。

#### ❌ 反模式

```swift
// 坏：每次按键都派生新任务
func search(_ query: String) {
    Task {
        try? await Task.sleep(for: .milliseconds(500))
        await performSearch(query)
    }
}
```

**问题**：多个任务同时执行，导致结果乱序。

**解决方案**：使用 `debounce()` 实现自动背压。

---

### throttle(for:clock:reducing:)

每个间隔最多发出一个值。用于按钮点击等重复动作。

#### 示例：点赞按钮

```swift
import AsyncAlgorithms

struct LikeButton: View {
    @State private var tapStream = AsyncStream<Void> { continuation in
        // Continuation 外部存储
    }
    @State private var isLiked = false

    var body: some View {
        Button(action: {
            tapStream.continuation?.yield()
        }) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
        }
        .task {
            await handleThrottledTaps()
        }
    }

    private func handleThrottledTaps() async {
        for await _ in tapStream.throttle(for: .seconds(1)) {
            await toggleLike()
        }
    }

    private func toggleLike() async {
        isLiked.toggle()
        await APIClient.updateLikeStatus(isLiked: isLiked)
    }
}
```

#### 理解 reducing 参数

```swift
// .latest（默认）：保留最新值
for await value in events.throttle(for: .seconds(1)) {
    process(value)
}

// .oldest：保留第一个值
for await value in events.throttle(for: .seconds(1), reducing: .oldest) {
    process(value)
}

// 自定义：求和所有值
for await value in events.throttle(for: .seconds(1)) { $0 + $1 } {
    process(value)
}
```

---

### AsyncTimerSequence

按固定间隔发出值。用于定期刷新或倒计时。

#### 示例：Feed 刷新

```swift
import AsyncAlgorithms

@MainActor @Observable
final class FeedViewModel {
    private(set) var articles: [Article] = []
    private var refreshTask: Task<Void, Never>?

    func startAutoRefresh() {
        refreshTask = Task {
            for await _ in AsyncTimerSequence(interval: .seconds(30)) {
                await refreshFeed()
            }
        }
    }

    private func refreshFeed() async {
        articles = await APIClient.fetchLatestArticles()
    }
}
```

#### ❌ 反模式

```swift
// 坏：手动计时器实现
func startTimer() {
    Task {
        while !Task.isCancelled {
            performAction()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
```

**解决方案**：使用 `AsyncTimerSequence`。

---

## 组合操作符

### merge(_:...)

将序列合并为一个，按到达顺序发出。**稳定操作符 ✅**

用于不相互依赖的独立数据源。

#### 示例：多房间聊天

```swift
import AsyncAlgorithms

actor ChatManager {
    private var messageContinuations: [String: AsyncStream<ChatMessage>.Continuation] = [:]

    func getMessagesStream(roomID: String) -> AsyncStream<ChatMessage> {
        AsyncStream { continuation in
            messageContinuations[roomID] = continuation
        }
    }

    func receiveMessage(_ message: ChatMessage) {
        messageContinuations[message.roomID]?.yield(message)
    }

    func startMonitoring(rooms: [String]) -> AsyncStream<ChatMessage> {
        let streams = rooms.map { getMessagesStream(roomID: $0) }
        return streams.merge()
    }
}

// 用法
let manager = ChatManager()
let mergedMessages = await manager.startMonitoring(rooms: ["general", "random"])

for await message in mergedMessages {
    print("[\(message.roomID)] \(message.text)")
}
```

**行为**：值从任何源到达时发出。顺序按时间交错。取消传播到所有源。

---

### combineLatest(_:...)

组合序列，当任何源发出时发出元组。始终使用最新值。**稳定操作符 ✅**

用于需要同步的依赖值。

#### 示例：表单验证

```swift
import AsyncAlgorithms

struct SignupForm: View {
    @State private var usernameStream = AsyncStream<String> { /* ... */ }
    @State private var emailStream = AsyncStream<String> { /* ... */ }
    @State private var passwordStream = AsyncStream<String> { /* ... */ }
    @State private var formState = FormState.incomplete

    var body: some View {
        Form {
            TextField("Username", text: $username)
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
        }
        .task {
            await validateForm()
        }
    }

    private func validateForm() async {
        for await (username, email, password) in
                usernameStream.combineLatest(emailStream, passwordStream)
        {
            formState = await validate(
                username: username,
                email: email,
                password: password
            )
        }
    }
}
```

#### ❌ 反模式

```swift
// 坏：手动组合值
actor FormValidator {
    private var currentUsername: String = ""
    private var currentEmail: String = ""

    func updateUsername(_ username: String) {
        currentUsername = username
        checkForm()
    }
}
```

**解决方案**：使用 `combineLatest()`。

---

### zip(_:...)

通过按顺序配对元素来组合序列。**稳定操作符 ✅**

#### 示例：图像 + 元数据

```swift
import AsyncAlgorithms

struct ImageLoader {
    func loadImagesWithMetadata(urls: [URL]) async throws -> [LoadedImage] {
        let imageStream = AsyncThrowingStream<UIImage, Error> { continuation in
            Task {
                for url in urls {
                    let image = try await downloadImage(from: url)
                    continuation.yield(image)
                }
                continuation.finish()
            }
        }

        let metadataStream = AsyncThrowingStream<ImageMetadata, Error> { continuation in
            Task {
                for url in urls {
                    let metadata = try await fetchMetadata(for: url)
                    continuation.yield(metadata)
                }
                continuation.finish()
            }
        }

        var results: [LoadedImage] = []
        for try await (image, metadata) in imageStream.zip(metadataStream) {
            results.append(LoadedImage(image: image, metadata: metadata))
        }
        return results
    }
}
```

**行为**：当所有序列都发出时发出元组。保持顺序。最短序列完成时完成。

---

### chain(_:...)

按顺序连接序列。**稳定操作符 ✅**

#### 示例：分页加载

```swift
import AsyncAlgorithms

struct ArticlePaginator {
    func loadAllArticles() -> AsyncStream<[Article]> {
        AsyncStream { continuation in
            Task {
                var page = 1
                var hasMore = true
                while hasMore {
                    let articles = try await fetchPage(page: page)
                    continuation.yield(articles)
                    hasMore = articles.count == 20
                    page += 1
                }
                continuation.finish()
            }
        }
    }
}

// 用法：链式缓存 + 网络
for await articles in loadFromCacheStream().chain(loadFromNetworkStream()) {
    display(articles)
}
```

**行为**：在开始第二个序列之前发出第一个序列的所有值。

---

## 实用操作符

### removeDuplicates()

移除相邻重复项。**稳定操作符 ✅**

```swift
import AsyncAlgorithms

actor ChatHistory {
    private var messageStream = AsyncStream<ChatMessage> { /* ... */ }

    func getUniqueMessages() -> AsyncStream<ChatMessage> {
        messageStream.removeDuplicates()
    }
}
```

---

### chunks() 和 chunked()

将值收集为批次。**稳定操作符 ✅**

```swift
import AsyncAlgorithms

struct BatchProcessor {
    func processLargeDataset(dataStream: AsyncStream<DataItem>) async {
        for await batch in dataStream.chunks(count: 100) {
            await processBatch(batch)
        }
    }

    func chunkedByTime(dataStream: AsyncStream<DataItem>) async {
        for await batch in dataStream.chunked(by: .seconds(5)) {
            await processBatch(batch)
        }
    }
}
```

---

### compacted() 和 adjacentPairs()

```swift
import AsyncAlgorithms

// 移除 nil 值
for await value in optionalValuesStream.compacted() {
    process(value)
}

// 配对相邻元素
for await (previous, current) in valuesStream.adjacentPairs() {
    let difference = current - previous
}
```

---

## 多消费者场景

### AsyncChannel

带背压的 AsyncSequence。**稳定操作符 ✅**

用于带流控制的生产者-消费者模式。

#### 示例：消息队列

```swift
import AsyncAlgorithms

actor MessageQueue {
    private let channel = AsyncChannel<Message>()

    func getMessages() -> AsyncStream<Message> {
        channel
    }

    func enqueue(_ message: Message) async {
        await channel.send(message)
    }

    func startProcessing() {
        Task {
            for await message in channel {
                await process(message)
            }
        }
    }
}

// 多个生产者
let queue = MessageQueue()
Task { await queue.enqueue(Message(type: .userAction, content: "tap")) }
Task { await queue.enqueue(Message(type: .network, content: "data")) }
queue.startProcessing()
```

#### ❌ 反模式

```swift
// 坏：值不可预测地分割
let stream = AsyncStream<Int> { continuation in
    for i in 1...10 {
        continuation.yield(i)
    }
    continuation.finish()
}

Task { for await value in stream { print("Consumer 1: \(value)") } }
Task { for await value in stream { print("Consumer 2: \(value)") } }
```

**问题**：每个值只去一个消费者。

**解决方案**：在多消费者场景中使用 `AsyncChannel`。

---

### AsyncThrowingChannel

类似 AsyncChannel 但可以发出错误。**稳定操作符 ✅**

#### 示例：WebSocket

```swift
import AsyncAlgorithms

actor WebSocketConnection {
    private let channel = AsyncThrowingChannel<WebSocketMessage, Error>()

    func getMessages() -> AsyncThrowingStream<WebSocketMessage, Error> {
        channel
    }

    func receiveMessage(_ message: WebSocketMessage) async {
        await channel.send(message)
    }

    func reportError(_ error: Error) async {
        await channel.finish(throwing: error)
    }
}

// 用法
do {
    for await message in connection.getMessages() {
        handle(message)
    }
} catch {
    print("WebSocket error: \(error)")
}
```

---

## Combine 迁移指南

### 操作符映射表

| Combine | AsyncAlgorithms | 状态 | 替代方案 |
|---------|-----------------|---------|-------------|
| `.debounce()` | `debounce()` | ✅ 稳定 | - |
| `.throttle()` | `throttle()` | ✅ 稳定 | - |
| `.merge()` | `merge()` | ✅ 稳定 | - |
| `.combineLatest()` | `combineLatest()` | ✅ 稳定 | - |
| `.zip()` | `zip()` | ✅ 稳定 | - |
| `.concat()` | `chain()` | ✅ 稳定 | - |
| `.removeDuplicates()` | `removeDuplicates()` | ✅ 稳定 | - |
| `.timer()` | `AsyncTimerSequence` | ✅ 稳定 | - |
| `.share()` | - | - | `AsyncChannel` |
| `.flatMap()` | - | - | `TaskGroup` |
| `.receive(on:)` | - | - | `Task` / `@MainActor` |
| `.eraseToAnyPublisher()` | - | - | `any AsyncSequence` |

---

### 迁移示例

#### 示例 1：ArticleSearcher

**之前：Combine**

```swift
import Combine

final class ArticleSearcher: ObservableObject {
    @Published private(set) var results: [Article] = []
    @Published var searchQuery = ""

    init() {
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .flatMap { query in
                APIClient.searchArticles(query)
                    .catch { _ in Just([]) }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$results)
    }
}
```

**之后：AsyncAlgorithms**

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
            for await query in searchQueryStream
                .debounce(for: .milliseconds(500))
                .removeDuplicates()
            {
                do {
                    self.results = try await APIClient.searchArticles(query)
                } catch {
                    self.results = []
                }
            }
        }
    }
}
```

**好处**：更简单的错误处理、无 cancellables、自动取消。

---

#### 示例 2：多源加载

**之前：Combine Merge**

```swift
import Combine

final class ArticleLoader: ObservableObject {
    @Published private(set) var items: [Item] = []

    func loadAllSources() {
        let source1 = APIClient.fetchItems(from: .source1)
        let source2 = APIClient.fetchItems(from: .source2)

        Publishers.Merge(source1, source2)
            .scan([]) { accumulated, new in
                accumulated + new
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$items)
    }
}
```

**之后：TaskGroup**

```swift
import AsyncAlgorithms

@Observable
final class ArticleLoader {
    @MainActor private(set) var items: [Item] = []

    func loadAllSourcesParallel() async {
        await withTaskGroup(of: [Item].self) { group in
            group.addTask {
                await APIClient.fetchItems(from: .source1)
            }
            group.addTask {
                await APIClient.fetchItems(from: .source2)
            }

            for await newItems in group {
                items.append(contentsOf: newItems)
            }
        }
    }
}
```

**关键区别**：对于并行执行，使用 `TaskGroup` 而非 `flatMap`。

---

#### 示例 3：表单验证

**之前：Combine**

```swift
import Combine

final class FormValidator: ObservableObject {
    @Published var username = ""
    @Published var email = ""

    @Published private(set) var formState: FormState = .incomplete

    init() {
        Publishers.CombineLatest2($username, $email)
            .map { username, email in
                validate(username: username, email: email)
            }
            .assign(to: &$formState)
    }
}
```

**之后：AsyncAlgorithms 或 async let**

```swift
import AsyncAlgorithms

@Observable
final class FormValidator {
    var username = ""
    var email = ""

    @MainActor private(set) var formState: FormState = .incomplete

    // 选项 1：combineLatest 用于基于流的验证
    func startStreamValidation() {
        Task { @MainActor in
            for await (username, email) in
                    usernameStream.combineLatest(emailStream)
            {
                self.formState = validate(
                    username: username,
                    email: email
                )
            }
        }
    }

    // 选项 2：async let 用于简单验证
    func validateForm() async {
        let (username, email) = await (username, email)
        formState = validate(
            username: username,
            email: email
        )
    }
}
```

**选择**：
- `combineLatest()`：字段变化时的持续验证
- `async let`：所有值可用时的一次性验证

---

## 代理常犯的错误

- **用 `Task.sleep` 手动 debounce**：这会创建多个并发任务，并可能导致结果乱序。改用 AsyncAlgorithms 的基于流的 `debounce(for:)` 操作符。
- **在多个消费者之间共享 `AsyncStream`**：值在消费者之间不可预测地分割。使用 `AsyncChannel` 实现带背压的多消费者场景。注意：`AsyncChannel` 是点对点的，不像 Combine 的 `.share()` 那样广播。
- **寻找 `.flatMap` 等价物**：使用 `TaskGroup` 实现扇出；其语义不同于 Combine/Rx 的 `flatMap`。
- **寻找 `.receive(on:)` 等价物**：改用 `@MainActor` 或 `Task` 上下文进行隔离。

## 最佳实践

1. **对快速输入使用基于时间的操作符**：debounce() 用于搜索，throttle() 用于按钮
2. **用 merge/combineLatest 组合流**，而非手动状态管理
3. **对带背压的多消费者场景使用 AsyncChannel**
4. **跨隔离边界使用操作符时确保 Sendable 一致性**
5. **利用取消**——Task 取消通过所有操作符传播
6. **选择正确工具**：AsyncAlgorithms 用于复杂流，AsyncStream 用于桥接回调
7. **避免手动 sleep 循环**——改用 AsyncTimerSequence

---

## 进一步学习

- [AsyncAlgorithms 文档](https://github.com/apple/swift-async-algorithms)
- [Combine 迁移指南](migration.md)
- [异步序列](async-sequences.md)
- [任务](tasks.md)——任务组和结构化并发
