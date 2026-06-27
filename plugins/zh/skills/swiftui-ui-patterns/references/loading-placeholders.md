# 加载与占位符

当视图需要一致的加载状态（骨架、遮罩、空状态）且不阻塞交互时使用此模式。

## 推荐模式

- **遮罩占位符** 用于列表/详情内容，加载时保留布局。
- **ContentUnavailableView** 用于加载完成后的空或错误状态。
- **ProgressView** 仅用于短暂的、全局的操作（在内容密集的屏幕中节制使用）。

## 推荐方法

1. 保留真实布局，渲染占位数据，然后应用 `.redacted(reason: .placeholder)`。
2. 对列表，显示固定数量的占位行（避免无限转圈）。
3. 加载完成但数据为空时切换到 `ContentUnavailableView`。

## 陷阱

- 遮罩期间不要动画化布局变化；保持帧稳定。
- 避免嵌套多个转圈；每个分区用一个加载指示器。
- 保持占位数量小（3–6），以减少低端设备上的卡顿。

## 最小用法

```swift
VStack {
  if isLoading {
    ForEach(0..<3, id: \.self) { _ in
      RowView(model: .placeholder())
    }
    .redacted(reason: .placeholder)
  } else if items.isEmpty {
    ContentUnavailableView("No items", systemImage: "tray")
  } else {
    ForEach(items) { item in RowView(model: item) }
  }
}
```
