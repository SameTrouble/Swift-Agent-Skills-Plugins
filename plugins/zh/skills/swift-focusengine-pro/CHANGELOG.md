# 更新日志

Swift FocusEngine Pro 的所有显著变更均记录在此。

## [1.7.1] - 2026-06-04

### 修复
- **仓库结构——`npx skills add` 现在可以正确解析。** 此前仓库同时拥有根目录 `SKILL.md` 和重复的 `swift-focusengine-pro/SKILL.md` 子文件夹（相同技能名称）。安装器在根目录 `SKILL.md` 处停止并复制整个仓库，导致 `references/` 深了一层，破坏了技能自身的引用路径。该技能现在是仓库根目录下的单个扁平技能（`SKILL.md` + `references/` + `agents/`）；重复的子文件夹已移除，`package.json` 指向 `.`。与 1.7.0 相比无技能内容变更——这纯粹是打包修复。
- 根目录 `SKILL.md` 的 description 升级为更完整的编写/审查触发文本，以改善自动激活。

## [1.7.0] - 2026-06-04

### 改进诊断（无新反模式）

这些编辑使现有修复可以从症状中找到——区域重新进入的修复已在反模式 #25 中记录，但没有任何内容从观察到的行为引导你找到它。

- **`swiftui-focus.md`——`focusSection()` "无最后焦点记忆"陷阱。** 明确说明，与 UIKit 的 `remembersLastFocusedIndexPath` 不同，`focusSection()` 每次进入时都按几何方式选择，不记忆任何内容。指出了常见症状（从网格向上箭头导航到一行标签时，落在最近的标签上而非选中的那个），并引导到反模式 #25 获取修复方案。注意反应式 `onChange` 重定向会导致可见跳跃，不是正确的修复。
- **`swiftui-focus.md`——区域宽度逃逸陷阱。** 比（或偏移于）其下方内容更窄的 `focusSection()` 会留下没有区域覆盖的列，因此向上会越过它逃逸（例如到标签栏）。修复：在 `.focusSection()` 之前使用 `.frame(maxWidth: .infinity, alignment: .leading)`。
- **`focus-restoration.md`——ZStack `if/else` 覆盖层恢复。** 手动实现的覆盖层切换不会像 `.sheet()`/`.fullScreenCover()` 那样自动恢复焦点。记录了时序陷阱：在关闭时同步 `@FocusState` 赋值会被丢弃，因为目标尚未重建——使用 `Task { @MainActor in … }` 延迟。

## [1.6.0] - 2026-04-29

### 新增
- **新 tvOS 反模式 #30**——具有多个可聚焦子视图的 UIKit 视图控制器上缺少 `preferredFocusEnvironments` 重写。没有显式重写，tvOS 会选择几何上第一个可聚焦视图，这通常会落在次要 CTA（例如"返回首页"）而非主要操作（例如"登录"）上。
- **缺失检查触发器**——PR 审查风格指南现在会标记缺少 `preferredFocusEnvironments` 重写的垂直 `UIStackView` 按钮、可聚焦列表+独立按钮、条件 CTA 和模态/sheet 展示。重写的缺失本身就是一项发现。
- **`uikit-focus.md`："何时重写 `preferredFocusEnvironments`"部分**——列举触发条件，提供带 `setNeedsFocusUpdate()` 交叉引用（反模式 #7）的条件 CTA 模式，用于视图出现后的状态变化。
- 反模式总数：30（从 29 增加）

## [1.5.0] - 2026-04-13

### 新增
- **5 个新生产级 tvOS 反模式**（#25–29），来自大规模媒体应用 tvOS 开发：
  - #25：活动选择状态下多个列表项上的 `.disabled()`——批量切换焦点级联
  - #26：`onChange` 内的 `ScrollViewReader.scrollTo()` 与焦点引擎产生反馈循环
  - #27：`@Observable` 同值变更触发不必要的 body 重新求值
  - #28：带 `.userInitiated` 的 `defaultFocus` 仅在初始出现时触发，而非重新进入时
  - #29：导航过渡期间的瞬态焦点弹跳（侧边栏穿透）
