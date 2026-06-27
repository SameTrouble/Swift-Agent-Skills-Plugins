# 数字样式

涵盖 `Float`、`Double`、`Int` 和 `Decimal` 的 `.number`、`.percent` 和 `.currency` 格式样式。

## 数字样式

基本用法：

```swift
32.formatted()               // "32"
Decimal(20.0).formatted()    // "20"
Float(10.0).formatted()      // "10"
Double(100.0003).formatted() // "100.0003"
```

组合修饰符：

```swift
Float(10).formatted(.number.scale(200.0).notation(.compactName).grouping(.automatic)) // "2K"
```

直接初始化：

```swift
FloatingPointFormatStyle<Double>().rounded(rule: .up, increment: 1).format(10.9) // "11"
IntegerFormatStyle<Int>().notation(.compactName).format(1_000) // "1K"
Decimal.FormatStyle().scale(10).format(1) // "10"
```

### 舍入

| 规则 | 行为 |
|------|----------|
| `.awayFromZero` | 绝对值 >= 源值 |
| `.down` | <= 源值 |
| `.toNearestOrAwayFromZero` | 最接近；平局时取较大绝对值 |
| `.toNearestOrEven` | 最接近；平局时取偶数 |
| `.towardZero` | 绝对值 <= 源值 |
| `.up` | >= 源值 |

```swift
Float(5.01).formatted(.number.rounded(rule: .awayFromZero, increment: 1))  // "6"
Float(5.01).formatted(.number.rounded(rule: .awayFromZero, increment: 10)) // "10"
Float(5.01).formatted(.number.rounded(rule: .down, increment: 1))          // "5"
```

### 符号

| 策略 | 行为 |
|----------|----------|
| `.automatic` | 仅负数显示符号 |
| `.never` | 不显示符号 |
| `.always(includingZero:)` | 始终显示符号 |

```swift
Float(1.90).formatted(.number.sign(strategy: .never))                     // "1.9"
Float(-1.90).formatted(.number.sign(strategy: .never))                    // "1.9"
Float(1.90).formatted(.number.sign(strategy: .always()))                  // "+1.9"
Float(0).formatted(.number.sign(strategy: .always(includingZero: true)))  // "+0"
Float(0).formatted(.number.sign(strategy: .always(includingZero: false))) // "0"
```

### 小数分隔符

```swift
Float(10).formatted(.number.decimalSeparator(strategy: .automatic)) // "10"
Float(10).formatted(.number.decimalSeparator(strategy: .always))    // "10."
```

### 分组

```swift
Float(1000).formatted(.number.grouping(.automatic)) // "1,000"
Float(1000).formatted(.number.grouping(.never))     // "1000"
```

### 精度

```swift
// Significant digits
Decimal(10.1).formatted(.number.precision(.significantDigits(1)))       // "10"
Decimal(10.1).formatted(.number.precision(.significantDigits(4)))       // "10.10"
Decimal(10.1).formatted(.number.precision(.significantDigits(1 ... 3))) // "10.1"

// Fraction length
Decimal(10.01).formatted(.number.precision(.fractionLength(1)))      // "10.0"
Decimal(10.01).formatted(.number.precision(.fractionLength(3)))      // "10.010"
Decimal(10).formatted(.number.precision(.fractionLength(0...2)))     // "10"
Decimal(10.111).formatted(.number.precision(.fractionLength(0...2))) // "10.11"

// Integer length
Decimal(10.111).formatted(.number.precision(.integerLength(1))) // "0.111"
Decimal(10.111).formatted(.number.precision(.integerLength(2))) // "10.111"

// Combined
Decimal(10.111).formatted(.number.precision(.integerAndFractionLength(integer: 2, fraction: 1))) // "10.1"
Decimal(10.111).formatted(.number.precision(.integerAndFractionLength(integer: 2, fraction: 3))) // "10.111"
```

### 记数法

```swift
Float(1_000).formatted(.number.notation(.automatic))   // "1,000"
Float(1_000).formatted(.number.notation(.compactName)) // "1K"
Float(1_000).formatted(.number.notation(.scientific))  // "1E3"
```

### 缩放

```swift
Float(10).formatted(.number.scale(1.5))  // "15"
Float(10).formatted(.number.scale(2.0))  // "20"
Float(10).formatted(.number.scale(-2.0)) // "-20"
```

### Locale

```swift
Float(1_000).formatted(.number.notation(.compactName).locale(Locale(identifier: "fr_FR"))) // "1 k"
Float(1_000).formatted(.number.grouping(.automatic).locale(Locale(identifier: "fr_FR")))   // "1 000"
```

### 本地化数字系统

使用 BCP-47 或 ICU 标识符选择替代的数字系统：

