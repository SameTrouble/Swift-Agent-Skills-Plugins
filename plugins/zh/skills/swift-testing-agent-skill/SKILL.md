---
name: swift-testing
description: 'Swift Testing 最佳实践、模式和实现的专家指导。在开发者提到以下内容时使用：(1) Swift Testing、@Test、#expect、#require 或 @Suite，(2) "使用 Swift Testing" 或 "现代测试模式"，(3) 测试替身、mock、stub、spy 或夹具，(4) 单元测试、集成测试或快照测试，(5) 从 XCTest 迁移到 Swift Testing，(6) TDD、Arrange-Act-Assert 或 F.I.R.S.T. 原则，(7) 参数化测试或测试组织。'
---
# Swift Testing

## 概览

本技能提供关于 Swift Testing 的专家指导，涵盖现代 Swift Testing 框架、测试替身（mock、stub、spy）、夹具、集成测试、快照测试以及从 XCTest 迁移。使用本技能帮助开发者编写遵循 F.I.R.S.T. 原则和 Arrange-Act-Assert 模式的可靠、可维护测试。

## 代理行为契约（遵循这些规则）

1. 所有新测试使用 Swift Testing 框架（`@Test`、`#expect`、`#require`、`@Suite`），而非 XCTest。
2. 始终以清晰的 Arrange-Act-Assert 阶段组织测试。
3. 遵循 F.I.R.S.T. 原则：Fast（快速）、Isolated（隔离）、Repeatable（可重复）、Self-Validating（自我验证）、Timely（及时）。
4. 按照 Martin Fowler 的分类法使用正确的测试替身术语（Dummy、Fake、Stub、Spy、SpyingStub、Mock）。
5. 将夹具放在模型附近，使用 `#if DEBUG`，不要放在测试 target 中。
6. 将测试替身放在接口附近，使用 `#if DEBUG`，不要放在测试 target 中。
7. 优先使用状态验证而非行为验证——测试更简单、更不易碎。
8. 使用 `#expect` 进行软断言（失败后继续）和 `#require` 进行硬断言（失败即停止）。

## 快速决策树

当开发者需要测试指导时，遵循此决策树：

1. **刚开始使用 Swift Testing？**
   - 阅读 `references/test-organization.md` 了解套件、标签、特质
   - 阅读 `references/async-testing.md` 了解异步测试模式

2. **需要创建测试数据？**
   - 阅读 `references/fixtures.md` 了解夹具模式和放置位置
   - 阅读 `references/test-doubles.md` 了解 mock/stub/spy 模式

3. **测试多个输入？**
   - 阅读 `references/parameterized-tests.md` 了解参数化测试

4. **测试模块交互？**
   - 阅读 `references/integration-testing.md` 了解集成测试模式

5. **测试 UI 回归？**
   - 阅读 `references/snapshot-testing.md` 了解快照测试设置

6. **测试数据结构或状态？**
   - 阅读 `references/dump-snapshot-testing.md` 了解基于文本的快照测试

7. **从 XCTest 迁移？**
   - 阅读 `references/migration-xctest.md` 了解迁移指南

## 分诊优先手册（常见问题 -> 最佳下一步）

- "XCTAssertEqual is unavailable" / 需要现代化测试
  - 使用 `references/migration-xctest.md` 进行 XCTest 到 Swift Testing 的迁移
- 需要测试异步代码
  - 使用 `references/async-testing.md` 了解异步模式、confirmation、超时
- 测试缓慢或不稳定
  - 检查 F.I.R.S.T. 原则，按 `references/test-doubles.md` 使用正确的 mock
- 需要确定性的测试数据
  - 使用 `references/fixtures.md` 了解带固定日期的夹具模式
- 需要高效测试多个场景
  - 使用 `references/parameterized-tests.md` 了解参数化测试
- 需要验证组件交互
  - 使用 `references/integration-testing.md` 了解集成测试模式

## 核心语法

### 基本测试

```swift
import Testing

@Test func basicTest() {
    #expect(1 + 1 == 2)
}
```

### 带描述的测试

```swift
@Test("Adding items increases cart count")
func addItem() {
    let cart = Cart()
    cart.add(item)
    #expect(cart.count == 1)
}
```

### 异步测试

```swift
@Test func asyncOperation() async throws {
    let result = try await service.fetch()
    #expect(result.isValid)
}
```

## Arrange-Act-Assert 模式

每个测试都用清晰的阶段来组织：

```swift
@Test func calculateTotal() {
    // Given
    let cart = ShoppingCart()
    cart.add(Item(price: 10))
    cart.add(Item(price: 20))

    // When
    let total = cart.calculateTotal()

    // Then
    #expect(total == 30)
}
```

## 断言

### #expect - 软断言

失败后继续执行测试：

```swift
@Test func multipleExpectations() {
    let user = User(name: "Alice", age: 30)
    #expect(user.name == "Alice")  // 如果失败，测试继续
    #expect(user.age == 30)        // 这行仍会执行
}
```

### #require - 硬断言

失败即停止测试执行：

```swift
@Test func requireExample() throws {
    let user = try #require(fetchUser())  // 如果为 nil 则停止
    #expect(user.name == "Alice")
}
```

### 错误测试

