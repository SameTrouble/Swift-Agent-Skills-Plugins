## Approachable Concurrency（Swift 6.2）—— 项目模式快速指南

当项目已启用 Swift 6.2 approachable concurrency 设置（默认 actor 隔离 / 默认 main actor）时使用本参考。

## 检测该模式

在 Xcode 构建设置的 "Swift Compiler - Concurrency" 下检查：
- Swift 语言版本（必须为 6.2+）。
- 默认 actor 隔离 / 默认 Main Actor。
- 严格并发检查级别（Complete/Targeted/Minimal）。

对于 SwiftPM，检查 Package.swift 的 swiftSettings 中的相同标志。

## 预期的行为变化

- async 函数默认留在调用方的 actor 上；除非实现选择这样做，否则它们不会跳转到全局并发执行器。
- 默认 main actor 减少了绑定 UI 的代码和全局状态的数据竞争错误，因为可变状态被隐式保护。
- 协议一致性可以被隔离（例如 `extension Foo: @MainActor Bar`）。

## 在此模式下如何应用修复

- 优先使用最少的标注；当代码绑定 UI 时，让默认 main actor 完成工作。
- 使用隔离的一致性，而不是强制使用 `nonisolated` 的变通方法。
- 将全局或共享可变状态保留在 main actor 上，除非有明确的性能需求将其卸载。

## 何时选择退出或卸载工作

- 在必须运行于并发池的 async 函数上使用 `@concurrent`。
- 仅当类型或成员真正线程安全且在 main actor 之外使用时，才将其设为 `nonisolated`。
- 当值跨 actor 或跨 Task 时，继续遵守 Sendable 边界。

## 常见陷阱

- `Task.detached` 会忽略继承的 actor 上下文；除非确实需要打破隔离，否则避免使用。
- 如果 CPU 密集型工作留在 main actor 上，默认 main actor 会隐藏性能问题；将此类工作移入 `@concurrent` async 函数。

## 关键字（来自源速查表）

| 关键字 | 作用 |
| --- | --- |
| `async` | 函数可以暂停 |
| `await` | 在此处暂停直到完成 |
| `Task { }` | 启动异步工作，继承上下文 |
| `Task.detached { }` | 启动异步工作，不继承上下文 |
| `@MainActor` | 在主线程运行 |
| `actor` | 具有隔离可变状态的类型 |
| `nonisolated` | 退出 actor 隔离 |
| `Sendable` | 可安全地在隔离域之间传递 |
| `@concurrent` | 始终在后台运行（Swift 6.2+） |
| `async let` | 启动并行工作 |
| `TaskGroup` | 动态并行工作 |

## 来源

https://fuckingapproachableswiftconcurrency.com/en/