```swift
// BCP-47
let enArab = Locale(identifier: "en-u-nu-arab")
123456.formatted(.number.locale(enArab)) // "١٢٣٬٤٥٦"

// ICU
let enArabICU = Locale(identifier: "en@numbers=arab")
12345.formatted(.number.locale(enArabICU)) // "١٢٬٣٤٥"
```

### 解析

```swift
try? Int("120", format: .number)                              // 120
try? Int("1E5", format: .number.notation(.scientific))        // 100000
try? Double("0.0025", format: .number)                        // 0.0025
try? Decimal("1E5", format: .number.notation(.scientific))    // 100000
```

---

## 百分比样式

**重要区别：** 整数百分比是字面值（100 = "100%"），浮点数是小数形式（1.0 = "100%"）。

```swift
0.1.formatted(.percent) // "10%"
```

```swift
Float(0.26575).formatted(.percent.rounded(rule: .awayFromZero))  // "26.575%"

Float(1.90).formatted(.percent.sign(strategy: .always()))        // "+189.999998%"

Float(1_000).formatted(.percent.grouping(.automatic))            // "100,000%"
Float(1_000).formatted(.percent.grouping(.never))                // "100000%"

Float(1_000).formatted(.percent.notation(.compactName))          // "100K%"

Float(10).formatted(.percent.scale(2.0))                         // "20%"
```

解析：

```swift
try? Int("98%", format: .percent)     // 98
try? Float("95%", format: .percent)   // 0.95
try? Decimal("95%", format: .percent) // 0.95
```

---

## 货币样式

**货币始终使用 `Decimal`。** 需要 ISO 4217 代码。

```swift
10.formatted(.currency(code: "JPY")) // "¥10"
```

直接初始化：

```swift
FloatingPointFormatStyle<Double>.Currency(code: "JPY").rounded(rule: .up, increment: 1).format(10.9) // "¥11"
IntegerFormatStyle<Int>.Currency(code: "GBP").presentation(.fullName).format(42) // "42.00 British pounds"
Decimal.FormatStyle.Currency(code: "USD").scale(12).format(0.1) // "$1.20"
```

### 舍入

```swift
Decimal(0.599).formatted(.currency(code: "GBP").rounded())                              // "£0.60"
Decimal(5.001).formatted(.currency(code: "GBP").rounded(rule: .awayFromZero))           // "£5.01"
Decimal(5.01).formatted(.currency(code: "GBP").rounded(rule: .awayFromZero, increment: 1)) // "£6"
```

### 符号

| 策略 | 描述 |
|----------|-------------|
| `.automatic` | 自动决定 |
| `.never` | 从不显示符号 |
| `.always()` | 始终显示 +/- |
| `.always(showZero:)` | 控制 0 是否显示 + 号 |
| `.accounting` | 负数的会计风格 |
| `.accountingAlways()` | 会计风格，始终显示符号 |
| `.accountingAlways(showZero:)` | 控制 0 是否显示 + 号 |

```swift
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .automatic))                         // "£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .never))                             // "£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .accounting))                        // "£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .accountingAlways()))                // "+£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .accountingAlways(showZero: true)))  // "+£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .accountingAlways(showZero: false))) // "+£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .always()))                          // "+£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .always(showZero: true)))            // "+£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .always(showZero: false)))           // "+£7.00"
```

### 精度

```swift
Decimal(3_000.003).formatted(.currency(code: "GBP").precision(.fractionLength(4))) // "£3,000.0029"
Decimal(10.1).formatted(.currency(code: "GBP").precision(.significantDigits(4)))   // "£10.10"
```

### 展示方式

```swift
Decimal(10).formatted(.currency(code: "GBP").presentation(.fullName)) // "10.00 British pounds"
Decimal(10).formatted(.currency(code: "GBP").presentation(.isoCode))  // "GBP 10.00"
Decimal(10).formatted(.currency(code: "GBP").presentation(.narrow))   // "£10.00"
Decimal(10).formatted(.currency(code: "GBP").presentation(.standard)) // "£10.00"
```

### Locale

```swift
Decimal(10).formatted(.currency(code: "GBP").presentation(.fullName).locale(Locale(identifier: "fr_FR")))
// "10,00 livres sterling"

Decimal(10000000).formatted(.currency(code: "GBP").locale(Locale(identifier: "hi_IN")))
// "£1,00,00,000.00"
```

### 组合

```swift
Decimal(10).formatted(.currency(code: "GBP").scale(200.0).sign(strategy: .always()).presentation(.fullName))
// "+2,000.00 British pounds"
```

### 解析

```swift
try Decimal("$3.14", format: .currency(code: "USD").locale(Locale(identifier: "en_US"))) // 3.14
```
