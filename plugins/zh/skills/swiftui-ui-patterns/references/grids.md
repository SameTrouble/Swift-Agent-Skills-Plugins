# 网格

## 意图

用 `LazyVGrid` 做图标选择器、媒体图库和需要项目按列对齐的密集视觉选择。

## 核心模式

- 对应在不同设备尺寸上缩放的布局使用 `.adaptive` 列。
- 当你想要固定列数时使用多个 `.flexible` 列。
- 保持间距一致且小，以避免不均匀的间距。
- 当需要方形缩略图时在网格单元内使用 `GeometryReader`。

## 示例：自适应图标网格

```swift
let columns = [GridItem(.adaptive(minimum: 120, maximum: 1024))]

LazyVGrid(columns: columns, spacing: 6) {
  ForEach(icons) { icon in
    Button {
      select(icon)
    } label: {
      ZStack(alignment: .bottomTrailing) {
        Image(icon.previewName)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .cornerRadius(6)
        if icon.isSelected {
          Image(systemName: "checkmark.seal.fill")
            .padding(4)
            .tint(.green)
        }
      }
    }
    .buttonStyle(.plain)
  }
}
```

## 示例：固定 3 列媒体网格

```swift
LazyVGrid(
  columns: [
    .init(.flexible(minimum: 100), spacing: 4),
    .init(.flexible(minimum: 100), spacing: 4),
    .init(.flexible(minimum: 100), spacing: 4),
  ],
  spacing: 4
) {
  ForEach(items) { item in
    GeometryReader { proxy in
      ThumbnailView(item: item)
        .frame(width: proxy.size.width, height: proxy.size.width)
    }
    .aspectRatio(1, contentMode: .fit)
  }
}
```

## 应保留的设计选择

- 大集合用 `LazyVGrid`；大集合避免非惰性网格。
- 需要时用 `.contentShape(Rectangle())` 保持点击目标全出血。
- 设置选择器和灵活布局优先用自适应网格。

## 陷阱

- 避免在每个网格单元中做重度覆盖；可能很昂贵。
- 没有明确理由时不要在网格内嵌套网格。
