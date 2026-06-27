# 焦点处理与字段链式

## 意图

用 `@FocusState` 控制键盘焦点、链式字段，并在复杂表单中协调焦点。

## 核心模式

- 用枚举表示可聚焦的字段。
- 在 `onAppear` 中设置初始焦点。
- 用 `.onSubmit` 把焦点移到下一个字段。
- 对于动态字段列表，使用带关联值的枚举（例如 `.option(Int)`）。

## 示例：单字段焦点

```swift
struct AddServerView: View {
  @State private var server = ""
  @FocusState private var isServerFieldFocused: Bool

  var body: some View {
    Form {
      TextField("Server", text: $server)
        .focused($isServerFieldFocused)
    }
    .onAppear { isServerFieldFocused = true }
  }
}
```

## 示例：带枚举的链式焦点

```swift
struct EditTagView: View {
  enum FocusField { case title, symbol, newTag }
  @FocusState private var focusedField: FocusField?

  var body: some View {
    Form {
      TextField("Title", text: $title)
        .focused($focusedField, equals: .title)
        .onSubmit { focusedField = .symbol }

      TextField("Symbol", text: $symbol)
        .focused($focusedField, equals: .symbol)
        .onSubmit { focusedField = .newTag }
    }
    .onAppear { focusedField = .title }
  }
}
```

## 示例：可变字段的动态焦点

```swift
struct PollView: View {
  enum FocusField: Hashable { case option(Int) }
  @FocusState private var focused: FocusField?
  @State private var options: [String] = ["", ""]
  @State private var currentIndex = 0

  var body: some View {
    ForEach(options.indices, id: \.self) { index in
      TextField("Option \(index + 1)", text: $options[index])
        .focused($focused, equals: .option(index))
        .onSubmit { addOption(at: index) }
    }
    .onAppear { focused = .option(0) }
  }

  private func addOption(at index: Int) {
    options.append("")
    currentIndex = index + 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
      focused = .option(currentIndex)
    }
  }
}
```

## 应保留的设计选择

- 将焦点状态保持在拥有字段的视图局部。
- 用焦点变化驱动 UX（校验消息、辅助 UI）。
- 在使用 ScrollView/Form 时配合 `.scrollDismissesKeyboard(...)`。

## 陷阱

- 不要把焦点状态放在共享对象中；它是视图局部的。
- 动画期间避免激进的焦点变化；必要时延迟。
