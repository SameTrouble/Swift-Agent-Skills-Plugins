# WCAG 2.2 → iOS/SwiftUI/UIKit 映射

将 WCAG 2.2 Level A 和 AA 成功标准映射到原生平台 API。覆盖 iOS、macOS、watchOS、tvOS 和 visionOS。基于 WCAG 2.2 和 WCAG2ICT（移动应用指南）。

**范围：** 仅 Level A 和 AA——这些是标准合规目标。原生框架提供支持的地方会注明 Level AAA 标准。

---

## 1. 可感知

### 1.1 文字替代方案

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 1.1.1 非文字内容 | A | 非文字内容的文字替代方案 | SwiftUI: `.accessibilityLabel(_:)`，装饰性用 `.accessibilityHidden(true)`；UIKit: `accessibilityLabel`，`isAccessibilityElement = false` |

### 1.2 基于时间的媒体

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 1.2.1 仅音频/仅视频 | A | 预录制媒体的替代方案 | 提供转录；使用 `AVPlayerViewController` |
| 1.2.2 字幕（预录制） | A | 预录制视频音频的字幕 | `AVPlayerViewController`（自动启用字幕）；`AVMediaCharacteristic.legible` |
| 1.2.3 音频描述或替代方案 | A | 预录制视频的音频描述 | `AVMediaCharacteristic.describesVideoForAccessibility` |
| 1.2.4 字幕（实时） | AA | 实时视频音频的字幕 | 应用提供的实时字幕/转录集成到流媒体体验中 |
| 1.2.5 音频描述（预录制） | AA | 预录制视频的音频描述 | `AVPlayerViewController` + 音频描述轨道 |

### 1.3 可适应

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 1.3.1 信息和关系 | A | 编程结构匹配视觉 | SwiftUI: `.accessibilityElement(children:)`、`.accessibilityAddTraits(.isHeader)`、`Section`、`NavigationStack`；UIKit: `UIAccessibilityTraits`、`accessibilityContainerType` |
| 1.3.2 有意义的序列 | A | 正确的阅读顺序 | SwiftUI: `.accessibilitySortPriority(_:)`、布局顺序；UIKit: `accessibilityElements` 数组顺序 |
| 1.3.3 感官特性 | A | 不仅依赖形状、大小、位置或声音 | 将视觉提示与文字标签和无障碍标签结合 |
| 1.3.4 方向 | AA | 内容在竖屏和横屏下都工作 | 通过 Auto Layout / SwiftUI 自适应布局支持两种方向；仅在必要时锁定（例如相机） |
| 1.3.5 识别输入目的 | AA | 输入字段的编程目的 | UIKit: `textContentType`（`.emailAddress`、`.password` 等）；SwiftUI: `.textContentType(_:)`、`.keyboardType(_:)` |

### 1.4 可区分

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 1.4.1 颜色使用 | A | 颜色不是唯一视觉指示器 | 在颜色旁添加形状、图标或文字；用 `@Environment(\.accessibilityDifferentiateWithoutColor)` 检查 |
| 1.4.2 音频控制 | A | 暂停/停止/控制音频的机制 | 标准播放控件；尊重静音模式 |
| 1.4.3 对比度（最低） | AA | 4.5:1 文字，3:1 大文字 | 语义颜色：`Color(.label)`、`Color(.secondaryLabel)`；用 Accessibility Inspector 对比度检查器检查；响应 `@Environment(\.colorSchemeContrast)` |
| 1.4.4 调整文字大小 | AA | 文字可调整到 200% 而不丢失 | SwiftUI: `.font(.body)` 文字样式、`@ScaledMetric`；UIKit: `UIFontMetrics`、`adjustsFontForContentSizeCategory = true`；用 Canvas 中的 Dynamic Type Variants 测试 |
| 1.4.5 文字图片 | AA | 使用真实文字，非文字图片 | 使用带样式的 `Text` 视图而非渲染的文字图片 |
| 1.4.10 重排 | AA | 内容在窄宽度下重排 | SwiftUI: `ViewThatFits`（iOS 16+）、自适应堆栈；UIKit: 带适当约束的 Auto Layout |
| 1.4.11 非文字对比度 | AA | UI 组件和图形 3:1 | 边框、图标、焦点指示器与其背景对比；使用 Accessibility Inspector |
| 1.4.12 文字间距 | AA | 支持调整间距 | 使用系统文字样式——它们自动尊重用户设置 |
| 1.4.13 悬停/焦点上的内容 | AA | 可关闭、可悬停、持久 | 确保 `.popover()` / `.help()` 内容在指针移入时保持可见，可通过 Escape 关闭，持续到关闭；避免指针移动时消失的自定义悬停触发 UI |

