# 无障碍 QA 清单

用于手动无障碍测试的独立清单。将其交给 QA 测试人员——无需技能或 Claude 知识。

与 Apple 的 9 个 App Store Accessibility Nutrition Labels 和 WCAG 2.2 Level AA 对齐。

---

## 如何使用此清单

1. 在**真实设备**上测试——Simulator 不完全支持 VoiceOver、Voice Control 或 Switch Control
2. 测试**每个关键用户流程**：启动、引导、登录、主功能、设置、购买（如适用）
3. 标记每项：Pass / Fail / N/A
4. Nutrition Label 类别中单个 Fail 意味着该标签在 App Store 上**不可声明**

---

## 开始之前：Xcode 工具

### Xcode Canvas Variants（开发期间）
在预览画布底部点击 **Variants** 按钮（网格图标）：
- **Dynamic Type Variants** —— 以全部 12 种文字大小渲染视图
- **Color Scheme Variants** —— 并排显示浅色和深色模式
- **Orientation Variants** —— 竖屏和横屏

### Xcode Canvas Device Settings（开发期间）
在画布底部点击 **Device Settings** 按钮（滑块图标）：
- 为单个预览设置配色方案、Dynamic Type 大小和方向
- 组合设置以测试特定场景（例如：深色模式 + 大文字）

### Accessibility Inspector（Simulator 或设备）
Xcode 菜单 → Open Developer Tool → Accessibility Inspector
- **Inspection 标签** —— 指向任意元素查看其标签、特质、值和 frame 大小
- **Audit 标签** —— 对当前屏幕运行自动化检查（缺失标签、低对比度、小目标）
- **Settings 标签** —— 在 Simulator 上切换 Increase Contrast、Reduce Motion、Bold Text、Reduce Transparency 而无需更改设备设置

### performAccessibilityAudit()（自动化测试）
添加到 XCUITest target（iOS 17+）。在 CI 中捕获缺失标签、低对比度、小点击区域、裁剪文字和 Dynamic Type 失败。参见 `resources/audit-template.swift` 获取可直接使用的模板。

---

## 1. VoiceOver

**启用：** Settings → Accessibility → VoiceOver（或三击侧边按钮（如已配置））

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 1.1 | 导航所有元素 | 连续右滑穿过整个屏幕 | 每个交互元素都可达 |
| 1.2 | 标签有意义 | 点击每个元素，听播报 | 标签简洁描述元素，而非"button"或"image" |
| 1.3 | 标签中无冗余类型 | 听是否有"button button"或"image image" | VoiceOver 自动添加类型——标签不应包含 |
| 1.4 | 状态作为特质 | 切换开关、选择标签页 | VoiceOver 说"selected"/"on"/"off"——而非嵌入在标签文字中 |
| 1.5 | 装饰性图片已隐藏 | 在屏幕上滑动 | 装饰性图片被跳过 |
| 1.6 | 阅读顺序合逻辑 | 使用"Read All"（双指上滑） | 内容按视觉顺序阅读，从上到下、从左到右 |
| 1.7 | 导航后聚焦 | push 新屏幕 | 焦点移到新屏幕的第一个元素（通常是标题或返回按钮） |
| 1.8 | 模态关闭后聚焦 | 关闭 sheet/alert | 焦点返回到触发它的元素 |
| 1.9 | 可调控件工作正常 | 在滑块或步进器上上下滑动 | 值改变并被播报 |
| 1.10 | 动态变化已播报 | 触发加载状态或错误 | VoiceOver 播报变化（"Loading complete"、"Error: …"） |
| 1.11 | 完成关键流程 | 用 VoiceOver 从头到尾完成主任务 | 任务无需视力辅助即可完成 |

---

## 2. Voice Control

