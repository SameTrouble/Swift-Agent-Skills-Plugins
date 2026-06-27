# 从 XCTest 迁移

如果项目有使用 XCTest 编写的现有测试，除非被要求，否则*不要*重写为 Swift Testing。即使被要求，也要记住 XCTest 支持 UI 测试，而 Swift Testing 不支持。

XCTest 中的大多数内容在 Swift Testing 中都有直接对应：

- `XCTAssertEqual(a, b)` 对应 `#expect(a == b)`
- `XCTAssertLessThan(a, b)` 对应 `#expect(a < b)`
- `XCTAssertThrowsError` 对应 `#expect(throws:)`
- `XCTUnwrap(optional)` 对应 `try #require(optional)`——两者都解包或失败，但 `#require` 也适用于任何布尔条件。
- `XCTFail("message")` 对应 `Issue.record("message")`——用于手动记录测试失败。
- `XCTAssertIdentical(a, b)` 对应 `#expect(a === b)`——用于检查两个引用是否指向同一个对象实例。

……等等。

然而，Swift Testing *不*提供内置的浮点数容差，用于检查两个浮点值是否*足够接近*以被视为相同。

为此，你必须引入 Apple 的 Swift Numerics 库并使用其 `isApproximatelyEqual(to:absoluteTolerance:)` 方法，如下所示：

```swift
#expect(celsius.isApproximatelyEqual(to: 0, absoluteTolerance: 0.000001))
```

**重要：** 除非项目中已经导入了该库，否则在未事先征得用户许可的情况下，*不要*将 Swift Numerics 添加为库。


## 从 XCTest 转换为 Swift Testing

如果你的任务是将 XCTest 代码转换为 Swift Testing，你应该：

1. 首先保持相同的大体结构：相同的类型名称（只是从类变为结构体），相同的测试方法（只是从名称中移除 `test` 并改用 `@Test`），将旧式断言切换为新式期望。
2. 寻找参数化测试可以减少测试代码或提高覆盖率的地方。
3. 在测试开头添加适当的 `#require` 检查作为前置条件。
4. 最后在适当的地方添加 trait——`.timeLimit()`、`.enabled(if:)`、`.tags()` 等，以替换 XCTest 的约定，例如跳过测试。
