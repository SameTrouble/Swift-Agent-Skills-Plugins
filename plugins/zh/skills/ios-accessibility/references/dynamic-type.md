# Dynamic Type

iOS 上可缩放文本和自适应布局的核心概念。

## 什么是 Dynamic Type

Dynamic Type 让用户选择他们偏好的文本大小。当你使用文本样式时，iOS 会自动缩放文本。

## 文本样式

iOS 提供语义文本样式，它们一起缩放：

| 样式 | 典型用途 |
|-------|-------------|
| `.largeTitle` | 屏幕标题 |
| `.title`、`.title2`、`.title3` | 章节标题 |
| `.headline` | 强调的正文文本 |
| `.subheadline` | 次要标签 |
| `.body` | 主要内容 |
| `.callout` | 补充描述 |
| `.footnote` | 三级信息 |
| `.caption`、`.caption2` | 元数据、时间戳 |

使用文本样式而不是固定字体大小。
如需按文本样式和内容大小类别的精确点大小，请参阅 Apple HIG：[iOS/iPadOS Dynamic Type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-Dynamic-Type-sizes)。

文本样式不会在各类别间以固定比例线性缩放。避免在更大尺寸时做出诸如"标题始终是正文的 X 倍"这样的假设。

## 更大的无障碍字号

除了 7 个标准字号外，iOS 还提供 5 个额外的无障碍字号。用户在**设置 > 无障碍 > 显示与文本大小 > 更大文本**中启用它们。
参考大小记录在 Apple HIG 中：[iOS/iPadOS larger accessibility type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-larger-accessibility-type-sizes)。

始终用这些更大字号测试——它们会揭示标准字号不会出现的布局问题。

### 测试最坏情况

Dynamic Type 问题通常出现在空状态、错误视图和弹出框等边缘屏幕中。

- 在**无障碍 5**（最大字号）下测试
- 用**更长的本地化字符串**测试（例如德语、西班牙语）
- 检查**加载/错误**屏幕，而不仅仅是主要流程

## 布局适应

在更大字号时，布局通常需要改变：
- 水平堆栈变为垂直
- 多列网格变为单列
- 允许更多行文本
- 元素可能需要换行

## Large Content Viewer

导航栏、标签栏和工具栏不会随 Dynamic Type 缩放。用户可以长按通过 Large Content Viewer 查看放大的标签。

## 测试

1. 使用控制中心的文本大小控件
   - 同时测试应用特定覆盖（可从控制中心按应用调整文本大小）
2. 启用更大的无障碍字号进行测试
3. 使用 Xcode 的环境覆盖
4. 使用 Accessibility Inspector 的设置标签页
5. 尝试双倍长度伪语言进行压力测试

## 实现

如需 UIKit 实现，请参阅 `dynamic-type-uikit.md`。

如需 SwiftUI 实现，请参阅 `dynamic-type-swiftui.md`。

## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
- https://github.com/Apress/developing-accessible-iOS-apps
