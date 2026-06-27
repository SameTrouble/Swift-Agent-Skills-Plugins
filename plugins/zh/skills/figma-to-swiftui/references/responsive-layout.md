# Figma 到响应式 SwiftUI 布局

如何将设备特定的 Figma 画板翻译为自适应 SwiftUI 视图。补充 layout-translation.md（覆盖 1:1 Auto Layout 映射），处理多设备适配。

## 目录

- [何时询问设备支持](#何时询问设备支持)
- [Figma 固定值 → 自适应 SwiftUI](#figma-固定值--自适应-swiftui)
- [用于布局切换的尺寸类别](#用于布局切换的尺寸类别)
- [导航和侧边栏](#导航和侧边栏)
- [图像和宽高比](#图像和宽高比)
- [按设备的安全区域](#按设备的安全区域)
- [跨设备排版](#跨设备排版)
- [多设备实现模式](#多设备实现模式)
- [清单](#清单)

## 何时询问设备支持

- Figma 画板宽度 375–430pt（iPhone 范围）且项目的部署目标包含 iPad → 在实现之前询问用户是否需要 iPad 适配
- Figma 包含不同设备的多个画板（iPhone + iPad）→ 通过 get_design_context + get_screenshot 获取所有画板，然后询问用户如何组合
- Figma 画板宽度仅 744–1024pt（iPad 范围）→ 询问是否需要 iPhone 支持
- 不要假设。始终与用户确认设备范围。

## Figma 固定值 → 自适应 SwiftUI

Figma 设计使用绝对像素值。并非所有值都应成为 SwiftUI 中的固定 frame。

**全屏宽度（375、390、393、430）**
→ `.frame(maxWidth: .infinity)`，绝不 `.frame(width: 375)`

**固定尺寸元素（图标、头像、徽章）**
→ 保持 `.frame(width:, height:)` ——这些是故意固定的

**固定宽度的内容容器**
→ 替换为相对尺寸。使用 `containerRelativeFrame`（iOS 17+）或 `GeometryReader` 实现比例宽度：
```swift
// Figma：375pt 画板中卡片宽度 343（屏幕的 91.5%）
.containerRelativeFrame(.horizontal) { length, _ in
    length * 0.915
}
```

**禁止：`UIScreen.main.bounds`**
→ 始终使用 `containerRelativeFrame`（iOS 17+）或 `GeometryReader`。屏幕 bounds 在分屏、Slide Over 和 Stage Manager 中会出问题。

## 用于布局切换的尺寸类别

当 Figma 显示每个设备根本不同的布局（不仅仅是更宽的间距）时，使用 `@Environment(\.horizontalSizeClass)`。

- compact = iPhone 竖屏、iPad 分屏/slide-over
- regular = iPad 全屏、iPhone 横屏（部分型号）

```swift
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            NavigationStack {
                ItemList()
            }
        } else {
            NavigationSplitView {
                ItemList()
            } detail: {
                ItemDetail()
            }
        }
    }
}
```

何时使用尺寸类别：
- Figma 显示列表（iPhone）vs 网格（iPad）→ 切换布局
- Figma 显示单列（iPhone）vs 侧边栏 + 内容（iPad）→ NavigationSplitView
- Figma 显示堆叠区块（iPhone）vs 并排（iPad）→ 在 VStack 和 HStack 之间切换

何时不使用尺寸类别：
- 相同布局，只是更宽 → 使用灵活的 frame 和 `.infinity`，无需分支

## 合并 iPhone + iPad Figma 画板

当 Figma 为 iPhone 和 iPad 提供单独画板时：

1. 通过 get_design_context + get_screenshot 获取两个画板
2. 识别共享组件（相同内容、相同结构）→ 提取为共享视图
3. 识别差异（布局变化、可见性变化、不同排列）
4. 实现一个基于 `horizontalSizeClass` 切换的 SwiftUI 视图

```swift
struct ProfileView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            // iPhone 布局：垂直堆叠
            ScrollView {
                VStack(spacing: 16) {
                    ProfileHeader()
                    ProfileStats()
                    ProfileContent()
                }
            }
        } else {
            // iPad 布局：并排
            HStack(alignment: .top, spacing: 24) {
                VStack {
                    ProfileHeader()
                    ProfileStats()
                }
                .frame(width: 320)

                ProfileContent()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
```

## ViewThatFits（iOS 16+）

当 Figma 显示两种布局变体（例如水平和垂直）而不绑定到特定设备时使用。SwiftUI 选择第一个适合可用空间的变体。

```swift
ViewThatFits(in: .horizontal) {
    // 先尝试水平
    HStack(spacing: 12) {
        icon
        label
        Spacer()
        value
    }
    // 回退到垂直
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) { icon; label }
        value
    }
}
```

最适合：操作栏、标签+值对、标签行——内容可能放得下一行也可能放不下的任何地方。

## 常见 Figma → 响应式模式

| Figma 设计 | SwiftUI 实现 |
|---|---|
| 侧边栏 + 内容（iPad）| `NavigationSplitView` |
| 2 列网格（iPad）→ 1 列（iPhone）| 带自适应列的 `LazyVGrid`：`GridItem(.adaptive(minimum: 160))` |
| 全宽卡片（iPhone）+ 受限卡片（iPad）| `.frame(maxWidth: 600)` 配合 `.frame(maxWidth: .infinity)` 父视图居中 |
| 水平标签（iPad）→ 底部标签栏（iPhone）| `TabView`（系统处理放置）或按 sizeClass 切换 |
| 宽表单字段（iPad）→ 全宽（iPhone）| `.frame(maxWidth: 500)` 在容器中居中 |
