# 术语表

使用本文件当：

- 你需要 Swift Concurrency 术语的快速定义。
- 你在其他参考文件中遇到不熟悉的术语。

跳过本文件如果：

- 你需要实现模式而非定义。使用相关的参考文件。

## Actor 隔离

编译器强制的规则：actor 隔离的状态只能从 actor 的执行器访问。跨 actor 访问需要 `await`。

## 全局 actor

通过 `@MainActor` 或自定义 `@globalActor` 等属性应用的共享隔离域。隔离到同一全局 actor 的类型/函数可以交互而不跨越隔离。

## 默认 actor 隔离

模块/目标级别的设置，更改声明的默认隔离。App 目标通常选择 `@MainActor` 作为默认以减少迁移噪音，但它会改变行为和诊断。

## 严格并发检查

编译器对 Sendable 和隔离诊断的强制级别（minimal/targeted/complete）。提高级别通常会揭示更多问题，并可能触发"并发兔子洞"，除非增量迁移。

## Sendable

标记协议，指示类型可以安全地跨隔离域传递。编译器验证存储属性和捕获值的线程安全性。

## @Sendable

用于可以并发执行的函数类型/闭包的注解。它收紧了捕获规则（捕获的值必须是 Sendable 或安全传递）。

## 挂起点

任务可能挂起并稍后恢复的 `await` 点。在挂起点之后，你必须假设其他工作可能已运行，并且（对于 actor）状态可能已改变（重入）。

## 重入（actor）

当 actor 在 `await` 处挂起时，其他任务可以进入 actor 并修改状态。`await` 之后的代码不能假设 actor 状态未改变。

## nonisolated

将声明标记为不隔离到周围的 actor/全局 actor。仅当它确实不触及隔离的可变状态时使用（通常是不可变 Sendable 数据）。

## nonisolated(nonsending)（Swift 6.2+ 行为）

一种退出选项，防止跨隔离"发送"非 Sendable 值，同时仍允许异步函数在调用方的隔离中运行。当你不需要跳转执行器时用于减少 Sendable 摩擦。

## @concurrent（Swift 6.2+ 行为）

用于显式将非隔离异步函数选择为并发执行（即不继承调用方的 actor）的属性。在启用 `NonisolatedNonsendingByDefault` 时用于迁移。
在 `Task { @concurrent in ... }` 上也有效，用于将任务体从包围 actor 的隔离中退出；当任务的同步前缀（第一个 `await` 之前的所有内容）不需要 main actor 时选择此项。

## @preconcurrency

用于抑制来自早于并发注解的模块的 Sendable 相关诊断的注解。它减少噪音但将安全责任转移给你。

## 基于区域的隔离 / sending

建模所有权转移的机制，使某些非 Sendable 值可以在区域之间安全移动。`sending` 关键字强制值在传递后不再使用。

## AsyncSequence

提供对元素进行异步、顺序迭代的类型的协议。遵循 `for await` 循环模式。用于元素随时间到达的流式数据。

## AsyncStream

`AsyncSequence` 的具体实现，将基于回调或基于代理的 API 桥接到 async/await。提供 `yield()` 发出值和 `finish()` 完成流。

## Continuation

将基于回调的 API 桥接到 async/await 的机制。`withCheckedContinuation` 和 `withCheckedThrowingContinuation` 提供带运行时检查的安全桥接。`withUnsafeContinuation` 变体跳过检查，用于性能关键代码。

## Task Local

任务作用域存储，通过任务层次结构自动传播值。用 `@TaskLocal` 声明，通过包装器的静态属性访问。子任务继承父任务的 task local。

## 协作式线程池

Swift 的线程模型，任务在运行时管理的有限线程池上运行。任务在挂起点协作式让出，允许其他任务运行。避免会饿死线程池的阻塞操作。

## 执行器

决定 actor 代码在哪里以及何时运行的调度机制。`MainActor` 使用主线程执行器。自定义 actor 使用默认执行器，除非指定自定义执行器。

## 结构化并发

子任务与父任务有明确关系的模式。子任务必须在父作用域退出之前完成。提供自动取消传播并防止孤立任务。通过 `async let` 和 `TaskGroup` 实现。

## 隔离域

保护可变状态免受并发访问的边界。每个 actor 实例定义自己的隔离域。`@MainActor` 全局 actor 为 UI 工作定义共享隔离域。代码必须通过 `await` 显式跨越隔离边界。

## 任务优先级

向运行时提示任务的相对重要性。优先级包括 `.high`、`.medium`、`.low`、`.userInitiated`、`.utility` 和 `.background`。更高优先级的任务在更低优先级的任务之前调度。当高优先级任务等待低优先级任务时，优先级可以升级。

## 取消

信号任务应停止的协作机制。在长时间运行的工作中检查 `Task.isCancelled` 或调用 `Task.checkCancellation()`（抛出）。取消在结构化并发中传播到子任务。

## Debounce

在发出值之前等待一段不活动期。用于减少搜索字段等快速输入的 API 调用。在 AsyncAlgorithms 中实现为 `debounce(for:tolerance:clock:)`。

## Throttle

每个时间间隔最多发出一个值，丢弃中间值。用于防止按钮点击等重复动作的过度调用。在 AsyncAlgorithms 中实现为 `throttle(for:clock:reducing:)`。

## Merge（AsyncAlgorithms）

将多个异步序列合并为一个，按从任何源到达的顺序发出值。顺序按发出时间交错。稳定操作符。

## CombineLatest（AsyncAlgorithms）

组合多个异步序列，当任何源发出新值时发出元组。始终使用每个序列的最新值。稳定操作符。

## Zip（AsyncAlgorithms）

通过按顺序配对元素来组合多个异步序列。等待所有序列发出后才产生元组。稳定操作符。

## AsyncChannel

带背压发送语义的 AsyncSequence。允许多个生产者安全地向多个消费者发送值并进行流控制。稳定操作符。

## AsyncThrowingChannel

类似 AsyncChannel 但可以通过流发出错误。稳定操作符。

## AsyncTimerSequence

按固定间隔发出值的 AsyncSequence。替代基于计时器的发布者和手动 sleep 循环。稳定操作符。