---

## 2. 可操作

### 2.1 键盘可访问

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 2.1.1 键盘 | A | 所有功能通过键盘 | Full Keyboard Access：每个元素可通过 Tab 到达；SwiftUI: `.focusable()`、`FocusState`；UIKit: `canBecomeFocused`、`UIKeyCommand` |
| 2.1.2 无键盘陷阱 | A | 键盘焦点始终可移开 | 确保 Escape 关闭模态；SwiftUI: `.sheet()` 处理此问题；UIKit: 实现 `accessibilityPerformEscape()` |
| 2.1.4 字符键快捷键 | A | 单键快捷键可重映射/禁用 | 避免单字符键快捷键；使用修饰键（Cmd+、Ctrl+） |

### 2.2 足够时间

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 2.2.1 时间可调 | A | 用户可延长时间限制 | 提供超时警告和延长；无用户控制不自动前进 |
| 2.2.2 暂停、停止、隐藏 | A | 自动更新内容可暂停 | 提供暂停控件；尊重 `@Environment(\.accessibilityReduceMotion)` |

### 2.3 癫痫和物理反应

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 2.3.1 三次闪烁 | A | 无内容闪烁 > 3 次/秒 | 避免闪烁内容；用 `accessibilityReduceMotion` 控制 |

### 2.4 可导航

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 2.4.1 跳过块 | A | 跳过重复内容 | SwiftUI: 使用 `NavigationStack`、`TabView` 构建结构；UIKit: `accessibilityContainerType = .semanticGroup` |
| 2.4.2 页面标题 | A | 屏幕有描述性标题 | SwiftUI: `.navigationTitle(_:)`；UIKit: `UIViewController` 的 `title` 属性 |
| 2.4.3 焦点顺序 | A | 逻辑焦点/导航顺序 | SwiftUI: `.accessibilitySortPriority(_:)`、布局顺序；UIKit: `accessibilityElements` 数组 |
| 2.4.4 链接目的 | A | 链接目的从上下文清晰 | 使用描述性按钮/链接标签；避免"Click here" |
| 2.4.5 多种方式 | AA | 多种到达内容的方式 | 标签栏 + 搜索 + 导航层级 |
| 2.4.6 标题和标签 | AA | 描述性标题和标签 | SwiftUI: `.accessibilityAddTraits(.isHeader)`；UIKit: `UIAccessibilityTraits.header` |
| 2.4.7 焦点可见 | AA | 键盘焦点指示器可见 | 系统提供默认焦点环；不要用 `.focusEffectDisabled(true)` 抑制；AppKit: 仅在绘制自定义焦点环或空间不足以容纳默认环时设置 `NSView.focusRingType = .none` |
| 2.4.11 焦点不被遮挡（最低） | AA | 聚焦元素不被完全隐藏 | 确保模态/遮罩不覆盖聚焦元素；使用 `.accessibilityViewIsModal` |

### 2.5 输入模态

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 2.5.1 指针手势 | A | 多点触控的单指针替代方案 | 为捏合/旋转手势提供按钮替代方案；`.accessibilityAction` 用于自定义手势 |
| 2.5.2 指针取消 | A | 按下事件不触发操作 | 使用 `touchUpInside`（UIKit 默认），而非 `touchDown`；SwiftUI `Button` 自动处理 |
| 2.5.3 名称中的标签 | A | 可访问名称包含可见文字 | Voice Control: `.accessibilityInputLabels` 必须匹配或包含可见文字 |
| 2.5.4 运动触发 | A | 设备运动的替代方案 | 不要求摇晃/倾斜；提供屏幕按钮替代方案 |
| 2.5.7 拖动动作 | AA | 拖动的单指针替代方案 | 提供基于按钮的重排；`.accessibilityAction(named: "Move Up") { … }`；`.accessibilityDragPoint` / `.accessibilityDropPoint` |
| 2.5.8 目标大小（最低） | AA | 触摸目标 ≥ 24×24 CSS px（推荐 44×44pt） | SwiftUI: `.frame(minWidth: 44, minHeight: 44)`；UIKit: 确保 `accessibilityFrame` ≥ 44×44pt；Human Interface Guidelines 推荐 44×44pt |

---

## 3. 可理解

