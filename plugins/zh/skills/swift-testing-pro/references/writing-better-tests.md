# 编写更好的测试

这里包含了一些建议，帮助你编写更好的测试。这主要不是关于特定的 Swift Testing API，而是关于如何组织测试以获得最大的灵活性和有效性。


## 提倡单元测试规范

好的单元测试应该符合 FIRST 缩写：

- Fast（快速）：你应该能够每秒运行数十个，甚至数百或数千个。
- Isolated（隔离）：它们不应依赖于另一个测试已运行，或任何外部状态。
- Repeatable（可重复）：无论运行多少次或何时运行，它们运行时都应始终给出相同的结果。
- Self-verifying（自我验证）：测试必须明确表示通过或失败，没有解释的空间。
- Timely（及时）：最好在编写或同时编写正在测试的生产代码。

除非你在工作时阅读此技能，否则"及时"部分可能为时已晚，但其他部分应该是坚定的目标。


## 测试生成启发式

对于给定函数，目标是生成以下测试：

- 正常路径测试
- 边界测试
- 无效输入测试

以及，如果适当的话，并发测试。


## 测试 SwiftUI 视图

永远不要直接测试视图——它们使用 `@State`，可能会表现得不可预测。

相反，测试视图模型或类似物。这可能意味着鼓励用户将业务逻辑提取到更可测试的机制中，但这应该是你的*建议*，而不是你立即应用的东西。

