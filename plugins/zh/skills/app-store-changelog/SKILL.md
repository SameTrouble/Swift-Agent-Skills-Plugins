---
name: app-store-changelog
description: 通过收集并汇总自上一个 git tag（或指定 ref）以来所有影响用户的变化，生成面向用户的 App Store 发布说明。当被要求基于 git 历史或 tag 生成完整的发布变更日志、App Store"新功能"文本或发布说明时使用。
---

# App Store 变更日志

## 概述
从自上一个 tag 以来的 git 历史中生成一份完整、面向用户的变更日志，然后将提交转化为清晰的 App Store 发布说明。

## 工作流程

### 1) 收集变更
- 在仓库根目录运行 `scripts/collect_release_changes.sh`，收集提交和改动的文件。
- 如需指定 tag 或 ref：`scripts/collect_release_changes.sh v1.2.3 HEAD`。
- 如果不存在任何 tag，脚本会回退到完整历史。

### 2) 筛选用户影响
- 浏览提交和文件，识别用户可见的变更。
- 按主题分组（新增、改进、修复），并合并重复内容。
- 去除纯内部工作（构建脚本、重构、依赖升级、CI）。

### 3) 撰写 App Store 说明
- 为每条面向用户的变更撰写简短、聚焦收益的条目。
- 使用清晰的动词和通俗语言，避免内部行话。
- 除非用户要求其他长度，否则控制在 5 到 10 条。

### 4) 校验
- 确保每一条都能对应到该范围内的真实变更。
- 检查是否存在重复或过于技术化的措辞。
- 如果某条变更含义模糊或可能仅为内部改动，请请求澄清。

## 提交到条目的转换示例

下表展示了如何将原始提交转化为 App Store 条目：

| 原始提交信息 | App Store 条目 |
|---|---|
| `fix(auth): resolve token refresh race condition on iOS 17` | • 修复了可能导致部分用户被意外登出的登录问题。 |
| `feat(search): add voice input to search bar` | • 通过新的语音输入选项，解放双手搜索你的资料库。 |
| `perf(timeline): lazy-load images to reduce scroll jank` | • 滚动浏览时间线现在更顺畅、更快速。 |

被**剔除**的纯内部提交（无用户影响）：
- `chore: upgrade fastlane to 2.219`
- `refactor(network): extract URLSession wrapper into module`
- `ci: add nightly build job`

## 示例输出

```
What's New in Version 3.4

• Search your library hands-free with the new voice input option.
• Scrolling through your timeline is now smoother and faster.
• Fixed a login issue that could leave some users unexpectedly signed out.
• Added dark-mode support to the settings screen.
• Improved load times when opening large photo albums.
```

## 输出格式
- 标题（可选）："What's New" 或产品名 + 版本号。
- 仅使用条目列表；每条一句话。
- 如果用户提供了上架地区限制，请遵守相应字数限制。

## 资源
- `scripts/collect_release_changes.sh`：收集自上一个 tag 以来的提交和改动文件。
- `references/release-notes-guidelines.md`：App Store 说明的语言、筛选和 QA 规则。
