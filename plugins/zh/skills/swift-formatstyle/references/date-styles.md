# 日期样式

涵盖所有日期格式化：组合、日期/时间预设、ISO 8601、相对、verbatim、HTTP、区间和 components。

## Date.FormatStyle 组合

像乐高积木一样混合搭配日期组件。符号的顺序不影响输出——显示顺序由 locale 控制。

```swift
let twosday = Calendar(identifier: .gregorian).date(from: DateComponents(
    year: 2022, month: 2, day: 22, hour: 2, minute: 22, second: 22
))!

twosday.formatted(.dateTime.day())     // "22"
twosday.formatted(.dateTime.month())   // "Feb"
twosday.formatted(.dateTime.year())    // "2022"
twosday.formatted(.dateTime.hour())    // "2 AM"
twosday.formatted(.dateTime.minute())  // "22"
twosday.formatted(.dateTime.second())  // "22"
twosday.formatted(.dateTime.weekday()) // "Tue"
twosday.formatted(.dateTime.era())     // "AD"
twosday.formatted(.dateTime.quarter()) // "Q1"

// Chained - locale controls order, not call order
twosday.formatted(.dateTime.year().month().day().hour().minute().second())
// "Feb 22, 2022, 2:22:22 AM"
```

### 组件选项

**日：**
```swift
.day(.twoDigits)           // "22"
.day(.defaultDigits)       // "22"
.day(.ordinalOfDayInMonth) // "4"
```

**月：**
```swift
.month(.defaultDigits) // "2"
.month(.twoDigits)     // "02"
.month(.wide)          // "February"
.month(.abbreviated)   // "Feb"
.month(.narrow)        // "F"
```

**年：**
```swift
.year(.twoDigits)      // "22"
.year(.defaultDigits)  // "2022"
.year(.padded(10))     // "0000002022"
```

**小时：**
```swift
.hour(.defaultDigits(amPM: .wide))        // "2 AM"
.hour(.defaultDigits(amPM: .narrow))      // "2 a"
.hour(.defaultDigits(amPM: .abbreviated)) // "2 AM"
.hour(.defaultDigits(amPM: .omitted))     // "02"
.hour(.twoDigits(amPM: .wide))           // "02 AM"
```

**星期：**
```swift
.weekday(.abbreviated) // "Tue"
.weekday(.wide)        // "Tuesday"
.weekday(.narrow)      // "T"
.weekday(.short)       // "Tu"
```

**时区：**
```swift
.timeZone(.specificName(.short))  // "MST"
.timeZone(.specificName(.long))   // "Mountain Standard Time"
.timeZone(.genericName(.short))   // "MT"
.timeZone(.identifier(.long))     // "America/Edmonton"
.timeZone(.iso8601(.long))        // "-07:00"
.timeZone(.localizedGMT(.short))  // "GMT-7"
.timeZone(.exemplarLocation)      // "Edmonton"
```

---

## 日期和时间预设

使用预设样式快速格式化：

**DateStyle：** `.omitted`、`.numeric`、`.abbreviated`、`.long`、`.complete`
**TimeStyle：** `.omitted`、`.shortened`、`.standard`、`.complete`

```swift
twosday.formatted(date: .abbreviated, time: .omitted)  // "Feb 22, 2022"
twosday.formatted(date: .complete, time: .omitted)     // "Tuesday, February 22, 2022"
twosday.formatted(date: .long, time: .omitted)         // "February 22, 2022"
twosday.formatted(date: .numeric, time: .omitted)      // "2/22/2022"

twosday.formatted(date: .omitted, time: .complete)     // "2:22:22 AM MST"
twosday.formatted(date: .omitted, time: .shortened)    // "2:22 AM"
twosday.formatted(date: .omitted, time: .standard)     // "2:22:22 AM"

twosday.formatted(date: .abbreviated, time: .shortened) // "Feb 22, 2022, 2:22 AM"
```

自定义 locale 和 calendar：

```swift
let frenchHebrew = Date.FormatStyle(
    date: .complete,
    time: .complete,
    locale: Locale(identifier: "fr_FR"),
    calendar: Calendar(identifier: .hebrew),
    timeZone: TimeZone(secondsFromGMT: 0)!,
    capitalizationContext: .standalone
)
twosday.formatted(frenchHebrew) // "Mardi 22 fevrier 2022 ap. J.-C. 9:22:22 UTC"
```

---

## ISO 8601

```swift
twosday.formatted(.iso8601) // "2022-02-22T09:22:22Z"
```

自定义配置：

```swift
let isoFormat = Date.ISO8601FormatStyle(
    dateSeparator: .dash,
    dateTimeSeparator: .standard,
    timeSeparator: .colon,
    timeZoneSeparator: .colon,
    includingFractionalSeconds: true,
    timeZone: TimeZone(secondsFromGMT: 0)!
)
isoFormat.format(twosday) // "2022-02-22T09:22:22.000Z"
```

解析：

```swift
try? Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 0)!)
    .year().day().month()
    .dateSeparator(.dash).dateTimeSeparator(.standard).timeSeparator(.colon)
    .time(includingFractionalSeconds: true)
    .parse("2022-02-22T09:22:22.000") // Feb 22, 2022, 2:22:22 AM
```

---

## 相对日期

自动选择最大的相关时间单位：

**展示方式：** `.numeric`（"1 day ago"）、`.named`（"yesterday"）
**单位样式：** `.abbreviated`、`.narrow`、`.spellOut`、`.wide`

```swift
let thePast = Calendar.current.date(byAdding: .day, value: -14, to: Date())!

thePast.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)) // "2 wk. ago"
thePast.formatted(.relative(presentation: .numeric, unitsStyle: .spellOut))    // "two weeks ago"
thePast.formatted(.relative(presentation: .named, unitsStyle: .wide))          // "2 weeks ago"
```

