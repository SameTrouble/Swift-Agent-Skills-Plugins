# appstore-review

一个 AI 技能，可对你的 iOS 项目运行全面的 App Store 审核就绪性审计。它在提交之前捕获拒绝风险——隐私清单缺口、缺失的订阅披露、不完整的元数据等。

## 为什么需要这个技能

大约 25% 的 App Store 提交会被拒绝（2024 年 7.77M 中的 1.93M）。最主要的原因都有文档记录，但很容易被忽略：不完整的应用、缺失的隐私声明、订阅披露违规以及元数据问题。

此技能将这些检查编码为结构化审计，由你的 AI 编程代理直接在项目中运行。它依据 Apple 2024 年透明度报告数据按拒绝频率排序，因此最高风险的项目会优先检查。

## 涵盖内容

**轨道 1 — 代码与 Entitlements**（8 个部分）
- 应用完整性（准则 2.1）— 第 1 大拒绝原因，占 40%+ 案例
- 隐私清单合规性（ITMS-91053/91061）— 自 2024 年 5 月起自动化拒绝
- 订阅与 IAP 付费墙披露（准则 3.1.1/3.1.2）
- 隐私与数据处理（准则 5.1）
- App Transport Security
- 出口合规
- Entitlements 与能力
- 代码质量标记

**轨道 2 — 提交元数据**（6 个部分）
- App Store Connect 元数据字段
- 截图与预览
- 应用图标
- 版本与构建号
- 年龄分级
- 审核备注

## 快速开始

```bash
./scripts/install.sh appstore-review
```

然后在 Claude Code 中，从你的 iOS 项目目录运行：

```
/appstore-review
```

完整的设置说明——包括如何在 CLAUDE.md 中注册技能、添加常设清单以及预期的输出——请参阅[设置与使用指南](references/setup-guide.md)。

## 文件

| 文件 | 用途 |
|------|---------|
| `SKILL.md` | 技能本身——AI 代理读取并执行的内容 |
| `references/appstore-review-ref.md` | 约 60 个 Apple 文档、WWDC 会议和社区资源的目录 |
| `references/setup-guide.md` | 安装、配置和使用说明 |

## 版本

1.0.0 — 初始版本，涵盖 iOS 17+ SwiftUI 应用搭配 StoreKit 2 订阅的所有主要 App Store 拒绝类别。
