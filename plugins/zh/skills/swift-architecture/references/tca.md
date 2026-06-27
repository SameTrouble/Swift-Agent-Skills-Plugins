# TCA 手册（Swift + SwiftUI/UIKit）

当需要严格单向数据流、强组合能力以及 `TestStore` 驱动的测试时使用本参考。

## 目录
- [心智模型](#心智模型)
- [规范功能结构](#规范功能结构)
- [视图集成](#视图集成)
- [组合模式](#组合模式)
- [依赖规则](#依赖规则)
- [Effect 与并发](#effect-与并发)
- [导航模式](#导航模式)
- [使用 TestStore 测试](#使用-teststore-测试)
- [反模式与修复](#反模式与修复)
- [何时优先使用 TCA](#何时优先使用-tca)
- [PR 评审清单](#pr-评审清单)

## 心智模型

```text
View -> store.send(Action)
Reducer(State, Action) -> state mutation + Effect<Action>
Effect emits Action -> reducer
```

核心期望：
- 基于值类型的状态
- reducer 驱动决策
- 通过 effect 隔离副作用
- 通过 TCA 依赖进行依赖注入
- 使用带 scope 的 reducer 进行功能组合

## 规范功能结构

优先使用带 `@Reducer` 和 `@ObservableState` 的现代 TCA。

```swift
import ComposableArchitecture

@Reducer
struct CounterFeature {
  enum CancelID { case fact }

  enum FactError: Error, Equatable {
    case unavailable
  }

  @ObservableState
  struct State: Equatable {
    var count = 0
    var isLoading = false
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: Equatable {
    case incrementTapped
    case decrementTapped
    case factButtonTapped
    case factResponse(Result<String, FactError>)
    case alert(PresentationAction<Alert>)

    enum Alert: Equatable {}
  }

  @Dependency(\.numberFact) var numberFact

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementTapped:
        state.count += 1
        return .none

      case .decrementTapped:
        state.count -= 1
        return .none

      case .factButtonTapped:
        state.isLoading = true
        let n = state.count
        return .run { send in
          do {
            let fact = try await numberFact.fetch(n)
            await send(.factResponse(.success(fact)))
          } catch is CancellationError {
            // 当新请求替换当前请求时，取消是预期行为。
          } catch {
            await send(.factResponse(.failure(.unavailable)))
          }
        }
        .cancellable(id: CancelID.fact, cancelInFlight: true)

      case .factResponse(.success(let fact)):
        state.isLoading = false
        state.alert = AlertState { TextState(fact) }
        return .none

      case .factResponse(.failure):
        state.isLoading = false
        state.alert = AlertState { TextState("Could not load fact.") }
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
```

## 视图集成

规则：
- 从视图发送 action
- 永远不要在视图中直接变更业务状态
- 观察最小可行的状态切片

### 现代模式（TCA 1.7+，使用 `@ObservableState`）

使用 `@ObservableState` 时，视图直接访问 store 属性——无需 `WithViewStore`。

```swift
struct CounterView: View {
  @Bindable var store: StoreOf<CounterFeature>

  var body: some View {
    VStack {
      Text("Count: \(store.count)")
      Button("+") { store.send(.incrementTapped) }
      Button("-") { store.send(.decrementTapped) }
      Button("Fact") { store.send(.factButtonTapped) }
      if store.isLoading { ProgressView() }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
```

### 旧版模式（TCA < 1.7，使用 `WithViewStore`）

```swift
struct CounterView: View {
  let store: StoreOf<CounterFeature>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      VStack {
        Text("Count: \(viewStore.count)")
        Button("+") { viewStore.send(.incrementTapped) }
        Button("-") { viewStore.send(.decrementTapped) }
        Button("Fact") { viewStore.send(.factButtonTapped) }
        if viewStore.isLoading { ProgressView() }
      }
      .alert(store: store.scope(state: \.alert, action: \.alert))
    }
  }
}
```

UIKit 指导：
- 在视图控制器中持有 store
- 从 store 订阅状态变更
- 将渲染集中在一个方法中

具体 UIKit 模式：

```swift
import ComposableArchitecture
import Combine
import UIKit

@MainActor
final class CounterViewController: UIViewController {
  private let viewStore: ViewStoreOf<CounterFeature>
  private var cancellables = Set<AnyCancellable>()

  init(store: StoreOf<CounterFeature>) {
    self.viewStore = ViewStore(store, observe: { $0 })
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { return nil }

  override func viewDidLoad() {
    super.viewDidLoad()

    viewStore.publisher
      .sink { [weak self] state in
        self?.render(state)
      }
      .store(in: &cancellables)
  }

  @objc private func incrementTapped() {
    viewStore.send(.incrementTapped)
  }

  private func render(_ state: CounterFeature.State) {
    title = "Count: \(state.count)"
    // 仅从状态渲染标签/按钮/加载。
  }
}
```

## 组合模式

使用 `Scope` 进行父子组合。

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var counter = CounterFeature.State()
  }

  enum Action: Equatable {
    case counter(CounterFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.counter, action: \.counter) {
      CounterFeature()
    }
  }
}
```

对具有稳定标识的集合使用 `IdentifiedArrayOf` 和 `forEach`。

## 依赖规则

- 保持依赖面小且聚焦于能力
- 通过 `@Dependency` 注入
- 永远不要将依赖放在 state 中
- 避免在 reducer 中调用单例

```swift
struct NumberFactClient {
  var fetch: @Sendable (Int) async throws -> String
}

extension NumberFactClient: DependencyKey {
  static let liveValue = Self(fetch: { number in
    "\(number) is a good number."
  })

  static let testValue = Self(fetch: { _ in
    "Test fact"
  })
}

extension DependencyValues {
  var numberFact: NumberFactClient {
    get { self[NumberFactClient.self] }
    set { self[NumberFactClient.self] = newValue }
  }
}
```

## Effect 与并发

使用 `.run` 执行异步工作，并将结果作为 action 回流。

对于可重入工作，添加取消（`.cancellable(id:cancelInFlight:)`）并将失败映射为显式 action。
如果取消不足以应对，添加请求版本控制。

## 导航模式

在 state 中建模导航，并通过 action 驱动。

常见形态：
- `@Presents var alert: AlertState<Action.Alert>?`
- `destination: Destination.State?`
- 为每个展示 action（`alert`、`destination` 等）附加匹配的 `.ifLet` reducer。

将导航决策保持在 reducer 中，并保持视图声明式。

## 使用 `TestStore` 测试

使用 `TestStore` 进行确定性 action/state 断言。
在异步 effect 中覆盖成功、失败和取消路径。

```swift
import XCTest
import ComposableArchitecture

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testIncrement() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }

    await store.send(.incrementTapped) {
      $0.count = 1
    }
  }

  func testFactSuccess() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.numberFact.fetch = { _ in "42 is great" }
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.success("42 is great"))) {
      $0.isLoading = false
      $0.alert = AlertState { TextState("42 is great") }
    }
  }

  func testFactFailure() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.numberFact.fetch = { _ in throw CounterFeature.FactError.unavailable }
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.failure(.unavailable))) {
      $0.isLoading = false
      $0.alert = AlertState { TextState("Could not load fact.") }
    }
  }

  func testFactCancellation_replacesInFlightRequest() async {
    let clock = TestClock()

    actor Sequence {
      var values = ["first", "second"]
      func next() -> String { values.removeFirst() }
    }
    let sequence = Sequence()

    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.numberFact.fetch = { _ in
        let value = await sequence.next()
        try await clock.sleep(for: .seconds(1))
        return value
      }
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.send(.factButtonTapped)

    await clock.advance(by: .seconds(1))

    await store.receive(.factResponse(.success("second"))) {
      $0.isLoading = false
      $0.alert = AlertState { TextState("second") }
    }
  }
}
```

## 反模式与修复

1. 巨型功能无组合：
- 症状：处理不相关领域的巨型 reducer。
- 修复：拆分为子 reducer 并通过 `Scope` 组合。

2. state 中使用引用类型：
- 症状：state 中存在类实例或共享可变集合。
- 修复：保持 state 基于值类型且可判等。

3. 视图中做业务工作：
- 症状：视图调用服务或转换领域数据。
- 修复：将逻辑移到 reducer/effect，并暴露可渲染的状态。

4. reducer 中直接副作用：
- 症状：内联分析/网络调用，无 effect 边界。
- 修复：通过依赖和 effect 路由。

5. store 外状态重复：
- 症状：本地 `@State` 镜像 store 状态。
- 修复：在 store 中保持唯一真相源。

6. 过度观察大状态：
- 症状：广泛观察触发不必要的重渲染。
- 修复：观察 scoped 状态并拆分 view/store 边界。

7. 缺失取消：
- 症状：重叠 effect 覆盖当前意图。
- 修复：使用 `.cancellable(id:cancelInFlight:)`，必要时使用请求 ID。

## 何时优先使用 TCA

优先使用 TCA 的场景：
- 应用有许多有状态工作流
- 测试确定性至关重要
- 需要组合和模块化扩展
- effect 取消正确性很重要

优先使用 MVVM 或轻量 MVI 变体的场景：
- 应用较小且不太可能增长
- 团队尚未准备好接受 UDF 纪律
- 功能速度和低样板优先

## PR 评审清单

- State 基于值类型且可判等。
- Reducer 避免直接副作用。
- 依赖被注入且测试中可覆盖。
- Effect 在需要时有取消策略。
- 功能通过 `Scope`/`forEach` 组合。
- 导航在 state 中建模。
- 测试覆盖成功、失败和取消流程。
- 视图仅渲染和发送 action。