Locale：

```swift
thePast.formatted(.relative(presentation: .named, unitsStyle: .spellOut).locale(Locale(identifier: "fr_FR")))
// "il y a deux semaines"
```

---

## 锚定相对（Xcode 16+）

类似于相对样式，但脱离系统时钟——使用固定锚点日期获得确定性输出：

```swift
let anchorDate = Calendar.current.date(byAdding: .day, value: -3, to: Date.now)!
let style = Date.AnchoredRelativeFormatStyle(anchor: anchorDate)
style.format(Date.now) // "3 days ago"
```

限制显示的单位：

```swift
let anchor = Calendar.current.date(byAdding: .hour, value: -49, to: Date.now)!
Date.AnchoredRelativeFormatStyle(anchor: anchor).format(Date.now)                        // "2 days ago"
Date.AnchoredRelativeFormatStyle(anchor: anchor, allowedFields: [.hour]).format(Date.now) // "49 hours ago"
```

---

## Verbatim

用于固定、结构化的格式字符串（替代 `dateFormat`）。使用类型安全的字符串插值，而非像 `"yyyy-MMM-dd"` 这样晦涩的 Unicode 模式。

```swift
twosday.formatted(
    .verbatim(
        "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .oneBased)):\(minute: .twoDigits):\(second: .twoDigits)",
        locale: .current,
        timeZone: .current,
        calendar: .current
    )
)
// "2022-02-22 22:22:22"
```

混合字面文本：

```swift
twosday.formatted(
    .verbatim(
        "It's Twosday! \(year: .defaultDigits)-\(month: .abbreviated)(\(month: .defaultDigits))-\(day: .defaultDigits)",
        locale: Locale(identifier: "en_US"),
        timeZone: .current,
        calendar: .current
    )
)
// "It's Twosday! 2022-Feb(2)-22"
```

### Verbatim 的陷阱

**务必显式指定 locale。** 省略 locale 会默认为 `nil`，产生损坏的输出：

```swift
// WRONG - nil locale gives garbled output
Date.VerbatimFormatStyle(
    format: "\(year: .defaultDigits)-\(month: .abbreviated)-\(day: .twoDigits)",
    timeZone: .current,
    calendar: .current
).format(twosday)
// "2022-M02-22" <- broken, not "2022-Feb-22"

// CORRECT - always provide locale
Date.VerbatimFormatStyle(
    format: "\(year: .defaultDigits)-\(month: .abbreviated)-\(day: .twoDigits)",
    locale: Locale(identifier: "en_US"),
    timeZone: .current,
    calendar: .current
).format(twosday)
// "2022-Feb-22"
```

**`.autoupdatingCurrent` locale 会覆盖 calendar 参数：**

```swift
// Locale .autoupdatingCurrent ignores calendar
Date.VerbatimFormatStyle(
    format: "\(year: .defaultDigits)-\(month: .abbreviated)-\(day: .twoDigits)",
    locale: .autoupdatingCurrent,
    timeZone: .autoupdatingCurrent,
    calendar: Calendar(identifier: .buddhist)
).format(twosday) // "2022-Feb-22" <- ignores Buddhist calendar

// Explicit locale respects calendar
Date.VerbatimFormatStyle(
    format: "\(year: .defaultDigits)-\(month: .abbreviated)-\(day: .twoDigits)",
    locale: Locale(identifier: "en_US"),
    timeZone: .autoupdatingCurrent,
    calendar: Calendar(identifier: .buddhist)
).format(twosday) // "2565-Feb-22" <- correct Buddhist year
```

---

## HTTP

用于 HTTP 头的固定 RFC 9110 兼容格式。不可自定义。

```swift
twosday.formatted(.http) // "Tue, 22 Feb 2022 09:22:22 GMT"

try? Date.HTTPFormatStyle().parse("Tue, 22 Feb 2022 09:22:22 GMT") // Feb 22, 2022
```

---

## 区间（日期范围）

显示最早和最晚的日期：

```swift
let range = date1..<date2

range.formatted(.interval)                    // "12/31/69, 5:00 PM - 12/31/00, 5:47 PM"
range.formatted(.interval.year())             // "1969 - 2000"
range.formatted(.interval.month(.wide))       // "December 1969 - December 2000"
range.formatted(.interval.hour())             // "12/31/1969, 5 PM - 12/31/2000, 5 PM"
```

---

## Components（日期范围）

以自然语言显示日期之间的距离：

**样式：** `.wide`、`.abbreviated`、`.condensedAbbreviated`、`.narrow`、`.spellOut`

```swift
let range = date1..<date2

range.formatted(.components(style: .abbreviated, fields: [.year, .month, .week]))
// "21 yrs, 1 mth, 3 wks"

range.formatted(.components(style: .condensedAbbreviated, fields: [.day, .month, .year]))
// "31y"

range.formatted(.components(style: .spellOut, fields: [.day]))
// "eleven thousand three hundred twenty-three days"

range.formatted(.components(style: .wide, fields: [.year, .month, .week, .hour, .second])
    .locale(Locale(identifier: "fr_FR")))
// "21 ans, 1 mois, 3 semaines, 9 heures et 1 342 secondes"
```

---

## 解析日期

```swift
try? Date.FormatStyle()
    .day().month().year().hour().minute().second()
    .parse("Feb 22, 2022, 2:22:22 AM")

try? Date(
    "Feb 22, 2022, 2:22:22 AM",
    strategy: Date.FormatStyle().day().month().year().hour().minute().second().parseStrategy
)
```
