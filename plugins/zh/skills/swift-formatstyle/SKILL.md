---
name: swift-format-style
description: 编写和审查 Swift FormatStyle 代码，用现代的 .formatted() API 替代旧式 Formatter 子类和 C 风格的 String(format:)。在格式化数字、日期、时长、度量、列表、名称、字节计数或 URL 时使用。
license: MIT
metadata:
  author: Anton Novoselov
  version: "1.0"
---

编写和审查用于展示的 Swift 格式化代码，确保使用现代的 FormatStyle API，而非旧式的 Formatter 子类或 C 风格格式化。

审查流程：

1. 检查旧式格式化模式，并使用 `references/anti-patterns.md` 中的现代 FormatStyle 等价物替换。
2. 使用 `references/numeric-styles.md` 验证数字、百分比和货币格式化。
3. 使用 `references/date-styles.md` 验证日期和时间格式化。
4. 使用 `references/duration-styles.md` 验证时长格式化。
5. 使用 `references/other-styles.md` 验证度量、列表、人名、字节计数和 URL 格式化。
6. 使用 `references/swiftui.md` 检查 SwiftUI Text 视图是否正确集成了 FormatStyle。

如果只做部分工作，仅加载相关的参考文件即可。


## 核心指令

- 基础 FormatStyle 的最低部署目标为 iOS 15+ / macOS 12+。时长和 URL 样式需要 iOS 16+ / macOS 13+。
- **绝不**使用旧式 `Formatter` 子类（`DateFormatter`、`NumberFormatter`、`MeasurementFormatter`、`DateComponentsFormatter`、`DateIntervalFormatter`、`PersonNameComponentsFormatter`、`ByteCountFormatter`）。
- **绝不**使用 C 风格的 `String(format:)` 进行数字格式化。始终使用 `.formatted()` 或直接使用 `FormatStyle`。
- **绝不**使用 `DispatchQueue` 在后台线程执行格式化——FormatStyle 类型是值类型且线程安全。
- 简单场景优先使用 `.formatted()` 实例方法，可复用或复杂配置则使用显式的 `FormatStyle` 类型。
- 在 SwiftUI 中，使用 `Text(_:format:)` 而非 `Text("\(value.formatted())")`。
- 货币值使用 `Decimal` 而非 `Float`/`Double`。
- FormatStyle 类型默认具备区域感知能力。仅当需要与用户当前区域不同的特定区域时，才显式设置 locale。
- FormatStyle 类型遵循 `Codable` 和 `Hashable`，因此可以安全地存储和比较。


## 输出格式

如果用户请求审查，按文件组织发现的问题。对每个问题：

1. 说明文件及相关行号。
2. 指出被替换的反模式名称。
3. 给出简短的前后代码修复对比。

跳过没有问题的文件。最后附上按优先级排序的摘要，列出应最先做的最具影响力的改动。

如果用户请求编写或修复格式化代码，直接做出修改，而不是返回发现报告。

输出示例：

### RecordingView.swift

**第 42 行：使用 Duration.formatted() 代替 String(format:) 来显示时间。**

```swift
// Before
let minutes = Int(duration) / 60
let seconds = Int(duration) % 60
return String(format: "%02d:%02d", minutes, seconds)

// After
Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))
```

**第 78 行：使用 Text(_:format:) 代替字符串插值。**

```swift
// Before
Text("\(fileSize.formatted(.byteCount(style: .file)))")

// After
Text(fileSize, format: .byteCount(style: .file))
```

### 摘要

1. **旧式格式化（高）：** 第 42 行的 C 风格 String(format:) 应改用 Duration.formatted()。
2. **SwiftUI（中）：** 第 78 行的 Text 插值应直接使用 format: 参数。

示例结束。


## 参考资料

- `references/anti-patterns.md` - 需要替换的旧式模式：String(format:)、DateFormatter、NumberFormatter 以及其他 Formatter 子类。
- `references/numeric-styles.md` - 数字、百分比和货币的格式化，包括舍入、精度、符号、记数法、缩放和分组。
- `references/date-styles.md` - 日期/时间组合、ISO 8601、相对、verbatim、HTTP、区间和 components 样式。
- `references/duration-styles.md` - Duration.TimeFormatStyle 和 Duration.UnitsFormatStyle，包括模式、单位、宽度和秒的小数部分。
- `references/other-styles.md` - 度量、列表、人名、字节计数、URL 格式化，以及自定义 FormatStyle 的创建。
- `references/swiftui.md` - SwiftUI Text 集成与最佳实践。
