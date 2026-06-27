# Swift

- 优先使用 Swift 原生字符串方法而非 Foundation 等价方法：使用 `replacing("a", with: "b")` 而非 `replacingOccurrences(of: "a", with: "b")`。
- 优先使用现代 Foundation API：使用 `URL.documentsDirectory` 而非 `FileManager` 目录查找，使用 `appending(path:)` 向 URL 追加字符串。
- 永远不要使用 C 风格的数字格式化，如 `String(format: "%.2f", value)`。使用 `Text(value, format: .number.precision(.fractionLength(2)))` 或类似的 `FormatStyle` API。
- 尽可能优先使用静态成员查找而非结构体实例，如 `.circle` 而非 `Circle()`，`.borderedProminent` 而非 `BorderedProminentButtonStyle()`。
- 避免强制解包（`!`）和强制 `try`，除非失败确实不可恢复；即便如此，也优先使用带清晰描述的 `fatalError()`。如果可能，使用 `if let`、`guard let`、nil 合并运算符，或 `try?`/`do-catch`。
- 基于用户输入的文本过滤必须使用 `localizedStandardContains()`，而非 `contains()` 或 `localizedCaseInsensitiveContains()`。
- 强烈优先使用 `Double` 而非 `CGFloat`，使用可选型或 `inout` 时除外；Swift 能够在除这两种情况外自由桥接两者。
- 如果你想计算匹配某个谓词的数组对象数量，始终使用 `count(where:)` 而非 `filter()` 后跟 `count`。
- 为清晰起见，优先使用 `Date.now` 而非 `Date()`。
- 当文件中已有 `import SwiftUI` 时，无需添加 `import UIKit` 或 `import AppKit` 来访问 `UIImage` 或 `NSImage` 等内容——它们会在相应平台自动导入。
- 处理人名时，强烈优先使用 `PersonNameComponents` 配合现代格式化，而非简单的字符串插值，如 `Text("\(firstName) \(lastName)")`。
- 如果某类数据反复使用相同的闭包进行排序，如 `books.sorted { $0.author < $1.author }`，优先让该类型遵循 `Comparable`，以便集中管理排序顺序。
- 尽可能避免手动日期格式化字符串。如果手动日期格式化*确实*用于用户显示，至少确保使用"y"而非"yyyy"来表示年份，以便年份值在所有本地化中正确。如果目的是与 API 进行数据交换，此规则不适用。
- 尝试将字符串转换为日期时，优先使用现代 `Date` 初始化器 API，如 `Date(myString, strategy: .iso8601)`。
- 标记由用户操作触发的错误被静默吞没的情况，例如使用 `print(error.localizedDescription)` 而非显示提醒或类似方式。
- 优先使用 `if let value {` 简写而非 `if let value = value {`。
- 单表达式函数省略 return。`if` 和 `switch` 在返回值和赋值给变量时可用作表达式。

例如，这类代码：

```swift
var tileColor: Color {
    if isCorrect {
        return .green
    } else {
        return .red
    }
}
```

应该这样编写：

```swift
var tileColor: Color {
    if isCorrect {
        .green
    } else {
        .red
    }
}
```


## Swift 并发

- 如果 API 同时提供现代 `async`/`await` 等价方法和较旧的基于闭包的变体，始终优先使用 `async`/`await` 版本。
- 永远不要使用 Grand Central Dispatch（`DispatchQueue.main.async()`、`DispatchQueue.global()` 等）。始终使用现代 Swift 并发（`async`/`await`、actor、`Task`）。
- 永远不要使用 `Task.sleep(nanoseconds:)`；改用 `Task.sleep(for:)`。
- 标记任何未被 actor 或 `@MainActor` 保护的可变共享状态，除非项目已配置使用 MainActor 默认 actor 隔离。
- 假设正在应用严格并发规则；标记 `@Sendable` 违规和数据竞争。
- 评估 `MainActor.run()` 时，首先检查项目是否已将默认 actor 隔离设为 Main Actor，因为可能不需要 `MainActor.run()`。
- `Task.detached()` 通常不是好主意。极其仔细地检查任何使用。

如需更多 Swift 并发帮助，建议使用 [Swift Concurrency Pro agent skill](https://github.com/twostraws/swift-concurrency-agent-skill)。
