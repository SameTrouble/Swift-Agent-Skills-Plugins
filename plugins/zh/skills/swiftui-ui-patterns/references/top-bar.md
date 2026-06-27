# 顶部栏覆盖（iOS 26+ 及回退）

## 意图

用 `safeAreaBar(.top)`（iOS 26）和更早 OS 版本的兼容回退，提供位于滚动内容上方的自定义顶部选择器或胶囊行。

## iOS 26+ 方法

用 `safeAreaBar(edge: .top)` 把视图附加到安全区域栏。

```swift
if #available(iOS 26.0, *) {
  content
    .safeAreaBar(edge: .top) {
      TopSelectorView()
        .padding(.horizontal, .layoutPadding)
    }
}
```

## 更早 iOS 的回退

用 `.safeAreaInset(edge: .top)` 并隐藏工具栏背景以避免双层。

```swift
content
  .toolbarBackground(.hidden, for: .navigationBar)
  .safeAreaInset(edge: .top, spacing: 0) {
    VStack(spacing: 0) {
      TopSelectorView()
        .padding(.vertical, 8)
        .padding(.horizontal, .layoutPadding)
        .background(Color.primary.opacity(0.06))
        .background(Material.ultraThin)
      Divider()
    }
  }
```

## 应保留的设计选择

- 可用时用 `safeAreaBar`；它与导航栏集成更好。
- 回退中用微妙背景 + 分隔线保持与内容的分离。
- 保持选择器高度紧凑，避免把内容推得太低。

## 陷阱

- 不要堆叠多个顶部 inset；会产生多余内边距。
- 避免与导航栏冲突的重度不透明背景。
