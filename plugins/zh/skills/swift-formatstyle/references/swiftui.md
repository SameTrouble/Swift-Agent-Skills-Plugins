# SwiftUI 集成

`Text` 视图直接接受 `format:` 参数。绝不要在 `Text` 内部使用带 `.formatted()` 的字符串插值。

## 核心规则

```swift
// WRONG
Text("\(value.formatted(.number.precision(.fractionLength(2))))")
Text("\(date.formatted(.dateTime.hour().minute()))")

// CORRECT
Text(value, format: .number.precision(.fractionLength(2)))
Text(date, format: .dateTime.hour().minute())
```

## 示例

```swift
struct ContentView: View {
    let date = Date.now
    let price: Decimal = 9.99
    let progress = 0.75

    var body: some View {
        VStack {
            // Dates
            Text(date, format: Date.FormatStyle(date: .complete, time: .complete))
            Text(date, format: .dateTime.hour())
            Text(date, format: .dateTime.year().month().day())

            // Numbers
            Text(price, format: .currency(code: "USD"))
            Text(progress, format: .percent)

            // Duration
            Text(Duration.seconds(125), format: .time(pattern: .minuteSecond))
        }
    }
}
```

## 秒表和计时器（Xcode 16+）

SwiftUI 专有的格式样式，输出实时更新的 `AttributedString` 值。这些不属于 Foundation——它们仅存在于 SwiftUI 中。

### 秒表

从开始日期显示已过时间，向上计时：

```swift
struct Stopwatch: View {
    @State var startDate: Date?
    @State var isRunning = false

    var body: some View {
        // Use TimeDataSource for live updates, static Date for paused state
        if isRunning {
            Text(TimeDataSource<Date>.currentDate, format: .stopwatch(startingAt: startDate ?? .now))
        } else {
            Text(Date.now, format: .stopwatch(startingAt: startDate ?? .now))
        }
        Button("Start") {
            startDate = .now
            isRunning = true
        }
    }
}
```

### 计时器（倒计时）

在日期范围内显示剩余时间，向下计时：

```swift
struct CountdownTimer: View {
    @State var isRunning = false
    @State var timerRange: Range<Date>?

    var body: some View {
        if isRunning {
            Text(TimeDataSource<Date>.currentDate, format: .timer(countingDownIn: timerRange ?? .now ..< .now))
        } else {
            Text(.now, format: .timer(countingDownIn: timerRange ?? .now ..< .now))
        }
        Button("Start 60s") {
            let now = Date.now
            timerRange = now ..< Calendar.current.date(byAdding: .second, value: 60, to: now)!
            isRunning = true
        }
    }
}
```

### 要点

- 使用 `TimeDataSource<Date>.currentDate` 而非 `TimelineView` 来实现实时更新
- 两者默认输出 `AttributedString`——只有 `Text` 视图能显示它们
- 秒表接受单个开始 `Date`；计时器接受 `Range<Date>`
- 计时器在下界或更低处显示 `0:00`，在上界或更高处显示完整偏移
- 日期计算始终使用 `Calendar` API（不要手动做 `TimeInterval` 运算）

---

## 样式化格式化的 AttributedString 输出

许多格式样式支持 `.attributed` 来获取带有可单独样式化 runs 的 `AttributedString`：

```swift
struct ContentView: View {
    var percentAttributed: AttributedString {
        var result = 0.8890.formatted(.percent.attributed)
        result.swiftUI.font = .title
        result.runs.forEach { run in
            if let numberRun = run.numberPart {
                switch numberRun {
                case .integer:
                    result[run.range].foregroundColor = .orange
                case .fraction:
                    result[run.range].foregroundColor = .blue
                }
            }
            if let symbolRun = run.numberSymbol {
                switch symbolRun {
                case .percent:
                    result[run.range].foregroundColor = .green
                case .decimalSeparator:
                    result[run.range].foregroundColor = .red
                default:
                    break
                }
            }
        }
        return result
    }

    var body: some View {
        Text(percentAttributed)
    }
}
```

适用于：`.number.attributed`、`.percent.attributed`、`.currency(code:).attributed`、`.dateTime.attributed`、`.measurement(width:).attributed`、`.byteCount(style:).attributed`

## 为什么这很重要

- `Text(_:format:)` 在渲染时应用格式化，遵循视图环境的 locale
- 带 `.formatted()` 的字符串插值会立即捕获格式化后的字符串，无法响应 locale 变化
- `format:` 参数在 locale 或 calendar 设置改变时自动更新
