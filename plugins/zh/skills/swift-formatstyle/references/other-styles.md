# 其他样式

涵盖度量、列表、人名、字节计数、URL 以及自定义 FormatStyle。

## 度量样式

格式化任何 `Measurement<UnitType>`，并具备区域感知的单位换算。

**重要：** 度量输出在不同设备上是非确定性的。默认的 `.general` 用法会换算为设备 locale 的首选单位，因此同一段代码在美国设备和瑞典设备上会产生不同输出。务必使用显式 locale 进行测试。

```swift
Measurement(value: 100, unit: UnitSpeed.kilometersPerHour).formatted() // "62 mph" (US locale)
Measurement(value: 200, unit: UnitLength.kilometers).formatted()       // "124 mi" (US locale)
Measurement(value: 70, unit: UnitLength.feet).formatted()              // "70 ft"
Measurement(value: 98.5, unit: UnitTemperature.fahrenheit).formatted() // "98degF"
```

### 宽度

```swift
let speed = Measurement(value: 100, unit: UnitSpeed.kilometersPerHour)

speed.formatted(.measurement(width: .wide))        // "62 miles per hour"
speed.formatted(.measurement(width: .abbreviated))  // "62 mph"
speed.formatted(.measurement(width: .narrow))       // "62mph"
```

### 用法

`.general` - 符合 locale 的单位，`.asProvided` - 保持原始单位：

```swift
let myHeight = Measurement(value: 190, unit: UnitLength.centimeters)

myHeight.formatted(.measurement(width: .abbreviated, usage: .general).locale(Locale(identifier: "en-US")))
// "6.2 ft"
myHeight.formatted(.measurement(width: .abbreviated, usage: .asProvided).locale(Locale(identifier: "en-US")))
// "190 cm"
myHeight.formatted(.measurement(width: .abbreviated, usage: .personHeight).locale(Locale(identifier: "en-US")))
// "6 ft, 2.8 in"
```

### 特定单位的用法选项

**UnitLength：** `.person`、`.personHeight`、`.road`、`.focalLength`、`.rainfall`、`.snowfall`
**UnitMass：** `.personWeight`
**UnitTemperature：** `.person`、`.weather`
**UnitEnergy：** `.food`、`.workout`
**UnitVolume：** `.liquid`

### numberFormatStyle

控制数字部分的格式化：

```swift
myHeight.formatted(
    .measurement(width: .abbreviated, usage: .personHeight, numberFormatStyle: .number.precision(.fractionLength(0)))
    .locale(Locale(identifier: "en-US"))
) // "6 ft, 3 in"
```

### UnitTemperature：hidesScaleName

仅适用于 `UnitTemperature` - 从输出中省略刻度名称：

```swift
let temp = Measurement(value: 25.0, unit: UnitTemperature.celsius)

temp.formatted(.measurement(width: .wide, usage: .asProvided))                          // "25 degrees Celsius"
temp.formatted(.measurement(width: .wide, usage: .asProvided, hidesScaleName: true))    // "25 degrees"
temp.formatted(.measurement(width: .abbreviated, usage: .asProvided, hidesScaleName: true)) // "25deg"
```

### 自定义单位

你可以创建自定义单位并将其与度量格式化一起使用：

```swift
// One-off custom unit
let smoots = UnitLength(symbol: "smoot", converter: UnitConverterLinear(coefficient: 1.70180))
let bridgeLength = Measurement(value: 364.4, unit: smoots)
bridgeLength.formatted(.measurement(width: .abbreviated, usage: .asProvided)) // "364.4 smoot"

// Extending an existing Dimension
extension UnitSpeed {
    static let furlongPerFortnight = UnitSpeed(
        symbol: "fur/ftn",
        converter: UnitConverterLinear(coefficient: 201.168 / 1209600.0)
    )
}
```

**注意：** 自定义单位只能与 `.asProvided` 用法一起正确显示，因为系统不知道如何对其进行本地化。

---

## 列表样式

将数组转换为本地化的文本列表。

```swift
["a", "b", "c", "d"].formatted()                                   // "a, b, c, and d"
["a", "b", "c", "d"].formatted(.list(type: .and, width: .standard)) // "a, b, c, and d"
["a", "b", "c", "d"].formatted(.list(type: .and, width: .short))    // "a, b, c, & d"
["a", "b", "c", "d"].formatted(.list(type: .and, width: .narrow))   // "a, b, c, d"
["a", "b", "c", "d"].formatted(.list(type: .or, width: .standard))  // "a, b, c, or d"
```

Locale：

```swift
["a", "b", "c", "d"].formatted(.list(type: .and).locale(Locale(identifier: "fr_FR")))
// "a, b, c, et d"
```

自定义条目格式化：

```swift
let dates = [date1, date2]
dates.formatted(.list(memberStyle: Date.FormatStyle().year(), type: .and))
// "2001 and 1970"
```

---

## 人名样式

