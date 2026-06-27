# 异步状态与任务生命周期

## 意图

当视图加载数据、响应变化的输入，或协调应遵循 SwiftUI 视图生命周期的异步工作时，使用此模式。

## 核心规则

- 用 `.task` 处理属于视图生命周期的加载即出现的工作。
- 当异步工作应因查询、选择或标识符等变化输入而重启时，用 `.task(id:)`。
- 将取消视为视图驱动任务的正常路径。在较长流程中检查 `Task.isCancelled`，不要把取消呈现为面向用户的错误。
- 在用户驱动的异步工作（如搜索）扩散为重复请求之前，对其进行防抖或合并。
- 保持面向 UI 的模型和变更在主线程安全；在服务中做后台工作，然后将结果发布回 UI 状态。

## 示例：出现时加载

```swift
struct DetailView: View {
  let id: String
  @State private var state: LoadState<Item> = .idle
  @Environment(ItemClient.self) private var client

  var body: some View {
    content
      .task {
        await load()
      }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .idle, .loading:
      ProgressView()
    case .loaded(let item):
      ItemContent(item: item)
    case .failed(let error):
      ErrorView(error: error)
    }
  }

  private func load() async {
    state = .loading
    do {
      state = .loaded(try await client.fetch(id: id))
    } catch is CancellationError {
      return
    } catch {
      state = .failed(error)
    }
  }
}
```

## 示例：输入变化时重启

```swift
struct SearchView: View {
  @State private var query = ""
  @State private var results: [ResultItem] = []
  @Environment(SearchClient.self) private var client

  var body: some View {
    List(results) { item in
      Text(item.title)
    }
    .searchable(text: $query)
    .task(id: query) {
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, !query.isEmpty else {
        results = []
        return
      }
      do {
        results = try await client.search(query)
      } catch is CancellationError {
        return
      } catch {
        results = []
      }
    }
  }
}
```

## 何时把工作移出视图

- 如果异步流程跨越多个屏幕或必须在视图关闭后存活，把它移到服务或模型中。
- 如果视图主要协调应用级生命周期或账户变化，在 `app-wiring.md` 的应用外壳处连接。
- 如果重试、缓存或离线策略变得复杂，将策略保留在客户端/服务中，视图只做简单的状态转换。

## 陷阱

- 不要直接从 `body` 启动网络工作。
- 不要对搜索、输入预测或快速变化的选择忽略取消。
- 当单一数据源足够时，避免在多处存储派生的异步状态。
