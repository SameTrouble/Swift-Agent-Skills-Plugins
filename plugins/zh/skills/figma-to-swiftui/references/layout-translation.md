# Figma 布局到 SwiftUI 翻译

将 Figma 布局概念翻译为 SwiftUI 代码的完整参考。

## 目录

- [Auto Layout 到 Stacks](#auto-layout-到-stacks)
- [绝对定位](#绝对定位)
- [滚动](#滚动)
- [常见模式](#常见模式)
- [效果与装饰](#效果与装饰)
- [动画与过渡](#动画与过渡)

## Auto Layout 到 Stacks

Figma Auto Layout 是与 SwiftUI stacks 最接近的类比。翻译基本是 1:1 的，但存在边缘情况。

### 方向

- 垂直 auto layout -> VStack(alignment:, spacing:)
- 水平 auto layout -> HStack(alignment:, spacing:)
- 换行（带换行的水平）-> SwiftUI 无原生等价物。使用带自适应列的 LazyVGrid，或自定义 FlowLayout。

### 对齐

Figma auto layout 对齐映射到 SwiftUI 对齐：

主轴对齐（justify）：
- Packed（start）-> 默认栈行为（无 Spacer）
- Packed（center）-> 在栈中用 Spacer() 包裹内容两侧，或使用 .frame(maxWidth/Height: .infinity) 配合居中对齐
- Packed（end）-> 内容前加 Spacer()
- Space between -> 每个子元素之间加 Spacer()
- Space around / space evenly -> 非原生；用自定义间距或 GeometryReader 分布

交叉轴对齐：
- VStack：.leading、.center、.trailing
- HStack：.top、.center、.bottom、.firstTextBaseline、.lastTextBaseline

### 间距（Gap）

Figma gap 值直接映射到 spacing 参数：
- gap: 12 -> VStack(spacing: 12) 或 HStack(spacing: 12)
- 子元素间混合间距 -> 无法使用单个 spacing 值。使用显式 Spacer().frame(height/width:) 或子元素间的 padding。

### Padding

Figma padding 映射到 SwiftUI .padding()：
- 统一 padding：16 -> .padding(16)
- 水平 16，垂直 12 -> .padding(.horizontal, 16).padding(.vertical, 12)
- 单独边缘 -> .padding(EdgeInsets(top:, leading:, bottom:, trailing:))
- 注意：Figma 使用 left/right，SwiftUI 使用 leading/trailing 以支持 RTL

**padding 与 background 的顺序很重要：**
```swift
// Figma：卡片内 padding 16pt，白色背景，12pt 圆角
content
    .padding(16)
    .background(Color.white, in: .rect(cornerRadius: 12))

// 不等价：
content
    .background(Color.white)
    .padding(16)
```

**Figma 文本图层 padding 并不总是真正的 padding：** Figma 有时将垂直居中编码为上/下 padding。当 Text 图层有 padding top=4、bottom=4 且 line-height != font-size 时，这通常是文本行框，而非容器 padding。不要重复应用。行高处理参见 references/visual-fidelity.md。

### 尺寸

Figma 尺寸模式：
- Fixed（width: 200）-> .frame(width: 200)
- Hug contents -> 无需修饰符。SwiftUI 视图默认 hug。
- Fill container -> .frame(maxWidth: .infinity) 或 .frame(maxHeight: .infinity)
- Fill with min/max -> .frame(minWidth:, maxWidth:, minHeight:, maxHeight:)

**常见尺寸错误：**
- 对全宽元素应用 `.frame(width: 375)` -> 使用 `.frame(maxWidth: .infinity)` 使其适应设备宽度
- 当 Figma 在填充宽度容器内左对齐内容时，忘记 `.frame(maxWidth: .infinity, alignment: .leading)`
- 对 Text 使用 `.frame(height:)` -> Text 高度来自字体行框；固定高度可能裁剪或添加意外空间
- 对图像应用 `.frame` 而没有 `.resizable()` -> 图像保持固有尺寸

### 宽高比

- Figma 约束"Preserve aspect ratio" -> .aspectRatio(width/height, contentMode: .fit) 或 .fill

## 绝对定位

不带 auto layout 的 Figma 画板使用绝对 (x, y) 定位。

- 当视觉结构允许时，优先翻译为 stacks
- 当必须使用绝对定位时，使用 ZStack 配合 .offset(x:, y:)
- 对于响应式绝对布局，使用 GeometryReader（谨慎使用）
- Figma constraints（固定左边、固定顶部等）-> 在父视图中将 .frame() 与 alignment 参数组合

## 滚动

- 带"Clip content" + 溢出的 Figma 画板 -> ScrollView
- 垂直滚动 -> ScrollView(.vertical) { VStack { ... } }
- 水平滚动 -> ScrollView(.horizontal) { HStack { ... } }
- 双向 -> ScrollView([.vertical, .horizontal]) { ... }
- 分页 -> ScrollView { LazyHStack { ... } }.scrollTargetBehavior(.paging)

## 常见模式

### 卡片布局
Figma：Frame（auto layout 垂直，padding 16，圆角 12，投影，填充白色）
SwiftUI：
```swift
VStack(alignment: .leading, spacing: 8) {
    // 卡片内容
}
.padding(16)
.background(Color.white)
.clipShape(RoundedRectangle(cornerRadius: 12))
.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
```

### 列表项
Figma：Frame（auto layout 水平，spacing 12，padding 垂直 12 水平 16，fill container）
SwiftUI：
```swift
HStack(spacing: 12) {
    // 列表项内容
}
.padding(.vertical, 12)
.padding(.horizontal, 16)
.frame(maxWidth: .infinity, alignment: .leading)
```

### 带返回按钮的头部
Figma：Frame（auto layout 水平，space between，padding 16）
SwiftUI：尽可能优先使用 .navigationTitle() + .toolbar {} 而非自定义头部。仅当设计明显非标准时才使用自定义头部。

### 底部安全区域内容
Figma：固定在底部带 padding 的 Frame
SwiftUI：
```swift
VStack {
    Spacer()
    content
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
}
.safeAreaInset(edge: .bottom) { ... }
// 或使用 .toolbar(.bottomBar)
```

## 效果与装饰

| Figma | SwiftUI |
|---|---|
| 投影 | `.shadow(color:, radius:, x:, y:)` ——使用完整形式；默认值是错的 |
| 内阴影 | `.overlay { RoundedRectangle(...).stroke(...).blur(...) }` 或自定义绘制 |
| 图层模糊 | `.blur(radius:)` |
| 背景模糊 | `.background(.ultraThinMaterial)` / `.regularMaterial` / `.thickMaterial` |
| 圆角，全部相等 | `.clipShape(.rect(cornerRadius:))` |
| 单独圆角 | `UnevenRoundedRectangle(topLeadingRadius:, topTrailingRadius:, bottomLeadingRadius:, bottomTrailingRadius:)` |
| 边框 / 描边 | `.overlay(RoundedRectangle(...).stroke(color, lineWidth:))` |
| 裁剪内容 | `.clipped()` 或 `.clipShape(...)` |
| 遮罩 | `.mask { ... }` |
| 混合模式 | `.blendMode(.multiply)` 等 |
| Liquid Glass（iOS 26+）| `.glassEffect()` 配合适当的形状 |

## 动画与过渡

Figma 原型连接描述过渡意图，而非字面上的动画规格。将它们理解为导航或状态变更动画。

| Figma | SwiftUI |
|---|---|
| Dissolve | `.opacity(...)` + `withAnimation(.easeInOut)` |
| Move in / slide in | `.transition(.move(edge:))` 或 `.offset(...)` |
| Push | `NavigationStack` 推送，使用系统过渡 |
| Smart animate | 状态变更时 `withAnimation { }` |
| Scroll animate | `ScrollView` + `.scrollTransition()`（支持时）|

规则：
- 检查项目依赖中的 Lottie 或其他动画库，如果已有则使用
- 不要过度动画；原型链接通常意味着导航，而非自定义动画
- 对于复杂的编排动画，询问是完全实现还是简化
