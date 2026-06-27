# 性能与最佳实践

## 何时使用此参考

当测试运行缓慢、不稳定或在 CI 中无法扩展，以及需要快速、确定性的 Swift Testing 套件实用模式时使用此文件。

## 核心原则

- 优先使用确定性测试而非对时间敏感的测试。
- 当不需要异步等待时优先使用同步验证。
- 保持测试独立，使并行执行保持安全有效。
- 将 `.serialized` 视为临时妥协，而非默认架构。

## 1) 尽可能保持测试同步

同步测试通常运行更快且更易推理。

```swift
import Testing

struct PriceCalculator {
	static func total(_ subtotal: Int, discount: Int) -> Int { subtotal - discount }
}

@Test func totalCalculation() {
	#expect(PriceCalculator.total(100, discount: 20) == 80)
}
```

避免为纯同步逻辑引入 `async` 或睡眠。

```swift
// 避免：
// @Test func totalCalculation() async {
//   try await Task.sleep(nanoseconds: 100_000_000)
//   #expect(...)
// }
```

## 2) 避免不必要的主 actor 隔离

`@MainActor` 会降低有效的并行化，应仅在代码确实需要主线程隔离时使用。

```swift
import Testing

// 良好：非 UI 逻辑保持非主 actor。
@Test func parserIsStable() {
	#expect("A,B,C".split(separator: ",").count == 3)
}

// 仅对 UI/主线程敏感的代码使用 @MainActor。
@MainActor
@Test func viewModelMutation() {
	#expect(true)
}
```

## 3) 移除共享可变状态

共享可变状态是不稳定性和并行失败的主要来源。

```swift
import Testing

enum Globals {
	static var token: String?
}

// 不稳定模式：
@Test func writeToken() {
	Globals.token = "abc"
	#expect(Globals.token == "abc")
}

@Test func expectsNoToken() {
	#expect(Globals.token == nil)
}
```

更好：按测试创建隔离状态。

```swift
import Testing

struct SessionState {
	var token: String?
}

@Test func isolatedTokenState() {
	var state = SessionState()
	state.token = "abc"
	#expect(state.token == "abc")
}
```

## 4) 快速路径优先使用内存依赖

为高频测试运行使用桩/内存仓储；将真实集成依赖保留给专用计划。

```swift
import Testing

protocol CacheStore {
	func put(key: String, value: String)
	func get(key: String) -> String?
}

final class InMemoryCacheStore: CacheStore {
	private var values: [String: String] = [:]
	func put(key: String, value: String) { values[key] = value }
	func get(key: String) -> String? { values[key] }
}

@Test func cacheRoundTrip() {
	let cache = InMemoryCacheStore()
	cache.put(key: "user", value: "42")
	#expect(cache.get(key: "user") == "42")
}
```

## 5) 使用参数化测试以减少开销并改善诊断

```swift
import Testing

func isValidPort(_ value: Int) -> Bool { (1...65535).contains(value) }

@Test(arguments: [1, 80, 443, 65535])
func validPorts(_ port: Int) {
	#expect(isValidPort(port))
}
```

这减少了重复的设置代码，并提供参数级的失败可见性。

## 6) 保持设置轻量且作用域明确

- 仅在需要时构建昂贵的夹具。
- 对共享只读数据优先使用按套件的不可变设置。
- 除非行为依赖网络/文件系统，否则避免在单元测试中做此类设置。

```swift
import Testing

struct CurrencyTests {
	let rates: [String: Double]

	init() {
		rates = ["USD": 1.0, "EUR": 0.92]
	}

	@Test func hasEURRate() {
		#expect(rates["EUR"] != nil)
	}
}
```

## 7) 谨慎使用 `.serialized`

```swift
import Testing

@Suite(.serialized)
struct TemporarySerialDBTests {
	@Test func migrationA() async throws { #expect(true) }
	@Test func migrationB() async throws { #expect(true) }
}
```

添加 TODO 上下文，并在依赖隔离后移除。

## 8) 减少不稳定性清单

- 不依赖执行顺序。
- 没有共享可变全局/单例而不重置。
- 不使用任意睡眠作为同步手段。
- 单元测试中无隐藏的外部依赖。
- 确定性的夹具和稳定的时钟/随机源。
- 对临时失败使用显式的已知问题包装。

## 快速应做 / 不应做

- 应做：先优化确定性，再优化速度。
- 应做：保持大多数测试并行安全且依赖轻量。
- 不应做：将测试缓慢仅视为硬件问题。
- 不应做：把一切都移到 `@MainActor` 或 `.serialized` 来掩盖不稳定性。
