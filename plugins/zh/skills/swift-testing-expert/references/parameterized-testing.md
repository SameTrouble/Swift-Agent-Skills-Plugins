# 参数化测试

## 何时使用此参考

当存在逻辑相同、仅输入变化的重复测试时使用此文件。

## 何时参数化

- 当行为相同、仅输入变化时使用一个参数化测试。
- 用 `@Test(arguments: ...)` 替换复制粘贴的测试和测试内的 `for` 循环。
- 每个参数化测试保持单一职责以保持清晰。

### 改造前 -> 改造后

```swift
// 改造前：多个近乎重复的测试。
// @Test func freeFeatureA() { ... }
// @Test func freeFeatureB() { ... }

import Testing

enum Feature: CaseIterable {
	case recording, darkMode, networkMonitor
	var isPremium: Bool { self == .networkMonitor }
}

@Test("Free features are not premium", arguments: [Feature.recording, .darkMode])
func freeFeatures(_ feature: Feature) {
	#expect(feature.isPremium == false)
}
```

## 单一输入集合

- 传入任何 Sendable 集合（数组、范围、字典等）作为参数。
- 每个参数成为独立的测试用例，具有单独的诊断。
- 单个失败的参数可以单独重跑，无需重跑所有输入。

### 基于范围的参数示例

```swift
import Testing

func isValidAge(_ value: Int) -> Bool { (18...120).contains(value) }

@Test(arguments: 18...21)
func validAges(_ age: Int) {
	#expect(isValidAge(age))
}
```

## 多个输入

- Swift Testing 最多直接支持两个参数集合。
- 两个集合会生成所有组合（笛卡尔积）。
- 通过以下方式控制组合爆炸：
  - 缩减参数集合
  - 按关注点拆分测试
  - 用 `zip(...)` 配对相关值

### 笛卡尔积示例

```swift
import Testing

enum Region { case eu, us }
enum Plan { case free, pro }

func canUseVATInvoice(region: Region, plan: Plan) -> Bool {
	region == .eu && plan == .pro
}

@Test(arguments: [Region.eu, .us], [Plan.free, .pro])
func vatInvoiceAccess(region: Region, plan: Plan) {
	let allowed = canUseVATInvoice(region: region, plan: plan)
	#expect((region == .eu && plan == .pro) == allowed)
}
```

## `zip` 用于配对场景

- 当输入 A 必须与对应输入 B 配对时使用 `zip`。
- 当只需要对齐的元组而非全组合时，优先使用 `zip`。
- 保持元组可读且有意为之。

### `zip` 示例

```swift
import Testing

enum Tier { case basic, premium }
func freeTries(for tier: Tier) -> Int { tier == .basic ? 3 : 10 }

@Test(arguments: zip([Tier.basic, .premium], [3, 10]))
func freeTryLimits(_ tier: Tier, expected: Int) {
	#expect(freeTries(for: tier) == expected)
}
```

### 需要避免的 `zip` 陷阱

**静默截断**：`zip` 会在较短集合处停止。如果两个数组长度不同，多出的元素会被静默丢弃——没有编译器错误，没有测试失败，只是缺失了覆盖。

```swift
// ❌ 静默缺失：第五个输入永远不会被测试
@Test(arguments: zip(
  [Status.active, .inactive, .pending, .banned, .suspended],
  ["Active", "Inactive", "Pending", "Banned"]  // 少一个
))
func statusLabel(_ status: Status, expected: String) {
	#expect(label(for: status) == expected)
}
```

**`CaseIterable` 的用例顺序脆弱性**：用 `zip` 配对两个 `allCases` 数组，如果枚举用例被重排（如按字母排序），会静默失效。

```swift
// ❌ 脆弱：重排任一枚举会使所有配对错位
enum Ingredient: CaseIterable { case rice, potato, egg }
enum Dish: CaseIterable { case onigiri, fries, omelette }

@Test(arguments: zip(Ingredient.allCases, Dish.allCases))
func cook(_ ingredient: Ingredient, into dish: Dish) {
	#expect(cook(ingredient) == dish)
}
```

优先使用显式数组字面量或下方替代方案之一。

## 配对输入的替代方案

当输入和预期输出必须配对时，优先使用以下方案而非 `zip`，以避免静默截断和用例顺序问题。

### 元组数组（推荐）

配对被放在一起，不可能错位。新增用例会强制同时写入匹配的输出。

```swift
import Testing

@Test(arguments: [
	(Ingredient.rice, Dish.onigiri),
	(.potato, .fries),
	(.egg, .omelette)
])
func cook(_ ingredient: Ingredient, into dish: Dish) {
	#expect(cook(ingredient) == dish)
}
```

### 字典参数

表达清晰的映射；每个条目自带说明。要求键为 `Hashable`。

