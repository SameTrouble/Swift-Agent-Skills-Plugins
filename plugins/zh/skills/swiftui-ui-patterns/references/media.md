# 媒体（图片、视频、查看器）

## 意图

用一致的模式加载图片、预览媒体和呈现全屏查看器。

## 核心模式

- 用 `LazyImage`（或 `AsyncImage`）加载带加载状态的远程图片。
- 内联媒体优先用轻量预览组件。
- 用共享查看器状态（如 `QuickLook`）呈现全屏媒体查看器。
- 桌面/visionOS 用 `openWindow`，iOS 用 sheet。

## 示例：内联媒体预览

```swift
struct MediaPreviewRow: View {
  @Environment(QuickLook.self) private var quickLook

  let attachments: [MediaAttachment]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(attachments) { attachment in
          LazyImage(url: attachment.previewURL) { state in
            if let image = state.image {
              image.resizable().aspectRatio(contentMode: .fill)
            } else {
              ProgressView()
            }
          }
          .frame(width: 120, height: 120)
          .clipped()
          .onTapGesture {
            quickLook.prepareFor(
              selectedMediaAttachment: attachment,
              mediaAttachments: attachments
            )
          }
        }
      }
    }
  }
}
```

## 示例：全局媒体查看器 sheet

```swift
struct AppRoot: View {
  @State private var quickLook = QuickLook.shared

  var body: some View {
    content
      .environment(quickLook)
      .sheet(item: $quickLook.selectedMediaAttachment) { selected in
        MediaUIView(selectedAttachment: selected, attachments: quickLook.mediaAttachments)
      }
  }
}
```

## 应保留的设计选择

- 保持预览轻量；在查看器中加载完整媒体。
- 使用共享查看器状态，使任何视图都能打开媒体而无需属性穿透。
- 查看器用单一入口点（sheet/窗口）以避免重复。

## 陷阱

- 避免在列表行中加载全尺寸图片；使用调整尺寸后的预览。
- 不要同时展示多个查看器 sheet；保持单一数据源。
