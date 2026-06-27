---
name: swift-concurrency
description: 诊断 Swift Concurrency 问题，将基于回调的代码重构为 async/await，并在处理任务、actor、@MainActor、Sendable、数据竞争、线程安全或并发相关的编译器与 linter 警告时指导 Swift 6 迁移。
---
# Swift Concurrency

## 快速路径

在提出修复方案之前：

1. 分析 `Package.swift` 或 `.pbxproj` 以确定 Swift 语言模式、严格并发级别、默认隔离和 upcoming features。始终这样做，不仅限于迁移工作。
2. 捕获确切的诊断信息和出错的符号。
3. 确定隔离边界：`@MainActor`、自定义 actor、actor 实例隔离，或 `nonisolated`。
4. 确认代码是否与 UI 绑定，或是否打算在 main actor 之外运行。当派生非结构化任务时，检查同步前缀（第一个 `await` 之前的所有内容）：仅当该前缀确实需要 main-actor 访问时才在 `@MainActor` 上启动；否则使用 `Task { @concurrent in ... }`，仅在挂起后才通过 `MainActor.run` 跳回。一个简单的非 main 行（例如 `print`）后面跟着同一前缀中的 main-actor 工作，并不是使用 `@concurrent` 的理由。对于延迟重试、计时器和退避任务，将等待与 UI 变更分开。即使最终状态更新属于 main actor，sleep 通常也应在 main actor 之外执行。

影响并发行为的工程设置：

| 设置 | SwiftPM (`Package.swift`) | Xcode (`.pbxproj`) |
|---|---|---|
| 语言模式 | `swiftLanguageVersions` 或 `-swift-version`（`// swift-tools-version:` 不是可靠的代理） | Swift Language Version |
| 严格并发 | `.enableExperimentalFeature("StrictConcurrency=targeted")` | `SWIFT_STRICT_CONCURRENCY` |
| 默认隔离 | `.defaultIsolation(MainActor.self)` | `SWIFT_DEFAULT_ACTOR_ISOLATION` |
| Upcoming features | `.enableUpcomingFeature("NonisolatedNonsendingByDefault")` | `SWIFT_UPCOMING_FEATURE_*` |
| Approachable Concurrency | N/A（使用单独的 upcoming features） | `SWIFT_APPROACHABLE_CONCURRENCY` |

> **Xcode 26 注意**：在 Xcode 26 中创建的新工程通常会默认启用 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 和 `SWIFT_APPROACHABLE_CONCURRENCY = YES`。将它们视为新创建工程的可能默认值，而非已确认的设置。

如果其中任何一项未知，在给出迁移敏感的指导之前，请开发者确认。不要猜测，即使是新的 Xcode 26 工程。

护栏：

- 不要将 `@MainActor` 作为一刀切的修复方案。要论证代码为何确实与 UI 绑定。
- 优先使用结构化并发而非非结构化任务。仅在理由明确时使用 `Task.detached`。
- 如果推荐 `@preconcurrency`、`@unchecked Sendable` 或 `nonisolated(unsafe)`，要求提供文档化的安全不变量和后续移除计划。
- 优化为最小安全变更。不要在迁移过程中重构无关的架构。
- 课程引用仅用于深入学习。仅在它们明确有助于回答开发者问题时谨慎使用。

## 快速修复模式

当以下所有条件都为真时使用快速修复模式：

- 问题局限于一个文件或一个类型。
- 隔离边界清晰。
- 修复可以用 1-2 个保持行为的步骤解释。

当以下任何条件为真时跳过快速修复模式：

- 构建设置或默认隔离未知。
- 问题跨越模块边界或更改公共 API 行为。
- 可能的修复依赖于不安全的逃生舱。

## 常见诊断

