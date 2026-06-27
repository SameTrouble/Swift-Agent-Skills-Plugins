# 输入工具栏（底部锚定）

## 意图

用底部锚定的输入栏做聊天、撰写器或快捷操作，而不与键盘冲突。

## 核心模式

- 用 `.safeAreaInset(edge: .bottom)` 把工具栏锚定在键盘上方。
- 将主内容放在 `ScrollView` 或 `List` 中。
- 用 `@FocusState` 驱动焦点，需要时设置初始焦点。
- 避免把输入栏嵌入滚动内容；保持分离。

## 示例：滚动视图 + 底部输入

```swift
@MainActor
struct ConversationView: View {
  @FocusState private var isInputFocused: Bool

  var body: some View {
    ScrollViewReader { _ in
      ScrollView {
        LazyVStack {
          ForEach(messages) { message in
            MessageRow(message: message)
          }
        }
        .padding(.horizontal, .layoutPadding)
      }
      .safeAreaInset(edge: .bottom) {
        InputBar(text: $draft)
          .focused($isInputFocused)
      }
      .scrollDismissesKeyboard(.interactively)
      .onAppear { isInputFocused = true }
    }
  }
}
```

## 应保留的设计选择

- 保持输入栏在视觉上与可滚动内容分离。
- 类聊天屏幕用 `.scrollDismissesKeyboard(.interactively)`。
- 确保发送操作可通过键盘回车或明确按钮触达。

## 陷阱

- 避免把输入视图放在滚动栈内；它会随内容跳动。
- 避免争夺拖拽手势的嵌套滚动视图。
