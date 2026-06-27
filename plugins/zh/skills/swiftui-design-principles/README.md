# SwiftUI 设计原则

一个编码了设计原则的智能体技能，用于构建精致、原生质感的 SwiftUI 应用和 WidgetKit 小组件。

源自对两款用 AI 编码工具构建的 iOS 应用的并排对比——一款看起来感觉精致，另一款的边距、间距、字号和小组件就是*不对劲*。这里的模式代表了两者之间的具体差异。

## 安装

```bash
npx skills add arjitj2/swiftui-design-principles
```

## 涵盖内容

| # | 原则 | 防止的问题 |
|---|-----------|-----------------|
| 1 | 间距系统（base-4/8 网格） | 26、34、36pt 这样的任意内边距值 |
| 2 | 排版层级（基于字重） | 7 个以上字号无清晰体系 |
| 3 | 系统语义色 | 到处硬编码 `Color.white.opacity(0.42)` |
| 4 | 成比例的组件尺寸 | 260pt 进度环、不匹配的描边宽度 |
| 5 | 原生分组内容 | 过度设计的渐变卡片加 22pt 圆角 |
| 6 | 使用 NavigationStack | 裸 ZStack 布局加手动标题 |
| 7 | WidgetKit 原生组件 | 手动绘制圆形而非 Gauge |
| 8 | 交互元素 | 隐藏 Toggle 标签、低对比度色调 |
| 9 | 共享数据模型 | 应用与小组件之间重复的逻辑 |
| 10 | 发布前清单 | 发布前快速验证 |

## 激活时机

在创建或修改以下内容时触发本技能：
- SwiftUI 视图
- iOS 小组件（WidgetKit）
- 任何原生 Apple UI

## 兼容智能体

兼容 Claude Code、Cursor、Cline、GitHub Copilot、Windsurf，以及任何支持 [Agent Skills](https://skills.sh) 格式的智能体。

## 许可证

MIT