### 3.1 可读

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 3.1.1 页面语言 | A | 内容语言是编程的 | 在 Info.plist `CFBundleDevelopmentRegion` 中设置应用语言；按视图：SwiftUI `.environment(\.locale, …)` |
| 3.1.2 部分语言 | AA | 部分语言已识别 | 带 `.accessibilitySpeechLanguage` 的 `NSAttributedString`；SwiftUI: `.accessibilitySpeechLanguage(_:)` |

### 3.2 可预测

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 3.2.1 聚焦时 | A | 聚焦时无意外变化 | 不要仅在聚焦时触发导航或状态变化 |
| 3.2.2 输入时 | A | 输入时无意外变化 | 提交前确认；不在选择器选择时自动导航 |
| 3.2.3 一致导航 | AA | 跨屏幕一致导航 | 使用标准 `TabView`、`NavigationStack` 模式 |
| 3.2.4 一致识别 | AA | 相同功能 = 相同标签 | 跨屏幕为相同操作使用一致的 `.accessibilityLabel` |
| 3.2.6 一致帮助 | A | 帮助机制在一致位置 | 将帮助放在 Settings 或一致的工具栏位置 |

### 3.3 输入辅助

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 3.3.1 错误识别 | A | 错误被识别和描述 | 为错误发送 `AccessibilityNotification.Announcement`；在错误文字上使用 `.accessibilityLabel` |
| 3.3.2 标签或说明 | A | 输入字段有标签 | SwiftUI: `TextField("Email", …)`；UIKit: `UITextField` 上的 `accessibilityLabel` |
| 3.3.3 错误建议 | AA | 为错误建议纠正 | 提供可操作的错误消息；使用 `.textContentType` 进行自动填充建议 |
| 3.3.4 错误预防（法律/财务） | AA | 可逆、已验证或已确认 | 确认破坏性操作；提供撤销；提交前审查 |
| 3.3.7 冗余输入 | A | 不重复要求已输入的信息 | 使用 Keychain、AutoFill 和状态管理避免重复输入 |
| 3.3.8 可访问认证（最低） | AA | 认证无认知功能测试 | 支持通行密钥、生物识别（`LAContext`）、密码管理器；避免 CAPTCHA |

---

## 4. 健壮

### 4.1 兼容

| SC | 级别 | 要求 | 平台 API |
|---|---|---|---|
| 4.1.2 名称、角色、值 | A | 所有 UI 组件有可访问名称、角色、值 | SwiftUI: `.accessibilityLabel`、`.accessibilityValue`、`.accessibilityAddTraits`；UIKit: `accessibilityLabel`、`accessibilityTraits`、`accessibilityValue` |
| 4.1.3 状态消息 | AA | 状态变化在不移动焦点的情况下播报 | SwiftUI: `AccessibilityNotification.Announcement(_:).post()`；UIKit: `UIAccessibility.post(notification: .announcement, argument:)` |

---

## 快速查找：WCAG SC → Nutrition Label

| Nutrition Label | 主要 WCAG SC |
|---|---|
| VoiceOver | 1.1.1, 1.3.1, 1.3.2, 2.4.3, 2.4.6, 4.1.2 |
| Voice Control | 2.5.3, 2.5.8, 2.1.1 |
| Larger Text | 1.4.4, 1.4.10, 1.4.12 |
| Dark Interface | 1.4.3, 1.4.11 |
| Differentiate Without Color | 1.4.1, 1.4.11 |
| Sufficient Contrast | 1.4.3, 1.4.11 |
| Reduced Motion | 2.2.2, 2.3.1 |
| Captions | 1.2.2, 1.2.4 |
| Audio Descriptions | 1.2.3, 1.2.5 |

---

## 移动特定注意事项（来自 WCAG2ICT）

- **触摸目标**：WCAG 2.5.8 规定最小 24×24 CSS 像素。Human Interface Guidelines 推荐 44×44pt——使用更严格的标准。
- **方向**：除非对体验至关重要（1.3.4），否则支持所有方向。除非功能需要（例如相机取景器），否则不要锁定为竖屏。
- **文字调整**：iOS Dynamic Type 满足 1.4.4。在所有大小（包括无障碍大小）下测试——使用 Xcode Canvas Dynamic Type Variants。
- **拖动替代方案**：2.5.7 要求拖动的单指针替代方案。提供基于按钮的重排、`.accessibilityAction(named:)` 或 `.accessibilityDragPoint` / `.accessibilityDropPoint`。
- **认证**：3.3.8 是 WCAG 2.2 新增。支持生物识别（`Face ID`、`Touch ID`）、通行密钥和密码自动填充以避免认知功能测试。
