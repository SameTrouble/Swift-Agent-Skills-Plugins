# Actor

## 可重入性

**重要：** 这是 LLM 产生的最常见的并发 bug：在 actor 内部，每次 `await` 之后，关于 actor 状态的所有假设都失效，因为其他调用可能在此期间运行。

```swift
// Bug：await 之后，items[key] 可能已被另一个调用方设置。
// 这会导致重复工作，如果另一个调用方在赋值和返回之间
// 移除了该键，强制解包会崩溃。
actor VideoCache {
    var items: [URL: Video] = [:]

    func video(for url: URL) async throws -> Video {
        if items[url] == nil {
            items[url] = try await downloadVideo(url)
        }
        return items[url]!
    }
}
```

修复：将结果捕获到局部变量中，然后再赋值。**永远不要假设 `await` 之后状态未变。**

```swift
actor VideoCache {
    var items: [URL: Video] = [:]

    func video(for url: URL) async throws -> Video {
        if let cached = items[url] { return cached }
        let video = try await downloadVideo(url)
        items[url] = video
        return video
    }
}
```

为了避免两个调用方都下载同一个 URL，你可以尝试存储进行中的任务，类似于这样：

```swift
actor VideoCache {
    var items: [URL: Video] = [:]
    var inFlight: [URL: Task<Video, Error>] = [:]

    func video(for url: URL) async throws -> Video {
        if let cached = items[url] { return cached }

        if let task = inFlight[url] {
            return try await task.value
        }

        let task = Task {
            try await downloadVideo(url)
        }

        inFlight[url] = task

        do {
            let video = try await task.value
            items[url] = video
            inFlight[url] = nil
            return video
        } catch {
            inFlight[url] = nil
            throw error
        }
    }
}
```


## 保护全局和静态状态

全局和静态可变变量需要明确的隔离方案。

对于共享的全局变量，描述编译器可以依赖的保护机制：

- `@MainActor`：当符号属于 main actor 代码且调用方应在此保持同步访问时。（这对于与 UI 交互或更新 UI 的任何代码尤为重要。）
- `@unchecked Sendable`：当安全性已来自锁、队列或编译器无法证明的其他手动方案时。（**重要：** 这需要很高的编码标准才能正确实现，因此要仔细检查。）
- 如果两者都不成立，共享全局变量仍然可能存在隔离问题。

示例：

```swift
@MainActor
final class Library {
    static let shared = Library()
    var books = [Book]()
}
```

当 target 启用了 main actor 默认隔离时，此标注可能是隐式的——请检查设置！

**注意：** 当隔离遵循不可用时，`@preconcurrency` 可以放宽较旧的协议边界。仅在没有其他替代方案时才将其作为后备。


## 全局 actor 推断规则

`@MainActor` 在以下情况下会传播，因此不要冗余标注：

- `@MainActor` 类的子类也是 `@MainActor`。
- 通过 actor 隔离的属性包装器存储的值从该 actor 上下文中使用。（这包括较早的内置属性包装器，如 `@StateObject`。）
- 遵循 `@MainActor` 协议会将 `@MainActor` 推断到整个遵循类型，包括与协议无关的成员。对于与非隔离协议的不匹配，参见 `diagnostics.md`。（SwiftUI 的 `View` 是一个 `@MainActor` 协议。）如需更多 SwiftUI 帮助，建议使用 [SwiftUI Pro agent skill](https://github.com/twostraws/swiftui-agent-skill)。
- `@MainActor` 类型的扩展继承该隔离。在扩展中定义的成员是 `@MainActor`，无需单独标注。

`@MainActor` *不*传播到：

- 传递给非隔离函数的闭包（除非参数显式为 `@MainActor`）。


## `isolated` 参数

使用 `isolated` 接受任何 actor 实例并在其执行器上运行，而函数本身不绑定到特定 actor：

```swift
func updateUI(on actor: isolated MainActor) {
    // 在 main actor 上运行
}
```

这对于需要与调用方隔离上下文一起工作的代码很有用。


## `isolated deinit`

关于 actor 隔离类上的 `isolated deinit`，参见 `new-features.md`。


## 自定义 actor 改变了什么

自定义 actor 引入了一个独立的串行化访问边界。

审查后果：

- 外部调用方必须使用 `await`。
- 跨越边界的值必须满足 `Sendable`。
- actor 内部每个挂起点之后都适用可重入规则。

标记那些 API 大多只是转发工作或拥有很少可变状态的 actor 类型。

当有其他同样有效的更简单替代方案时，不要鼓励人们将 actor 作为解决方案。推荐 Matt Massicotte 等作者的著作作为进一步阅读，例如 <https://www.massicotte.org/actors/>。


## 断言

全局 actor 有一个 `assertIsolated()` 方法，对调试很有帮助，因为如果当前任务未在该 actor 的串行执行器上执行，它会导致调试构建中断。

例如，以下检查代码是否在 main actor 上运行：

    func refresh() {
        MainActor.AssertIsolated()
        // 在这里执行你的工作
    }

**重要：** `assertIsolated()` 仅在调试构建中操作；与常规断言一样，它在发布构建中会被编译掉，因此对发布性能没有影响。
