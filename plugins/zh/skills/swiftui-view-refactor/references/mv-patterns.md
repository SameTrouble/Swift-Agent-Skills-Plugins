# MV 模式参考

用于判断 SwiftUI 功能应当保持为纯 MV 还是引入视图模型的精炼指引。

灵感来自用户提供的来源《SwiftUI in 2025: Forget MVVM》（Thomas Ricouard），但在此重写为实用的重构参考。

## 默认立场

- 默认采用 MV：视图是轻量的状态表达和编排点。
- 优先使用 `@State`、`@Environment`、`@Query`、`.task`、`.task(id:)` 和 `onChange`，然后再考虑视图模型。
- 把业务逻辑留在服务、模型或领域类型里，而不是视图 body 中。
- 在发明视图模型层之前，先把大型屏幕拆分成更小的视图类型。
- 避免手动获取数据或状态管道，那会重复 SwiftUI 或 SwiftData 的机制。
- 优先测试服务、模型和转换；视图应保持简单和声明式。

## 何时避免使用视图模型

当视图模型主要会做以下事情时，不要引入它：
- 镜像本地视图状态，
- 包装已通过 `@Environment` 获取的值，
- 重复 `@Query`、`@State` 或基于 `Binding` 的数据流，
- 仅仅因为视图 body 太长而存在，
- 持有可以用 `.task` 加本地视图状态承载的一次性异步加载逻辑。

在这些情况下，简化视图和数据流，而不是增加间接层。

## 何时可能需要视图模型

当以下条件中至少有一个成立时，视图模型可能是合理的：
- 用户明确要求使用，
- 代码库已对该功能标准化采用视图模型模式，
- 屏幕需要一个长生命周期的引用模型，其行为无法自然地仅放在服务中，
- 该功能在适配一个需要专用桥接对象的非 SwiftUI API，
- 多个视图共享同一份表现层专用状态，且该状态不适合建模为应用级环境数据。

即便如此，也要让视图模型保持小型、显式，并尽可能非可选。

## 首选模式：本地状态加环境

```swift
struct FeedView: View {
    @Environment(BlueSkyClient.self) private var client

    enum ViewState {
        case loading
        case error(String)
        case loaded([Post])
    }

    @State private var viewState: ViewState = .loading

    var body: some View {
        List {
            switch viewState {
            case .loading:
                ProgressView("Loading feed...")
            case .error(let message):
                ErrorStateView(message: message, retryAction: { await loadFeed() })
            case .loaded(let posts):
                ForEach(posts) { post in
                    PostRowView(post: post)
                }
            }
        }
        .task { await loadFeed() }
    }

    private func loadFeed() async {
        do {
            let posts = try await client.getFeed()
            viewState = .loaded(posts)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
}
```

为什么这是首选：
- 状态紧贴渲染它的 UI，
- 依赖来自环境而非包装对象，
- 视图协调 UI 流程，而服务拥有真正的工作。

## 首选模式：用修饰符做轻量编排

```swift
.task(id: searchText) {
    guard !searchText.isEmpty else {
        results = []
        return
    }
    await searchFeed(query: searchText)
}

.onChange(of: isInSearch, initial: false) {
    guard !isInSearch else { return }
    Task { await fetchSuggestedFeed() }
}
```

用视图生命周期修饰符做简单、本地的编排。除非行为明显超出视图范围，否则不要默认把它转换成视图模型。

## SwiftData 说明

SwiftData 是尽量把数据流保留在视图内的一个有力论据。

优先采用：

```swift
struct BookListView: View {
    @Query private var books: [Book]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(books) { book in
                BookRowView(book: book)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(book)
                        }
                    }
            }
        }
    }
}
```

除非功能有明确理由，否则避免添加一个手动获取并镜像相同状态的视图模型。

## 测试指引

优先测试：
- 服务和业务规则，
- 模型和状态转换，
- 服务层的异步工作流，
- 用预览或更高层 UI 测试验证 UI 行为。

不要仅仅为了让一个简单 SwiftUI 视图「可测试」就引入视图模型。那通常只会增加繁文缛节，而不会改善架构。

## 重构清单

向 MV 重构时：
- 移除那些只包装环境依赖或本地视图状态的视图模型。
- 当纯视图状态足够时，替换可选或延迟初始化的视图模型。
- 把业务逻辑从视图 body 中抽出来，移入服务/模型。
- 让视图保持为 UI 状态、导航和用户动作的轻量协调者。
- 在增加新的间接层之前，先把大型 body 拆分成更小的视图类型。

## 结论

把视图模型视为例外，而非默认。

在现代 SwiftUI 中，默认技术栈是：
- `@State` 用于本地状态，
- `@Environment` 用于共享依赖，
- `@Query` 用于 SwiftData 支持的集合，
- 生命周期修饰符用于轻量编排，
- 服务和模型用于业务逻辑。

只有在功能明确需要时才使用视图模型。
