# Swift 6.2 并发

本文件用于记录对审查建议有重大影响的最新并发变化。

## 控制默认 actor 隔离推断

Swift 6.2 可以让模块默认采用 main actor 隔离。对于许多应用 target 而言，这非常实用：大量代码可以保持有效的单线程，直到项目主动选择其他方式。

当此模式开启时，大多数声明表现得就像它们被标记为 `@MainActor` 一样，除非你主动退出。这消除了 UI 密集型代码的并发摩擦，让团队可以推迟并发决策，直到真正需要并行时。

审查影响：

- 这是针对每个模块的设置。相邻模块和依赖可以使用不同的默认值。
- 缺少的 `@MainActor` 标注可能因为 target 配置而仍然隐式存在。
- 此模式对于已经在 main actor 上花费大部分时间的应用代码特别有吸引力。
- 网络和其他天然异步的 API 仍然正常工作。挂起的 I/O 并不意味着调用方阻塞了 main actor。
- 许多代码库已经将"在证明不需要之前都设为 `@MainActor`"作为实际默认值。Swift 6.2 将其变成了一个显式工具。
- 这是更大的数据竞争安全性易用性推进的一部分，而非独立存在。
- 如果某个 target 主要是 UI 和生命周期代码，此模式是一个认真的选择，而非边缘情况。

**重要：** 有些用户认为将应用 target 设为 `@MainActor` 意味着网络也会在 main actor 上运行，这并不正确——那是外部模块，所以它像往常一样在其他地方运行。


## 全局 actor 隔离的遵循

Swift 6.2 允许遵循存在于全局 actor 上，而不是假装需求可以从任何地方调用。

```swift
@MainActor
class User: @MainActor Equatable {
    var id: UUID
    var name: String

    init(name: String) {
        self.id = UUID()
        self.name = name
    }

    static func ==(lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
```

审查影响：

- `@MainActor` 类型可以满足协议，同时保持遵循与 actor 绑定。
- 编译器会拒绝从错误的隔离域使用该遵循。
- 如果协议需求确实必须可以从任何地方调用，此模型就不合适。


## 默认在调用方的 actor 上运行 `nonisolated` async 函数

Swift 6.2 改变了普通 async 方法的思维模型。`nonisolated` async 函数现在会留在调用方的 actor 上，除非有东西显式地将其卸载到其他地方。

```swift
struct Measurements {
    func fetchLatest() async throws -> [Double] {
        let url = URL(string: "https://hws.dev/readings.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Double].self, from: data)
    }
}

@MainActor
struct WeatherStation {
    let measurements = Measurements()

    func getAverageTemperature() async throws -> Double {
        let readings = try await measurements.fetchLatest()
        return readings.reduce(0, +) / Double(readings.count)
    }
}
```

在 Swift 6.2 之前，对 `measurements.fetchLatest()` 的调用会自动离开调用方的 actor。在 Swift 6.2 及更高版本中，除非你另有指定，它会留在调用方的 actor 上。

审查影响：

- 自有的辅助方法上的普通 async 不再意味着后台执行。
- 这消除了整类"sending 风险导致数据竞争"诊断。
- 如果确实需要旧行为，函数需要显式卸载。


## 使用 `@concurrent` 卸载工作

`@concurrent` 是应该离开调用方 actor 并在并发池上运行的代码的选择加入工具。

```swift
nonisolated struct Measurements {
    @concurrent
    func analyzeReadings(_ readings: [Double]) async -> AnalysisResult { ... }
}

let result = await Measurements().analyzeReadings(readings)
```

审查影响：

- 将其用于 CPU 密集型工作，如解析、图像处理、压缩或大型变换。
- 不要建议用于普通的异步 I/O，它已经会自然挂起。
- 如果一个函数是 `nonisolated` 但仍期望"在后台"运行，检查 `@concurrent` 是否是缺失的部分。


## 从调用方上下文同步启动任务

`Task.immediate` 在调用方已在目标执行器上时立即开始运行，而不是仅仅将任务排队等待稍后执行。

```swift
print("Starting")

Task {
    print("In Task")
}

Task.immediate {
    print("In Immediate Task")
}

print("Done")
try await Task.sleep(for: .seconds(0.1))
```

该顺序意味着 `Task.immediate` 可以在调用方继续之前执行初始同步工作，直到第一个挂起点。

审查影响：

- 仅当立即启动本身就是目的时才使用它。
- 在第一段同步执行之后，它仍然是一个非结构化任务。
- 任务组也新增了 `addImmediateTask()` 和 `addImmediateTaskUnlessCancelled()`，为子任务提供相同的立即启动行为。


## 隔离的 deinit

默认情况下，actor 隔离类上的析构器*不*是隔离的——即使类本身是 `@MainActor`，它也在 actor 之外运行。这意味着从 `deinit` 访问类的隔离状态是编译错误。

将析构器标记为 `isolated` 以在类的 actor 上运行它：

```swift
@MainActor
class Session {
    let user: User

    init(user: User) {
        self.user = user
        user.isLoggedIn = true
    }

    isolated deinit {
        // 在 main actor 上运行，因此访问 user 是安全的。
        user.isLoggedIn = false
    }
}
```

如果没有 `isolated`，deinit 将无法编译，因为 `user` 是 main actor 隔离的，而析构器不是。当清理逻辑需要触及受 actor 保护的状态时使用此特性。


## 任务优先级提升 API

Swift 6.2 直接暴露了优先级提升。任务可以观察提升，代码可以在需要时请求更高的优先级。

```swift
let newsFetcher = Task(priority: .medium) {
    try await withTaskPriorityEscalationHandler {
        let url = URL(string: "https://hws.dev/messages.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    } onPriorityEscalated: { oldPriority, newPriority in
        print("Priority has been escalated to \(newPriority)")
    }
}

newsFetcher.escalatePriority(to: .high)
```

审查影响：

- 当更高优先级的任务等待较低优先级的工作时，优先级提升通常是自动的。
- 手动提升存在，但大多数代码应该将其留给运行时。
- 如果代码库显式处理提升，那是高级协调而非日常任务使用。


## 任务命名

Swift 6.2 的任务和任务组子任务可以携带名称，当某个任务行为异常时，这对于识别它很有用。

```swift
let task = Task(name: "MyTask") {
    print("Current task name: \(Task.name ?? "Unknown")")
}
```

任务组也支持命名：

```swift
let stories = await withTaskGroup { group in
    for i in 1...5 {
        group.addTask(name: "Stories \(i)") {
            do {
                let url = URL(string: "https://hws.dev/news-\(i).json")!
                let (data, _) = try await URLSession.shared.data(from: url)
                return try JSONDecoder().decode([NewsStory].self, from: data)
            } catch {
                print("Loading \(Task.name ?? "Unknown") failed.")
                return []
            }
        }
    }

    var allStories = [NewsStory]()

    for await stories in group {
        allStories.append(contentsOf: stories)
    }

    return allStories
}
```

审查影响：

- 任务名称是调试辅助工具，而非正确性功能。
- 当日志、追踪或故障诊断很重要时，值得保留。
