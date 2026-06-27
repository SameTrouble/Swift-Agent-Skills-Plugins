---
name: swift-concurrency-expert
description: Swift 6.2+ 的 Swift Concurrency 审查与修复。当被要求审查 Swift Concurrency 用法、提升并发合规性，或修复某功能或文件中的 Swift 并发编译器错误时使用。具体操作包括添加 Sendable 一致性、应用 @MainActor 标注、解决 actor 隔离警告、修复数据竞争诊断，以及将完成处理器迁移到 async/await。
---

# Swift Concurrency Expert

## 概览

通过应用 actor 隔离、Sendable 安全性和现代并发模式，并以最小的行为变更来审查和修复 Swift 6.2+ 代码库中的 Swift Concurrency 问题。

## 工作流程

### 1. 对问题进行分诊

- 记录确切的编译器诊断信息和出错的符号。
- 检查项目并发设置：Swift 语言版本（6.2+）、严格并发级别，以及是否启用了 approachable concurrency（默认 actor 隔离 / 默认 main actor）。
- 识别当前的 actor 上下文（`@MainActor`、`actor`、`nonisolated`）以及是否启用了默认 actor 隔离模式。
- 确认代码是否绑定 UI，或是否意图在 main actor 之外运行。

### 2. 应用最小的安全修复

优先选择能保持现有行为同时满足数据竞争安全的修改。

常见修复：
- **绑定 UI 的类型**：用 `@MainActor` 标注该类型或相关成员。
- **main actor 类型上的协议一致性**：将一致性设为隔离的（例如 `extension Foo: @MainActor SomeProtocol`）。
- **全局/静态状态**：用 `@MainActor` 保护或移入 actor 中。
- **后台任务**：将耗时工作移入 `nonisolated` 类型上的 `@concurrent` async 函数，或使用 `actor` 来守护可变状态。
- **Sendable 错误**：优先使用不可变/值类型；仅在正确时才添加 `Sendable` 一致性；除非能证明线程安全，否则避免使用 `@unchecked Sendable`。

### 3. 验证修复

- 重新构建并确认所有并发诊断已解决，且未引入新的警告。
- 运行测试套件检查回归——并发改动即使在构建干净时也可能引入微妙的运行时问题。
- 如果修复暴露出新的警告，将每个警告视为新的分诊（回到步骤 1）并迭代解决，直到构建干净且测试通过。

### 示例

**绑定 UI 的类型 —— 添加 `@MainActor`**

```swift
// 之前：数据竞争警告，因为 ViewModel 从主线程访问
// 但没有 actor 隔离
class ViewModel: ObservableObject {
    @Published var title: String = ""
    func load() { title = "Loaded" }
}

// 之后：标注整个类型，使所有存储状态和方法
// 自动隔离到 main actor
@MainActor
class ViewModel: ObservableObject {
    @Published var title: String = ""
    func load() { title = "Loaded" }
}
```

**协议一致性隔离**

```swift
// 之前：编译器错误 —— SomeProtocol 方法是 nonisolated 的，
// 但一致性类型是 @MainActor
@MainActor
class Foo: SomeProtocol {
    func protocolMethod() { /* 访问 main actor 状态 */ }
}

// 之后：将一致性限定到 @MainActor，使要求
// 在正确的隔离上下文内得到满足
@MainActor
extension Foo: SomeProtocol {
    func protocolMethod() { /* 安全地访问 main actor 状态 */ }
}
```

**使用 `@concurrent` 的后台任务**

```swift
// 之前：耗时计算阻塞 main actor
@MainActor
func processData(_ input: [Int]) -> [Int] {
    input.map { heavyTransform($0) }   // 在主线程运行
}

// 之后：为重活跳离 main actor，然后返回结果
// 调用方 await 结果并留在自己的 actor 上
nonisolated func processData(_ input: [Int]) async -> [Int] {
    await Task.detached(priority: .userInitiated) {
        input.map { heavyTransform($0) }
    }.value
}

// 或者使用 @concurrent async 函数（Swift 6.2+）：
@concurrent
func processData(_ input: [Int]) async -> [Int] {
    input.map { heavyTransform($0) }
}
```

## 参考材料

- 有关 Swift 6.2 的变更、模式和示例，参见 `references/swift-6-2-concurrency.md`。
- 当项目启用了 approachable concurrency 模式时，参见 `references/approachable-concurrency.md`。
- 有关 SwiftUI 特定的并发指导，参见 `references/swiftui-concurrency-tour-wwdc.md`。
