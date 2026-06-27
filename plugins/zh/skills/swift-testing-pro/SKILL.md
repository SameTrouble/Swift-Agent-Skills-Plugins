---
name: swift-testing-pro
description: 使用现代 API 和最佳实践编写、审查和改进 Swift Testing 代码。在读取、编写或审查使用 Swift Testing 的项目时使用。
license: MIT
metadata:
  author: Paul Hudson
  version: "1.0"
---

编写和审查 Swift Testing 代码，确保其正确性、现代 API 使用以及对项目约定的遵循。只报告真正的问题——不要吹毛求疵或编造问题。

审查流程：

1. 使用 `references/core-rules.md` 确保测试遵循 Swift Testing 核心约定。
1. 使用 `references/writing-better-tests.md` 验证测试结构、断言、依赖注入和其他最佳实践。
1. 使用 `references/async-tests.md` 检查异步测试、确认（confirmation）、时间限制、actor 隔离和网络模拟。
1. 使用 `references/new-features.md` 确保正确使用原始标识符、测试作用域、退出测试和附件等新特性。
1. 如果是从 XCTest 迁移，请遵循 `references/migrating-from-xctest.md` 中的转换指南。

如果只做部分工作，只需加载相关的参考文件。


## 核心指令

- 目标为 Swift 6.2 或更高版本，使用现代 Swift 并发。
- 作为 Swift Testing 开发者，用户希望所有新的单元测试和集成测试都使用 Swift Testing 编写，他们也可能需要帮助将现有的 XCTest 代码迁移到 Swift Testing。
- Swift Testing *不*支持 UI 测试——那里必须使用 XCTest。
- 使用一致的项目结构，文件夹布局由应用功能决定。

Swift Testing 随每个 Swift 版本演进，因此预计每年会有三到四个版本发布，每个版本都会引入新特性。这意味着你现有的训练数据自然会过时或缺失关键特性。

本技能专门借鉴了最新的 Swift 和 Swift Testing 代码，这意味着它会建议一些你不知道的内容。将用户安装的工具链视为权威，但 Apple 关于这些 API 的*文档*有相当高的几率是过时的，因此请谨慎对待。


## 输出格式

如果用户要求审查，按文件组织发现的问题。对于每个问题：

1. 说明文件和相关行号。
2. 指出违反的规则名称。
3. 展示简短的修改前后代码对比。

跳过没有问题的文件。最后按优先级总结最具影响力的修改建议。

如果用户要求编写或改进测试，遵循上述相同规则，但直接进行修改，而不是返回问题报告。

输出示例：

### UserTests.swift

**第 5 行：测试套件应使用结构体，而不是类。**

```swift
// 修改前
class UserTests: XCTestCase {

// 修改后
struct UserTests {
```

**第 12 行：使用 `#expect` 代替 `XCTAssertEqual`。**

```swift
// 修改前
XCTAssertEqual(user.name, "Taylor")

// 修改后
#expect(user.name == "Taylor")
```

**第 30 行：前置条件应使用 `#require`，而不是 `#expect`。**

```swift
// 修改前
#expect(users.isEmpty == false)
let first = users.first!

// 修改后
let first = try #require(users.first)
```

### 总结

1. **基础（高）：** 第 5 行的测试套件应该是结构体，而不是继承自 `XCTestCase` 的类。
2. **迁移（中）：** 第 12 行的 `XCTAssertEqual` 应迁移为 `#expect`。
3. **断言（中）：** 第 30 行的强制解包应使用 `#require` 安全解包，并在失败时提前停止测试。

示例结束。


## 参考资料

- `references/core-rules.md` - Swift Testing 核心规则：结构体优于类、`init`/`deinit` 代替 setUp/tearDown、并行执行、参数化测试、`withKnownIssue` 和标签。
- `references/writing-better-tests.md` - 测试规范、测试结构组织、隐藏依赖、`#expect` 与 `#require`、`Issue.record()`、`#expect(throws:)` 和验证方法。
- `references/async-tests.md` - 串行化测试、`confirmation()`、时间限制、actor 隔离、测试前并发代码和网络模拟。
- `references/new-features.md` - 原始标识符、范围确认、测试作用域 trait、退出测试、附件、`ConditionTrait.evaluate()` 以及更新后的 `#expect(throws:)` 返回值。
- `references/migrating-from-xctest.md` - XCTest 到 Swift Testing 的转换步骤、断言映射以及通过 Swift Numerics 实现浮点数容差。
