# Lint 和并发

使用本文件当：

- SwiftLint 标记 `async_without_await` 或其他并发相关警告。
- 你需要决定是否抑制、修复或重新配置并发 lint 规则。

跳过本文件如果：

- 问题是编译器诊断而非 lint 规则。使用 `actors.md`、`sendable.md` 或 `threading.md`。

跳转到：

- SwiftLint 并发规则概述
- `async_without_await` 规则
- 抑制策略

## SwiftLint 并发规则概述

SwiftLint 提供了几条针对 async/await 和并发模式的规则。理解何时修复 vs 抑制至关重要。

| 规则 | 默认 | 用途 |
|------|---------|---------|
| `async_without_await` | warning | 标记从不 await 的 `async` 函数 |
| `unowned_variable_capture` | warning | 警告闭包中的 `unowned`（在异步中有风险） |
| `class_delegate_protocol` | warning | 确保代理是类绑定的（AnyObject） |
| `weak_delegate` | warning | 代理应该是 weak 的以避免循环引用 |

## SwiftLint：`async_without_await`

- **意图**：如果声明从不 await，则不应是 `async`。
- **绝不要通过**插入假挂起来"修复"（例如 `await Task.yield()`、`await Task { ... }.value`）。这些掩盖了真正的问题并添加了无意义的挂起点。
- **`Task.yield()` 的合法用途**：在测试或调度控制中确实需要让出时 OK；不作为 lint 变通方法。

### 诊断声明为何是 `async`
1) **协议要求**——协议方法/属性是 `async`。
2) **override 要求**——基类 API 是 `async`。
3) **`@concurrent` 要求**——即使没有 `await` 也保持 `async`。
4) **意外/遗留 `async`**——没有调用方需要异步语义。

### 首选修复（顺序）
1) **移除 `async`**（并调整调用点）当不需要异步语义时。
2) 如果 `async` 是必需的（协议/override/@concurrent）：
   - 如果你拥有上游 API，重新评估（它可以是非异步的吗？）。
   - 如果不能更改，保持 `async` 并在适当位置**窄范围抑制规则**（常见于 mock/stub/override）。

### 抑制示例（保持范围紧凑）
```swift
// swiftlint:disable:next async_without_await
func fetch() async { perform() }

// 对于代码块：
// swiftlint:disable async_without_await
func makeMock() async { perform() }
// swiftlint:enable async_without_await
```

### 快速清单
- [ ] 确认 `async` 是否确实必需（协议/override/@concurrent）。
- [ ] 如果不必需，移除 `async` 并更新调用方。
- [ ] 如果必需，优先使用局部抑制而非假 await。
- [ ] 避免无意中添加新的挂起点。

## 编译器警告：Sendable 和隔离

Swift 编译器根据严格并发检查级别生成并发相关警告。

### 常见警告模式

**"Capture of non-sendable type"**
```swift
// 警告：在 `@Sendable` 闭包中捕获非 Sendable 类型 'MyClass' 的 'self'
Task {
    self.doWork() // 'self' 是非 Sendable
}
```

**修复（按优先顺序）：**
1. 如果类型确实线程安全，使其 `Sendable`
2. 如果与 UI 相关，使用 `@MainActor` 隔离
3. 仅捕获 Sendable 值而非 `self`
4. 使用带文档化安全不变量的 `@unchecked Sendable`（最后手段）

**"Non-sendable result returned"**
```swift
// 警告：隐式异步调用返回非 Sendable 类型 'MyResult'
let result = await actor.getData() // 返回非 Sendable 类型
```

**修复：**
1. 使返回类型 Sendable
2. 返回 Sendable 投影（ID、数据副本）
3. 将处理保持在 actor 的隔离内

### Actor 隔离警告

**"Main actor-isolated property accessed from non-isolated context"**
```swift
// 警告：不能从非隔离上下文引用 Main actor 隔离的属性 'title'
func updateTitle() {
    viewModel.title = "New" // viewModel 是 @MainActor
}
```

**修复：**
1. 将调用函数标记为 `@MainActor`
2. 对于一次性访问使用 `await MainActor.run { }`
3. 重新考虑属性是否确实需要 @MainActor 隔离

## 抑制策略

### 何时抑制 vs 修复

**修复当：**
- 警告识别了真实的数据竞争风险
- 修复简单（添加 Sendable、调整隔离）
- 代码是新的或正在积极维护

**抑制当：**
- 协议/继承要求签名
- 第三方代码强制此模式
- 迁移正在进行中（有跟踪的工单）

### 抑制注解

```swift
// 为遗留导入抑制 Sendable 警告
@preconcurrency import LegacyFramework

// 为单个声明抑制
nonisolated(unsafe) var legacyCallback: (() -> Void)?

// 类型级别抑制（谨慎使用）
struct LegacyWrapper: @unchecked Sendable {
    // 记录为什么这是安全的
    private let lock = NSLock()
    private var value: Int
}
```

### 文档要求

使用抑制注解时，记录：
1. **为什么**需要抑制
2. **什么**不变量使其安全
3. **何时**可以移除（链接到迁移工单）

```swift
/// 线程安全：内部锁保护所有修改。
/// TODO: 迁移到 actor 后移除 @unchecked（JIRA-1234）
final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
}
```