**启用：** Settings → Accessibility → Voice Control

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 2.1 | Show numbers | 说"Show numbers" | 每个交互元素都有数字覆盖层 |
| 2.2 | 按数字点击 | 说"Tap [数字]" | 正确的元素被激活 |
| 2.3 | Show names | 说"Show names" | 每个元素显示其可见文字标签 |
| 2.4 | 按名称点击 | 说"Tap [标签]" | 元素被激活——标签必须精确匹配可见文字 |
| 2.5 | 文字输入 | 在文字字段中说"Type [文字]" | 文字正确输入 |
| 2.6 | 滚动 | 说"Scroll down"/"Scroll up" | 内容滚动 |
| 2.7 | 仅图标元素 | 对仅图标按钮说"Tap Share"（或标签） | 按钮被激活——需要 `.accessibilityInputLabels` |

---

## 3. Larger Text（Dynamic Type）

**启用：** Settings → Accessibility → Display & Text Size → Larger Text → 拖动滑块到最大

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 3.1 | 文字缩放 | 设置为 Accessibility 5（最大） | 所有文字都变大 |
| 3.2 | 无裁剪 | 在最大尺寸下导航所有屏幕 | 无文字被截断且无"..."提示 |
| 3.3 | 无重叠 | 在最大尺寸下检查所有屏幕 | 无元素重叠 |
| 3.4 | 布局自适应 | 检查水平布局 | 行/列在需要时重排为垂直 |
| 3.5 | 固定 UI chrome | 长按标签栏图标或工具栏项 | Large Content Viewer 显示放大版本 |
| 3.6 | 小文字可读 | 设置为最小尺寸 | 文字仍然可读 |

**用 Xcode 快速检查：** 使用 Canvas Dynamic Type Variants 一次查看所有 12 种大小。

---

## 4. Sufficient Contrast

**工具：** Accessibility Inspector → Inspection 标签 → Color contrast

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 4.1 | 正常文字 | 检查正文与背景 | ≥ 4.5:1 对比度 |
| 4.2 | 大文字 | 检查标题（≥ 18pt 或 14pt 粗体） | ≥ 3:1 对比度 |
| 4.3 | 非文字元素 | 检查图标、边框、焦点环 | ≥ 3:1 对比度 |
| 4.4 | 两种模式 | 在深色模式下重复所有检查 | 浅色和深色都通过 |
| 4.5 | Increase Contrast | 在 Accessibility Inspector Settings 中启用 Increase Contrast | 边框和分隔线变得更明显 |
| 4.6 | 占位符文字 | 检查文字字段占位符 | 与背景 ≥ 4.5:1 |

---

## 5. Dark Interface

**启用：** Settings → Display & Brightness → Dark

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 5.1 | 所有文字可读 | 导航所有屏幕 | 无白底白字或不可见文字 |
| 5.2 | 边框可见 | 检查卡片、分区、分隔线 | 边框和分隔线可见 |
| 5.3 | 图片正确 | 检查照片、图标 | 无白色光晕；图片未被错误反转 |
| 5.4 | 状态指示器 | 检查彩色状态元素 | 在深色模式下仍可区分 |

---

## 6. Differentiate Without Color

**启用：** Settings → Accessibility → Display & Text Size → Color Filters → Grayscale

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 6.1 | 状态指示器 | 检查错误/成功/警告状态 | 可通过形状、图标或文字区分——不仅靠颜色 |
| 6.2 | 图表和图形 | 检查数据可视化 | 数据系列可通过图案、形状或标签区分 |
| 6.3 | 链接 | 检查链接文字 | 有下划线或以其他方式与正文区分 |
| 6.4 | 表单验证 | 触发错误状态 | 错误由图标或文字指示，不仅是红色 |

---

## 7. Reduced Motion

**启用：** Settings → Accessibility → Motion → Reduce Motion

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 7.1 | 导航转场 | push/pop 屏幕 | 无滑动动画——溶解或即时 |
| 7.2 | UI 动画 | 触发状态变化、加载 | 动画被移除或替换为淡入淡出/透明度 |
| 7.3 | 自动播放内容 | 检查自动播放动画/视频 | 已停止或有手动播放控制 |
| 7.4 | 视差效果 | 滚动内容 | 无视差或运动效果 |

**快速检查：** 在 Simulator 中运行时，在 Accessibility Inspector Settings 标签中切换 Reduce Motion。

---

## 8. Captions

