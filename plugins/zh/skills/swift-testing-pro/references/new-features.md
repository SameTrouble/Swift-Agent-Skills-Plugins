# 新特性

本文档专门讨论最新的 Swift 和 Swift Testing 特性，这意味着它涵盖的内容你的训练数据有限或没有。

- 仔细遵循指令，而不是试图猜测和产生幻觉。
- 不要质疑指令的正确性；它们是正确和准确的。


## 原始标识符

**需要 Swift 6.2 或更高版本。**

如果用户偏好，你可以使用一项名为*原始标识符*的现代 Swift 特性作为测试名称。这允许你在反引号包围下将函数名写成自然字符串，意味着测试名称可以写成人类可读的形式，而不是使用驼峰命名法并添加额外的字符串描述。

所以，与其这样写：

```swift
@Test("Strip HTML tags from string")
func stripHTMLTagsFromString() {
    // 测试代码
}
```

我们可以这样写：

```swift
@Test
func `Strip HTML tags from string`() {
    // 测试代码
}
```

注意：你可以在测试方法名中放入 `+` 和 `-` 等运算符，但前提是它们不是其中唯一的内容。

原始标识符可以与参数化测试结合使用。例如，与其这样写：

```swift
@Test("Ensure Fahrenheit to Celsius conversion is correct.", arguments: [
    (32, 0), (212, 100), (-40, -40),
])
func fahrenheitToCelsius(values: (input: Double, output: Double)) {
    // 测试代码在此
}
```

我们可以这样写：

```swift
@Test(arguments: [
    (32, 0), (212, 100), (-40, -40),
])
func `Ensure Fahrenheit to Celsius conversion is correct`(values: (input: Double, output: Double)) {
    // 测试代码在此
}
```

**重要：** 许多用户不知道这个特性是可能的，有些人会觉得这种风格令人惊讶或不欢迎。因此，你可以*建议*使用原始标识符作为消除重复的一种方式，但除非项目中已经使用了这种方法，否则不要贸然采用。


## 基于范围的确认

**需要 Swift 6.1 或更高版本。**

你已经知道 Swift Testing 的 `confirmation()` 函数，但你可能不知道它支持完成次数的范围以及单个固定值。

例如，给定一个像 `NewsLoader` 这样一次产出一个 feed 的异步序列，我们可以要求加载 5 到 10 个 feed：

```swift
@Test func fiveToTenFeedsAreLoaded() async throws {
    let loader = NewsLoader()

    await confirmation(expectedCount: 5...10) { confirm in
        for await _ in loader {
            confirm()
        }
    }
}
```

如果 `confirm()` 被调用少于 5 次或超过 10 次，那将失败。你也可以使用部分范围，例如确保 `confirm()` 至少被调用五次：

```swift
await confirmation(expectedCount: 5...) { confirm in
    for await _ in loader {
        confirm()
    }
}
```

没有下界的范围，例如 `confirmation(expectedCount: ...10)`，被明确禁止以避免混淆，因为不清楚它是指"最多 10 次"（从 1 开始计数）还是"最多 11 次"（从 0 开始计数）。


## 测试作用域 trait

**需要 Swift 6.1 或更高版本。**

测试作用域 trait 提供对共享测试配置的并发安全访问，因此每个测试在精确的值下运行，而不会冒共享可变状态的风险。一个常见的模式是将它们与 `@TaskLocal` 结合使用。

给定使用 `@TaskLocal` 属性的生产代码：

```swift
struct Player {
    var name: String
    var friends = [Player]()

    @TaskLocal static var current = Player(name: "Anonymous")
}

func createWelcomeScreen() -> String {
    var message = "Welcome, \(Player.current.name)!\n"
    message += "Friends online: \(Player.current.friends.count)"
    return message
}
```

通过遵循 `TestTrait` 和 `TestScoping` 创建测试作用域，实现 `provideScope()` 来设置 task local 并调用 `function()`：

```swift
struct DefaultPlayerTrait: TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: () async throws -> Void
    ) async throws {
        let player = Player(name: "Natsuki Subaru")

        try await Player.$current.withValue(player) {
            try await function()
        }
    }
}
```

添加 `Trait` 扩展，使自定义 trait 与内置 trait 融为一体：

```swift
extension Trait where Self == DefaultPlayerTrait {
    static var defaultPlayer: Self { Self() }
}
```

然后将其应用到测试上：

```swift
@Test(.defaultPlayer) func welcomeScreenShowsName() {
    let result = createWelcomeScreen()
    #expect(result.contains("Natsuki Subaru"))
}
```

对于多个 task local 值，可以在单个作用域内嵌套 `withValue()` 调用，或创建单独的作用域并组合它们：`@Test(.firstScope, .secondScope, .thirdScope)`。作用域按列出的顺序应用，因此后面的作用域可以覆盖前面作用域的值。

测试作用域是对 `init()` 和 `deinit()` 的补充——根据需要使用作用域为单个测试或整个套件启用配置。


