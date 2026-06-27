# 从 XCTest 迁移到 Swift Testing

如何将现有 XCTest 测试迁移到 Swift Testing。

## 快速参考

| XCTest | Swift Testing |
|--------|---------------|
| `class FooTests: XCTestCase` | `@Suite struct FooTests` |
| `func testFoo()` | `@Test func foo()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertFalse(x)` | `#expect(!x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertNotNil(x)` | `#expect(x != nil)` 或 `try #require(x)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `XCTFail("message")` | `Issue.record("message")` |
| `XCTSkip("reason")` | 测试特质 `.disabled("reason")` |
| `setUp()` | `init()` |
| `tearDown()` | `deinit` |

## 基本测试迁移

### 之前（XCTest）

```swift
import XCTest

class UserTests: XCTestCase {
    func testUserCreation() {
        let user = User(name: "Alice")
        XCTAssertEqual(user.name, "Alice")
        XCTAssertNotNil(user.id)
    }
}
```

### 之后（Swift Testing）

```swift
import Testing

@Suite struct UserTests {
    @Test func userCreation() throws {
        let user = User(name: "Alice")
        #expect(user.name == "Alice")
        let id = try #require(user.id)
        #expect(!id.isEmpty)
    }
}
```

## 断言迁移

### 相等性

```swift
// XCTest
XCTAssertEqual(result, expected)
XCTAssertEqual(result, expected, "Custom message")

// Swift Testing
#expect(result == expected)
#expect(result == expected, "Custom message")
```

### 布尔值

```swift
// XCTest
XCTAssertTrue(condition)
XCTAssertFalse(condition)

// Swift Testing
#expect(condition)
#expect(!condition)
```

### Nil 检查

```swift
// XCTest
XCTAssertNil(optional)
XCTAssertNotNil(optional)

// Swift Testing
#expect(optional == nil)
#expect(optional != nil)

// 或使用 #require 解包
let value = try #require(optional)
```

### 错误测试

```swift
// XCTest
XCTAssertThrowsError(try riskyOperation()) { error in
    XCTAssertEqual(error as? MyError, .specific)
}

XCTAssertNoThrow(try safeOperation())

// Swift Testing
#expect(throws: MyError.specific) {
    try riskyOperation()
}

#expect(throws: Never.self) {
    try safeOperation()
}
```

## Setup 和 Teardown

### 之前（XCTest）

```swift
class DatabaseTests: XCTestCase {
    var database: Database!

    override func setUp() {
        super.setUp()
        database = Database.inMemory()
    }

    override func tearDown() {
        database.close()
        database = nil
        super.tearDown()
    }

    func testInsert() {
        database.insert(record)
    }
}
```

### 之后（Swift Testing）

```swift
@Suite struct DatabaseTests {
    let database: Database

    init() throws {
        database = try Database.inMemory()
    }

    @Test func insert() {
        database.insert(record)
    }
}
```

## 异步测试

### 之前（XCTest）

```swift
func testAsyncFetch() async throws {
    let result = try await service.fetch()
    XCTAssertFalse(result.isEmpty)
}

// 或使用 expectation
func testAsyncWithExpectation() {
    let expectation = XCTestExpectation(description: "Fetch")

    service.fetch { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5)
}
```

### 之后（Swift Testing）

```swift
@Test func asyncFetch() async throws {
    let result = try await service.fetch()
    #expect(!result.isEmpty)
}

// 回调使用 confirmation
@Test func asyncWithConfirmation() async {
    await confirmation { confirm in
        service.fetch { result in
            #expect(result != nil)
            confirm()
        }
    }
}
```

## 参数化测试

### 之前（XCTest）

```swift
func testValidEmails() {
    let validEmails = ["a@b.com", "test@example.org"]
    for email in validEmails {
        XCTAssertTrue(EmailValidator.isValid(email), "\(email) should be valid")
    }
}
```

### 之后（Swift Testing）

```swift
@Test(arguments: ["a@b.com", "test@example.org"])
func validEmail(email: String) {
    #expect(EmailValidator.isValid(email))
}
```

## 跳过测试

### 之前（XCTest）

```swift
func testPlatformSpecific() throws {
    #if !os(iOS)
    throw XCTSkip("iOS only")
    #endif
    // 测试代码
}
```

### 之后（Swift Testing）

```swift
@Test(.enabled(if: Platform.isIOS, "iOS only"))
func platformSpecific() {
    // 测试代码
}

// 或
@Test(.disabled("Not implemented yet"))
func futureFeature() { }
```

## 测试组织

### 之前（XCTest）

```swift
class CartTests: XCTestCase {
    // 通过注释分组测试
    // MARK: - Adding Items
    func testAddSingleItem() { }
    func testAddMultipleItems() { }

    // MARK: - Removing Items
    func testRemoveItem() { }
}
```

### 之后（Swift Testing）

```swift
@Suite("Cart")
struct CartTests {
    @Suite("Adding Items")
    struct AddingTests {
        @Test func singleItem() { }
        @Test func multipleItems() { }
    }

    @Suite("Removing Items")
    struct RemovingTests {
        @Test func removeItem() { }
    }
}
```

## 迁移策略

1. **从叶子测试开始**：不依赖 XCTest 基础设施的测试
2. **一次迁移一个文件**：保持变更可审查
3. **同时运行两者**：XCTest 和 Swift Testing 可以共存
4. **更新 CI 配置**：确保迁移期间两者都被运行
5. **完全迁移后移除 XCTest**：清理导入和依赖

## 共存

同一项目中可以同时存在两个框架：

```swift
// XCTest（现有）
import XCTest
class OldTests: XCTestCase { }

// Swift Testing（新）
import Testing
@Suite struct NewTests { }
```

两者都会被 `swift test` 发现并运行。
