# 无障碍术语表

常见无障碍术语和概念的快速参考。

## 辅助技术

**VoiceOver** — Apple 的屏幕阅读器。朗读屏幕内容并允许通过手势或键盘导航。失明或低视力用户依赖 VoiceOver 使用 iOS 应用。

**Voice Control** — 系统级语音导航和听写。识别无障碍标签并允许无需互联网的完整设备控制。

**Switch Control** — 基于扫描的外部开关导航。用户循环浏览元素并通过开关按压激活。对严重运动障碍用户至关重要。

**Full Keyboard Access** — 用外部键盘导航和控制 iOS。适用于无法使用触摸输入的用户。

**Dynamic Type** — 系统级文本大小控制。用户从 12 种尺寸中选择（7 种标准 + 5 种无障碍尺寸）。文本相对于默认值从 -3 缩放到 +5。如需精确尺寸，请参阅 Apple HIG：[iOS/iPadOS Dynamic Type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-Dynamic-Type-sizes) 和 [iOS/iPadOS larger accessibility type sizes](https://developer.apple.com/design/human-interface-guidelines/typography#iOS-iPadOS-larger-accessibility-type-sizes)。

**Zoom** — 系统级屏幕放大。用户可放大至 15 倍。与应用内的捏合放大不同。

**Large Content Viewer** — 不可缩放元素的点击并按住界面。在屏幕中央显示放大版本。iOS 13+（[`UILargeContentViewerInteraction`](https://developer.apple.com/documentation/uikit/uilargecontentviewerinteraction)）。

**Guided Access** — 将设备锁定到单个应用并可限制触摸区域。适用于教育、信息亭或专注任务。

**Magnifier** — 基于相机的放大工具，用于查看真实世界内容。适用于阅读印刷文本或标志。

**Assistive Touch (AssistiveTouch)** — 用于手势和操作的屏幕菜单。减少对复杂多指手势的需求。

## 无障碍属性

**accessibilityLabel** — 元素的名称。回答"这是什么？"示例："关闭"、"播放"、"设置"。应简洁，不包含控件类型。

**accessibilityValue** — 当前状态或值。回答"它当前的状态是什么？"示例："50 percent"、"On"、"第 3 行，共 10 行"。随状态变化更新。

**accessibilityHint** — 操作结果的描述。回答"使用它会发生什么？"示例："播放音频"、"打开设置"。可选；仅在非显而易见的操作时谨慎使用。

**accessibilityTraits** — 描述元素角色和状态的特征。示例：`.button`、`.header`、`.selected`、`.adjustable`。可组合多个特质。

**accessibilityCustomActions** — 通过 VoiceOver 的操作转子可用的次要操作。示例：删除、分享、标记为已读。iOS 8+（[`UIAccessibilityCustomAction`](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction)）。

**accessibilityElements** — 容器内无障碍元素的有序数组。用于在自动排序不正确时控制导航顺序。

## 常见特质

**.button** — 执行操作的可点击控件

**.header** — 章节标题（显示在 VoiceOver 的标题转子中）

**.selected** — 组中当前选中的项目（选择器、标签、分段控件）

**.adjustable** — 值可以递增/递减（滑块、步进器、选择器）

**.link** — 打开 URL 或导航

**.isModal** — 限制焦点的模态对话框

**.updatesFrequently** — 值快速变化（防止 VoiceOver 中断）

**.startsMediaSession** — 激活时播放音频/视频

**.allowsDirectInteraction** — 传递触摸（用于绘图、钢琴应用）

## 无障碍功能（iOS 设置）

**减弱动效** — 最小化动画和视差效果。用户启用以减少前庭触发和晕动症。

**减弱透明度** — 使半透明背景变为不透明。改善对比度并减少视觉复杂度。

**增强对比度** — 增加整个系统的颜色对比度。帮助低视力用户区分元素。

**不使用颜色区分** — 在颜色旁添加形状/图标以传达含义。对色盲用户至关重要。

**粗体文本** — 使系统字体更粗。需要重启应用。

**按钮形状** — 为按钮添加轮廓/下划线。帮助识别交互元素。

**智能反转颜色** — 反转颜色但不影响图像和媒体。深色模式的高对比度替代方案。

**反转颜色** — 经典颜色反转，影响所有内容，包括图像。

**单声道音频** — 以单声道播放音频声道。适用于单耳听力受损的用户。

**LED 闪烁提醒** — 通知时闪烁相机 LED（帮助失聪或听力受损用户）。

**音频描述** — 描述视频中视觉内容的旁白。

**Made for iPhone 助听器** — 让用户将音频直接流式传输到兼容的助听器。

**更大的无障碍字号** — 超出标准 Large 的五种文本尺寸（从 XXL 到无障碍 5）。

## 文本样式（Dynamic Type）

**标准尺寸：**
- Large Title（默认 34pt）
- Title（28pt）
- Title 2（22pt）
- Title 3（20pt）
- Headline（17pt 粗体）
- Body（17pt）— 基础尺寸
- Callout（16pt）
- Subheadline（15pt）
- Footnote（13pt）
- Caption（12pt）
- Caption 2（11pt）

全部随用户的文本大小设置成比例缩放。

## 概念

**无障碍元素** — 辅助技术可交互的任何 UI 组件。默认情况下，标准控件（按钮、标签）是无障碍元素；自定义视图不是。

**焦点** — VoiceOver 或 Full Keyboard Access 当前高亮的元素。一次只有一个元素有焦点。

**转子** — VoiceOver 手势（双指旋转），显示上下文菜单。常见转子：标题、链接、表单控件、地标、自定义操作。

**语义颜色** — 适应浅色/深色模式和增强对比度的系统颜色。示例：`.label`、`.systemBackground`、`.secondaryLabel`。

**点击区域** — 控件的可点击区域。为无障碍应至少 44×44 点。

**隔离域** — 在 Swift 并发上下文中：主 actor vs 后台 actor。对于无障碍：确保 UI 更新在主线程上发生。

**分组** — 将多个元素组合成一个无障碍元素。减少滑动次数并使导航更容易。

**无障碍容器** — 包含其他无障碍元素并可控制其顺序的视图。

## 测试术语

**Accessibility Inspector** — Xcode 工具，用于检查无障碍属性和运行审计。窗口 > Accessibility Inspector。

**无障碍标识符** — 用于在 UI 测试中标识元素的字符串。VoiceOver 不读取；纯用于自动化。

**环境覆盖** — Xcode 功能，用于在不更改系统设置的情况下测试不同的无障碍设置。

**审计** — Accessibility Inspector 功能，检查常见问题：缺少标签、低对比度、小目标。

**字幕面板** — VoiceOver 功能，将语音输出显示为文本。设置 > 无障碍 > VoiceOver > 字幕面板。

**屏幕变暗** — VoiceOver 功能，关闭显示同时保持手机功能。三指三次点击。

## 缩写

**AT** — 辅助技术

**A11y** — "accessibility"的缩写（a + 11 个字母 + y）

**VO** — VoiceOver

**DT** — Dynamic Type

**WCAG** — Web Content Accessibility Guidelines（也适用于 iOS 应用）

**ARIA** — Accessible Rich Internet Applications（Web 标准；存在 iOS 等效物）

## 相关术语

**包容性设计** — 从一开始就考虑多样人类能力的设计方法，而非事后补充。

**通用设计** — 尽可能让所有人都能使用的设计，无需适配。

**残障** — 人的能力与环境之间的不匹配。无障碍移除障碍。

**永久性、临时性、情境性** — 残障类型。示例：失明（永久性）、眼部受伤（临时性）、强光（情境性）。

**残障的社会模型** — 将残障视为社会障碍而非个人损伤创造的框架。

## 来源

- [Apple Developer Documentation — UIKit Accessibility](https://developer.apple.com/documentation/uikit/accessibility)
- [Apple Human Interface Guidelines — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Accessibility Up To 11 — #365DaysIOSAccessibility](https://accessibilityupto11.com/365-days-ios-accessibility/)
