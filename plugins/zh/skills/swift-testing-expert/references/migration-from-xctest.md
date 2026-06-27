# 从 XCTest 迁移

## 何时使用此参考

在将现有 XCTest 代码增量迁移到 Swift Testing 时使用此文件，同时保持安全性和 CI 信号。

## 共存策略

- Swift Testing 和 XCTest 可在同一 target 中共存。
- 增量迁移；不要因全面重写而阻塞迁移。
- 迁移期间单个源文件可同时导入 `XCTest` 和 `Testing`。
- 在 Swift Testing 不适用的场景保留 XCTest：
  - UI 自动化（`XCUIApplication`）
  - 性能 API（`XCTMetric`）
  - 仅 Objective-C 的测试

### 混合导入文件示例

```swift
import XCTest
import Testing
```

## 务实的迁移顺序

1. 将断言转换为 `#expect` / `#require`。
2. 用显式 `@Test` 替换 `test...` 命名约束。
3. 在有帮助时将类重组为套件。
4. 将重复方法合并为参数化测试。
5. 添加 Trait/Tag 以实现控制和测试计划过滤。

## 转换示例：类方法 -> Swift Testing 函数

```swift
// 改造前（XCTest）
final class PriceTests: XCTestCase {
	func testDiscountedTotal() {
		XCTAssertEqual(Price.total(subtotal: 20, discount: 5), 15)
	}
}

// 改造后（Swift Testing）
import Testing

@Test func discountedTotal() {
	#expect(Price.total(subtotal: 20, discount: 5) == 15)
}
```

## 断言映射要点

- 大多数 `XCTAssert*` 变体 -> `#expect(...)`。
- 可选解包检查 -> `try #require(optionalValue)`。
- 提前停止语义 -> `#require` 替代全局 `continueAfterFailure = false`。
- `XCTFail("...")` -> `Issue.record("...")`。

### 表格式快速映射

```swift
// XCTAssertTrue(isEnabled)
#expect(isEnabled)

// XCTAssertNil(error)
#expect(error == nil)

// XCTAssertThrowsError(try run())
#expect(throws: (any Error).self) { try run() }

// try XCTUnwrap(user)
let user = try #require(user)
```

## 套件模型差异

- XCTest：类 + `XCTestCase`。
- Swift Testing：struct/actor/class 套件，显式属性，对值语义友好的默认。
- 在合适时，设置可从 `setUp` 模式迁移到套件初始化。
- 使用 class/actor 套件时，清理可迁移到 `deinit`。
- XCTest 同步测试默认在主 actor 上运行；Swift Testing 除非显式隔离（如 `@MainActor`），否则在任意任务上运行测试。

### 设置迁移示例

```swift
import Testing

struct SessionTests {
	let session: Session

	init() {
		self.session = Session(environment: .test)
	}

	@Test func startsDisconnected() {
		#expect(session.isConnected == false)
	}
}
```

## 异步迁移要点

- 对异步 API 直接使用 `await`。
- 用 `withCheckedContinuation`/`withCheckedThrowingContinuation` 转换完成处理器 API。
- 测试异步事件流时用确认替代 `XCTestExpectation` 模式。

### 期望式流程 -> 确认

```swift
import Testing

@Test func receivesAtLeastOneEvent() async {
	await confirmation("Receives event", expectedCount: 1...) { confirm in
		confirm()
	}
}
```

## 迁移卫生

- 优先采用机械的、可评审的提交。
- 使用编辑器的模式替换来加速常见断言转换。
- 避免在 Swift Testing 测试中混入 XCTest 断言（反之亦然）。

## 常见陷阱

- 一次性迁移所有文件而非分阶段迁移。
- 保留 `continueAfterFailure` 模式而非使用针对性的 `#require`。
- 不必要地为每个迁移的测试标注 `@MainActor`。