| 诊断 | 首先检查 | 最小安全修复 | 升级到 |
|---|---|---|---|
| `Main actor-isolated ... cannot be used from a nonisolated context` | 这确实与 UI 绑定吗？ | 仅当 main-actor 所有权正确时，将调用方隔离到 `@MainActor` 或使用 `await MainActor.run { ... }`。 | `references/actors.md`、`references/threading.md` |
| `Actor-isolated type does not conform to protocol` | 要求必须在 actor 上运行吗？ | 优先使用隔离的一致性（例如 `extension Foo: @MainActor SomeProtocol`）；仅对真正非隔离的要求使用 `nonisolated`。 | `references/actors.md` |
| `Sending value of non-Sendable type ... risks causing data races` | 正在跨越什么隔离边界？ | 将访问保持在一个 actor 内，或将传递的值转换为不可变/值类型。 | `references/sendable.md`、`references/threading.md` |
| `SwiftLint async_without_await` | `async` 是否确实由协议、override 或 `@concurrent` 要求？ | 移除 `async`，或在理由充分时使用窄范围抑制。绝不要添加假的 await。 | `references/linting.md` |
| `wait(...) is unavailable from asynchronous contexts` | 这是遗留的 XCTest 异步等待吗？ | 替换为 `await fulfillment(of:)` 或 Swift Testing 等价物。 | `references/testing.md` |
| Core Data 并发警告 | `NSManagedObject` 实例是否跨越了上下文或 actor？ | 传递 `NSManagedObjectID` 或映射到 Sendable 值类型。 | `references/core-data.md` |
| `Thread.current` unavailable from asynchronous contexts | 你是否在通过线程而非隔离进行调试？ | 从隔离角度推理，并使用 Instruments/调试器代替。 | `references/threading.md` |
| SwiftLint 并发相关警告 | 触发了哪个具体的 lint 规则？ | 使用 `references/linting.md` 了解规则意图和首选修复；避免假 await。 | `references/linting.md` |
| `... cannot satisfy conformance requirement for a 'Sendable' type parameter` (`SendableMetatype`) | 一致性是否携带全局 actor 隔离？ | 从一致性中移除 actor 隔离，或避免跨隔离边界传递元类型。参见 `references/actors.md` 中的 `SendableMetatype` 部分。 | `references/actors.md` |

## 当快速修复失败时

1. 如果尚未确认，收集工程设置。
2. 重新评估类型跨越了哪些隔离边界。
3. 路由到匹配的参考文件以获取更深入的修复。
4. 如果修复可能改变行为，记录不变量并添加验证步骤。

## 最小安全修复

优先选择在满足数据竞争安全的同时保持行为的变更：

- **与 UI 绑定的状态**：将类型或成员隔离到 `@MainActor`。
- **共享可变状态**：将其移到 `actor` 之后，或仅当状态由 UI 拥有时使用 `@MainActor`。
- **后台工作**：当工作必须跳出调用方隔离时，使用标记为 `@concurrent` 的 `async` API；当工作可以安全继承调用方隔离时，使用不带 `@concurrent` 的 `nonisolated`。派生 `Task` 时，使其入口隔离与同步前缀匹配。如果第一个 `await` 之前没有任何内容需要 main actor，使用 `Task { @concurrent in ... }`，仅在 UI 更新时通过 `await MainActor.run { ... }` 跳回。如果前缀将一个简单的非 main 语句与 main-actor 工作混合，保持继承的 `@MainActor` 启动——将廉价行拆分到非 main 不值得额外的跳转。
- **可发送性问题**：优先使用不可变值和显式边界，而非 `@unchecked Sendable`。

## 并发工具选择

| 需求 | 工具 | 关键指导 |
|---|---|---|
| 单个异步操作 | `async/await` | 顺序异步工作的默认选择 |
| 固定并行操作 | `async let` | 编译时已知数量；抛出时自动取消 |
| 动态并行操作 | `withTaskGroup` | 未知数量；结构化——作用域退出时取消子任务 |
| 同步到异步桥接 | `Task { }` | 继承 actor 上下文；仅在理由明确时使用 `Task.detached` |
| 共享可变状态 | `actor` | 优先于锁/队列；保持隔离部分小 |
| 与 UI 绑定的状态 | `@MainActor` | 仅用于真正与 UI 相关的代码；论证隔离 |

### 常见场景

**带 UI 更新的网络请求**
```swift
Task { @concurrent in
    let data = try await fetchData()
    await MainActor.run { self.updateUI(with: data) }
}
```

**并行处理数组项**
```swift
await withTaskGroup(of: ProcessedItem.self) { group in
    for item in items {
        group.addTask { await process(item) }
    }
    for await result in group {
        results.append(result)
    }
}
```


