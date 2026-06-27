# 并行化与隔离

## 何时使用此参考

当测试在 CI 中不稳定、存在隐藏的顺序依赖，或需要安全地扩展执行速度时使用此文件。

## 默认执行模型

- Swift Testing 默认并行运行测试函数。
- 执行顺序随机化，以暴露隐藏的测试依赖。
- 并行化适用于同步和异步测试。

## 示例：并行执行暴露的隐藏依赖

```swift
import Testing

enum SharedStore {
	static var counter = 0
}

@Test func incrementsCounter() {
	SharedStore.counter += 1
	#expect(SharedStore.counter >= 1)
}

@Test func expectsFreshCounter() {
	// 如果测试并行运行或顺序随机，则不稳定。
	#expect(SharedStore.counter == 0)
}
```

## 为什么这很重要

- 更快的 CI 反馈和更短的本地迭代循环。
- 更好地检测共享状态耦合和不稳定行为。
- 对并发敏感的代码路径施加更真实的压力。

## 隔离策略优先

- 默认使测试独立。
- 避免跨测试的共享可变全局变量和单例变更。
- 按测试调用隔离状态（每次使用新的套件实例有帮助）。
- 优先使用确定性的测试数据设置，而非隐式的顺序假设。

### 更好的模式：按测试隔离

```swift
import Testing

struct CounterStore {
	var counter = 0
	mutating func increment() { counter += 1 }
}

@Test func isolatedCounter() {
	var store = CounterStore()
	store.increment()
	#expect(store.counter == 1)
}
```

## `.serialized` 作为针对性工具

- 当测试必须逐个运行时对套件应用 `.serialized`。
- 在从串行 XCTest 套件迁移期间作为过渡安全措施使用。
- 在普遍规范化序列化之前，先向并行安全测试重构。
- 序列化套件仍可与其他无关套件并行运行。

### 过渡性序列化示例

```swift
import Testing

@Suite(.serialized)
struct LegacyDatabaseTests {
	@Test func migrationStepA() { #expect(true) }
	@Test func migrationStepB() { #expect(true) }
}
```

## 共享资源场景

- 如果测试访问共享的 DB/文件/服务，选择其一：
  - 按测试隔离后端状态
  - 使用内存替代
  - 为集成路径创建单独的串行测试计划
- 优先采用既支持快速内存测试又支持选择性真实集成测试的架构。

## 应做 / 不应做

- 应做：在添加大范围序列化之前先修复共享状态耦合。
- 应做：为快速路径使用内存桩。
- 不应做：依赖执行顺序。
- 不应做：跨测试变更单例而不重置/隔离。
