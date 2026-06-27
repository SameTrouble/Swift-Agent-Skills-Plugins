# 核心规则

Swift Testing 与 XCTest 相比仍然非常新，这意味着大多数项目使用 XCTest，同时你的大多数训练数据也是基于 XCTest 的。

本指南提供了你必须始终遵循的核心规则，以确保你自然、地道地使用 Swift Testing，而不是基于旧的训练数据给 XCTest 换皮。

**重要：** 目前 Swift Testing *不*支持 UI 测试，因此那里必须使用 XCTest。

- 在组织测试套件时，优先使用结构体而不是类。你*可以*使用类，但除非需要子类化或析构器，否则优先使用结构体。
- 代理经常为每个测试结构体添加 `@Suite`。这是不必要的：任何包含 `@Test` 方法的类型都会自动被视为测试套件。只有当你想为其命名或附加 trait 时才需要显式使用 `@Suite`，例如 `@Suite(.tags(.networking))`。
- 不应使用 XCTest 旧的 `setUp()`/`tearDown()` 方式。你可以直接在结构体中使用 `init()`，在类中使用 `init()` 和 `deinit()`，或在更高级的场景中使用测试作用域。例如：

    ```swift
    struct PlayerTests {
        let sut: Player

        init() {
            sut = Player(name: "Natsuki Subaru")
        }

        @Test func nameIsCorrect() {
            #expect(sut.name == "Natsuki Subaru")
        }
    }
    ```
- 所有测试套件必须有一个不接受参数的初始化器，这样它们才能被该套件内的测试调用。如果向测试套件添加了任何属性，它们必须有默认值，或者你必须添加一个自定义初始化器来为它们设置值。
- 测试套件初始化器可以标记为 `async` 和/或 `throws`，所有测试也是如此。
- 在 Swift Testing 中，任何单元测试或集成测试都不需要使用 `XCTestCase` 或任何形式的 `XCTAssert`。
- 你*不*需要在测试方法前加 `test` 前缀。例如，可以使用 `userCanLogOut()` 而不是 `testUserCanLogOut`。
- 随机的、并行的测试执行是 Swift Testing 的标准，因此每个测试都必须编写为可以以任何顺序、在任何时间执行。
- 参数化测试非常强大，允许测试覆盖更广泛的范围而不会大幅增加代码量，因此尽可能优先使用。但要小心：它们最多接受两个参数集合，两个集合形成笛卡尔积而不是逐对配对，因此产生的组合数量可能快速增长。如果你需要两个集合的逐对配对，请将 `zip(collection1, collection2)` 作为 `arguments` 值传入。
- Swift Testing 支持在单个测试上使用 `@available`，但*不*支持在测试套件上使用。因此，如果某个套件（例如）只包含为 iOS 26 编写的测试，请将 `@available(iOS 26, *)` 放在每个单独的测试上，而*不*是放在整个套件上。
- 如果测试执行时没有到达任何 `#expect` 或 `#require`，则视为通过。
- 你应该使用 `withKnownIssue` 来包装有已知 bug 的代码——它期望测试失败发生，如果未记录任何问题则*失败*。添加 `isIntermittent: true` 会改变语义：如果未记录问题则测试通过，但如果记录了则标记为预期失败，这对你正在积极调试的不稳定问题很有用。
- 永远不要在 `#expect` 或 `#require` 中使用 `!` 来否定布尔值，因为这会破坏 Swift Testing 的宏展开。所以 `#expect(!isLoggedIn)` 是不好的，失败时会报告无用的结果，而 `#expect(isLoggedIn == false)` 是好的，如果期望失败会被正确评估。

最后，使用 `@Tag` 创建自定义 Swift Testing 标签，如下所示：

```swift
extension Tag {
    @Tag static var networking: Self
}
```

标签让你可以跨套件对测试进行分类，这样无论测试位于何处，都可以按标签运行或过滤。在单个测试上使用 `@Test(.tags(.networking))` 或在整个套件上使用 `@Suite(.tags(.networking))` 来应用它们。例如：

```swift
@Test(.tags(.networking))
func fetchUserProfile() async throws {
    // 测试代码在此
}
```
