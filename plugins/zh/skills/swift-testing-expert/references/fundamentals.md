# 基础

## 何时使用此参考

在创建新的 Swift Testing 套件或重构测试结构时使用此文件，适用于进入 Trait、参数化或迁移等更深层主题之前。

## 构建块

- 仅在测试 target 中导入 `Testing`。
- 使用 `@Test` 显式声明测试（全局函数或类型方法）。
- 使用套件（`struct`、`actor` 或 `class`）来分组相关测试。
- 优先使用 `struct` 套件以获得值语义，防止意外的状态共享。
- 在添加套件级 Trait 或显示名称时使用 `@Suite`。
- 使用嵌套套件来反映功能分组并提升可发现性。

## 核心示例

### 全局测试函数

```swift
import Testing
@testable import FoodTruck

@Test("Food truck has a valid default name")
func defaultName() {
	let truck = FoodTruck()
	#expect(truck.name.isEmpty == false)
}
```

### 带实例测试的套件

```swift
import Testing
@testable import FoodTruck

@Suite("Menu tests")
struct MenuTests {
	@Test("Returns no duplicates")
	func uniqueItems() {
		let items = Menu.default.items
		#expect(Set(items).count == items.count)
	}
}
```

### 用于功能分组的嵌套套件

```swift
import Testing
@testable import FoodTruck

struct CheckoutTests {
	struct Taxes {
		@Test func taxIsRoundedToTwoDigits() {
			let total = Checkout.total(subtotal: 10.00, taxRate: 0.0825)
			#expect(total == 10.83)
		}
	}

	struct Discounts {
		@Test func promoCodeAppliesFixedAmount() {
			let total = Checkout.total(subtotal: 20.00, discount: .fixed(5))
			#expect(total == 15.00)
		}
	}
}
```

## 推荐默认

- 保持测试小巧且聚焦于行为。
- 优先使用描述性名称，而非模板化的 `test...` 前缀。
- 在人类可读输出有助于分诊时使用显示名称。
- 保持设置局部化，或在跨测试共享时集中到套件初始化中。
- 避免隐藏的可变全局状态。
- 仅在待测代码需要主线程隔离时使用 `@MainActor`。
- 在需要平台/语言版本限制时对测试函数使用 `@available`。

## 组织指导

- 按功能行为分组，而非仅按实现类分组。
- 当所有测试都继承共享 Trait（如 tag）时，将其提升到套件级。
- 使用 Tag 进行跨文件/跨 target 的横切分组。
- 将无关测试放在不同套件中以保持清晰的所有权。

## 需强制遵守的套件约束

- 如果套件有实例测试方法，它必须具备可调用的零参数初始化器（隐式或显式，同步/异步，抛出或不抛出均可）。
- 如果初始化要求无法满足，将测试转为静态/全局函数或重构套件状态。
- 套件类型（及包含它的类型）必须始终可用；不要对套件声明应用 `@available`。

### 零参数初始化器要求示例

```swift
import Testing

@Suite
struct SessionTests {
	let config: URLSessionConfiguration

	// 有效：因为有默认值，可零参数调用。
	init(config: URLSessionConfiguration = .ephemeral) {
		self.config = config
	}

	@Test func usesEphemeralByDefault() {
		#expect(config == .ephemeral)
	}
}
```

### 无效的可用性标注

```swift
import Testing

// 不要在套件类型上这样做：
// @available(iOS 18, *)
@Suite
struct PushTests {
	@available(iOS 18, *)
	@Test func supportsNewPushFormat() {
		#expect(true)
	}
}
```

## 应做 / 不应做

- 应做：保持每个测试聚焦于一个行为。
- 应做：在显示名称能提升失败可读性时使用它们。
- 不应做：依赖测试执行顺序。
- 不应做：用 `@available` 标注套件；应标注测试函数。

## 评审清单

- 测试 target 导入 `Testing`，app target 不导入。
- 套件选择（`struct`/`actor`/`class`）与设置和清理需求相匹配。
- 实例测试具备可调用的零参数初始化路径。
- 可用性标注应用于测试函数而非套件类型。