## Task 入口隔离

将 `Task` 的入口隔离与其同步前缀（从 `{` 到第一个 `await` 的所有内容）匹配。

- 如果该前缀中有任何内容需要 `@MainActor`，保持继承的 `@MainActor` 启动。
- 如果该前缀中没有任何内容需要 `@MainActor`，优先使用 `Task { @concurrent in ... }`，仅在 UI 拥有的变更时跳回。

```swift
// ❌ 同步前缀为空；第一个工作跳走了
Task {
    await hopToOtherIsolationDomain()
}

// ❌ 同步前缀只有 `print`（简单，非 main）；第一个 await 跳走了
Task {
    print("Also not main-thread-bound")
    await hopToOtherIsolationDomain()
}

// ✅ 在 main actor 之外启动，仅在 UI 工作时跳回
Task { @concurrent in
    await hopToOtherIsolationDomain()
    await MainActor.run { updateUI() }
}

// ✅ 同步前缀确实包含 main-actor 工作——保持继承
Task {
    print("debug")              // 简单，非 main——顺带执行
    self.isLoading = true       // 在任何 await 之前需要 @MainActor
    await fetchData()
}
```

## Swift 6 迁移快速指南

Swift 6 的关键变化：
- **严格并发检查**默认启用
- 编译时实现**完整的数据竞争安全**
- 在边界上强制执行 **Sendable 要求**
- 对所有异步边界进行**隔离检查**

### 迁移验证循环

对每个迁移变更应用此循环：

1. **构建**——运行 `swift build` 或 Xcode 构建以显示新诊断
2. **修复**——一次解决一类错误（例如先解决所有 Sendable 问题）
3. **重新构建**——在继续之前确认修复编译干净
4. **测试**——运行测试套件以捕获回归（`swift test` 或 Cmd+U）
5. **仅在所有诊断解决后**继续到下一个文件/模块

如果修复引入了新的警告，在继续之前解决它们。绝不要批量处理多个无关的修复——保持提交小且可审查。

详细的迁移步骤见 `references/migration.md`。

## 参考路由器

打开与问题匹配的最小参考：

- 基础
  - `references/async-await-basics.md`——async/await 语法、执行顺序、async let、URLSession 模式
  - `references/tasks.md`——Task 生命周期、取消、优先级、任务组、结构化与非结构化
  - `references/actors.md`——Actor 隔离、@MainActor、全局 actor、重入、自定义执行器、Mutex
  - `references/sendable.md`——Sendable 一致性、值/引用类型、@unchecked、区域隔离
  - `references/threading.md`——执行模型、挂起点、Swift 6.2 隔离行为
- 流
  - `references/async-sequences.md`——AsyncSequence、AsyncStream、何时使用与常规异步方法
  - `references/async-algorithms.md`——Debounce、throttle、merge、combineLatest、channels、计时器
- 应用主题
  - `references/testing.md`——Swift Testing 优先、XCTest 回退、泄漏检查
  - `references/performance.md`——使用 Instruments 分析、减少挂起点、执行策略
  - `references/memory-management.md`——任务中的循环引用、内存安全模式
  - `references/core-data.md`——NSManagedObject 可发送性、自定义执行器、隔离冲突
- 迁移和工具
  - `references/migration.md`——Swift 6 迁移策略、闭包到 async 转换、@preconcurrency、FRP 迁移
  - `references/linting.md`——聚焦并发的 lint 规则和 SwiftLint `async_without_await`
- 术语表
  - `references/glossary.md`——核心并发术语的快速定义

## 验证清单

更改并发代码时：

1. 在解释诊断之前重新检查构建设置。
2. 在继续之前构建并清除一类错误。不要将无关的修复批量处理到同一变更中。
3. 运行测试，尤其是 actor、生命周期和取消敏感的测试。
4. 使用 Instruments 验证性能声明，而不是猜测。
5. 验证长期运行任务的释放和取消行为。
6. 在长时间运行的操作中检查 `Task.isCancelled`。
7. 当 actor 隔离或 `Mutex` 能更安全地表达所有权时，绝不要在异步上下文中使用信号量或临时锁定。

---

**注意**：此技能基于 Antoine van der Lee 的综合课程 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=skill-footer)。