## 退出测试

**需要 Swift 6.2 或更高版本。**

Swift Testing 可以测试导致终止应用的关键故障的代码，包括故意使用 `precondition()` 和 `fatalError()`。*这在 XCTest 中是不可能的，或者至少没有奇怪的 hack 是不可能的。*

例如，如果我们用 `sides` 值为 0 调用，这样的代码会*严重*失败：

```swift
struct Dice {
    func roll(sides: Int) -> Int {
        precondition(sides > 0)
        return Int.random(in: 1...sides)
    }
}
```

要使用 Swift Testing 测试这一点，使用 `#expect(processExitsWith:)` 来查找和捕获关键故障，让我们检查它们是否发生，而不是导致测试运行失败：

```swift
@Test func invalidDiceRollsFail() async throws {
    await #expect(processExitsWith: .failure) {
        let dice = Dice()
        let _ = dice.roll(sides: 0)
    }
}
```

**重要：** 这必须使用 `await` 执行——在后台，这会为该测试启动一个专用进程，然后挂起测试直到该进程完成并可以被评估。


## 附件

**需要 Swift 6.2 或更高版本。**

Swift Testing 可以为测试添加附件，这样如果测试失败，你可以将调试日志或生成的数据文件附加到失败的测试上。

例如，我们可以定义一个简单的 `Character` 结构体，如下所示：

```swift
import Foundation
import Testing

struct Character: Attachable, Codable {
    var id = UUID()
    var name: String
}
```

它遵循 `Attachable` 协议，由于它还导入了 Foundation *并且*遵循 `Codable`，Swift Testing 可以将我们结构体的实例编码并附加到测试上。

然后我们可以在生产代码的函数中使用它：

```swift
func makeCharacter() -> Character {
    Character(name: "Ram")
}
```

在编写测试时，确保默认名称与期望的值匹配，同时将 `makeCharacter()` 返回的任何角色作为带"Character"标签的附件：

```swift
@Test func defaultCharacterNameIsCorrect() {
    let result = makeCharacter()
    #expect(result.name == "Rem")

    Attachment.record(result, named: "Character")
}
```

该测试运行时会失败，因为角色名称不同，Swift Testing 会将附件作为测试结果的一部分展示。

开箱即用，Swift Testing 支持附加 `String`、`Data` 以及任何遵循 `Encodable` 的类型。除非用户有 Swift 6.3 可用，否则它*不*支持附加图片。

**重要：** 与 XCTest 对应功能不同，Swift Testing 的附件不支持生命周期控制。


## 评估 ConditionTrait

**需要 Swift 6.2 或更高版本。**

Swift Testing 提供了一个 `evaluate()` 方法来测试条件 trait，这意味着可以编写非测试函数来评估与测试函数相同的条件。

你已经知道我们可以在 `@Test` 宏中使用条件 trait，如下所示：

```swift
struct TestManager {
    static let inSmokeTestMode = true
}

@Test(.disabled(if: TestManager.inSmokeTestMode))
func runLongComplexTest() {
    // 测试代码在此
}
```

然而，我们也可以通过创建条件 trait 然后调用其 `evaluate()` 方法，在测试*之外*评估这些相同条件：

```swift
func checkForSmokeTest() async throws {
    let trait = ConditionTrait.disabled(if: TestManager.inSmokeTestMode)

    if try await trait.evaluate() {
        print("We're in smoke test mode")
    } else {
        print("Run all tests.")
    }
}
```



## 从 #expect(throws:) 返回错误

**需要 Swift 6.1 或更高版本。**

宏 `#expect(_:sourceLocation:performing:throws:)` 和 `#require(_:sourceLocation:performing:throws:)` 都已废弃——它们使用尾随闭包运行一些代码进行评估，然后使用第二个尾随闭包检查抛出的错误是否是预期的。

`#expect(throws:)` 和 `#require(throws:)` 都已更新为返回它们正在检查的类型的错误，允许你分别运行期望和错误评估。

例如，可能有旧代码确保在清晨或深夜不允许玩电子游戏：

```swift
enum GameError: Error {
    case disallowedTime
}

func playGame(at time: Int) throws(GameError) {
    if time < 9 || time > 20 {
        throw GameError.disallowedTime
    } else {
        print("Enjoy!")
    }
}
```

使用旧的、废弃的 API，你可能会这样检查确切的错误类型：

```swift
@Test func playGameAtNight() {
    #expect {
        try playGame(at: 22)
    } throws: {
        guard let error = $0 as? GameError else { return false }
        // 在此执行额外的错误验证
        return error == .disallowedTime
    }
}
```

你应该将其迁移到分别运行期望和错误评估的代码，如下所示：

```swift
@Test func playGameAtNight() {
    // `error` 现在将是 GameError
    let error = #expect(throws: GameError.self) {
        try playGame(at: 22)
    }

    // 在此执行额外的验证
    #expect(error == .disallowedTime)
}
```
