# Accessibility Nutrition Labels

全部 9 个 App Store Accessibility Nutrition Labels，包含官方评估标准、所需 API 和实现清单。

## 目录
- [概述](#概述)
- [1. VoiceOver](#1-voiceover)
- [2. Voice Control](#2-voice-control)
- [3. Larger Text](#3-larger-text)
- [4. Dark Interface](#4-dark-interface)
- [5. Differentiate Without Color](#5-differentiate-without-color)
- [6. Sufficient Contrast](#6-sufficient-contrast)
- [7. Reduced Motion](#7-reduced-motion)
- [8. Captions](#8-captions)
- [9. Audio Descriptions](#9-audio-descriptions)
- [评估矩阵模板](#评估矩阵模板)
- [准确性和 App Review](#准确性和-app-review)

---

## 概述

Accessibility Nutrition Labels 出现在 App Store 产品页面上。每个标签表明用户可以使用该无障碍功能完成应用中的**所有常见任务**。部分支持不符合资格——如果任何主要任务被阻断，该标签不可声明。

**"常见任务"通常意味着：**
- 应用启动和引导
- 主要功能使用（用户下载应用的核心原因）
- 登录/账户访问
- 设置或偏好
- 关键数据录入或购买流程（如适用）

标签目前是自愿的。平台审查流程在应用审查期间检查准确性。不准确的标签违反 App Store Review Guideline 2.3。

**原生 API 优先：** 大多数内置 SwiftUI 和 UIKit 控件免费提供无障碍。自定义实现需要为每个功能显式工作。

---

## 1. VoiceOver

**是什么：** 面向盲人和低视力用户的屏幕阅读器。朗读 UI 并通过手势启用导航。

### 通过标准

- [ ] 所有交互控件（按钮、链接、文字字段）有简洁、准确的无障碍标签
- [ ] 标签不包含控件类型（"button"、"link"）——VoiceOver 自动添加
- [ ] 标签不嵌入状态（"selected"、"checked"）——使用特质表达状态
- [ ] 装饰性图片已隐藏（`accessibilityHidden(true)`）
- [ ] 所有可见文字可被 VoiceOver 朗读
- [ ] 阅读顺序合逻辑且与视觉布局一致
- [ ] 元素类型和状态正确朗读（特质匹配元素角色）
- [ ] 导航完整——无交互元素不可达
- [ ] 内容刷新期间无意外 VoiceOver 光标重置
- [ ] 所有复杂手势（滑动、长按、捏合）有通过自定义操作的可访问替代方案
- [ ] 每个模态和 alert 在自身内捕获焦点（`accessibilityViewIsModal = true`）
- [ ] 每个模态可用双指 Z 手势关闭（`accessibilityPerformEscape`）
- [ ] 导航或模态出现后焦点移到新内容
- [ ] 模态关闭后 VoiceOver 焦点返回触发元素
- [ ] 动态内容变化（异步加载、实时区域）被播报

### 关键 API

| 功能 | SwiftUI | UIKit |
|---|---|---|
| 标签 | `.accessibilityLabel(_:)` | `accessibilityLabel` |
| 提示 | `.accessibilityHint(_:)` | `accessibilityHint` |
| 值 | `.accessibilityValue(_:)` | `accessibilityValue` |
| 特质 | `.accessibilityAddTraits(_:)` | `accessibilityTraits` |
| 隐藏 | `.accessibilityHidden(true)` | `isAccessibilityElement = false` |
| 自定义操作 | `.accessibilityAction(named:)` | `accessibilityCustomActions` |
| 模态捕获 | 使用 `.sheet()` 自动 | `accessibilityViewIsModal = true` |
| 焦点 | `@AccessibilityFocusState` | `UIAccessibility.post(.screenChanged)` |
| 播报 | `AccessibilityNotification.Announcement` | `UIAccessibility.post(.announcement)` |

---

## 2. Voice Control

**是什么：** 通过语音命令免手导航。由能看见屏幕但有运动障碍的人使用。

### 通过标准

- [ ] 每个交互元素出现在"Show numbers"覆盖层中
- [ ] 每个元素在"Show names"覆盖层中有可见文字标签
- [ ] "Show names"中的标签与 UI 中可见的文字匹配
- [ ] 无无特定上下文的通用标签（"button"、"image"）
- [ ] "Tap [可见文字]"激活每个有标签的按钮
- [ ] 仅图标按钮有匹配其操作的 `accessibilityInputLabels`
- [ ] 自定义操作在"Show numbers"覆盖层中显示为">>"且可激活
- [ ] "Type [文字]"在每个文字字段中插入文字
- [ ] "Select [单词]"在文字字段中选择文字
- [ ] "Scroll up/down/left/right"在可滚动内容中工作
- [ ] 无 Voice Control 操作需要无语音替代方案的自定义多点触控手势

### 关键 API

| 功能 | SwiftUI | UIKit |
|---|---|---|
| 输入标签 | `.accessibilityInputLabels([_:])` | `accessibilityUserInputLabels` |
| 使可交互 | 使用 `Button`（首选） | `isAccessibilityElement = true` + `.button` 特质 |
| 自定义操作 | `.accessibilityAction(named:)` | `accessibilityCustomActions` |
| 唯一标签 | `.accessibilityLabel("Delete \(item.name)")` | 带上下文的 `accessibilityLabel` |

### 常见失败

- 非 Button 视图上的 `onTapGesture`——元素对 Voice Control 不可见
- `accessibilityLabel` 说"Submit"但按钮文字是"Send"——"Tap Send"失败
- 滑动删除无语音替代方案——Voice Control 用户不可访问

---

## 3. Larger Text

**是什么：** Dynamic Type 支持——当用户增大首选字体大小时文字和布局缩放。

### 通过标准

- [ ] 所有文字使用 Dynamic Type 文字样式（非固定字体大小）
- [ ] 文字至少缩放到最大无障碍大小（iOS 200%，watchOS 140%）
- [ ] 无文字在 Accessibility 5 大小下裁剪、重叠或严重截断
- [ ] 布局在大尺寸下适配（例如 HStack 切换到 VStack）
- [ ] 必须缩放的非文字元素使用 `@ScaledMetric`
- [ ] 无法缩放的仅图标元素使用 `.accessibilityShowsLargeContentViewer()`
- [ ] 自定义字体使用 `Font.custom(_:size:relativeTo:)` 或 `UIFontMetrics`
- [ ] 完整内容可访问——截断文字有详情视图或"More"提示

### 文字样式参考

| 样式 | 默认大小 | 用途 |
|---|---|---|
| `.largeTitle` | 34pt | 屏幕标题 |
| `.title` | 28pt | 主要标题 |
| `.title2` | 22pt | 次要标题 |
| `.title3` | 20pt | 第三级标题 |
| `.headline` | 17pt 粗体 | 分区标签 |
| `.body` | 17pt | 主要内容 |
| `.callout` | 16pt | 辅助内容 |
| `.subheadline` | 15pt | 次要内容 |
| `.footnote` | 13pt | 脚注 |
| `.caption` | 12pt | 说明 |
| `.caption2` | 11pt | 细则 |

### 关键 API

| 功能 | SwiftUI | UIKit |
|---|---|---|
| 文字样式 | `.font(.body)`、`.font(.title2)` 等 | `UIFont.preferredFont(forTextStyle:)` |
| 自定义字体 | `Font.custom(_:size:relativeTo:)` | `UIFontMetrics.default.scaledValue(for:)` |
| 缩放非字体值 | `@ScaledMetric(relativeTo: .body)` | `UIFontMetrics(forTextStyle:).scaledValue(for:)` |
| Large Content Viewer | `.accessibilityShowsLargeContentViewer()` | `UILargeContentViewerInteraction` |
| 检测大小 | `@Environment(\.dynamicTypeSize)` | `traitCollection.preferredContentSizeCategory` |

---

## 4. Dark Interface

**是什么：** 应用支持系统深色模式，或应用默认深色。

### 通过标准

- [ ] 应用响应系统深色模式（无需重启即改变外观）或应用默认深色
- [ ] 所有文字在深色模式下有足够对比度（启用 Increase Contrast 测试）
- [ ] 视图转场期间无明亮闪烁
- [ ] 所有视图外观一致深色（无保持浅色的屏幕）
- [ ] 全程使用语义颜色（非硬编码 hex 值）
- [ ] 自定义颜色有深色模式变体（Color Set 或 UIColor 动态提供者）
- [ ] 白色背景图片在需要时使用 `accessibilityIgnoresInvertColors`
- [ ] 边框和分隔线在深色模式下保持可见

### 关键 API

| 功能 | SwiftUI | UIKit |
|---|---|---|
| 检测模式 | `@Environment(\.colorScheme)` | `traitCollection.userInterfaceStyle` |
| 语义颜色 | `.foregroundStyle(.primary)`、`Color(.systemBackground)` | `.label`、`.systemBackground` |
| 动态颜色 | Asset catalog Color Set | `UIColor { traits in traits.userInterfaceStyle == .dark ? ... : ... }` |
| 响应变化 | 使用语义颜色自动 | `traitCollectionDidChange(_:)`（iOS 17 弃用；使用 `registerForTraitChanges`） |
| 强制深色测试 | `.environment(\.colorScheme, .dark)` | `overrideUserInterfaceStyle = .dark` |

### 常见陷阱

- 浅色模式对比度足够但深色模式失败——**始终两者都测试**
- 深色背景上的灰色文字——使用自动调整的 `.secondary`
- 浅色通过但深色失败的半透明遮罩

---

## 5. Differentiate Without Color

**是什么：** 颜色不是意义的唯一指示器。色觉缺陷用户必需（影响约 10% 的人）。

### 通过标准

- [ ] 应用通过灰度滤镜测试（灰度下所有信息可理解）
- [ ] 状态指示器在颜色之外使用形状、图标或文字
- [ ] 图表和数据可视化在颜色之外使用图案、标签或位置
- [ ] 交互状态（选中、禁用）在颜色之外传达
- [ ] 错误和成功状态不靠颜色可区分
- [ ] 链接与非交互文字可区分（下划线或字重，不仅靠颜色）
- [ ] 添加额外指示器时尊重 `accessibilityDifferentiateWithoutColor` 设置

### 关键 API

| 功能 | SwiftUI | UIKit |
|---|---|---|
| 检测设置 | `@Environment(\.accessibilityDifferentiateWithoutColor)` | `UIAccessibility.shouldDifferentiateWithoutColor` |
| 观察变化 | `.onChange(of: differentiateWithoutColor)` | `UIAccessibility.differentiateWithoutColorDidChangeNotification` |
| 图表符号 | Swift Charts 上 `.symbol(by: .value(...))` | 每系列符号形状 |

### 测试方法

启用：Settings → Accessibility → Display & Text Size → Color Filters → Grayscale。导航每个屏幕。如果任何信息变得模糊或不可见，测试失败。

---

## 6. Sufficient Contrast

**是什么：** 文字和交互元素满足 WCAG 对比度比率，面向低视力用户。

### WCAG 对比度比率

| 元素 | 最低 | 增强（AAA） |
|---|---|---|
| 正常文字（<18pt 常规，<14pt 粗体） | **4.5:1** | 7:1 |
| 大文字（≥18pt 常规或 ≥14pt 粗体） | **3:1** | 4.5:1 |
| 非文字交互元素 | **3:1** | — |
| 状态指示器（复选框边框、开关轨道） | **3:1** | — |
| 无信息价值的装饰性文字 | 无要求 | — |
| 占位符文字 | **4.5:1**（必须可读） | — |

### 通过标准

- [ ] 所有正文在浅色和深色模式下满足 4.5:1
- [ ] 大文字在浅色和深色模式下满足 3:1
- [ ] 所有交互元素边框、焦点指示器和状态标记满足 3:1
- [ ] 占位符文字满足 4.5:1（可见但与已输入文字区分）
- [ ] 同时启用 Bold Text 和 Increase Contrast 时测试通过
- [ ] 用 Accessibility Inspector 对比度检查器或等效工具验证对比度

### 关键 API

```swift
// SwiftUI —— 语义颜色自动适应对比度
@Environment(\.colorSchemeContrast) var contrast
let increaseContrast = (contrast == .increased)

// 示例：对比度增加时使用更粗的边框
RoundedRectangle(cornerRadius: 8)
    .stroke(
        increaseContrast ? Color(.label) : Color(.separator),
        lineWidth: increaseContrast ? 2 : 1
    )

// UIKit
UIAccessibility.isDarkerSystemColorsEnabled
```

---

## 7. Reduced Motion

**是什么：** 有前庭障碍的用户禁用运动以避免恶心和眩晕。

### 通过标准

- [ ] 视差效果、深度模拟和动画模糊已禁用
- [ ] 旋转、涡旋或多轴动画被移除或替换
- [ ] 自动前进的轮播和幻灯片停止或提供手动控制
- [ ] 有意义的动画（传达信息的）被替换——而非移除——用溶解/淡入淡出/颜色偏移
- [ ] 纯装饰性动画被完全移除
- [ ] 系统设置自动检测（无需应用内设置即可通过）

### 决策规则

**装饰性动画**（弹跳标志、粒子效果、背景波纹）：**完全移除。**

**功能性动画**（卡片滑动表示已保存、视图放大显示层级）：**替换**为无运动等价物（淡入淡出、颜色变化、高亮）。永远不要移除——移除会破坏理解。

### 关键 API

| 功能 | SwiftUI | UIKit | watchOS |
|---|---|---|---|
| 检测 | `@Environment(\.accessibilityReduceMotion)` | `UIAccessibility.isReduceMotionEnabled` | `WKAccessibilityIsReduceMotionEnabled()` |
| 观察 | `onChange(of: reduceMotion)` | `UIAccessibility.reduceMotionStatusDidChangeNotification` | `WKAccessibilityReduceMotionStatusDidChange` |

---

## 8. Captions

**是什么：** 面向聋人和重听用户的视频和音频内容的字幕和副标题。

### 通过标准

- [ ] 系统"Closed Captions + SDH"设置开启时自动启用字幕
- [ ] 第一方视频中的所有对话都有字幕
- [ ] 与理解相关的音效有字幕（SDH 格式）
- [ ] 第三方内容的字幕显示 CC 或 SDH 徽章指示器
- [ ] 仅音频内容有文字转录可用
- [ ] 字幕外观遵循系统偏好（大小、颜色、字体）
- [ ] 如果应用无视频或音频内容则不声明

### 关键 API

| 功能 | API |
|---|---|
| 自动字幕支持 | 使用 `AVPlayerViewController`——自动处理一切 |
| 检查系统设置 | `MACaptionAppearanceGetDisplayType(.user)` |
| 选择字幕轨道 | 带 `.legible` 特征的 `AVMediaSelectionGroup` |
| SDH 特征 | `AVMediaCharacteristic.isSDH` |
| 自定义播放器 | `MACaptionAppearanceGetDisplayType` 返回 `.alwaysOn` 时选择轨道 |

---

## 9. Audio Descriptions

**是什么：** 为盲人用户旁白视频中的视觉内容。

### 通过标准

- [ ] 系统 AD 设置开启时自动激活音频描述轨道
- [ ] 所有第一方视频的视觉动作、场景变化和屏幕文字都被描述
- [ ] 游戏过场动画和动画序列已覆盖
- [ ] 带 AD 的第三方内容显示"AD"徽章指示器
- [ ] 描述内容很少时不要声明支持
- [ ] 如果应用无视频内容则不声明

### 关键 API

| 功能 | API |
|---|---|
| 自动 AD 支持 | 使用 `AVPlayerViewController`——自动选择 AD 轨道 |
| 检测 AD 轨道 | 带 `.describesVideoForAccessibility` 特征的 `AVMediaSelectionGroup` |
| 显示"AD"徽章 | 检查轨道存在 → 在自定义播放器 UI 中显示徽章 |
| 音频会话 | `.spokenAudio` 模式加 `.duckOthers` 与其他音频共存 |

---

## 评估矩阵模板

在提交 Nutrition Label 前使用此表。将每个常见任务标记为 Pass（✅）、Fail（❌）或 Not Applicable（—）。

| 常见任务 | VoiceOver | Voice Control | Larger Text | Dark Mode | No Color | Contrast | Motion | Captions | Audio Desc |
|---|---|---|---|---|---|---|---|---|---|
| 应用启动/引导 | | | | | | | | | |
| 登录/认证 | | | | | | | | | |
| 核心主要功能 | | | | | | | | | |
| 搜索/浏览内容 | | | | | | | | | |
| 设置/偏好 | | | | | | | | | |
| 购买/交易 | | | | | | | | | |
| 媒体播放 | | | | | | | | — |

**一列中所有单元格必须为 ✅ 或 — 才能声明该 Nutrition Label。**

---

## 准确性和 App Review

平台审查流程在应用审查期间验证 Nutrition Label 声明。不准确的声明违反 **App Store Review Guideline 2.3**。

- 不完整支持（例如 VoiceOver 可浏览但不可结账）→ 不要声明
- 部分合规（例如部分视频有字幕但非全部）→ 不要声明
- 在真实设备上测试，不仅是在 Simulator 或 Previews 中
- 每次涉及 UI 或媒体的主要发布后重新评估
