---
name: swiftui-view-refactor
description: 重构和审查 SwiftUI 视图文件，对小型专用子视图、MV 优先于 MVVM 的数据流、稳定的视图树、显式依赖注入以及正确的 Observation 用法给出强力默认方案。用于清理 SwiftUI 视图、拆分过长的 body、移除内联动作或副作用、减少计算型 `some View` 辅助方法，或规范化 `@Observable` 和视图模型初始化模式时使用。
---

# SwiftUI View Refactor

## 概览
将 SwiftUI 视图重构为小型、显式、稳定的视图类型。默认采用原生 SwiftUI：本地状态放在视图中，共享依赖放在环境里，业务逻辑放在服务/模型中，只有在请求或现有代码明确需要时才使用视图模型。

## 核心准则

### 1) 视图顺序（自上而下）
- 除非现有文件已有必须保留的更强本地约定，否则强制采用以下顺序。
- Environment
- `private`/`public` `let`
- `@State` / 其他存储属性
- 计算型 `var`（非视图）
- `init`
- `body`
- 计算型视图构建器 / 其他视图辅助方法
- 辅助 / 异步函数

### 2) 默认使用 MV，而非 MVVM
- 视图应当是轻量的状态表达和编排点，而不是业务逻辑的容器。
- 优先使用 `@State`、`@Environment`、`@Query`、`.task`、`.task(id:)` 和 `onChange`，然后再考虑视图模型。
- 通过 `@Environment` 注入服务和共享模型；把领域逻辑留在服务/模型里，而不是视图 body 中。
- 不要仅仅为了镜像本地视图状态或包装环境依赖而引入视图模型。
- 如果一个屏幕变大，先把 UI 拆分成子视图，而不是凭空发明新的视图模型层。

### 3) 强烈优先使用专用子视图类型，而非计算型 `some View` 辅助方法
- 标记那些长度约超过一屏或包含多个逻辑段的 `body` 属性。
- 对于非简单段，优先抽取为专用 `View` 类型，尤其是当它们带有状态、异步工作、分支逻辑，或值得拥有独立预览时。
- 让计算型 `some View` 辅助方法保持稀少且小巧。不要用一堆 `private var header: some View` 风格的片段拼出整个屏幕。
- 向抽取出的子视图传入小型、显式的输入（数据、绑定、回调），而不是把整个父状态往下传。
- 如果某个抽取出的子视图变得可复用或具有独立意义，就把它移到自己的文件里。

优先采用：

```swift
var body: some View {
    List {
        HeaderSection(title: title, subtitle: subtitle)
        FilterSection(
            filterOptions: filterOptions,
            selectedFilter: $selectedFilter
        )
        ResultsSection(items: filteredItems)
        FooterSection()
    }
}

private struct HeaderSection: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title2)
            Text(subtitle).font(.subheadline)
        }
    }
}

private struct FilterSection: View {
    let filterOptions: [FilterOption]
    @Binding var selectedFilter: FilterOption

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(filterOptions, id: \.self) { option in
                    FilterChip(option: option, isSelected: option == selectedFilter)
                        .onTapGesture { selectedFilter = option }
                }
            }
        }
    }
}
```

避免：

```swift
var body: some View {
    List {
        header
        filters
        results
        footer
    }
}

private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.title2)
        Text(subtitle).font(.subheadline)
    }
}
```

### 3b) 将动作和副作用从 `body` 中抽取出来
- 不要在视图 body 中保留非简单的按钮动作内联代码。
- 不要把业务逻辑埋在 `.task`、`.onAppear`、`.onChange` 或 `.refreshable` 里。
- 优先从视图调用小型私有方法，并把真正的业务逻辑移入服务/模型。
- body 应当读起来像 UI，而不是像视图控制器。

```swift
Button("Save", action: save)
    .disabled(isSaving)

.task(id: searchText) {
    await reload(for: searchText)
}

private func save() {
    Task { await saveAsync() }
}

private func reload(for searchText: String) async {
    guard !searchText.isEmpty else {
        results = []
        return
    }
    await searchService.search(searchText)
}
```

### 4) 保持稳定的视图树（避免顶层条件式视图切换）
- 避免 `body` 或计算型视图通过 `if/else` 返回完全不同的根分支。
- 优先使用单一稳定的基础视图，把条件放在各个段/修饰符内部（`overlay`、`opacity`、`disabled`、`toolbar` 等）。
- 根层级分支切换会导致身份频繁变动、更大范围的失效以及额外的重计算。

优先采用：

```swift
var body: some View {
    List {
        documentsListContent
    }
    .toolbar {
        if canEdit {
            editToolbar
        }
    }
}
```

避免：

```swift
var documentsListView: some View {
    if canEdit {
        editableDocumentsList
    } else {
        readOnlyDocumentsList
    }
}
```

### 5) 视图模型处理（仅在已存在或被明确要求时）
- 将视图模型视为遗留模式或显式需求模式，而非默认选择。
- 除非请求或现有代码明确需要，否则不要引入视图模型。
- 如果视图模型已存在，尽可能将其设为非可选。
- 通过 `init` 把依赖传入视图，然后在视图的 `init` 中创建视图模型。
- 避免 `bootstrapIfNeeded` 之类的模式以及其他延迟设置的变通手段。

示例（基于 Observation）：

```swift
@State private var viewModel: SomeViewModel

init(dependency: Dependency) {
    _viewModel = State(initialValue: SomeViewModel(dependency: dependency))
}
```

### 6) Observation 用法
- 对于 iOS 17+ 上的 `@Observable` 引用类型，在持有它的视图中以 `@State` 存储。
- 显式地向下传递 observable；除非 UI 确实需要，否则避免可选状态。
- 如果部署目标包含 iOS 16 或更早版本，在持有方使用 `@StateObject`，注入遗留 observable 模型时使用 `@ObservedObject`。

## 工作流

1. 重新排序视图以符合排序规则。
2. 从 `body` 中移除内联动作和副作用；把业务逻辑移入服务/模型，视图只保留轻量编排。
3. 通过抽取专用子视图类型来缩短过长的 body；避免用许多计算型 `some View` 辅助方法重建屏幕。
4. 确保稳定的视图结构：避免基于顶层 `if` 的分支切换；把条件移到局部化的段/修饰符中。
5. 如果视图模型已存在或被明确要求，用在 `init` 中初始化的非可选 `@State` 视图模型替换可选视图模型。
6. 确认 Observation 用法：iOS 17+ 上根 `@Observable` 模型使用 `@State`，仅在部署目标要求时使用遗留包装器。
7. 保持行为不变：除非被请求，否则不要改变布局或业务逻辑。

## 备注

- 优先使用小型、显式的视图类型，而非大型条件块和大型计算型 `some View` 属性。
- 让计算型视图构建器位于 `body` 之下，非视图计算型 var 位于 `init` 之上。
- 一次好的 SwiftUI 重构应当让视图自上而下读起来像「数据流 + 布局」，而不是布局与命令式逻辑混杂。
- 关于 MV 优先的指引和理由，参见 `references/mv-patterns.md`。

## 大型视图处理

当一个 SwiftUI 视图文件超过约 300 行时，应当积极地拆分。把有意义的段抽取为专用 `View` 类型，而不是用许多计算型属性来隐藏复杂度。对动作和辅助方法可以使用带 `// MARK: -` 注释的 `private` 扩展，但不要把扩展当成把巨型屏幕拆成更小视图类型的替代品。如果某个抽取出的子视图被复用或具有独立意义，就把它移到自己的文件里。
