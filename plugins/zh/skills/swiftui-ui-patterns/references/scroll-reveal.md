# 滚动露出详情面

## 意图

当详情屏幕先有主面、次要内容在其后，且希望用户通过滚动或滑动来露出该次要层，而非点击单独按钮时，使用此模式。

典型适用：

- 露出操作或元数据的媒体详情屏幕
- 过渡到结构化详情的地图、卡片或画布
- 带第二"操作"或"洞察"页的全屏查看器

## 核心模式

把交互构建为一个分页式垂直 `ScrollView`，含两个区块：

1. 尺寸等于视口的主区块
2. 其下的次区块

从垂直内容偏移派生一个归一化的 `progress` 值，并从这一个值驱动所有视觉变化。

除非单独滚动无法表达该交互，否则不要把露出当作独立手势系统。

## 最小结构

```swift
private enum DetailSection: Hashable {
  case primary
  case secondary
}

struct DetailSurface: View {
  @State private var revealProgress: CGFloat = 0
  @State private var secondaryHeight: CGFloat = 1

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { proxy in
        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 0) {
            PrimaryContent(progress: revealProgress)
              .frame(height: geometry.size.height)
              .id(DetailSection.primary)

            SecondaryContent(progress: revealProgress)
              .id(DetailSection.secondary)
              .onGeometryChange(for: CGFloat.self) { geo in
                geo.size.height
              } action: { newHeight in
                secondaryHeight = max(newHeight, 1)
              }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .onScrollGeometryChange(for: CGFloat.self, of: { scroll in
          scroll.contentOffset.y + scroll.contentInsets.top
        }) { _, offset in
          revealProgress = (offset / secondaryHeight).clamped(to: 0...1)
        }
        .safeAreaInset(edge: .bottom) {
          ChevronAffordance(progress: revealProgress) {
            withAnimation(.smooth) {
              let target: DetailSection = revealProgress < 0.5 ? .secondary : .primary
              proxy.scrollTo(target, anchor: .top)
            }
          }
        }
      }
    }
  }
}
```

## 应保留的设计选择

- 当交互应感觉像在状态间分页时，让主区块精确等于视口尺寸。
- 从真实滚动偏移计算 `progress`，而非从 `isExpanded`、`isShowingSecondary`、`isSnapped` 等重复布尔值。
- 用 `progress` 驱动 `offset`、`opacity`、`blur`、`scaleEffect` 和工具栏状态，使整个面保持同步。
- 用 `ScrollViewReader` 做从主内容或雪佛龙提示上的点击触发的编程式吸附。
- 当需要已落定的区块状态用于触感反馈、tooltip 消失、分析或无障碍播报时，用 `onScrollTargetVisibilityChange`。

## 共享控件的形变

如果一个控件看起来从主面移动到次要内容中，不要渲染两个完全可见的副本。

而是：

- 在主区域暴露一个源锚点
- 在次区域暴露一个目标锚点
- 渲染一个用 `progress` 插值位置和尺寸的覆盖层

```swift
Color.clear
  .anchorPreference(key: ControlAnchorKey.self, value: .bounds) { anchor in
    ["source": anchor]
  }

Color.clear
  .anchorPreference(key: ControlAnchorKey.self, value: .bounds) { anchor in
    ["destination": anchor]
  }

.overlayPreferenceValue(ControlAnchorKey.self) { anchors in
  MorphingControlOverlay(anchors: anchors, progress: revealProgress)
}
```

这保持运动连贯并避免重复命中目标的 bug。

## 触感反馈与提示

- 露出开始时用轻阈值触感反馈，接近已提交状态时用更强触感反馈。
- 当 `progress` 接近零时保留可见提示如雪佛龙或胶囊。
- 随次要区块变为活跃，翻转、淡出或模糊提示。

## 交互守卫

- 当冲突模式激活时（如捏合缩放、裁剪或全屏媒体操作）禁用垂直滚动。
- 对一旦次要内容露出就应消失的覆盖层禁用命中测试。
- 除非内层视图在露出期间实际上是静态或禁用的，否则避免同轴嵌套滚动视图。

## 陷阱

- 不要硬编码 progress 除数。测量次要区块高度或其他真实露出距离。
- 不要为同一属性混合多个动画源。如果 `progress` 驱动它，保持其他动画不触及该属性。
- 除非另一个 API 需要，否则不要存储 `isSecondaryVisible` 等派生状态。优先从 `progress` 或可见滚动目标派生。
- 测量高度时当心布局反馈循环。钳制零值并仅在测量高度真正变化时更新。

## 具体示例

- Pool iOS 瓦片详情露出：`/Users/dimillian/Documents/Dev/Pool/pool-ios/Pool/Sources/Features/Tile/Detail/TileDetailView.swift`
- 次要内容锚点示例：`/Users/dimillian/Documents/Dev/Pool/pool-ios/Pool/Sources/Features/Tile/Detail/TileDetailIntentListView.swift`
