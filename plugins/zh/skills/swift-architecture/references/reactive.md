# Reactive 架构手册（Swift + Combine/RxSwift）

当涉及流驱动功能（搜索、实时更新、实时推送）时使用本参考。

## 目录
- [核心理念](#核心理念)
- [规范 Combine 模式](#规范-combine-模式)
- [按技术栈的 UI 集成](#按技术栈的-ui-集成)
- [操作符指导](#操作符指导)
- [RxSwift 映射说明](#rxswift-映射说明)
- [错误处理模式](#错误处理模式)
- [反模式与修复](#反模式与修复)
- [测试策略](#测试策略)
- [何时优先使用 Reactive 架构](#何时优先使用-reactive-架构)
- [PR 评审清单](#pr-评审清单)

## 核心理念

将输入、转换和输出建模为流。

```text
Input -> Publisher/Observable chain -> State -> UI
```

将流组合保持在表现层或专用响应式层，而非视图中。

## 规范 Combine 模式

```swift
final class SearchViewModel<S: Scheduler>: ObservableObject
where S.SchedulerTimeType == DispatchQueue.SchedulerTimeType {
    @Published var query = ""
    @Published private(set) var results: [String] = []

    private var cancellables = Set<AnyCancellable>()

    init(service: SearchService, scheduler: S) {
        $query
            .debounce(for: .milliseconds(300), scheduler: scheduler)
            .removeDuplicates()
            .map { query in
                service.search(query)
                    .replaceError(with: [])
            }
            .switchToLatest()
            .receive(on: scheduler)
            .sink { [weak self] values in
                self?.results = values
            }
            .store(in: &cancellables)
    }
}
```

在生产环境中，将 `DispatchQueue.main` 作为调度器传入。

规则：
- 对用户文本输入做 debounce
- 在有意义处去除重复
- 在写入 UI 绑定状态前跳转到主线程
- 将 cancellables 与生命周期绑定

## 按技术栈的 UI 集成

### SwiftUI 模式

- 将操作符链放在 `ObservableObject`/`@Observable` 类型中，而非 `View` 中。
- 将 UI 输入（`TextField`、开关、选择）绑定到模型上的 published 输入。

### UIKit 模式（Combine）

- 将管道放在 Presenter/ViewModel 中。
- 将 delegate/target-action 回调映射为输入 subject。
- 从单一状态订阅渲染。

```swift
import Combine
import UIKit

@MainActor
final class SearchPresenter<S: Scheduler> where S.SchedulerTimeType == DispatchQueue.SchedulerTimeType {
    let state = CurrentValueSubject<SearchResultState, Never>(.loaded([]))
    private let query = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(service: SearchService, scheduler: S) {
        query
            .debounce(for: .milliseconds(300), scheduler: scheduler)
            .removeDuplicates()
            .map { value in
                service.search(value)
                    .map(SearchResultState.loaded)
                    .catch { Just(.failed($0.localizedDescription)) }
            }
            .switchToLatest()
            .sink { [weak self] in self?.state.send($0) }
            .store(in: &cancellables)
    }

    func queryChanged(_ text: String) { query.send(text) }
}

// 在生产环境中，将 DispatchQueue.main 作为调度器传入。

final class SearchViewController: UIViewController, UISearchBarDelegate {
    private let presenter: SearchPresenter<DispatchQueue>
    private var cancellables = Set<AnyCancellable>()

    init(presenter: SearchPresenter<DispatchQueue>) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.state
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancellables)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        presenter.queryChanged(searchText)
    }

    private func render(_ state: SearchResultState) {
        // 从流状态渲染标签/列表/错误。
    }
}
```

## 操作符指导

- `debounce`：稳定嘈杂的用户输入（搜索框）
- `throttle`：限制高频事件（滚动、传感器）
- `flatMap`：当所有响应都重要时合并并发异步工作
- `switchToLatest`：仅保留最新请求（typeahead/搜索）
- `share`：避免多个订阅者的重复副作用
- `catch`：用回退流从可恢复错误中恢复

对于请求替换流程，优先使用 `switchToLatest` 而非嵌套订阅。

## RxSwift 映射说明

Combine 与 RxSwift 映射：
- `AnyPublisher` <-> `Observable`
- `AnyCancellable` <-> `DisposeBag`
- `receive(on:)` <-> `observe(on:)`
- `subscribe(on:)` 语义应有意使用，以卸载重活

## 错误处理模式

在流边界处恢复，并暴露对用户安全的状态：

```swift
protocol SearchService {
    func search(_ query: String) -> AnyPublisher<[String], Error>
}

enum SearchResultState: Equatable {
    case loaded([String])
    case failed(String)
}

func searchState(
    query: String,
    service: SearchService
) -> AnyPublisher<SearchResultState, Never> {
    service.search(query)
        .map(SearchResultState.loaded)
        .catch { Just(.failed($0.localizedDescription)) }
        .eraseToAnyPublisher()
}
```

对于瞬时失败，优先使用回退状态而非终止流。

## 反模式与修复

1. 嵌套订阅：
- 症状：订阅中嵌套订阅，取消和推理困难。
- 修复：用 `flatMap`/`switchToLatest` 组合。

2. 缺失取消/释放：
- 症状：屏幕释放或重新绑定后流仍在继续。
- 修复：正确存储 `AnyCancellable` 或使用 `DisposeBag` 生命周期。

3. 视图中的业务逻辑：
- 症状：视图构造管道并直接调用服务。
- 修复：将流编排移到 Presenter/ViewModel 层。

4. UI 线程违规：
- 症状：在主线程之外发布 UI 绑定状态。
- 修复：在 UI 变更前应用 `receive(on:)` / `observe(on:)`。

5. 无界扇出：
- 症状：大量订阅者触发重复网络调用。
- 修复：在副作用应单次执行处使用 `share`/多播。

## 测试策略

确定性测试流行为：
- 输入 -> 预期输出转换
- 成功路径发出预期状态序列
- 使用可控调度器的 debounce/throttle 行为
- 替换请求的取消行为
- 错误回退行为

规则：
- 为测试注入调度器/时间提供者
- 尽可能避免实时 sleep
- 断言发出的状态序列，而非内部操作符细节

```swift
import Combine
import CombineSchedulers
import XCTest

final class SearchViewModelTests: XCTestCase {
    func test_queryEmitsResults() {
        let subject = PassthroughSubject<[String], Error>()
        let stubService = StubSearchService { _ in subject.eraseToAnyPublisher() }
        // 需要 Point-Free 的 CombineSchedulers 包。
        let scheduler = DispatchQueue.test
        let vm = SearchViewModel(service: stubService, scheduler: scheduler.eraseToAnyScheduler())

        var collected: [[String]] = []
        let cancellable = vm.$results
            .dropFirst()
            .sink { collected.append($0) }

        vm.query = "swift"

        // 推进超过 debounce 间隔。
        scheduler.advance(by: .milliseconds(300))

        // 模拟服务响应。
        subject.send(["SwiftUI", "Swift"])
        subject.send(completion: .finished)

        // 推进以处理 receive(on:)。
        scheduler.advance()

        XCTAssertEqual(collected, [["SwiftUI", "Swift"]])
        cancellable.cancel()
    }

    func test_errorFallsBackToEmptyResults() {
        let subject = PassthroughSubject<[String], Error>()
        let stubService = StubSearchService { _ in subject.eraseToAnyPublisher() }
        let scheduler = DispatchQueue.test
        let vm = SearchViewModel(service: stubService, scheduler: scheduler.eraseToAnyScheduler())

        var collected: [[String]] = []
        let cancellable = vm.$results
            .dropFirst()
            .sink { collected.append($0) }

        vm.query = "swift"
        scheduler.advance(by: .milliseconds(300))

        subject.send(completion: .failure(TestError.offline))
        scheduler.advance()

        XCTAssertEqual(collected, [[]])
        cancellable.cancel()
    }

    func test_switchToLatest_ignoresStaleInFlightResponse() {
        let first = PassthroughSubject<[String], Error>()
        let second = PassthroughSubject<[String], Error>()
        let stubService = StubSearchService { query in
            switch query {
            case "sw":
                return first.eraseToAnyPublisher()
            case "swift":
                return second.eraseToAnyPublisher()
            default:
                return Empty<[String], Error>().eraseToAnyPublisher()
            }
        }
        let scheduler = DispatchQueue.test
        let vm = SearchViewModel(service: stubService, scheduler: scheduler.eraseToAnyScheduler())

        var collected: [[String]] = []
        let cancellable = vm.$results
            .dropFirst()
            .sink { collected.append($0) }

        vm.query = "sw"
        scheduler.advance(by: .milliseconds(300))

        vm.query = "swift"
        scheduler.advance(by: .milliseconds(300))

        // 这应该被忽略，因为更新的查询替换了订阅。
        first.send(["stale"])
        second.send(["fresh"])
        scheduler.advance()

        XCTAssertEqual(collected, [["fresh"]])
        cancellable.cancel()
    }
}

struct StubSearchService: SearchService {
    let searchHandler: (String) -> AnyPublisher<[String], Error>
    func search(_ query: String) -> AnyPublisher<[String], Error> {
        searchHandler(query)
    }
}

private enum TestError: Error {
    case offline
}
```

规范的 `SearchViewModel` 已支持为测试注入调度器。

## 何时优先使用 Reactive 架构

优先使用的场景：
- 功能是事件密集且面向流的
- 实时更新和转换是核心行为
- 可组合的异步管道比命令式回调更清晰

优先使用 MVI/TCA 的场景：
- 显式状态机和严格 reducer 流是主要需求

## PR 评审清单

- 流组合无嵌套订阅。
- 取消/释放与生命周期安全。
- UI 绑定更新被调度到主线程。
- 操作符匹配意图（`debounce`、`throttle`、`switchToLatest`、`share`）。
- 视图/控制器不持有业务管道逻辑。
- 错误处理使 UX 对瞬时失败保持韧性。