**适用于：** 包含视频或音频内容的应用

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 8.1 | 字幕可用 | 播放有对话的视频 | 可通过播放器控件启用字幕 |
| 8.2 | 自动启用 | 在 Settings → Accessibility → Subtitles & Captioning 中启用 Closed Captions | 字幕自动出现 |
| 8.3 | 字幕准确 | 观看时阅读字幕 | 字幕与口语内容匹配 |
| 8.4 | 时间正确 | 观看视频时的字幕 | 字幕与音频同步 |

---

## 9. Audio Descriptions

**适用于：** 视觉信息重要的视频内容应用

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 9.1 | 音频描述可用 | 播放视频 | 可选择 Audio Description 音轨 |
| 9.2 | 自动启用 | 在 Settings → Accessibility → Audio Descriptions 中启用 Audio Descriptions | 音频描述自动播放 |
| 9.3 | 内容已描述 | 聆听音频描述 | 重要的视觉信息被旁白 |

---

## 10. 附加检查

### Switch Control

**启用：** Settings → Accessibility → Switch Control

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 10.1 | 扫描 | 启用自动扫描 | 每个元素按顺序高亮 |
| 10.2 | 激活 | 选择高亮元素 | 触发正确操作 |
| 10.3 | 自定义操作 | 导航到有滑动操作的元素 | 操作出现在扫描菜单中 |
| 10.4 | 无超时 | 慢速使用应用 | 无超时或自动前进 |

### Full Keyboard Access（iPad / Mac）

**启用：** Settings → Accessibility → Keyboards → Full Keyboard Access

| # | 测试 | 如何验证 | 通过标准 |
|---|---|---|---|
| 10.5 | Tab 导航 | 反复按 Tab | 焦点穿过所有交互元素 |
| 10.6 | 反向 Tab | 按 Shift+Tab | 焦点向后移动 |
| 10.7 | 激活 | 在聚焦元素上按 Space 或 Return | 元素被激活 |
| 10.8 | Escape 关闭 | 在模态上按 Escape | 模态关闭 |
| 10.9 | 无焦点陷阱 | 在整个应用中 Tab | 焦点永不卡住 |

---

## 摘要模板

测试后，填写：

| Nutrition Label | 状态 | 阻断问题 |
|---|---|---|
| VoiceOver | Pass / Fail | |
| Voice Control | Pass / Fail | |
| Larger Text | Pass / Fail | |
| Sufficient Contrast | Pass / Fail | |
| Dark Interface | Pass / Fail | |
| Differentiate Without Color | Pass / Fail | |
| Reduced Motion | Pass / Fail | |
| Captions | Pass / Fail / N/A | |
| Audio Descriptions | Pass / Fail / N/A | |

### App Store 建议草案

使用上面完成的摘要准备 App Store Accessibility Nutrition Label 建议：

- You could claim: 每个标记为 Pass 的标签
- You should not claim: 每个标记为 Fail 的标签
- Not applicable: 每个标记为 N/A 的标签
- 为支持和不支持的标签添加简短理由

示例交接：

```md
Accessibility Nutrition Label recommendation

You could claim:
- VoiceOver
- Voice Control
- Larger Text
- Sufficient Contrast
- Dark Interface
- Differentiate Without Color
- Reduced Motion

Why you could claim them:
- VoiceOver: all reviewed common tasks are reachable, labeled, and operable with VoiceOver
- Voice Control: all reviewed interactive elements can be activated by visible name or input label
- Larger Text: reviewed screens reflow correctly and remain readable at the largest supported sizes
- Sufficient Contrast: reviewed text and interactive elements meet contrast requirements in light and dark mode
- Dark Interface: reviewed screens support dark appearance without unreadable content or broken chrome
- Differentiate Without Color: reviewed states and status indicators remain understandable without color alone
- Reduced Motion: reviewed transitions and state changes respect Reduce Motion

You should not claim:
- Captions
- Audio Descriptions

Why you should not claim them:
- Captions: the app has no primary video or long-form media experience in the reviewed scope
- Audio Descriptions: the app has no video content that would justify this label in the reviewed scope
```
