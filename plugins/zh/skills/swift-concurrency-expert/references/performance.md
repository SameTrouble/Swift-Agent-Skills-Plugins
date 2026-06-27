# 性能

使用本文件当：

- 异步代码比预期慢或导致 UI 卡顿。
- 你需要在同步、异步和并行执行之间做选择。
- 你正在使用 Instruments 分析并发开销。

跳过本文件如果：

- 问题是关于隔离或 Sendable 的编译器诊断。使用 `actors.md` 或 `sendable.md`。
- 你主要需要修复内存泄漏。使用 `memory-management.md`。

跳转到：

- 核心原则
- 常见性能问题
- 使用 Xcode Instruments
- 挂起点 / 减少挂起
- 选择执行方式
- 并行化成本
- 优化清单

## 核心原则

### 测量是必不可少的

无法改进你不测量的东西。在优化之前建立基线。

### 从简单开始，稍后优化

```
同步 → 异步 → 并行
```

仅在证明必要时向右移动。

### 并发的三个阶段

1. **无并发**——同步方法
2. **挂起无并行**——异步方法
3. **高级并发**——并行执行

## 常见性能问题

### UI 卡顿

主线程上过多工作导致界面冻结。

### 糟糕的并行化

重工作汇入单个任务而非并行执行。

### Actor 争用

任务等待繁忙的 actor，导致不必要的挂起。

## 使用 Xcode Instruments

### Swift Concurrency 模板

用 CMD + I 分析 → 选择 "Swift Concurrency" 模板。

**包含的 Instruments**：
- **Swift Tasks**：跟踪运行中、存活、总任务数
- **Swift Actors**：显示 actor 执行和队列大小

### 关键指标

```
任务：
- 总数
- 运行 vs 挂起
- 任务状态（Creating、Running、Suspended、Ending）

Actor：
- 队列大小
- 执行时间
- 争用点

主线程：
- 卡顿
- 阻塞时间
```

### 任务状态

- **Creating**：任务正在初始化
- **Running**：正在执行
- **Suspended**：等待（在 await 处）
- **Ending**：正在完成

