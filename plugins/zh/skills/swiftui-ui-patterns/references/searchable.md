# Searchable

## 意图

用 `searchable` 添加带可选作用域和异步结果的原生搜索 UI。

## 核心模式

- 将 `searchable(text:)` 绑定到局部状态。
- 用 `.searchScopes` 做多种搜索模式。
- 用 `.task(id: searchQuery)` 或防抖任务避免过度请求。
- 结果加载时显示占位符或进度状态。

## 示例：带作用域的 searchable

```swift
@MainActor
struct ExploreView: View {
  @State private var searchQuery = ""
  @State private var searchScope: SearchScope = .all
  @State private var isSearching = false
  @State private var results: [SearchResult] = []

  var body: some View {
    List {
      if isSearching {
        ProgressView()
      } else {
        ForEach(results) { result in
          SearchRow(result: result)
        }
      }
    }
    .searchable(
      text: $searchQuery,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: Text("Search")
    )
    .searchScopes($searchScope) {
      ForEach(SearchScope.allCases, id: \.self) { scope in
        Text(scope.title)
      }
    }
    .task(id: searchQuery) {
      await runSearch()
    }
  }

  private func runSearch() async {
    guard !searchQuery.isEmpty else {
      results = []
      return
    }
    isSearching = true
    defer { isSearching = false }
    try? await Task.sleep(for: .milliseconds(250))
    results = await fetchResults(query: searchQuery, scope: searchScope)
  }
}
```

## 应保留的设计选择

- 当搜索为空或无结果时显示占位符。
- 对输入防抖以避免轰炸网络。
- 保持搜索状态在视图局部。

## 陷阱

- 避免对空字符串运行搜索。
- 获取期间不要阻塞主线程。
