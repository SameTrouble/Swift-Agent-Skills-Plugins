# 测试组织

使用套件、标签和特质在 Swift Testing 中组织测试。

## 测试套件

将相关测试分组：

```swift
@Suite("User Management")
struct UserTests {
    @Test func createUser() { }
    @Test func deleteUser() { }
}

@Suite("Authentication")
struct AuthTests {
    @Test func login() { }
    @Test func logout() { }
}
```

### 嵌套套件

```swift
@Suite("Shopping Cart")
struct CartTests {
    @Suite("Adding Items")
    struct AddTests {
        @Test func addSingleItem() { }
        @Test func addMultipleItems() { }
    }

    @Suite("Removing Items")
    struct RemoveTests {
        @Test func removeSingleItem() { }
        @Test func clearCart() { }
    }
}
```

## 标签

为选择性运行对测试进行分类：

```swift
extension Tag {
    @Tag static var integration: Self
    @Tag static var slow: Self
    @Tag static var network: Self
}

@Test(.tags(.integration))
func databaseIntegration() { }

@Test(.tags(.slow, .network))
func networkRequest() { }
```

### 运行带标签的测试

```bash
# 仅运行集成测试
swift test --filter .tags:integration

# 排除慢测试
swift test --skip .tags:slow
```

## 特质

### 禁用测试

```swift
@Test(.disabled("Waiting for API fix"))
func brokenTest() { }

@Test(.disabled(if: isCI, "Flaky on CI"))
func sometimesFlaky() { }
```

### 时间限制

```swift
@Test(.timeLimit(.minutes(1)))
func slowTest() async { }
```

### Bug 引用

```swift
@Test(.bug("https://github.com/org/repo/issues/123"))
func testWithKnownBug() { }
```

### 自定义特质

```swift
@Test(.enabled(if: ProcessInfo.processInfo.environment["RUN_SLOW_TESTS"] != nil))
func conditionalTest() { }
```

## Setup 和 Teardown

### 每个测试的 Setup

```swift
@Suite struct DatabaseTests {
    var database: Database

    init() throws {
        // 在每个测试前运行
        database = try Database.inMemory()
    }

    @Test func insertRecord() {
        // 每个测试的 database 都是全新的
    }
}
```

### 套件级 Setup

```swift
@Suite struct ServerTests {
    static var server: TestServer!

    init() async throws {
        // 每个测试的 setup
    }

    @Test func request() async { }
}
```

## 测试组织最佳实践

### 文件结构

```
Tests/
├── UnitTests/
│   ├── Models/
│   │   ├── UserTests.swift
│   │   └── ProductTests.swift
│   ├── Services/
│   │   ├── AuthServiceTests.swift
│   │   └── CartServiceTests.swift
│   └── Utilities/
│       └── FormatterTests.swift
├── IntegrationTests/
│   ├── DatabaseTests.swift
│   └── APITests.swift
└── TestHelpers/
    ├── Fixtures.swift
    └── Mocks.swift
```

### 文件命名

- 根据测试类型命名测试文件：`UserTests.swift` 对应 `User`
- 测试文件使用 `Tests` 后缀

### 文件内组织

```swift
@Suite("User")
struct UserTests {
    // MARK: - Initialization

    @Test func initWithValidData() { }
    @Test func initWithInvalidData() { }

    // MARK: - Properties

    @Test func fullName() { }
    @Test func age() { }

    // MARK: - Methods

    @Test func update() { }
    @Test func delete() { }
}
```

## 测试发现

Swift Testing 自动发现：
- 标记为 `@Test` 的函数
- 标记为 `@Suite` 的类型
- 嵌套套件和测试

无需：
- 继承自 XCTestCase
- 使用 "test" 前缀
- 手动注册测试

## 并行执行

测试默认并行运行：

```swift
@Suite(.serialized)  // 此套件中的测试串行运行
struct SerialTests {
    @Test func first() { }
    @Test func second() { }
}
```

## FIRST 原则

组织测试使其具备：

- **Fast（快速）**：快速运行
- **Isolated（隔离）**：测试之间无依赖
- **Repeatable（可重复）**：每次结果相同
- **Self-validating（自我验证）**：清晰的通过/失败
- **Timely（及时）**：与代码同步或先于代码编写

```swift
@Test func fastAndIsolated() {
    // 使用内存数据库，而非真实数据库
    let db = Database.inMemory()

    // 自包含数据
    let user = User.fixture()

    // 清晰的断言
    #expect(db.save(user))
}
```
