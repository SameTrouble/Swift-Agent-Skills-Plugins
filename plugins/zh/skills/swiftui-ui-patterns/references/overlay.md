# 覆盖层与 toasts

## 意图

用覆盖层做瞬态 UI（toasts、横幅、加载器）而不影响布局。

## 核心模式

- 用 `.overlay(alignment:)` 放置全局 UI 而不改变底层布局。
- 保持覆盖层轻量且可关闭。
- 当多个功能触发 toasts 时用专门的 `ToastCenter`（或类似）做全局状态。

## 示例：toast 覆盖层

```swift
struct AppRootView: View {
  @State private var toast: Toast?

  var body: some View {
    content
      .overlay(alignment: .top) {
        if let toast {
          ToastView(toast: toast)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { self.toast = nil }
              }
            }
        }
      }
  }
}
```

## 应保留的设计选择

- 瞬态 UI 优先用覆盖层，而非嵌入布局栈。
- 用转场和短暂自动消失计时器。
- 保持覆盖层对齐到明确的边缘（`.top` 或 `.bottom`）。

## 陷阱

- 避免阻塞所有交互的覆盖层，除非明确需要。
- 不要堆叠多个覆盖层；用队列或替换当前 toast。
