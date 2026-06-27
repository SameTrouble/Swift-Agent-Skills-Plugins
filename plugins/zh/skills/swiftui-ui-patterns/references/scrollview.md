# ScrollView 与 Lazy 栈

## 意图

当需要自定义布局、混合内容或横向/网格滚动时，用 `ScrollView` 配合 `LazyVStack`、`LazyHStack` 或 `LazyVGrid`。

## 核心模式

- 类聊天或自定义信息流布局优先用 `ScrollView` + `LazyVStack`。
- 用 `ScrollView(.horizontal)` + `LazyHStack` 做标签、标签、头像和媒体条。
- 用 `LazyVGrid` 做图标/媒体网格；尽可能优先用自适应列。
- 用 `ScrollViewReader` 做滚动到顶/底和基于锚点的跳转。
- 用 `safeAreaInset(edge:)` 做应固定在键盘上方的输入栏。

## 示例：垂直自定义信息流

```swift
@MainActor
struct ConversationView: View {
  private enum Constants { static let bottomAnchor = "bottom" }
  @State private var scrollProxy: ScrollViewProxy?

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack {
          ForEach(messages) { message in
            MessageRow(message: message)
              .id(message.id)
          }
          Color.clear.frame(height: 1).id(Constants.bottomAnchor)
        }
        .padding(.horizontal, .layoutPadding)
      }
      .safeAreaInset(edge: .bottom) {
        MessageInputBar()
      }
      .onAppear {
        scrollProxy = proxy
        withAnimation {
          proxy.scrollTo(Constants.bottomAnchor, anchor: .bottom)
        }
      }
    }
  }
}
```

## 示例：横向标签

```swift
ScrollView(.horizontal, showsIndicators: false) {
  LazyHStack(spacing: 8) {
    ForEach(chips) { chip in
      ChipView(chip: chip)
    }
  }
}
```

## 示例：自适应网格

```swift
let columns = [GridItem(.adaptive(minimum: 120))]

ScrollView {
  LazyVGrid(columns: columns, spacing: 8) {
    ForEach(items) { item in
      GridItemView(item: item)
    }
  }
  .padding(8)
}
```

## 应保留的设计选择

- 当项目数大或未知时用 `Lazy*` 栈。
- 对小型、固定尺寸内容用非惰性栈以避免惰性开销。
- 使用 `ScrollViewReader` 时保持 ID 稳定。
- 滚动到 ID 时优先用显式动画（`withAnimation`）。

## 陷阱

- 避免同轴嵌套滚动视图；会导致手势冲突。
- 没有明确理由时不要在同一层级混合 `List` 和 `ScrollView`。
- 对微小内容过度使用 `LazyVStack` 会增加不必要的复杂性。
