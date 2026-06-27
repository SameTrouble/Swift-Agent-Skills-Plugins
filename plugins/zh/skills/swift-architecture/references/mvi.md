# MVI 手册（Swift + SwiftUI/UIKit）

当需要严格单向数据流和确定性状态转换时使用本参考。

## 目录
- [心智模型](#心智模型)
- [核心类型](#核心类型)
- [Reducer 模式](#reducer-模式)
- [Store 模式](#store-模式)
- [组合 Reducer](#组合-reducer)
- [视图指导](#视图指导)
- [并发规则](#并发规则)
- [反模式与修复](#反模式与修复)
- [测试期望](#测试期望)
- [何时优先使用 MVI](#何时优先使用-mvi)
- [PR 评审清单](#pr-评审清单)

## 心智模型

```text
Intent -> Reducer -> New State -> View
                 -> Effect -> Action -> Reducer
```

核心规则：
- 保持唯一真相源：`State`。
- 保持 reducer 逻辑确定性。
- 将副作用隔离在 `Effect` 中。
- 将副作用输出作为 `Action` 回流。

## 核心类型

### State

- 仅使用值类型（`struct`）。
- 在可行处保持 state 可判等/可序列化。
- 存储规范状态，而非冗余派生值。

```swift
enum Loadable<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

struct CounterState: Equatable {
    var load: Loadable<Int> = .idle

    var count: Int {
        guard case .loaded(let value) = load else { return 0 }
        return value
    }
}
```

### Intent

- 仅表示用户驱动的输入。
- 不要用 intent 表示网络响应。

```swift
enum CounterIntent {
    case incrementTapped
    case decrementTapped
    case resetTapped
}
```

### Action

- 表示内部事件和副作用结果。
- Reducer 处理 action 以完成异步闭环。

```swift
enum CounterAction {
    case incrementResponse(Result<Int, Error>)
    case decrementResponse(Result<Int, Error>)
    case resetResponse(Result<Int, Error>)
}
```

用于完成异步转换的 action reducer：

```swift
func reduce(state: inout CounterState, action: CounterAction) {
    switch action {
    case .incrementResponse(.success(let value)):
        state.load = .loaded(value)
    case .incrementResponse(.failure(let error)):
        state.load = .failed(error.localizedDescription)
    case .decrementResponse(.success(let value)):
        state.load = .loaded(value)
    case .decrementResponse(.failure(let error)):
        state.load = .failed(error.localizedDescription)
    case .resetResponse(.success(let value)):
        state.load = .loaded(value)
    case .resetResponse(.failure(let error)):
        state.load = .failed(error.localizedDescription)
    }
}
```

### Effect

- 封装异步副作用。
- 将副作用执行保持在 store 中。

```swift
enum Effect<Action> {
    case none
    case run(() async throws -> Action)
    case cancellable(id: AnyHashable, () async throws -> Action)
}
```

## Reducer 模式

- 对 `Intent` 做 reduce：为即时转换变更状态，并可选地返回 effect。
- 对 `Action` 做 reduce：从副作用输出完成转换。
- 避免在 reducer 分支内直接产生副作用。

```swift
protocol CounterServicing {
    func increment() async throws -> Int
    func decrement() async throws -> Int
    func reset() async throws -> Int
}

func reduce(
    state: inout CounterState,
    intent: CounterIntent,
    service: CounterServicing
) -> Effect<CounterAction>? {
    switch intent {
    case .incrementTapped:
        state.load = .loading
        return .run {
            do {
                let value = try await service.increment()
                return .incrementResponse(.success(value))
            } catch {
                return .incrementResponse(.failure(error))
            }
        }
    case .decrementTapped:
        state.load = .loading
        return .run {
            do {
                let value = try await service.decrement()
                return .decrementResponse(.success(value))
            } catch {
                return .decrementResponse(.failure(error))
            }
        }
    case .resetTapped:
        state.load = .loading
        return .run {
            do {
                let value = try await service.reset()
                return .resetResponse(.success(value))
            } catch {
                return .resetResponse(.failure(error))
            }
        }
    }
}
```

这个签名是一个务实的捷径：将 `service` 传入 `reduce` 保持调用点简单，但 reducer 与环境耦合。如果想要更严格的 MVI 纯度，让 `reduce` 返回 effect 描述符，并在 reducer 之外执行它们。

```swift
enum CounterEffect {
    case increment
    case decrement
    case reset
}

func reduce(state: inout CounterState, intent: CounterIntent) -> CounterEffect? {
    switch intent {
    case .incrementTapped:
        state.load = .loading
        return .increment
    case .decrementTapped:
        state.load = .loading
        return .decrement
    case .resetTapped:
        state.load = .loading
        return .reset
    }
}

func run(_ effect: CounterEffect, service: CounterServicing) async -> CounterAction {
    do {
        switch effect {
        case .increment:
            return .incrementResponse(.success(try await service.increment()))
        case .decrement:
            return .decrementResponse(.success(try await service.decrement()))
        case .reset:
            return .resetResponse(.success(try await service.reset()))
        }
    } catch {
        switch effect {
        case .increment:
            return .incrementResponse(.failure(error))
        case .decrement:
            return .decrementResponse(.failure(error))
        case .reset:
            return .resetResponse(.failure(error))
        }
    }
}
```

将纯 `reduce/run` 对接入 `Store` 的适配器模式：

```swift
@MainActor
func makeCounterStore(service: CounterServicing) -> Store<CounterState, CounterIntent, CounterAction> {
    Store(
        initial: CounterState(),
        reduceIntent: { state, intent in
            guard let effect = reduce(state: &state, intent: intent) else { return nil }
            return .run {
                await run(effect, service: service)
            }
        },
        reduceAction: { state, action in
            reduce(state: &state, action: action)
        }
    )
}
```

## Store 模式

- 将 store 保持在主线程上，确保 UI 变更安全。
- 接收 `Intent`，运行 reducer，执行 `Effect`，派发 `Action`。
- 为并发请求添加取消和请求版本控制。
- 将所有预期的服务失败映射为显式失败 action；`onUnexpectedError` 应该是 bug 钩子，而非业务错误路径。

```swift
@MainActor
final class Store<State, Intent, Action>: ObservableObject {
    @Published private(set) var state: State

    private let reduceIntent: (inout State, Intent) -> Effect<Action>?
    private let reduceAction: (inout State, Action) -> Void
    private let onUnexpectedError: @MainActor (Error) -> Void
    private var activeTasks: [AnyHashable: Task<Void, Never>] = [:]

    init(
        initial: State,
        reduceIntent: @escaping (inout State, Intent) -> Effect<Action>?,
        reduceAction: @escaping (inout State, Action) -> Void,
        onUnexpectedError: @escaping @MainActor (Error) -> Void = { error in
            assertionFailure("Unexpected unmodeled effect error: \(error)")
        }
    ) {
        self.state = initial
        self.reduceIntent = reduceIntent
        self.reduceAction = reduceAction
        self.onUnexpectedError = onUnexpectedError
    }

    func send(_ intent: Intent) {
        guard let effect = reduceIntent(&state, intent) else { return }
        handle(effect)
    }

    private func handle(_ effect: Effect<Action>) {
        switch effect {
        case .none:
            break
        case .run(let operation):
            Task {
                do {
                    let action = try await operation()
                    reduceAction(&state, action)
                } catch is CancellationError {
                    // 任务被取消；不更新状态。
                } catch {
                    onUnexpectedError(error)
                }
            }
        case .cancellable(let id, let operation):
            activeTasks[id]?.cancel()
            activeTasks[id] = Task {
                do {
                    let action = try await operation()
                    reduceAction(&state, action)
                } catch is CancellationError {
                    // 被同 id 的新请求取消。
                } catch {
                    onUnexpectedError(error)
                }
                activeTasks[id] = nil
            }
        }
    }

    deinit {
        for task in activeTasks.values { task.cancel() }
    }
}
```

将预期的服务失败映射为显式失败 action；将 `onUnexpectedError` 留给真正的穿透故障（例如解码 bug、违反不变量、或 effect 接线错误）。如果此处理器因正常的 API 失败而触发，将其视为建模 bug，并添加显式失败 action 路径。

## 组合 Reducer

按功能拆分 reducer 并组合它们。

```swift
enum AppAction {
    case counter(CounterAction)
    case settings(SettingsAction)
}

func appReduce(
    state: inout AppState,
    intent: AppIntent,
    services: AppServices
) -> Effect<AppAction>? {
    switch intent {
    case .counter(let counterIntent):
        return counterReduce(
            state: &state.counter,
            intent: counterIntent,
            service: services.counter
        )?.map(AppAction.counter)
    case .settings(let settingsIntent):
        return settingsReduce(
            state: &state.settings,
            intent: settingsIntent,
            service: services.settings
        )?.map(AppAction.settings)
    }
}
```

为 `Effect` 添加 `map` 辅助方法，将子 action 提升为父 action：

```swift
extension Effect {
    func map<B>(_ transform: @escaping (Action) -> B) -> Effect<B> {
        switch self {
        case .none:
            return .none
        case .run(let operation):
            return .run {
                let action = try await operation()
                return transform(action)
            }
        case .cancellable(let id, let operation):
            return .cancellable(id: id) {
                let action = try await operation()
                return transform(action)
            }
        }
    }
}
```

组合权衡：单个应用级 `AppIntent`/`AppAction` 随着功能数量增长可能嵌套很深。在可行时优先使用功能级 store，仅在流程边界（例如 tab 根、结账流程、引导）组合，而非强制使用一个全局巨型枚举。

## 视图指导

- 仅渲染 `store.state`。
- 通过 `store.send(intent)` 发送用户事件。
- 永远不要在视图中直接变更领域状态。

### SwiftUI 集成

```swift
struct CounterView: View {
    @StateObject var store: Store<CounterState, CounterIntent, CounterAction>

    var body: some View {
        VStack {
            Text("Count: \(store.state.count)")
            if case .loading = store.state.load { ProgressView() }
            Button("+") { store.send(.incrementTapped) }
            Button("-") { store.send(.decrementTapped) }
            Button("Reset") { store.send(.resetTapped) }
        }
    }
}
```

如果你的 SwiftUI 优先功能面向 iOS 17+，可以用 `@Observable` store 替换 `ObservableObject`/`@Published` store（如 MVVM 手册所示），并在视图中使用 `@State` + `@Bindable`。当同一 store 必须向 UIKit 暴露 Combine publisher 时，保留 `ObservableObject`。

### UIKit 集成

在 UIKit 中，订阅一次，从状态渲染，并将控件事件映射为 intent。

```swift
import Combine
import UIKit

final class CounterViewController: UIViewController {
    private let store: Store<CounterState, CounterIntent, CounterAction>
    private var cancellables = Set<AnyCancellable>()

    init(store: Store<CounterState, CounterIntent, CounterAction>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        store.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancellables)
    }

    @objc private func incrementTapped() {
        store.send(.incrementTapped)
    }

    private func render(_ state: CounterState) {
        title = "Count: \(state.count)"
        // 仅从状态更新标签/按钮/加载。
    }
}
```

UIKit 规则：
- 将所有 UI 写入集中在 `render(_:)` 中
- 将 delegate/target-action 回调转换为 `Intent`

## 并发规则

- 在可能出现重复请求时，按 intent/effect key 追踪活动任务。
- 在发起更新请求前取消过期的进行中工作。
- 当响应可能乱序到达时使用请求 ID。
- 将共享可变服务状态放在 actor 中。

## 反模式与修复

1. reducer 内部副作用：
- 症状：在 reducer 分支中直接做分析/网络调用。
- 修复：发出 `Effect` 并通过 action 循环处理。

2. Intent 与 action 合并：
- 症状：用户输入和副作用输出共用一个枚举。
- 修复：分离 `Intent` 和 `Action`。

3. 多个真相源：
- 症状：本地 `@State` 镜像 store 状态。
- 修复：仅在 store 中保持规范状态。

4. 冗余存储派生字段：
- 症状：持久化 `isEven` 与 `count` 并存。
- 修复：计算派生属性。

5. 单体 reducer：
- 症状：跨不相关领域的庞大 switch。
- 修复：按功能拆分 reducer 并组合。

## 测试期望

- 单元测试 intent reducer 转换。
- 单元测试 action reducer 成功/失败转换。
- 验证取消和过期响应处理。
- 使用可控的服务、调度器或时钟保持测试确定性。
- 断言状态机行为，而非视图细节。

示例测试套件：

```swift
import XCTest

struct StubCounterService: CounterServicing {
    func increment() async throws -> Int { 1 }
    func decrement() async throws -> Int { 0 }
    func reset() async throws -> Int { 0 }
}

final class CounterReducerTests: XCTestCase {
    func test_intentIncrement_setsLoading_andReturnsEffect() {
        var state = CounterState()
        let service = StubCounterService()

        let effect = reduce(
            state: &state,
            intent: .incrementTapped,
            service: service
        )

        XCTAssertEqual(state.load, .loading)
        XCTAssertNotNil(effect)
    }

    func test_actionFailure_setsError_andStopsLoading() {
        var state = CounterState(load: .loaded(3))

        reduce(state: &state, action: .incrementResponse(.failure(TestError.offline)))

        XCTAssertEqual(state.count, 0)
        if case .failed = state.load {
            // 符合预期
        } else {
            XCTFail("Expected failed state")
        }
    }
}

struct SearchState: Equatable {
    var latestRequestID: UUID?
    var results: [String] = []
}

enum SearchAction {
    case response(requestID: UUID, Result<[String], Error>)
}

func reduce(state: inout SearchState, action: SearchAction) {
    switch action {
    case .response(let requestID, .success(let results)):
        guard requestID == state.latestRequestID else { return }
        state.results = results
    case .response:
        break
    }
}

final class SearchReducerTests: XCTestCase {
    func test_matchingLatestRequest_updatesResults() {
        let requestID = UUID()
        var state = SearchState(latestRequestID: requestID, results: [])

        reduce(
            state: &state,
            action: .response(requestID: requestID, .success(["new"]))
        )

        XCTAssertEqual(state.results, ["new"])
    }

    func test_staleResponse_isIgnored() {
        let latestID = UUID()
        let staleID = UUID()
        var state = SearchState(latestRequestID: latestID, results: ["current"])

        reduce(
            state: &state,
            action: .response(requestID: staleID, .success(["old"]))
        )

        XCTAssertEqual(state.results, ["current"])
    }
}

private enum TestError: Error {
    case offline
}
```

## 何时优先使用 MVI

优先使用 MVI 的场景：
- 复杂状态机
- 重度并发/副作用编排
- 高确定性和可测试性要求

优先使用 MVVM 的场景：
- 屏幕复杂度中等
- 较少样板代码比严格状态机建模更重要

## PR 评审清单

- State 基于值类型且为规范源。
- Reducer 确定且无副作用。
- Effect 被隔离并映射回 action。
- 并发请求存在取消/版本控制。
- View 仅发送 intent；无直接业务变更。
- Reducer 测试覆盖成功、失败和取消。