```swift
@Test func throwsError() {
    #expect(throws: ValidationError.self) {
        try validate(invalidInput)
    }
}

@Test func throwsSpecificError() {
    #expect(throws: ValidationError.emptyField) {
        try validate("")
    }
}
```

## F.I.R.S.T. 原则

| 原则 | 描述 | 应用 |
|------|------|------|
| **Fast（快速）** | 测试在毫秒级执行 | Mock 昂贵的操作 |
| **Isolated（隔离）** | 测试之间不相互依赖 | 每个测试使用全新实例 |
| **Repeatable（可重复）** | 每次结果相同 | Mock 日期、网络、外部依赖 |
| **Self-Validating（自我验证）** | 自动报告通过/失败 | 使用 `#expect`，不要依赖 `print()` |
| **Timely（及时）** | 与代码同步编写测试 | 对边界情况使用参数化测试 |

## 测试替身快速参考

依据 [Martin Fowler 的定义](https://martinfowler.com/articles/mocksArentStubs.html)：

| 类型 | 用途 | 验证方式 |
|------|------|----------|
| **Dummy** | 填充参数，从不使用 | 无 |
| **Fake** | 带捷径的工作实现 | 状态 |
| **Stub** | 提供预设答案 | 状态 |
| **Spy** | 记录调用以供验证 | 状态 |
| **SpyingStub** | Stub + Spy 组合（最常见） | 状态 |
| **Mock** | 预设期望，自我验证 | 行为 |

**重要**：Swift 社区所说的 "Mock" 通常是 **SpyingStub**。

详细模式见 `references/test-doubles.md`。

## 测试替身放置位置

将测试替身放在**接口附近**，而非测试 target 中：

```swift
// 在 PersonalRecordsCore-Interface/Sources/...

public protocol PersonalRecordsRepositoryProtocol: Sendable {
    func getAll() async throws -> [PersonalRecord]
    func save(_ record: PersonalRecord) async throws
}

#if DEBUG
public final class PersonalRecordsRepositorySpyingStub: PersonalRecordsRepositoryProtocol {
    // Spy：捕获调用
    public private(set) var savedRecords: [PersonalRecord] = []

    // Stub：可配置的响应
    public var recordsToReturn: [PersonalRecord] = []
    public var errorToThrow: Error?

    public func getAll() async throws -> [PersonalRecord] {
        if let error = errorToThrow { throw error }
        return recordsToReturn
    }

    public func save(_ record: PersonalRecord) async throws {
        if let error = errorToThrow { throw error }
        savedRecords.append(record)
    }
}
#endif
```

## 夹具

将夹具放在**模型附近**：

```swift
// 在 Sources/Models/PersonalRecord.swift

public struct PersonalRecord: Equatable, Sendable {
    public let id: UUID
    public let weight: Double
    // ...
}

#if DEBUG
extension PersonalRecord {
    public static func fixture(
        id: UUID = UUID(),
        weight: Double = 100.0
        // ... 为所有属性提供默认值
    ) -> PersonalRecord {
        PersonalRecord(id: id, weight: weight)
    }
}
#endif
```

详细模式见 `references/fixtures.md`。

## 测试金字塔

```
        +-------------+
        |   UI Tests  |  5%  - 端到端流程
        |   (E2E)     |
        +-------------+
        | Integration |  15% - 模块交互
        |    Tests    |
        +-------------+
        |    Unit     |  80% - 单个组件
        |    Tests    |
        +-------------+
```

## 参考文件

根据特定主题按需加载这些文件：

- **`test-organization.md`** - 套件、标签、特质、并行执行
- **`parameterized-tests.md`** - 高效测试多个输入
- **`async-testing.md`** - 异步模式、confirmation、超时、取消
- **`migration-xctest.md`** - 完整的 XCTest 到 Swift Testing 迁移指南
- **`test-doubles.md`** - 带示例的完整分类法（Dummy、Fake、Stub、Spy、SpyingStub、Mock）
- **`fixtures.md`** - 夹具模式、放置位置和最佳实践
- **`integration-testing.md`** - 模块交互测试模式
- **`snapshot-testing.md`** - 使用 SnapshotTesting 库进行 UI 回归测试
- **`dump-snapshot-testing.md`** - 数据结构的基于文本的快照测试

## 最佳实践总结

1. **新测试使用 Swift Testing** - 现代语法，更好的功能
2. **遵循 Arrange-Act-Assert** - 清晰的测试结构
3. **应用 F.I.R.S.T. 原则** - Fast、Isolated、Repeatable、Self-Validating、Timely
4. **夹具放在模型附近** - 使用 `#if DEBUG` 守卫
5. **测试替身放在接口附近** - 使用 `#if DEBUG` 守卫
6. **优先使用状态验证** - 比行为验证更简单、更不易碎
7. **使用参数化测试** - 高效测试多个输入
8. **遵循测试金字塔** - 80% 单元测试，15% 集成测试，5% UI 测试

## 验证清单（编写测试时）

- 测试遵循 Arrange-Act-Assert 模式
- 测试名称描述行为，而非实现
- 夹具使用合理的默认值，而非随机值
- 测试替身保持精简（只 stub 必要部分）
- 异步测试使用正确的模式（async/await、confirmation）
- 测试快速（mock 昂贵操作）
- 测试隔离（无共享状态）
- 测试可重复（无不稳定的日期/时间依赖）
