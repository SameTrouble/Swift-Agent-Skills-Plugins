# 期望（断言）

## 何时使用此参考

在编写断言、从 `XCTAssert*` 迁移、测试抛出的错误或记录已知失败时使用此文件。

## `#expect` 作为默认

- 大多数断言使用 `#expect`。
- 传入自然的 Swift 表达式（`==`、`>`、`.contains`、`.isEmpty` 等）。
- 依赖 Xcode 中捕获的子表达式值来获得丰富诊断。
- 在 Swift Testing 测试中避免使用旧的 XCTest 断言家族。

### 示例：富有表现力的断言

```swift
import Testing

@Test func pricingRules() {
	let subtotal = 25
	let discount = 5
	let total = subtotal - discount

	#expect(total == 20)
	#expect(total > 0)
	#expect([10, 20, 30].contains(total))
}
```

## `#require` 用于前置条件

- 当后续断言依赖此条件时使用 `try #require(...)`。
- 将 `#require` 视为"guard + 提前失败"。
- 使用返回值安全解包可选值，减少嘈杂的可选链。
- 当失败应中止测试流程时，优先使用此模式而非手动可选检查。

### 示例：可选前置条件 + 解包使用

```swift
import Testing

@Test func parsedURLHasHTTPS() throws {
	let value = "https://www.avanderlee.com"
	let url = try #require(URL(string: value), "URL should parse")
	#expect(url.scheme == "https")
}
```

## 抛出行为检查

- 对抛出函数的成功路径调用，直接调用并断言返回值。
- 对预期失败，使用感知抛出的期望来验证：
  - 任何抛出
  - 特定错误类型
  - 特定错误用例/值
- 除非确实需要自定义分支，否则避免冗长的手写 `do/catch`。

### 示例：预期抛出与不抛出

```swift
import Testing

enum BrewError: Error, Equatable {
	case missingBeans
}

func brew(_ hasBeans: Bool) throws -> String {
	guard hasBeans else { throw BrewError.missingBeans }
	return "coffee"
}

@Test func expectedThrows() {
	#expect(throws: BrewError.self) {
		try brew(false)
	}
}

@Test func expectedNoThrow() {
	#expect(throws: Never.self) {
		try brew(true)
	}
}
```

## 已知问题处理

- 对你仍希望编译/运行的临时预期失败使用 `withKnownIssue`。
- 当需要持续可见性时，优先使用 `withKnownIssue` 而非全面禁用。
- 一旦失败条件被修复，移除已知问题包装。

### 示例：仅限定失败部分

```swift
import Testing

@Test func checkoutFlow() {
	#expect(true) // 仍然被验证

	withKnownIssue("Checkout backend intermittently returns 503", isIntermittent: true) {
		Issue.record("Known upstream issue")
	}

	#expect(2 + 2 == 4) // 测试其余部分仍执行
}
```

## 可读性提升

- 让复杂的领域类型遵循 `CustomTestStringConvertible` 以获得简洁的测试输出。
- 需要时将生产代码的 `CustomStringConvertible` 与测试专用描述分开。

### 示例：清晰的诊断描述

```swift
import Testing

struct Receipt: CustomTestStringConvertible {
	let id: UUID
	let total: Decimal

	var testDescription: String {
		"Receipt(total: \(total))"
	}
}
```

## XCTest 映射快速示例

```swift
// XCTAssertEqual(total, 20)
#expect(total == 20)

// try XCTUnwrap(user)
let user = try #require(user)

// XCTFail("Unreachable")
Issue.record("Unreachable")
```

## 应做 / 不应做

- 应做：当后续检查依赖某个值时使用 `#require`。
- 应做：保持 `withKnownIssue` 作用域狭窄。
- 不应做：在 Swift Testing 测试中使用 XCTest 断言。
- 不应做：将前置条件失败隐藏在后续可选链中。
