# Trait 与 Tag

## 何时使用此参考

在控制测试执行行为、关联 Bug 上下文，以及组织大型测试套件以进行针对性运行和 CI 过滤时使用此文件。

## Trait 类别

- **信息类**：显示名称、Bug 关联、Tag。
- **条件类**：`.enabled(if:)`、`.disabled(...)`、可用性属性。
- **行为类**：`.timeLimit(...)`、`.serialized`。

## 基础 Trait 示例

```swift
import Testing

@Test("Uploads complete quickly", .timeLimit(.seconds(10)))
func uploadWithinTimeLimit() async throws {
	#expect(true)
}

@Test(.disabled("Flaky on CI while investigating issue"), .bug("https://example.com/issues/12"))
func temporaryDisabledTest() {
	#expect(true)
}
```

## 条件与禁用

- 对运行时评估的环境使用 `.enabled(if:)` 或 `.disabled(if:)`。
- 使用 `.disabled("reason")` 而非注释掉测试。
- 在禁用 Trait 中包含可操作的说明文本，用于 CI/测试报告。
- 添加 `.bug(...)` 以关联问题跟踪器，便于未来清理。

### 运行时条件示例

```swift
import Testing

enum Runtime {
	static let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
}

@Test(.enabled(if: Runtime.isCI))
func ciOnlySmokeTest() {
	#expect(true)
}
```

## 可用性

- 当整个行为受系统版本限制时，对测试使用 `@available`。
- 优先使用 `@available` 而非内联运行时检查，以获得更清晰的报告语义。

```swift
import Testing

@available(iOS 18, *)
@Test func modernPushPayload() {
	#expect(true)
}
```

## Tag

- 声明自定义 Tag 并应用于测试/套件，以实现跨套件分组。
- 使用 Tag 进行测试计划的包含/排除、导航器过滤和失败分析。
- 将 Tag 视为横切元数据，而非套件结构的替代品。
- 使用有意义的领域标签（如 `networking`、`regression`、`spicy`）而非模糊术语。

### 定义与应用 Tag

```swift
import Testing

extension Tag {
	@Tag static var networking: Self
	@Tag static var regression: Self
}

@Suite(.tags(.networking))
struct APITests {
	@Test func fetchUser() async throws {
		#expect(true)
	}
}

struct CheckoutTests {
	@Test(.tags(.regression))
	func orderTotal() {
		#expect(3 * 3 == 9)
	}
}
```

## 继承与作用域

- 套件上的 Trait 和 Tag 会级联到所包含的测试。
- 当广泛适用时在套件级应用；当特定时按测试应用。
- 保持 Trait 意图明确，以避免意外的大范围行为变更。

## 应做 / 不应做

- 应做：将共享 Tag 放在套件级以保持一致性。
- 应做：为临时禁用或已知失败附上 Bug 关联。
- 不应做：将 Tag 作为有意义的套件分组的替代品。
- 不应做：过度使用 `.serialized` 作为笼统的可靠性修复。

## 评审清单

- 每个被禁用的测试都有原因（理想情况下还有 Bug 关联）。
- Tag 反映领域关注点并被一致复用。
- 可用性和条件 Trait 应用于最小且正确的作用域。
