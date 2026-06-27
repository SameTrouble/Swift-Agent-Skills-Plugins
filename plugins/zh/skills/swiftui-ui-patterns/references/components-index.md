# 组件索引

用此文件查找组件和横切指引。每个条目列出何时使用。

## 可用组件

- TabView：`references/tabview.md` — 在构建基于标签页的应用或任何标签化功能集时使用。
- NavigationStack：`references/navigationstack.md` — 在需要 push 导航和编程式路由，尤其是各标签页独立历史时使用。
- Sheets 与展示：`references/sheets.md` — 用于局部 item 驱动的 sheets、集中式模态路由和 sheet 特定的操作模式。
- Form 与设置：`references/form.md` — 用于设置、分组输入和结构化数据录入。
- macOS 设置：`references/macos-settings.md` — 在使用 SwiftUI 的 Settings 场景构建 macOS 设置窗口时使用。
- 分栏视图与列：`references/split-views.md` — 用于 iPad/macOS 多列布局或自定义次级列。
- List 与 Section：`references/list.md` — 用于信息流式内容和设置行。
- ScrollView 与 Lazy 栈：`references/scrollview.md` — 用于自定义布局、横向滚动器或网格。
- 滚动露出详情面：`references/scroll-reveal.md` — 当详情屏幕在用户滚动或在全屏区块间滑动时露出次要内容或操作时使用。
- 网格：`references/grids.md` — 用于图标选择器、媒体图库和平铺布局。
- 主题与动态字号：`references/theming.md` — 用于应用级主题 token、颜色和字号缩放。
- 控件（Toggle、Picker、Slider）：`references/controls.md` — 用于设置控件和输入选择。
- 输入工具栏（底部锚定）：`references/input-toolbar.md` — 用于带固定输入栏的聊天/撰写器屏幕。
- 顶部栏覆盖（iOS 26+ 及回退）：`references/top-bar.md` — 用于滚动内容上方的固定选择器或胶囊。
- 覆盖层与 toasts：`references/overlay.md` — 用于横幅或 toasts 等瞬态 UI。
- 焦点处理：`references/focus.md` — 用于字段链式和键盘焦点管理。
- Searchable：`references/searchable.md` — 用于带作用域和异步结果的原生搜索 UI。
- 异步图片与媒体：`references/media.md` — 用于远程媒体、预览和媒体查看器。
- 触感反馈：`references/haptics.md` — 用于与关键操作绑定的触觉反馈。
- 匹配转场：`references/matched-transitions.md` — 用于从源到目标的平滑动画。
- 深度链接与 URL 路由：`references/deeplinks.md` — 用于从 URL 进行应用内导航。
- 标题菜单：`references/title-menus.md` — 用于导航标题中的筛选或上下文菜单。
- 菜单栏命令：`references/menu-bar.md` — 在添加或自定义 macOS/iPadOS 菜单栏命令时使用。
- 加载与占位符：`references/loading-placeholders.md` — 用于遮罩骨架、空状态和加载 UX。
- 轻量客户端：`references/lightweight-clients.md` — 用于注入到 store 中的小型、基于闭包的 API 客户端。

## 横切参考

- 应用连接与依赖图：`references/app-wiring.md` — 用于连接应用外壳、安装共享依赖以及决定什么该放进环境。
- 异步状态与任务生命周期：`references/async-state.md` — 当视图加载数据、响应变化输入或需要取消/防抖指引时使用。
- 预览：`references/previews.md` — 在添加 `#Preview`、测试夹具、mock 环境或隔离预览设置时使用。
- 性能护栏：`references/performance.md` — 当屏幕大、滚动密集、频繁更新或出现可避免的重新渲染迹象时使用。

## 计划中的组件（按需创建文件）

- Web 内容：创建 `references/webview.md` — 用于内嵌 Web 内容或应用内浏览。
- 状态撰写器模式：创建 `references/composer.md` — 用于撰写或编辑器工作流。
- 文本输入与校验：创建 `references/text-input.md` — 用于表单、校验和重度文本输入。
- 设计系统使用：创建 `references/design-system.md` — 在应用共享样式规则时使用。

## 添加条目

- 添加组件文件并在此处附带简短的"何时使用"描述进行链接。
- 保持每个组件参考简短且可操作。