> **课程深入**：此主题在 [Lesson 10.1: Using Xcode Instruments to find performance bottlenecks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 识别问题

### 主线程阻塞

```swift
// ❌ 所有工作在主线程
@MainActor
func generateWallpapers() {
    Task {
        for _ in 0..<100 {
            let image = generator.generate() // 阻塞主线程
            wallpapers.append(image)
        }
    }
}
```

**Instruments 显示**：长时间主线程卡顿，无并行。

### 解决方案：移到后台

```swift
@MainActor
func generateWallpapers() {
    Task {
        for _ in 0..<100 {
            let image = await backgroundGenerator.generate()
            wallpapers.append(image)
        }
    }
}

actor BackgroundGenerator {
    func generate() -> Image {
        // 后台重工作
    }
}
```

### Actor 争用

```swift
actor Generator {
    func generate() -> Image {
        // 重工作
    }
}

// ❌ 通过 actor 顺序执行
for _ in 0..<100 {
    let image = await generator.generate() // 队列大小 = 1
}
```

**Instruments 显示**：Actor 队列从不超过 1，无并行。

### 解决方案：移除不必要的 actor

```swift
struct Generator {
    @concurrent
    static func generate() async -> Image {
        // 重工作，无共享状态
    }
}

// ✅ 并行执行
for i in 0..<100 {
    Task(name: "Image \(i)") {
        let image = await Generator.generate()
        await addToCollection(image)
    }
}
```

## 挂起点

### 什么创建挂起

每个 `await` 都是潜在挂起点：

```swift
let data = await fetchData() // 可能挂起
```

**不保证**——如果隔离匹配，可能不挂起。

### 挂起表面积

挂起点之间的代码。越大 = 越难推理：
- Actor 不变量
- 性能
- 线程跳转
- 重入
- 状态一致性

### 目标

- 在跨越隔离之前完成工作
- 跨越一次
- 完成工作
- 仅在必要时再次跨越

## 减少挂起

### 1. 使用同步方法

```swift
// ❌ 不必要的 async
private func scale(_ image: CGImage) async { }

func process(_ image: CGImage) async {
    let scaled = await scale(image) // 挂起点
}

// ✅ 同步辅助
private func scale(_ image: CGImage) { }

func process(_ image: CGImage) async {
    let scaled = scale(image) // 无挂起
}
```

**规则**：如果方法不需要挂起，不要标记 async。

### 2. 防止 actor 重入

```swift
// ❌ 重新进入 actor
actor BankAccount {
    func deposit(_ amount: Int) async {
        balance += amount
        await logTransaction() // 离开 actor
        balance += bonus // 重新进入——状态可能已改变
    }
}

// ✅ 在离开之前完成工作
actor BankAccount {
    func deposit(_ amount: Int) async {
        balance += amount
        balance += bonus
        await logTransaction() // 在状态更改后离开
    }
}
```

### 3. 继承隔离

```swift
// ❌ 切换隔离
@MainActor
func update() async {
    await process() // 从 main actor 切走
}

// ✅ 继承隔离（仍然需要 await——但无执行器跳转）
@MainActor
func update() async {
    await process() // 当 nonisolated(nonsending) 时留在 main actor
}

nonisolated(nonsending) func process() async { }
```

> **课程深入**：此主题在 [Lesson 10.2: Reducing suspension points by managing isolation effectively](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

### 4. 使用非挂起 API

```swift
// ❌ 可能挂起
try await Task.checkCancellation()

// ✅ 无挂起
if Task.isCancelled {
    return
}
```

### 5. 将 Task 入口隔离与同步前缀匹配

对于非结构化 `Task { ... }`，从同步前缀（第一个 `await` 之前的所有内容）决定启动隔离。如果该前缀需要 main-actor 访问，保持继承的 `@MainActor` 入口。如果前缀不需要 main actor，使用 `Task { @concurrent in ... }`，仅在需要 UI 拥有的变更时通过 `MainActor.run` 跳回。当同一前缀中已存在 main-actor 工作时，一个简单的非 main 行（如 `print`）**不**证明 `@concurrent` 合理。

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

延迟重试是此规则的一个特化：

```swift
// ❌ 可能在 MainActor 上等待，然后立即挂起
registrationRetryTask = Task { @MainActor [weak self] in
    try? await Task.sleep(for: .milliseconds(100))
    guard let self else { return }
    self.registrationRetryTask = nil
    self.updateConnectedTargetWindow()
}
```

延迟本身不是 UI 工作。从 `@MainActor` 启动可能在到达 `Task.sleep` 之前增加可避免的执行器等待，特别是从其他执行器调度或 main actor 繁忙时。

```swift
// ✅ 在非 main 上 sleep，仅在 UI 拥有的工作时跳回
registrationRetryTask = Task { @concurrent [weak self] in
    do {
        try await Task.sleep(for: .milliseconds(100))
    } catch is CancellationError {
        return
    }
    guard let self else { return }

    await MainActor.run {
        self.registrationRetryTask = nil
        self.updateConnectedTargetWindow()
    }
}
```

此规则适用于任何非结构化任务：延迟重试、退避、类计时器工作、非 main 计算和 actor 跳转。关键检查始终是"第一个 `await` 之前运行什么？"，而非"任务最终做什么？"。

### 6. 拥抱并行

```swift
// ❌ 顺序
for url in urls {
    let image = await download(url)
    images.append(image)
}

// ✅ 并行
await withTaskGroup(of: Image.self) { group in
    for url in urls {
        group.addTask { await download(url) }
    }
    for await image in group {
        images.append(image)
    }
}
```

## 在 Instruments 中分析挂起

### 查看任务状态

1. 选择 Swift Tasks instrument
2. 切换到 "Task States" 视图
3. 查找 Suspended 状态
4. 检查挂起持续时间

### 导航到代码

1. 点击任务状态（Running/Suspended）
2. 打开 Extended Detail
3. 点击相关方法
4. 使用 "Open in Source Viewer"

### 预测挂起

```swift
Task {
    // 状态 1：Running
    // 状态 2：Suspended（切换到后台）
    let data = await backgroundWork()
    // 状态 3：Running（在后台）
    // 状态 4：Suspended（切换到 main actor）
    // 状态 5：Running（在 main actor 上）
    await MainActor.run {
        updateUI(data)
    }
}
```

### 优化示例

```swift
// 之前：两次挂起
Task {
    let data = await generate() // 挂起 1
    self.items.append(data) // 挂起 2（回到 main）
}

> **课程深入**：此主题在 [Lesson 10.3: Using Xcode Instruments to detect and remove suspension points](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

// 之后：一次挂起
Task { @concurrent in
    let data = generate() // 无挂起（同步）
    await MainActor.run {
        self.items.append(data) // 挂起 1（到 main）
    }
}
```

## 选择执行方式

### 决策清单

**使用 async/parallel 如果**：
- [ ] 明显阻塞 main actor（>16ms）
- [ ] 随数据扩展（N 项 → N 成本）
- [ ] 涉及 I/O（网络、磁盘）
- [ ] 从组合操作中受益
- [ ] 频繁调用

**2+ 项** → async/parallel 合理。

### 从同步开始

```swift
// 从这里开始
func processData(_ data: Data) -> Result {
    // 快速，内存中工作
}
```

**仅当以下情况移到 async**：
- Instruments 显示主线程卡顿
- 用户报告迟缓
- 工作随输入大小扩展

### 何时使用 async

```swift
func processData(_ data: Data) async -> Result {
    // 使用当：
    // - 触及持久化存储
    // - 解析大型数据集
    // - 网络通信
    // - 通过分析证明慢
}
```

### 何时使用并行

```swift
await withTaskGroup(of: Result.self) { group in
    for item in items {
        group.addTask { await process(item) }
    }
}

// 使用当：
// - 多个独立操作
// - 首次结果时间重要

> **课程深入**：此主题在 [Lesson 10.4: How to choose between serialized, asynchronous, and parallel execution](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍
// - 工作随集合大小扩展
// - 通过分析证明有益
```

## 并行化成本

### 权衡

**好处**：
- 更快完成（如果是 CPU 密集型）
- 更好的资源利用
- 改善响应性

**成本**：
- 增加内存压力
- CPU 调度开销
- 系统资源饱和
- 电池消耗
- 热影响

### 何时并行化有害

```swift
// ❌ 过度并行化
for i in 0..<1000 {
    Task { await lightWork(i) }
}
// 为简单工作创建 1000 个任务
```

**更好**：批量工作或使用更少的任务。

## UX 驱动的决策

### 流畅动画 > 原始速度

```swift
// 主线程 80ms，但动画卡顿
@MainActor
func process() {
    heavyWork() // 冻结 UI 一帧
}

// 总共 100ms，但 UI 流畅
@MainActor
func process() async {
    await backgroundWork() // UI 保持响应
}
```

**感知**：流畅感觉比原始速度更快。

### 进度指示

```swift
@MainActor
func loadItems() async {
    isLoading = true
    
    for i in 0..<100 {
        let item = await fetchItem(i)
        items.append(item)
        progress = Double(i) / 100 // 增量更新
    }
    
    isLoading = false
}
```

后台工作 + 进度 = 感觉更快。

## 优化清单

优化之前，询问：

- [ ] 我是否用 Instruments 分析过？
- [ ] 主线程是否实际阻塞？
- [ ] 这可以是同步的吗？
- [ ] 我是否过度并行化？
- [ ] Actor 争用是否是问题？
- [ ] 挂起是否必要？
- [ ] UX 是否需要后台工作？
- [ ] 这会随数据扩展吗？

非结构化任务要避免的反模式：
- 当同步前缀（第一个 `await` 之前）中没有任何内容需要 main actor 时，从继承的 `@MainActor` 启动。
- 当同一同步前缀已包含必需的 main-actor 变更时，将简单的非 main 行移出 `@MainActor`。

## 常见模式

### 将重工作移到后台

```swift
// 之前
@MainActor
func generate() {
    for _ in 0..<100 {
        let item = heavyGeneration()
        items.append(item)
    }
}

// 之后
@MainActor
func generate() async {
    for _ in 0..<100 {
        let item = await backgroundGenerate()
        items.append(item)
    }
}

@concurrent
func backgroundGenerate() async -> Item {
    // 重工作在主线程之外
}
```

### 并行化独立工作

```swift
// 之前：顺序
for url in urls {
    let image = await download(url)
    images.append(image)
}

// 之后：并行
await withTaskGroup(of: Image.self) { group in
    for url in urls {
        group.addTask { await download(url) }
    }
    for await image in group {
        images.append(image)
    }
}
```

### 减少 actor 跳转

```swift
// 之前：多次跳转
actor Store {
    func process() async {
        let a = await fetch1() // 跳转 1
        let b = await fetch2() // 跳转 2
        let c = await fetch3() // 跳转 3
        combine(a, b, c)
    }
}

// 之后：批量获取
actor Store {
    func process() async {
        async let a = fetch1()
        async let b = fetch2()
        async let c = fetch3()
        combine(await a, await b, await c) // 一次跳转
    }
}
```

## 最佳实践

1. **优化之前分析**——测量基线
2. **从同步开始**——仅在需要时添加 async
3. **定期使用 Instruments**——及早捕获问题
4. **命名任务**——在 Instruments 中更容易调试
5. **检查挂起计数**——减少不必要的 await
6. **避免过早并行化**——有成本
7. **考虑 UX**——流畅 > 快速
8. **批量 actor 工作**——减少争用
9. **在真实设备上测试**——模拟器会说谎
10. **在生产中监控**——真实使用模式不同

## 调试性能

### Instruments 工作流

1. 用 Swift Concurrency 模板分析
2. 识别主线程卡顿
3. 检查任务并行性
4. 分析 actor 队列大小
5. 审查挂起点
6. 导航到有问题的代码
7. 应用优化
8. 重新分析验证

### Instruments 中的危险信号

- 主线程阻塞 >16ms
- Actor 队列大小始终为 1
- 高挂起计数
- 任务创建但未运行
- 过度任务创建（1000+）

## 进一步学习

有关真实世界优化示例、分析技术和高级性能模式，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