- **生产级侧边栏模式**——双重 `@FocusState`（容器+每项）配合 `.disabled()` 门控用于焦点重新进入
- **UIKit 参考代码库侧边栏对比**——`remembersLastFocusedIndexPath`、容器级 `isUserInteractionEnabled`、0.5s 防抖
- **`ScrollPosition` vs `ScrollViewReader`**——不与焦点引擎对抗的声明式滚动绑定
- **滚动边缘淡出模式**——`.scrollEdgeEffectStyle(.soft)`（tvOS 26+）、带 `.mask()` 的手动渐变遮罩、`onGeometryChange` 跟踪
- **焦点缩放匹配**——SwiftUI `scaleEffect` 的 1.13x 缩放参考对比表
- **`@Observable` 焦点集成**——同值守卫、非 UI 状态的 `@ObservationIgnored`
- **ScrollTo 反馈循环文档**——`async-focus.md` 中的详细原因/修复
- **焦点级联调试指南**——结构化日志模式、级联日志中需要注意的内容
- **VoiceOver 滚动动画守卫**——动画滚动前检查 `UIAccessibility.isVoiceOverRunning`
- **更新反模式 #1**——添加了关于 tvOS 上 `.allowsHitTesting(false)` 可靠性的注意事项
- **更新 SKILL.md 核心指令**——`defaultFocus` 重新进入限制、`ScrollPosition` 偏好
- 反模式总数：29（从 24 增加）

## [1.4.0] - 2026-04-10

### 新增
- **3 个来自生产环境的新 tvOS 反模式**（#15–17）——`LazyVStack` 焦点逃逸、垂直 `.focusSection()`、焦点回调中的对象分配
- **VStack + 内部 LazyHStack 模式**——轻量级外部容器保留在层次结构中，重内容在每行内部保持懒加载
- **标签栏焦点逃逸检测**——`didUpdateFocus` 模式用于检测焦点从内容逃逸到标签栏
- **VoiceOver 卡片组合模式**——`.accessibilityElement(children: .ignore)` 配合组合标签用于多元素可聚焦卡片
- 反模式总数：24（从 21 增加）

## [1.3.0] - 2026-04-10

### 新增
- **macOS 焦点覆盖**——新 `macos-focus.md` 参考文件（650+ 行）
  - AppKit：NSResponder 链、`acceptsFirstResponder`、`canBecomeKeyView`、键视图循环
  - 关键窗口 vs 主窗口、NSPanel 焦点行为、`becomesKeyOnlyIfNeeded`
  - 焦点环：`NSFocusRingType`、`drawFocusRingMask()`、自定义形状
  - macOS 上的 SwiftUI：`@FocusState`、`.focusable()`、`.focusSection()`、`.onKeyPress`
  - 菜单栏命令的 `focusedValue` / `focusedSceneValue`
  - NSToolbar、NSPopover、sheets、NSAlert 焦点
  - 多窗口、多屏幕、外接显示器
  - Mac Catalyst 桥接
  - 完全键盘访问
- **7 个 macOS 特定反模式**（#15–21）在 `anti-patterns.md` 中
- `focus-styling.md` 中的 macOS 焦点环样式
- `accessibility-focus.md` 中的 macOS VoiceOver、NSAccessibility、语音控制
- `debugging.md` 中的 macOS 第一响应者调试
- `layout-patterns.md` 中的 macOS 布局模式（侧边栏、工具栏、多窗口、检查器、三列）
- `focus-restoration.md` 中的 macOS 焦点恢复（sheets、NSDocument 恢复）

## [1.2.0] - 2026-04-08

### 新增
- **扩展 iOS 焦点覆盖**——游戏手柄焦点、Stage Manager 多窗口、`.onKeyPress`、指针悬停效果、`focusedValue` / `focusedSceneValue` 深入探讨
- **扩展 watchOS 焦点覆盖**——`.digitalCrownAccessory()`、嵌套滚动冲突、管理多个可聚焦控件
- 常见问题部分，包含 20 个可折叠问题（tvOS、iOS、iPadOS、watchOS、visionOS、macOS）
- 用于 AI 模型发现的 `llms.txt`
- 用于注册表索引的 SKILL.md 关键词元数据
- 社区健康文件：CONTRIBUTING.md、issue 模板、PR 模板

## [1.1.0] - 2026-04-07

### 新增
- **watchOS 焦点参考**——Digital Crown 路由、顺序焦点、`.focusable()` 顺序、Crown 冲突
- **RealityKit 焦点参考**——`HoverEffectComponent`、碰撞形状、着色器效果、混合 SwiftUI + RealityKit 层次结构
- **辅助功能焦点参考**——`@AccessibilityFocusState`、VoiceOver 协调、完全键盘访问、Switch Control、减弱动态效果

## [1.0.0] - 2026-04-06

### 新增
- 首次发布，包含 10 个参考文件，涵盖 tvOS、iOS/iPadOS 和 visionOS
- SwiftUI 和 UIKit 焦点管理
- 14 个关键反模式
- 焦点样式、恢复、布局模式、异步协调、调试
- 代理技能格式（SKILL.md）适用于 Claude Code、Codex、Cursor、Copilot、Gemini CLI
