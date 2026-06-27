# 诊断

将常见的严格并发编译器错误映射到可能的修复方案。

## "Sending 'x' risks causing data races"（"sending 'x' 有导致数据竞争的风险"）

编译器发现一个值跨越隔离边界，而它仍然可以从发送方被访问。

可能的修复（按顺序尝试）：

1. **检查基于区域的隔离是否已经处理了它。** 如果发送方在传递后可证明停止使用该值，编译器可能无需更改就接受它。避免过早添加 `Sendable`。
2. **将参数标记为 `sending`。** 这告诉编译器调用方转移所有权且之后不会触及该值。（这可能有用，但并不常见。）
3. **使类型 `Sendable`**，如果它确实可以安全共享（值类型、不可变类或内部同步的类）。
4. **检查 `nonisolated(nonsending)` 是否能解决它。** 如果函数不再跳转执行器，该值可能实际上没有跨越边界。
5. **最后手段：`@unchecked Sendable`**，仅当类型使用手动同步（锁）且你已验证正确性时。参见 `bridging.md`。


## "Static property 'x' is not concurrency-safe"（"静态属性 'x' 不是并发安全的"）

全局或静态变量可从多个隔离域访问且没有保护。

可能的修复：

1. **用 `@MainActor` 标注声明**：`@MainActor static let shared = MyType()`。这是最简单的代码局部修复。
2. **如果值确实是常量且不可变**，考虑它是否可以遵循 `Sendable`（例如仅 `let` 的结构体）。编译器不会标记 `Sendable` 常量。
3. **使用 `nonisolated(unsafe)`**，仅用于编译器无法证明安全的真正不可变状态（例如 C 互操作常量）。这是一个危险工具，误用会隐藏真实竞态。
4. **如果整个模块主要是单线程的**，默认 main actor 隔离可能解释了为什么类似的声明在另一个 target 中表现不同。那是构建设置差异，不是代码修复。


## "Capture of 'x' with non-sendable type in a `@Sendable` closure"（"在 `@Sendable` 闭包中捕获了非 Sendable 类型的 'x'"）

跨越隔离边界的闭包（例如传递给 `Task {}`、`Task.detached {}` 或 `addTask`）捕获了非 Sendable 的值。

可能的修复：

1. **检查捕获的值是否可以变为 `Sendable`。** 只有 `Sendable` 存储属性的结构体和枚举只需声明遵循。具有不可变（`let`）存储属性的 final 类也可以遵循。
2. **重构以避免捕获。** 将所需数据作为参数传递给任务，而不是闭包一个大的非 Sendable 对象。例如，`let id = object.id; Task { use(id) }`
3. **将工作移到同一个 actor 上。** 如果闭包不需要并发运行，将其保留在调用方的 actor 上。
4. **在参数上使用 `sending`**，如果你可以干净地转移所有权。这相对小众。

倾向于使用 `@unchecked Sendable` 很诱人，但除非用户*绝对确定*他们的代码是安全的，否则很少是好主意。


## "Conformance of 'X' to protocol 'Y' crosses into main actor-isolated code and can cause data races"（"'X' 对协议 'Y' 的遵循跨入了 main actor 隔离代码并可能导致数据竞争"）

协议和类型描述了不同的调用边界。直接修复边界不匹配：

| 实际需求 | 要使用的形态 |
|---|---|
| 类型级别的 actor 隔离是附带的而非必需的 | 移除类型隔离。参见 `actors.md`。 |
| 遵循应仅在 `MainActor` 上可用 | `extension MyType: @MainActor SomeProtocol {}` |

这些是不同的边界选择，不可互换的抑制手段。


## "Expression is 'async' but is not marked with 'await'"（"表达式是 'async' 但未标记 'await'"）

调用跨越隔离边界并需要 async 跳转。当从 actor 外部调用 actor 隔离的方法，或从非隔离上下文访问 `@MainActor` 状态时，这常常令人惊讶。

可能修复：添加 `await`。如果调用在无法变为 async 的同步代码中，用 `Task {}` 包装（但参见 `unstructured.md` 了解何时合适）。


## "Main actor-isolated conformance of 'X' to 'Y' cannot be used in nonisolated context"（"'X' 对 'Y' 的 main actor 隔离遵循不能在非隔离上下文中使用"）

隔离的遵循（例如 `extension X: @MainActor Y`）正从不共享该隔离的代码中使用。编译器阻止这一点，因为在 actor 之外调用协议方法会是数据竞争。

可能的修复：

1. **将使用点移到同一个 actor 上。** 如果消费代码可以是 `@MainActor`，遵循就可用了。
2. **从遵循中移除隔离**，如果协议方法实际上不需要受 actor 保护的状态。
