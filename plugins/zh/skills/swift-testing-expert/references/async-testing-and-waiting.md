# 异步测试与等待

## 何时使用此参考

当测试涉及 async/await 函数、完成处理器、流/事件或与时序相关的不稳定性时使用此文件。

## 首选方式

- 自然地使用异步测试函数和 `await`。
- 保持异步测试代码贴近生产异步模式。
- 优先使用结构化并发模式而非临时同步。
- 对于无法自然 await 的异步事件式测试，优先使用确认（confirmation）。

### 异步函数测试示例

```swift
import Testing

struct APIClient {
	func fetchName() async throws -> String { "Antoine" }
}

@Test func fetchNameReturnsValue() async throws {
	let client = APIClient()
	let value = try await client.fetchName()
	#expect(value == "Antoine")
}
```

## 回调桥接

- 对于没有 async 重载的完成处理器 API，使用以下方式桥接：
  - `withCheckedContinuation`
  - `withCheckedThrowingContinuation`
- 保持 continuation 包装精简且聚焦于测试。

### 完成处理器到 async 的桥接

```swift
import Testing

func legacyLoad(_ completion: @escaping (Result<Int, Error>) -> Void) {
	completion(.success(42))
}

@Test func legacyAPI() async throws {
	let value = try await withCheckedThrowingContinuation { continuation in
		legacyLoad { result in
			continuation.resume(with: result)
		}
	}
	#expect(value == 42)
}
```

## 用于异步事件的确认

- 当验证无法干净映射到直接 `await` 的事件投递/计数语义时使用确认。
- 显式设置预期计数：
  - 精确计数用于严格验证
  - 下界范围用于"至少"语义
- 保持确认作用域小，并确保确认在确认块返回前发生。

### 确认示例

```swift
import Testing

@Test func eventIsPublishedTwice() async {
	await confirmation("Publishes two events", expectedCount: 2) { confirm in
		confirm()
		confirm()
	}
}
```

## 事件处理器与多次触发回调

- 在严格并发模式下避免从回调闭包中使用不安全的可变共享计数器。
- 使用隔离安全的模式（actor 状态、AsyncSequence 包装器或线程安全容器）。
- 当行为依赖时，显式验证回调计数和顺序。

### Actor 隔离的计数模式

```swift
import Testing

actor EventCounter {
	private(set) var count = 0
	func increment() { count += 1 }
}

@Test func countEventsSafely() async {
	let counter = EventCounter()
	await counter.increment()
	await counter.increment()
	#expect(await counter.count == 2)
}
```

## 避免遗留等待反模式

- 不要在异步回调工作完成前从测试返回。
- 避免将睡眠/基于时间的等待作为主要同步手段。
- 用可 await 的条件和确定性同步点替换脆弱的等待。

```swift
// 避免此模式：
// try await Task.sleep(nanoseconds: 500_000_000)
// #expect(flag == true)
```

## 测试中的 Actor 隔离

- 仅当行为确实需要时才将测试隔离到全局 actor（如 `@MainActor`）。
- 保持非 UI 测试脱离主 actor，以保留真实的并发行为。

### 仅在需要时使用主 actor 测试

```swift
import Testing

@MainActor
@Test func uiModelMutation() {
	#expect(true)
}
```
