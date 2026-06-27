# 匹配转场

## 意图

用匹配转场在源视图（缩略图、头像）和目标视图（sheet、详情、查看器）之间创造平滑的连续性。

## 核心模式

- 使用共享 `Namespace` 和源的稳定 ID。
- iOS 26+ 用 `matchedTransitionSource` + `navigationTransition(.zoom(...))`。
- 在视图层级内的原地转场用 `matchedGeometryEffect`。
- 保持 ID 在视图更新间稳定（避免随机 UUID）。

## 示例：媒体预览到全屏查看器（iOS 26+）

```swift
struct MediaPreview: View {
  @Namespace private var namespace
  @State private var selected: MediaAttachment?

  var body: some View {
    ThumbnailView()
      .matchedTransitionSource(id: selected?.id ?? "", in: namespace)
      .sheet(item: $selected) { item in
        MediaViewer(item: item)
          .navigationTransition(.zoom(sourceID: item.id, in: namespace))
      }
  }
}
```

## 示例：视图内的匹配几何

```swift
struct ToggleBadge: View {
  @Namespace private var space
  @State private var isOn = false

  var body: some View {
    Button {
      withAnimation(.spring) { isOn.toggle() }
    } label: {
      Image(systemName: isOn ? "eye" : "eye.slash")
        .matchedGeometryEffect(id: "icon", in: space)
    }
  }
}
```

## 应保留的设计选择

- 跨屏幕转场优先用 `matchedTransitionSource`。
- 保持源和目标尺寸合理，以避免突兀的缩放变化。
- 状态驱动的转场用 `withAnimation`。

## 陷阱

- 不要用不稳定 ID；会破坏转场。
- 避免不匹配的形状（例如方形到圆形），除非设计期望如此。
