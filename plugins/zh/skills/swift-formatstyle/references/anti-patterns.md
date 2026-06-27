# 反模式：需要替换的旧式格式化

LLM 常常根据 iOS 15 之前的训练数据生成旧式格式化代码。本指南涵盖你必须捕获并替换的模式。

## 用于数字的 C 风格 String(format:)

这是最常见的错误。绝不要用 `String(format:)` 格式化数字。

```swift
// WRONG - C-style formatting
String(format: "%.2f", value)
String(format: "%02d:%02d", minutes, seconds)
String(format: "%d%%", percentage)
String(format: "$%.2f", price)

// CORRECT - FormatStyle
value.formatted(.number.precision(.fractionLength(2)))
Duration.seconds(totalSeconds).formatted(.time(pattern: .minuteSecond))
percentage.formatted(.percent)
price.formatted(.currency(code: "USD"))
```

## 旧式 Formatter 子类

每个 `Formatter` 子类都有现代替代品：

| 旧式 | 现代替代品 |
|--------|-------------------|
| `NumberFormatter` | `.formatted(.number)` / `FloatingPointFormatStyle` / `IntegerFormatStyle` |
| `DateFormatter` | `.formatted(.dateTime)` / `Date.FormatStyle` |
| `DateComponentsFormatter` | `Duration.formatted(.units())` / `Duration.formatted(.time(...))` |
| `DateIntervalFormatter` | `.formatted(.interval)` / `Date.IntervalFormatStyle` |
| `MeasurementFormatter` | `.formatted(.measurement(...))` |
| `PersonNameComponentsFormatter` | `.formatted(.name(style:))` |
| `ByteCountFormatter` | `.formatted(.byteCount(style:))` |
| `RelativeDateTimeFormatter` | `.formatted(.relative(...))` |

## 常见时长格式化错误

智能体常常手动构建时长格式化，而不使用内置样式：

```swift
// WRONG - manual calculation
let minutes = Int(seconds) / 60
let secs = Int(seconds) % 60
return String(format: "%02d:%02d", minutes, secs)

// CORRECT - Duration.TimeFormatStyle
Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
// Output: "16:40"

// WRONG - manual hours:minutes:seconds
let h = Int(seconds) / 3600
let m = (Int(seconds) % 3600) / 60
let s = Int(seconds) % 60
return String(format: "%d:%02d:%02d", h, m, s)

// CORRECT
Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
// Output: "0:16:40"
```

## 常见日期格式化错误

```swift
// WRONG - DateFormatter
let formatter = DateFormatter()
formatter.dateStyle = .medium
formatter.timeStyle = .short
return formatter.string(from: date)

// CORRECT
date.formatted(date: .abbreviated, time: .shortened)

// WRONG - custom date format string
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
return formatter.string(from: date)

// CORRECT - verbatim for fixed formats
date.formatted(
    .verbatim(
        "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
        locale: .current,
        timeZone: .current,
        calendar: .current
    )
)

// CORRECT - ISO 8601 if that's the intent
date.formatted(.iso8601)
```

## SwiftUI 特有的反模式

```swift
// WRONG - formatting in string interpolation
Text("\(price, specifier: "%.2f")")
Text("\(Date(), formatter: dateFormatter)")
Text(String(format: "%.1f%%", percentage * 100))

// CORRECT - use format: parameter
Text(price, format: .currency(code: "USD"))
Text(Date(), format: .dateTime.hour().minute())
Text(percentage, format: .percent)
```

## Verbatim 的 locale 陷阱

使用 `.verbatim()` 时，务必显式指定 locale。省略它会默认为 `nil` 并产生损坏的输出：

```swift
// WRONG - nil locale
date.formatted(.verbatim(
    "\(year: .defaultDigits)-\(month: .abbreviated)-\(day: .twoDigits)",
    timeZone: .current, calendar: .current
))
// "2022-M02-22" <- broken

// CORRECT
date.formatted(.verbatim(
    "\(year: .defaultDigits)-\(month: .abbreviated)-\(day: .twoDigits)",
    locale: Locale(identifier: "en_US"), timeZone: .current, calendar: .current
))
// "2022-Feb-22"
```

## 不必要的手动 locale 处理

FormatStyle 会自动遵循用户的 locale。仅当需要*特定* locale 时才显式设置：

```swift
// UNNECESSARY
let formatter = NumberFormatter()
formatter.locale = Locale.current  // redundant
formatter.numberStyle = .decimal
return formatter.string(from: NSNumber(value: number))!

// CORRECT - locale is automatic
number.formatted(.number)

// ONLY set locale when you need a specific one
number.formatted(.number.locale(Locale(identifier: "fr_FR")))
```