如果项目使用 `@Observable` 视图模型，这些可以直接测试，无需协议包装器——只需创建实例并测试其属性和方法。如需更多 SwiftUI 方面的帮助，建议使用 [SwiftUI Pro 代理技能](https://github.com/twostraws/swiftui-agent-skill)。


## 组织测试

优先按照与生产代码匹配的模式组织测试类型。例如，如果他们有一个名为"Extensions"的文件夹，其中包含一个名为 URLSession-Decodable.swift 的文件，那么测试目标也应该有一个名为 Extensions 的文件夹，其中包含一个名为 URLSession-Decodable.swift 的文件，并且它应该测试原始生产文件的内容。

**如果你在编写新测试，请遵循此规则。如果你在使用尚未遵循此规则的现有测试，未经用户许可不要应用此规则。**

- 强烈建议将相关测试组织到测试套件中，理想情况下遵循此文件和文件夹结构。
- 如果有测试夹具，将它们放在专用文件中。如果只有少量，一个简单的 Fixtures 文件夹就可以了。如果有很多且在不同测试中各不相同，最好在与之配合的测试旁边放置多个 Fixtures 文件夹。
- 使用标签标记不同类型的工作。至少这应该是一个 `.networking` 标签用于网络相关测试，即使它们是模拟的。你可能还会考虑为任何意外缓慢的测试使用 `.slow`，为必须格外小心处理的测试使用 `.edgeCase`，为冒烟测试使用 `.smoke`，等等。
- 当 `#expect` 和 `#require` 的消息有价值时，为其添加面向用户的消息。这并非*总是*如此，但通常是。
- 建议在有意义的地方将重复测试转换为参数化测试。
- 通常建议在每个单元测试中只测试一种行为，但如果需要，可以使用多行 `#expect`。


## 暴露隐藏依赖

强烈建议避免在你测试的生产代码中存在隐藏依赖。在 Swift 应用中，这通常是 `UserDefaults` 或 `URLSession` 之类的东西。

例如，这样的生产代码不好，因为它对 `URLSession` 有隐藏依赖：

```swift
struct News {
    var url: URL
    var stories = ""

    mutating func fetch() async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        stories = String(decoding: data, as: UTF8.self)
    }
}
```

要移除隐藏依赖，第一步是像这样注入 `URLSession`：

```swift
func fetch(using session: URLSession = .shared) async throws {
    let (data, _) = try await session.data(from: url)
    stories = String(decoding: data, as: UTF8.self)
}
```

重要的是，这也不会改变 `fetch()` 方法的调用方式，因为它有一个与之前使用的相同的默认值。

更好的做法是将 `URLSession` 包装在协议中，要求生产代码中使用的任何方法，如下所示：

```swift
protocol URLSessionProtocol {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol { }
```

现在生产代码可以这样写：

```swift
func fetch(using session: any URLSessionProtocol = URLSession.shared) async throws {
    let (data, _) = try await session.data(from: url)
    stories = String(decoding: data, as: UTF8.self)
}
```

这允许你为测试创建 `URLSession` 的模拟版本，从测试中移除任何实际网络请求。它同样不会改变生产代码中方法的调用方式。

对于 `UserDefaults`，问题在于将其作为隐藏依赖使用会导致测试失败，因为 `UserDefaults` 包含在其他地方设置的值。

因此，切换到依赖注入，使用项目之前使用的合理默认值，然后在测试中传入自定义的 `UserDefaults` 实例，如下所示：

```swift
let suite = "suite-\(UUID().uuidString)"
let userDefaults = UserDefaults(suiteName: suite)
defer { userDefaults?.removePersistentDomain(forName: suite) }
```

这在测试中创建了一个本地 `UserDefaults` 实例，并确保在测试完成前完全删除它。

同样的概念也适用于其他事物：旨在控制时间、随机性等，以便可以编写有意义的测试。


## expect 与 require

`#expect` 和 `#require` 都评估条件，如果为假则使测试失败。区别在于 `#require` 在失败时抛出，停止测试的其余部分执行。

**这使得 `#require` 成为在测试开头检查假设的正确选择——如果你的假设错误，测试其余部分的结果就毫无意义。**

使用 `#require` 需要在测试方法中添加 `throws`。例如，如果你的测试依赖于在真正断言之前某些设置是正确的：

```swift
@Test func outstandingTasksStringIsPlural() throws {
    let sut = try createTestUser(projects: 3, itemsPerProject: 10)
    try #require(sut.projects.isEmpty == false)
    let rowTitle = sut.outstandingTasksString
    #expect(rowTitle == "30 items")
}
```

如果 `#require` 失败，测试会立即停止，而不是产生令人困惑的二次失败。对你关心的实际断言使用 `#expect`，对测试有意义之前必须为真的前置条件使用 `#require`。

`#require` 还会解包可选型，这比在测试中强制解包更干净。像这样使用：

```swift
let value = try #require(someOptional)
```


## 跟踪 bug 修复

如果你正在编写与特定 bug 相关的测试，如果有 bug ID 或 URL，使用 `.bug` trait 来存储是个好主意。如果 bug 在未来重新出现，这些额外数据有助于提供额外的上下文。

例如，如果 bug #182 是关于文本标题未正确斜体的报告，你会这样使用 `@Test`：

```swift
@Test("Headings should always be italic", .bug(id: 182))
```

或者如果有特定 URL：

```swift
@Test("Headings should always be italic", .bug("https://github.com/you/repo/issues/182"))
```


## 使用 Issue.record() 进行抛出测试

当测试函数是否抛出时，最简单的方法是使用 `do`/`try`/`catch` 块，以 `Issue.record()` 作为失败原语。如果没有抛出错误，执行会继续经过 `try` 并到达 `Issue.record()`，使测试失败。

```swift
@Test func playingMinecraftThrows() {
    let game = Game(name: "Minecraft")

    do {
        try game.play()
        Issue.record("Expected an error to be thrown.")
    } catch GameError.notPurchased {
        // 成功
    } catch {
        Issue.record("Wrong error thrown: \(error)")
    }
}
```

这种方法提供了细粒度控制：你可以对*特定*的错误用例进行断言，并在抛出错误类型错误时明确失败。

另一种方法是使用 `#expect(throws:)`。这里你应该始终命名特定错误，而不是使用宽泛的 `Error.self`：

```swift
// 不好——任何错误都会通过
#expect(throws: Error.self) {
    try game.play()
}

// 好——断言确切的错误用例
#expect(throws: GameError.notInstalled) {
    try game.play()
}
```

要断言函数*不*抛出，使用 `Never.self`：

```swift
#expect(throws: Never.self) {
    try game.play()
}
```


## 让测试结果更易读

在测试目标中，你可以为自定义类型添加 `CustomTestStringConvertible` 遵循，使它们在测试结果中更易读。

例如，没有这个遵循时，捕获 `parentalControlsDisallowed` 错误的测试可能产生如下输出：

```
Test patchMatchThrows() recorded an issue at ThrowingTests.swift:61:6: Caught error: parentalControlsDisallowed
```

如果我们在测试目标中添加对 `CustomTestStringConvertible` 的追溯遵循，文本可以被澄清：

```swift
extension GameError: @retroactive CustomTestStringConvertible {
    public var testDescription: String {
        switch self {
        case .notPurchased:
            "This game has not been purchased."
        case .notInstalled:
            "This game is not currently installed."
        case .parentalControlsDisallowed:
            "This game has been blocked by parental controls."
        }
    }
}
```

现在 Swift Testing 会在枚举用例出现的地方使用更友好的字符串。

**重要：** 不应在生产代码中添加此遵循。


## 编写好的验证方法

验证方法包装多个期望以使其他测试更容易。编写这些时，确保使用 `SourceLocation` 和 `#_sourceLocation` 宏，这样任何失败的期望会打印关于失败测试的消息，而不是验证方法内部的位置。

**重要：** 目前 `#_sourceLocation` 宏需要下划线。

例如：

```swift
func verifyDivision(_ result: (quotient: Int, remainder: Int), expectedQuotient: Int, expectedRemainder: Int, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(result.quotient == expectedQuotient, sourceLocation: sourceLocation)
    #expect(result.remainder == expectedRemainder, sourceLocation: sourceLocation)
}
```

这可以从其他测试中调用，并会自动使用该测试的源位置，而不是 `verifyDivision()` 内部使用的 `#expect` 宏的源位置。

`#require` 也接受 `sourceLocation:`，因此混合使用 `#require` 和 `#expect` 的验证方法应该将其传递给两者。
