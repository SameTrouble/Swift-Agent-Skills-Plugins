# 线程

使用本文件当：

- 你需要理解任务和线程之间的关系。
- 你正在调试挂起点、actor 重入或意外的执行上下文。
- 你需要 Swift 6.2 行为指导（`nonisolated async`、`@concurrent`、`nonisolated(nonsending)`）。

跳过本文件如果：

- 你主要需要保护可变状态。使用 `actors.md`。
- 你需要使类型安全传递。使用 `sendable.md`。

跳转到：

- 核心概念（Task vs 线程）
- 协作式线程池
- 挂起点和 Actor 重入
- Swift 6.2 变化（SE-461、SE-466）
- 默认隔离域
- 调试线程执行
- 常见误解
- 迁移策略

## 核心概念

### 什么是线程？

运行指令的系统级资源。创建和切换开销高。Swift Concurrency 抽象了线程管理。

### Task vs 线程

**Task** 是异步工作单元，不绑定到特定线程。Swift 从协作式线程池中的可用线程动态调度任务。

**关键洞察**：一个任务和一个线程之间没有直接关系。

> **课程深入**：此主题在 [Lesson 7.1: How Threads relate to Tasks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

**重要（Swift 6+）**：避免在异步上下文中使用 `Thread.current`。在 Swift 6 语言模式中，`Thread.current` 在异步上下文中不可用，将无法编译。优先从隔离域角度推理；需要时使用 Instruments 和调试器观察执行。

## 协作式线程池

Swift 仅创建与 CPU 核心数相同的线程。任务高效共享这些线程。

### 工作方式

1. **有限线程**：数量匹配 CPU 核心
2. **任务调度**：任务调度到可用线程
3. **挂起**：在 `await` 处，任务挂起，线程释放用于其他工作
4. **恢复**：任务在任意可用线程上恢复（不一定是同一个）

```swift
func example() async {
    print("Started on: \(Thread.current)")
    
    try await Task.sleep(for: .seconds(1))
    
    print("Resumed on: \(Thread.current)") // 可能不同线程
}
```

### 相比 GCD 的好处

**防止线程爆炸**：
- 无过度线程创建
- 无空闲线程的高内存开销
- 无过度上下文切换
- 无优先级反转

**更好性能**：
- 更少线程 = 更少上下文切换
- 用 continuation 代替阻塞
- CPU 核心保持高效忙碌

## 线程思维 → 隔离思维

### 旧方式（GCD）

```swift
// 思考线程
DispatchQueue.main.async {
    // 在主线程更新 UI
}

DispatchQueue.global(qos: .background).async {
    // 在后台线程重工作
}
```

### 新方式（Swift Concurrency）

```swift
// 思考隔离域
@MainActor
func updateUI() {
    // 在 main actor 上运行（通常是主线程）
}

func heavyWork() async {
    // 在池中任意可用线程上运行
}
```

### 从隔离域思考

**不要问**："这应该在什么线程上运行？"

**问**："什么隔离域应该拥有这个工作？"

- `@MainActor` 用于 UI 更新
- 自定义 actor 用于特定状态
- 非隔离用于一般异步工作

### 提供提示，而非命令

```swift
Task(priority: .userInitiated) {
    await doWork()
}
```

你在描述工作的性质，而非分配线程。Swift 优化执行。

> **课程深入**：此主题在 [Lesson 7.2: Getting rid of the "Threading Mindset"](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 挂起点

### 什么是挂起点？

任务**可能**暂停以允许其他工作的时刻。由 `await` 标记。

```swift
let data = await fetchData() // 潜在挂起
```

**关键**：`await` 标记*可能*的挂起，不保证。如果操作同步完成，不发生挂起。

### 为什么挂起点重要

1. **代码可能意外暂停**——稍后恢复，可能不同线程
2. **状态可能改变**——可变状态可能在挂起期间被修改
3. **Actor 重入**——其他任务可以在挂起期间访问 actor

相同的入口隔离规则适用于任何非结构化任务：根据同步前缀的需要选择启动隔离。如果第一个 `await` 之前没有任何内容需要 main actor——无论第一个操作是 `Task.sleep`、actor 跳转、`print` 还是 Sendable 计算——优先使用 `Task { @concurrent in ... }`，仅在 UI 变更时通过 `MainActor.run` 跳回。如果同步前缀已经因为一条语句需要 main actor，将附近的廉价行保留在 main 上，而非拆分。

### Actor 重入示例

```swift
actor BankAccount {
    private var balance: Int = 0
    
    func deposit(amount: Int) async {
        balance += amount
        print("Balance: \(balance)")
        
        await logTransaction(amount) // ⚠️ 挂起点
        
        balance += 10 // 奖金
        print("After bonus: \(balance)")
    }
    
    func logTransaction(_ amount: Int) async {
        try? await Task.sleep(for: .seconds(1))
    }
}

// 两个并发存款
async let _ = account.deposit(amount: 100)
async let _ = account.deposit(amount: 100)

// 意外：100 → 200 → 210 → 220
// 预期：  100 → 110 → 210 → 220
```

**原因**：在 `logTransaction` 期间，第二次存款运行，在第一次完成之前修改了余额。

### 避免重入 bug

**在挂起之前完成 actor 工作**：

```swift
func deposit(amount: Int) async {
    balance += amount
    balance += 10 // 先应用奖金
    print("Final balance: \(balance)")
    
    await logTransaction(amount) // 在状态更改后挂起
}
```

**规则**：不要在挂起点之后修改 actor 状态。

> **课程深入**：此主题在 [Lesson 7.3: Understanding Task suspension points](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍


## 选择 Task 入口隔离

对于非结构化 `Task { ... }`，根据同步前缀（第一个 `await` 之前的所有内容）选择入口隔离，而非根据任务创建位置。

裸 `Task { ... }` 在 `@MainActor` 上启动的两个常见原因：
- 任务从 `@MainActor` 上下文派生。
- 模块启用了默认 main-actor 隔离（例如 `defaultIsolation(MainActor.self)`）。

规则：
- 如果同步前缀包含任何 main-actor 工作，保持继承的 main-actor 入口。
- 如果同步前缀不包含 main-actor 工作，用 `Task { @concurrent in ... }` 启动，仅在需要时跳回 `MainActor`。

```swift
// ❌ 同步前缀为空；第一个工作跳走
Task {
    await hopToOtherIsolationDomain()
}

// ❌ 同步前缀只有 `print`（简单，非 main）；第一个 await 跳走
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

延迟重试 `Task.sleep` 模式（见 `performance.md` "Match Task entry isolation to its synchronous prefix"）是同一规则的特化：等待通常不是 UI 拥有的，而最终变更是。

注意 `Task { @concurrent in ... }` 更改了闭包的隔离，因此从包围 actor 捕获非 Sendable 状态必须移到 `MainActor.run { ... }` 跳转内部，或被弱捕获（例如 `[weak self]` 加 `guard let self`）在那里使用。上面的示例通过将 `self` 使用保持在 `MainActor.run` 内来保持安全。如果体需要直接触及非 Sendable 状态，在求助于 `@concurrent` 之前见 `sendable.md`。

## 线程执行模式

### 默认：后台线程

任务在协作式线程池（后台线程）上运行：

```swift
Task {
    print(Thread.current) // 后台线程
}
```

### 主线程执行

使用 `@MainActor` 获取主线程：

```swift
@MainActor
func updateUI() {
    Task {
        print(Thread.current) // 主线程
    }
}
```

### 继承示例

```swift
@MainActor
func updateUI() {
    print("Main thread: \(Thread.current)")
    
    await backgroundTask() // 切换到后台
    
    print("Back on main: \(Thread.current)") // 返回 main
}

func backgroundTask() async {
    print("Background: \(Thread.current)")
}
```

## Swift 6.2 变化

### 非隔离异步函数（SE-461）

**旧行为**：非隔离异步函数始终切换到后台。

**新行为**：默认继承调用方的隔离。

```swift
class NotSendable {
    func performAsync() async {
        print(Thread.current)
    }
}

@MainActor
func caller() async {
    let obj = NotSendable()
    await obj.performAsync()
    // 旧：后台线程
    // 新：主线程（继承 @MainActor）
}
```

### 启用新行为

在 Xcode 16+ 中：

```swift
// 构建设置或 swift-settings
.enableUpcomingFeature("NonisolatedNonsendingByDefault")
```

### 用 @concurrent 退出

强制函数从调用方的隔离切换走：

```swift
@concurrent
func performAsync() async {
    print(Thread.current) // 始终后台
}
```

### nonisolated(nonsending)

防止跨隔离发送非 Sendable 值：

```swift
nonisolated(nonsending) func storeTouch(...) async {
    // 在调用方的隔离上运行，无值发送
}
```

> **课程深入**：此主题在 [Lesson 7.4: Dispatching to different threads using nonisolated(nonsending) and @concurrent (Updated for Swift 6.2)](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

**使用当**：方法不需要切换隔离，避免 Sendable 要求。

## 默认隔离域（SE-466）

### 配置默认隔离

**构建设置**（Xcode 16+）：
- Default Actor Isolation：`MainActor` 或 `None`

**Swift Package**：

```swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .defaultIsolation(MainActor.self)
    ]
)
```

### 为什么更改默认？

大多数 app 代码在主线程上运行。将 `@MainActor` 设为默认：
- 减少假警告
- 避免"并发兔子洞"
- 使迁移更容易

### 带 @MainActor 默认的推断

```swift
// 以 @MainActor 为默认：

func f() {} // 推断：@MainActor

class C {
    init() {} // 推断：@MainActor
    static var value = 10 // 推断：@MainActor
}

@MyActor
struct S {
    func f() {} // 推断：@MyActor（显式覆盖）
}

> **课程深入**：此主题在 [Lesson 7.5: Controlling the default isolation domain (Updated for Swift 6.2)](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍
```

### 每模块设置

必须为每个模块/包选择加入。不跨依赖全局生效。

### 向后兼容

仅选择加入。如果未指定，默认保持 `nonisolated`。

## 调试线程执行

### 打印当前线程

**⚠️ 重要**：`Thread.current` 在 Swift 6 语言模式的异步上下文中不可用。编译器错误指出："Class property 'current' is unavailable from asynchronous contexts; Thread.current cannot be used from async contexts."

**变通方法**（仅 Swift 6+ 模式）：

```swift
extension Thread {
    public static var currentThread: Thread {
        Thread.current
    }
}

print("Thread: \(Thread.currentThread)")
```

### 调试导航器

1. 在任务中设置断点
2. Debug → Pause
3. 检查 Debug Navigator 获取线程信息

### 验证主线程

```swift
assert(Thread.isMainThread)
```

## 常见误解

### ❌ 每个 Task 在新线程上运行

**错误**。任务共享有限线程池，重用线程。

### ❌ await 阻塞线程

**错误**。`await` 挂起任务而不阻塞线程。其他任务可以使用该线程。

### ❌ Task 执行顺序有保证

**错误**。任务根据系统调度执行。使用 `await` 强制顺序。

### ❌ 相同 Task = 相同线程

**错误**。任务可以在挂起后在不同线程上恢复。

## 为什么 Sendable 重要

由于任务在线程之间不可预测地移动：

```swift
func example() async {
    print("Thread 1: \(Thread.current)")
    
    await someWork()
    
    print("Thread 2: \(Thread.current)") // 不同线程
}
```

跨越挂起点的值可能跨越线程。**Sendable** 确保安全。

## 最佳实践

1. **停止思考线程**——思考隔离域
2. **信任系统**——Swift 优化线程使用
3. **UI 使用 @MainActor**——清晰、显式的主线程执行
4. **最小化 actor 中的挂起点**——避免重入 bug
5. **在挂起之前完成状态更改**——防止不一致状态
6. **将优先级作为提示**——而非保证
7. **使类型 Sendable**——跨线程边界安全
8. **启用 Swift 6.2 功能**——更容易迁移，更好默认值
9. **为 app 设置默认隔离**——减少假警告
10. **不要强制线程切换**——让 Swift 优化

## 迁移策略

### 对于新项目（Xcode 16+）

1. 将默认隔离设置为 `@MainActor`
2. 启用 `NonisolatedNonsendingByDefault`
3. 显式后台工作使用 `@concurrent`

### 对于现有项目

1. 逐步启用 Swift 6 语言模式
2. 考虑默认隔离更改
3. 需要时使用 `@concurrent` 保持旧行为
4. 逐模块迁移

## 决策树

```
需要控制执行？
├─ UI 更新？ → @MainActor
├─ 特定状态隔离？ → 自定义 actor
├─ 后台工作？ → 常规 async（信任 Swift）
└─ 需要强制后台？ → @concurrent（Swift 6.2+）

看到 Sendable 警告？
├─ 可以使类型 Sendable？ → 添加一致性
├─ 相同隔离 OK？ → nonisolated(nonsending)
└─ 需要不同隔离？ → 使 Sendable 或重构
```

## GCD 到隔离域迁移

不要问"这应该在什么线程上运行？"，而要问"什么隔离域应该拥有这个工作？"

- `DispatchQueue.main.async { }` → `@MainActor func updateUI()`
- `DispatchQueue.global().async { }` → `func work() async`（或如果必须离开调用方隔离则用 `@concurrent`）
- `DispatchQueue(label:).sync { }` → `actor` 或 `Mutex` 用于保护状态
- 用于排序的串行队列 → `actor`（保证串行访问）

## 决策规则

- UI 状态 → 通常是 `@MainActor`
- 可变共享状态 → 通常是 `actor`
- 无隔离状态的普通异步工作 → 带显式所有权的 `async` API
- 在 Swift 6.2 时代行为下必须跳出调用方隔离的工作 → 考虑 `@concurrent`

## 代理常犯的错误

- 当 actor 隔离已经表达了所有权模型时推荐 GCD 队列跳转。
- 通过线程 ID 而非隔离和顺序调试正确性。
- 将 `await` 视为阻塞调用——它挂起任务，释放线程。
- 将每个 `Task` 映射到概念线程。
- 从包围上下文而非任务的同步前缀选择任务入口隔离。从 `@MainActor` 上下文中第一个 `await` 立即跳走的 `Task { ... }`（之前无 main-actor 工作）通常应该是 `Task { @concurrent in ... }`。

## 性能洞察

### 为什么更少线程 = 更好性能

- **更少上下文切换**：CPU 在实际工作上花费更多时间
- **更好缓存利用**：线程在相同核心上停留更久
- **无线程爆炸**：可预测的资源使用
- **前向进展**：线程永不阻塞，始终高效

### 协作式池优势

- 匹配硬件（每个核心一个线程）
- 防止过度订阅
- 高效任务调度
- 自动负载均衡

## 进一步学习

有关迁移策略、真实世界示例和高级线程模式，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
