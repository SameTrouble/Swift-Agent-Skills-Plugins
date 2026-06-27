# SwiftUI 并发之旅（摘要）

背景：以 SwiftUI 为重点的并发概览，涵盖 actor 隔离、Sendable 闭包，以及 SwiftUI 如何在主线程之外运行工作。

## SwiftUI 中的默认 main actor

- `View` 默认是 `@MainActor` 隔离的；成员和 `body` 继承隔离。
- Swift 6.2 可以为模块中的所有类型推断 `@MainActor`（新语言模式）。
- 此默认值简化了 UI 代码，并与 UIKit/AppKit 的 `@MainActor` API 保持一致。

## SwiftUI 在主线程之外运行代码的地方

- 出于性能考虑，SwiftUI 可能在后台线程上评估某些视图逻辑。
- 示例：`Shape` 路径生成、`Layout` 方法、`visualEffect` 闭包以及 `onGeometryChange` 闭包。
- 这些 API 通常需要 `Sendable` 闭包，以反映其运行时语义。

## Sendable 闭包与数据竞争安全

- 从 `Sendable` 闭包访问 `@MainActor` 状态是不安全的，会被编译器标记。
- 优先在闭包捕获列表中捕获值副本（例如复制一个 `Bool`）。
- 避免仅仅为了读取单个属性而将 `self` 发送到 sendable 闭包中。

## 用 SwiftUI 组织异步工作

- SwiftUI 的动作回调是同步的，因此 UI 更新（如加载状态）可以立即进行。
- 使用 `Task` 桥接到 async 上下文；保持 async 代码体最小化。
- 以状态作为边界：async 工作更新模型/状态；UI 同步响应。

## 性能驱动的并发

- 从 main actor 卸载耗时工作以避免卡顿。
- 保持时间敏感的 UI 逻辑（动画、手势响应）同步。
- 将 UI 代码与长时间运行的异步工作分离，以提升响应性和可测试性。
