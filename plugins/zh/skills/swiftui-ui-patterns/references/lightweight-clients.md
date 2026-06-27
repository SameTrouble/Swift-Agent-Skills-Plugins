# 轻量客户端（基于闭包）

用此模式让网络或服务依赖保持简单且可测试，而无需引入完整视图模型或重型 DI 框架。它适用于希望拥有小型、可组合 API 表面并能在预览/测试中替换的 SwiftUI 应用。

## 意图
- 提供一个由异步闭包组成的微型"客户端"类型。
- 把业务逻辑保留在 store 或功能层，而非视图中。
- 在预览/测试中轻松打桩。

## 最小形态
```swift
struct SomeClient {
    var fetchItems: (_ limit: Int) async throws -> [Item]
    var search: (_ query: String, _ limit: Int) async throws -> [Item]
}

extension SomeClient {
    static func live(baseURL: URL = URL(string: "https://example.com")!) -> SomeClient {
        let session = URLSession.shared
        return SomeClient(
            fetchItems: { limit in
                // build URL, call session, decode
            },
            search: { query, limit in
                // build URL, call session, decode
            }
        )
    }
}
```

## 用法模式
```swift
@MainActor
@Observable final class ItemsStore {
    enum LoadState { case idle, loading, loaded, failed(String) }

    var items: [Item] = []
    var state: LoadState = .idle
    private let client: SomeClient

    init(client: SomeClient) {
        self.client = client
    }

    func load(limit: Int = 20) async {
        state = .loading
        do {
            items = try await client.fetchItems(limit)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
```

```swift
struct ContentView: View {
    @Environment(ItemsStore.self) private var store

    var body: some View {
        List(store.items) { item in
            Text(item.title)
        }
        .task { await store.load() }
    }
}
```

```swift
@main
struct MyApp: App {
    @State private var store = ItemsStore(client: .live())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
```

## 指引
- 把解码和 URL 构建保留在客户端；把状态变化保留在 store。
- 让 store 在 `init` 中接受客户端并保持私有。
- 避免全局单例；用 `.environment` 注入 store。
- 如需多种变体（mock/stub），添加 `static func mock(...)`。

## 陷阱
- 不要把 UI 状态放进客户端；状态保留在 store。
- 不要在客户端闭包中捕获 `self` 或视图状态。
