---
name: swift-concurrency-pro
description: 审查 Swift 代码的并发正确性、现代 API 用法以及常见的 async/await 陷阱。在读取、编写或审查 Swift 并发代码时使用。
license: MIT
metadata:
  author: Paul Hudson
  version: "1.0"
---

审查 Swift 并发代码的正确性、现代 API 用法以及是否遵循项目约定。只报告真实存在的问题——不要吹毛求疵或臆造问题。

审查流程：

1. 使用 `references/hotspots.md` 扫描已知危险模式，以确定优先检查的内容。
1. 使用 `references/new-features.md` 检查 Swift 6.2 的最新并发行为。
1. 使用 `references/actors.md` 验证 actor 使用中的可重入性和隔离正确性。
1. 使用 `references/structured.md` 确保在合适场景下优先使用结构化并发而非非结构化并发。
1. 使用 `references/unstructured.md` 检查非结构化任务使用的正确性。
1. 使用 `references/cancellation.md` 验证取消操作是否被正确处理。
1. 使用 `references/async-streams.md` 验证 async stream 和 continuation 的使用。
1. 使用 `references/bridging.md` 检查同步与异步世界之间的桥接代码。
1. 使用 `references/interop.md` 审查任何遗留并发迁移。
1. 使用 `references/bug-patterns.md` 与常见失败模式进行交叉核对。
1. 如果项目存在严格并发错误，使用 `references/diagnostics.md` 将诊断映射到修复方案。
1. 如果在审查测试，使用 `references/testing.md` 检查异步测试模式。

如果进行部分审查，只加载相关的参考文件。


## 核心说明

- 目标为 Swift 6.2 或更高版本，启用严格并发检查。
- 如果代码跨越多个 target 或包，在假设行为应当一致之前，先比较它们的并发构建设置。
- 优先使用结构化并发（任务组）而非非结构化并发（`Task {}`）。
- 对于新代码，优先使用 Swift 并发而非 Grand Central Dispatch。在低层代码、框架互操作或性能关键的同步工作中，队列和锁仍是正确的工具，此时 GCD 仍然可接受——不要将其标记为错误。
- 如果某个 API 同时提供 `async`/`await` 和基于闭包的变体，始终优先使用 `async`/`await`。
- 未经询问，不要引入第三方并发框架。
- 不要建议使用 `@unchecked Sendable` 来修复编译器错误。它只是压制了诊断而没有修复底层的竞态。优先使用 actor、值类型或 `sending` 参数。唯一合理的用途是用于具有内部锁定且可证明线程安全的类型。


## 输出格式

按文件组织发现的问题。对于每个问题：

1. 说明文件和相关的行号。
2. 指出被违反的规则。
3. 展示简短的前后对比代码修复。

跳过没有问题的文件。最后给出按优先级排序的总结，列出最具影响力的改动建议。

输出示例：

### DataLoader.swift

**第 18 行：Actor 可重入性——状态可能在 `await` 期间已发生变化。**

```swift
// 修改前
actor Cache {
    var items: [String: Data] = [:]

    func fetch(_ key: String) async throws -> Data {
        if items[key] == nil {
            items[key] = try await download(key)
        }
        return items[key]!
    }
}

// 修改后
actor Cache {
    var items: [String: Data] = [:]

    func fetch(_ key: String) async throws -> Data {
        if let existing = items[key] { return existing }
        let data = try await download(key)
        items[key] = data
        return data
    }
}
```

**第 34 行：使用 `withTaskGroup` 替代在循环中创建任务。**

```swift
// 修改前
for url in urls {
    Task { try await fetch(url) }
}

// 修改后
try await withThrowingTaskGroup(of: Data.self) { group in
    for url in urls {
        group.addTask { try await fetch(url) }
    }

    for try await result in group {
        process(result)
    }
}
```

### 总结

1. **正确性（高）：** 第 18 行的 actor 可重入 bug 可能导致重复下载和强制解包崩溃。
2. **结构（中）：** 第 34 行循环中的非结构化任务丢失了取消传播。

示例结束。


## 参考资料

- `references/hotspots.md` - 代码审查的 grep 目标：已知危险模式及每种模式的检查要点。
- `references/new-features.md` - Swift 6.2 中改变审查建议的变化：默认 actor 隔离、隔离遵循、调用方 actor 的 async 行为、`@concurrent`、`Task.immediate`、任务命名和优先级提升。
- `references/actors.md` - Actor 可重入性、共享状态标注、全局 actor 推断和隔离模式。
- `references/structured.md` - 任务组优于循环、丢弃式任务组、并发限制。
- `references/unstructured.md` - Task 与 Task.detached 的对比，`Task {}` 何时是代码坏味道。
- `references/cancellation.md` - 取消传播、协作式检查、错误的取消模式。
- `references/async-streams.md` - AsyncStream 工厂、continuation 生命周期、背压。
- `references/bridging.md` - 检查型 continuation、包装遗留 API、`@unchecked Sendable`。
- `references/interop.md` - 从 GCD、`Mutex`/锁、完成处理程序、代理和 Combine 迁移。
- `references/bug-patterns.md` - 常见并发失败模式及其修复方案。
- `references/diagnostics.md` - 严格并发编译器错误、协议遵循修复及可能的补救措施。
- `references/testing.md` - 使用 Swift Testing 的异步测试策略、竞态检测、避免基于时间的测试。
