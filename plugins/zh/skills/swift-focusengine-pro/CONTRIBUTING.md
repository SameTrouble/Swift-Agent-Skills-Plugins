# 为 Swift FocusEngine Pro 贡献

欢迎贡献！此技能帮助 AI 编码助手为 Apple 平台编写正确的焦点管理代码。

## 贡献什么

- **边缘情况**——让开发者措手不及的非显而易见的焦点行为
- **新平台 API**——iOS 19、tvOS 19、visionOS 3、watchOS 12 的新增内容
- **真实世界模式**——来自生产应用的经过实战检验的解决方案
- **反模式**——LLM 常犯的错误

## 指南

- 保持参考文件聚焦，每个不超过 300 行
- 不要重复 LLM 已经知道的内容——专注于它们弄错的地方
- 包含可编译并演示概念的代码示例
- 注意每个提到的 API 的最低操作系统版本要求
- 所有贡献必须采用 MIT 许可证

## 结构

参考文件位于 `references/` 中。每个文件涵盖特定主题：

| 文件 | 焦点 |
|------|-------|
| `anti-patterns.md` | 破坏焦点的关键错误 |
| `swiftui-focus.md` | tvOS SwiftUI 焦点 API |
| `uikit-focus.md` | tvOS UIKit 焦点 API |
| `ios-focus.md` | iOS/iPadOS 焦点（键盘、游戏手柄、Stage Manager） |
| `watchos-focus.md` | watchOS Digital Crown 和顺序焦点 |
| `visionos-focus.md` | visionOS 注视、悬停和焦点 |
| `realitykit-focus.md` | RealityKit 实体悬停和手势 |
| `focus-styling.md` | 焦点视觉样式模式 |
| `focus-restoration.md` | 数据重新加载间的焦点状态保持 |
| `layout-patterns.md` | 常见 tvOS 布局模式 |
| `async-focus.md` | async/await 和焦点协调 |
| `accessibility-focus.md` | VoiceOver、完全键盘访问、Switch Control |
| `debugging.md` | 焦点调试工具和技术 |

## 提交更改

1. Fork 仓库
2. 创建分支（`git checkout -b my-improvement`）
3. 进行更改
4. 测试示例可编译且准确
5. 提交 pull request，清楚描述你添加了什么以及为什么

## 行为准则

在贡献之前，请阅读[行为准则](CODE_OF_CONDUCT.md)。