```swift
import Testing

@Test(arguments: [
	Ingredient.rice: Dish.onigiri,
	.potato: .fries,
	.egg: .omelette
])
func cook(_ ingredient: Ingredient, into dish: Dish) {
	#expect(cook(ingredient) == dish)
}
```

### 固定大小 `zip` 配合 `InlineArray`（Swift 6.2+）

为 `InlineArray` 定制的 `zip` 重载可通过泛型长度参数在编译期强制等长。这不是标准库的一部分——你需要自行定义该辅助方法。

```swift
import Testing

// 自定义辅助方法：对两个相同长度的 `InlineArray` 值执行 `zip`。
func zip<let N: Int, A, B>(
  _ a: InlineArray<N, A>,
  _ b: InlineArray<N, B>
) -> Zip2Sequence<[A], [B]> {
  zip(Array(a), Array(b))
}

// ✅ 长度不同时编译错误——在编译期强制
@Test(arguments: zip(
  InlineArray<2, Ingredient>(.rice, .potato),
  InlineArray<2, Dish>(.onigiri, .curry)
))
func cook(_ ingredient: Ingredient, into dish: Dish) {
  #expect(cook(ingredient) == dish)
}
```

## 命名与输出质量

- 使用有意义的参数标签和显示名称。
- 确保参数类型在输出中可读；如有噪声则提供自定义测试描述。
- 保持参数列表易于扫描（推荐多行格式）。

## 何时适合使用 `CaseIterable.allCases`

将 `allCases` 作为参数对于**基于属性的测试**是有效模式——即验证某属性对类型的每个成员都成立。关键区别在于：预期结果是从*被测属性*推导出来的，而非硬编码映射。

```swift
import Testing

// ✅ 有效：验证一个数学属性对所有方向都成立。
@Test(
  "Rotating clockwise four times returns to the original orientation",
  arguments: Orientation.allCases
)
func fullRotation(orientation: Orientation) {
	#expect(
		orientation
			.rotated(.clockwise)
			.rotated(.clockwise)
			.rotated(.clockwise)
			.rotated(.clockwise)
		== orientation
	)
}
```

当需要具体的、特定用例的预期值时避免使用 `allCases`——改用显式数组或元组。

## 常见陷阱

- **派生预期值掩盖 Bug**：当预期值与被测系统使用相同的输入表达式派生时，两边一起偏移，Bug 会静默通过。在 `#expect` 中对特定用例的期望使用具体字面量。

```swift
// ❌ 掩盖：如果 format(day) 返回 "monday" 而非 "Monday"，
//    此测试仍通过，因为 rawValue 有同样的大小写 Bug。
@Test(arguments: Day.allCases)
func dayLabel(day: Day) {
	#expect(format(day) == day.rawValue)
}

// ✅ 具体：每个期望都是独立的数据点。
@Test(arguments: [
	(Day.monday, "Monday"),
	(.friday, "Friday")
])
func dayLabel(day: Day, expected: String) {
	#expect(format(day) == expected)
}
```

- **测试体中的控制流**：参数化测试体内的 `if`/`switch` 会镜像实现逻辑。与生产代码以相同方式分支的测试是在验证自身，而非独立验证行为。

```swift
// ❌ 镜像实现——非独立验证。
@Test(arguments: Day.allCases)
func greeting(day: Day) {
	if day == .friday {
		#expect(greet(day) == "TGIF!")
	} else {
		#expect(greet(day) == "Hello, \(day)!")
	}
}

// ✅ 将特殊情况拆分为单独的测试。
@Test func fridayGreeting() {
	#expect(greet(.friday) == "TGIF!")
}

@Test(arguments: [Day.monday, .tuesday, .wednesday, .thursday, .saturday, .sunday])
func standardGreeting(day: Day) {
	#expect(greet(day) == "Hello, \(day)!")
}
```

- **在测试内使用 `for` 循环而非参数化参数**（诊断更差）。
- **传入巨大参数集合导致组合爆炸**并拖慢 CI。
- **将多个关注点混入一个参数化函数**。
- **将参数数组提取到单独的属性或扩展中**：这会隐藏测试覆盖了什么，迫使读者在定义间跳转。除非列表确实被多个测试函数复用，否则保持参数内联。

## 评审清单

- 重复的测试已合并为一个参数化测试。
- 参数反映领域词汇并产生可读的失败信息。
- 配对输入建模为元组数组或字典；仅在输入必须保持为独立集合时才使用等长显式数组的 `zip`。
- 配对输入使用元组或字典，而非 `zip(allCases, allCases)`。
- `#expect` 使用具体字面量期望，而非从输入本身派生的值。
- 参数化测试体内无 `if`/`switch` 分支。
- `CaseIterable.allCases` 仅用于基于属性的断言，而非基于示例的映射。