```swift
let guest = PersonNameComponents(
    namePrefix: "Dr",
    givenName: "Elizabeth",
    middleName: "Jillian",
    familyName: "Smith",
    nameSuffix: "Esq.",
    nickname: "Liza"
)

guest.formatted()                           // "Elizabeth Smith"
guest.formatted(.name(style: .abbreviated)) // "ES"
guest.formatted(.name(style: .short))       // "Liza"
guest.formatted(.name(style: .medium))      // "Elizabeth Smith"
guest.formatted(.name(style: .long))        // "Dr Elizabeth Jillian Smith Esq."
```

区域感知的排序：

```swift
guest.formatted(.name(style: .medium).locale(Locale(identifier: "zh_CN")))
// "Smith Elizabeth"
```

解析：

```swift
try? PersonNameComponents.FormatStyle().parseStrategy.parse("Dr Elizabeth Jillian Smith Esq.")
```

---

## 字节计数样式

有两种实现：用于 `Int64` 的 `ByteCountFormatStyle`（Xcode 13+），以及 `Measurement<UnitInformationStorage>.FormatStyle.ByteCount`（Xcode 14+）。

### 样式

| 样式 | 行为 |
|-------|----------|
| `.file` | 平台特定的文件显示 |
| `.memory` | 平台特定的内存显示 |
| `.decimal` | 1000 字节 = 1 KB |
| `.binary` | 1024 字节 = 1 KB |

```swift
let tb: Int64 = 1_000_000_000_000

tb.formatted(.byteCount(style: .binary))  // "931.32 GB"
tb.formatted(.byteCount(style: .decimal)) // "1 TB"
tb.formatted(.byteCount(style: .file))    // "1 TB"
tb.formatted(.byteCount(style: .memory))  // "931.32 GB"
```

### 选项

```swift
tb.formatted(.byteCount(style: .file, allowedUnits: .gb))                    // "931.32 GB"
tb.formatted(.byteCount(style: .file, allowedUnits: [.kb, .mb]))             // varies

Int64.zero.formatted(.byteCount(style: .file, spellsOutZero: true))          // "Zero kB"
Int64.zero.formatted(.byteCount(style: .file, spellsOutZero: false))         // "0 bytes"

Int64(1_000).formatted(.byteCount(style: .file, includesActualByteCount: true))
// "1 kB (1,000 bytes)"
```

### Measurement 变体（Xcode 14+）

```swift
let tbMeasurement = Measurement(value: 1, unit: UnitInformationStorage.terabytes)
tbMeasurement.formatted(.byteCount(style: .file)) // "1 TB"
```

---

## URL 样式（Xcode 14+）

```swift
let url = URL(string: "https://apple.com")!
url.formatted()     // "https://apple.com"
url.formatted(.url) // "https://apple.com"
```

### 组件显示

每个组件的选项：`.always`、`.never`、`.omitIfHTTPFamily`

```swift
let style = URL.FormatStyle(
    scheme: .always,
    user: .never,
    password: .never,
    host: .always,
    port: .always,
    path: .always,
    query: .never,
    fragment: .never
)
```

条件式：`.displayWhen(_:matches:)`、`.omitWhen(_:matches:)`、`.omitSpecificSubdomains(_:includeMultiLevelSubdomains:)`

### 解析

```swift
try URL.FormatStyle.Strategy(port: .defaultValue(80)).parse("http://www.apple.com")
// http://www.apple.com:80

try URL.FormatStyle.Strategy(port: .optional).parse("http://www.apple.com")
// http://www.apple.com

try URL.FormatStyle.Strategy(port: .required).parse("http://www.apple.com")
// throws error
```

---

## 自定义 FormatStyle

为实现任何转换，遵循该协议：

```swift
public protocol FormatStyle: Decodable, Encodable, Hashable {
    associatedtype FormatInput
    associatedtype FormatOutput

    func format(_ value: Self.FormatInput) -> Self.FormatOutput
    func locale(_ locale: Locale) -> Self
}
```

通过点语法使其可用：

```swift
extension FormatStyle where Self == MyCustomStyle {
    static var myStyle: MyCustomStyle { .init() }
}

// Usage
value.formatted(.myStyle)
```

### ParseableFormatStyle（双向）

要支持将字符串解析回你的类型，请遵循 `ParseableFormatStyle`：

```swift
public protocol ParseableFormatStyle: FormatStyle {
    associatedtype Strategy: ParseStrategy
        where Strategy.ParseOutput == FormatInput, Strategy.ParseInput == FormatOutput

    var parseStrategy: Strategy { get }
}

public protocol ParseStrategy: Decodable, Encodable, Hashable {
    associatedtype ParseInput
    associatedtype ParseOutput

    func parse(_ value: ParseInput) throws -> ParseOutput
}
```

支持解析的内置类型：数字、百分比、货币、日期（`Date.FormatStyle` 和 `Date.ISO8601FormatStyle`）、人名以及 URL（iOS 16+）。
