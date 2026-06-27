# iOS/SwiftUI 资源处理

处理 Figma 资源用于 Xcode，不替换或近似设计师创作的视觉内容。

## 目录

- [核心规则：Figma 资源优先](#核心规则figma-资源优先)
- [1. 构建视觉资源清单](#1-构建视觉资源清单)
- [2. 选择策略](#2-选择策略)
- [3. 从 Figma 下载](#3-从-figma-下载)
- [4. 命名和去重](#4-命名和去重)
- [5. 将 PNG 图像添加到 Asset Catalog](#5-将-png-图像添加到-asset-catalog)
- [6. 选择渲染模式](#6-选择渲染模式)
- [7. 在 SwiftUI 中使用资源](#7-在-swiftui-中使用资源)
- [8. 最终自检](#8-最终自检)
- [资源规则摘要](#资源规则摘要)

## 核心规则：Figma 资源优先

每个可见的 Figma 拥有图标、Logo、插画、照片和装饰图形必须由真正的 Figma 渲染 PNG 导出表示，除非用户明确批准替换。

禁止的替换：
- 用 `Image(systemName:)` 替换 Figma 设计的图标
- `Text("G")`、`Text("f")` 或类似的假 Logo 文本
- `Rectangle`、`Circle` 或自定义 `Shape` 充当 Logo 或图标
- 插画或复杂图形的简化 SwiftUI 重绘
- 设计中可见资源的占位图像

允许的例外：
- 应保持系统提供的 iOS 系统组件：导航返回箭头、ShareLink/分享面板图标、原生标签栏符号、提醒、键盘、状态栏、主指示条
- 你展示 Figma 资源和提议的 SF Symbol 或平台无关替代方案后用户批准的替换
- 简单 UI 几何：卡片背景、分隔符、圆点、简单徽章、纯色/渐变背景
- 远程内容：用户头像、信息流图像或 CDN 照片——数据驱动而非打包的应用资源

跨平台注意事项：如果项目目标为多平台（Skip、KMP、共享设计系统或 Android 对等），不要默默使用 SF Symbols。展示每个图标及提议的替换，并询问用户批准 SF Symbols、自定义 Figma 导出或平台无关替代方案。

## 1. 构建视觉资源清单

从截图开始，而非类 JSX 代码。在实现之前列出每个可见的非文本元素。

使用此表：

| # | 用途 | 来源 | 节点 ID / URL | 策略 | 文件名 | 备注 |
|---|---|---|---|---|---|---|
| 1 | 关闭图标 | metadata | 3166:70211 | download | closeIcon | template |
| 2 | 主视觉插画 | screenshot | 3166:70200 | download | onboardingHero | original |
| 3 | 头像照片 | remote | 数据模型 | remote | n/a | 使用现有图像加载器 |
| 4 | 卡片背景 | code | n/a | code | n/a | 圆角矩形 + 渐变 |

交叉核对三个来源：
- 截图：可见内容的真实依据
- `get_design_context`：localhost 资源 URL、图像填充、矢量片段、`imageRef`、图层名
- `get_metadata`：`VECTOR`、`BOOLEAN_OPERATION`、`INSTANCE`、Logo、图标和插画画板的节点 ID

规则：
- 每个可见非文本元素一行
- 如果图标/Logo/插画可见但找不到节点 ID 或 URL，停止并询问用户
- 不要因为 SF Symbol 看起来相似就移除行
- 不要将 iOS 系统组件算作应用资源

## 2. 选择策略

### Download

从 Figma 导出为 PNG 并打包到 Asset Catalog。用于：
- 图标，包括 Figma 中绘制的常见箭头和关闭图标
- Logo、品牌标记、社交登录图标
- 插画、主视觉、空状态图形
- 作为已发布设计一部分的静态照片和图像填充
- 复杂矢量、遮罩、混合模式和装饰图形

### Code

仅在元素是真正的结构性 UI 时用 SwiftUI 绘制：
- 圆角卡片或按钮背景
- 分隔线
- 圆形/圆点指示器
- 简单徽章背景
- 纯色、渐变、材质、边框或阴影

不要仅仅因为图标几何简单就对图标使用 `code`。

### Remote

对数据驱动内容使用项目现有的图像加载模式：
- 用户头像
- 信息流/帖子照片
- 从 API 加载的产品图像
- 真实应用数据中的 CDN 图像

检查 Kingfisher、SDWebImage、Nuke、自定义图像缓存或现有包装器。如果没有项目模式，在选择 `AsyncImage` 之前询问。

### 扁平化 vs 分解

当区域是静态组合图形时扁平化为一个 PNG：
- 引导主视觉插画
- 空状态场景
- 带装饰、渐变和叠加视觉效果的横幅
- 带 3+ 重叠装饰层的图形

当元素独立交互、可复用、动态或有状态时分解：
- 工具栏图标按钮
- 标签栏
- 表单行
- 可复用卡片
- 图标网格

允许混合区域：扁平化装饰图形，然后在 `ZStack` 中叠加实时 SwiftUI 文本/按钮。

## 3. 从 Figma 下载

在活跃 MCP 会话期间下载，因为 localhost URL 是临时的。

优先顺序：
1. `get_screenshot(fileKey, nodeId)` 用于单独的图标/Logo/插画节点。这是默认方式，因为它返回 Figma 渲染的 PNG，无需 `FIGMA_TOKEN`
2. `get_design_context` 中的 localhost URL，存在时，仅当验证为 PNG 时
3. Figma REST images 端点，仅当 `FIGMA_TOKEN` 已可用且批量有用时。请求 `format=png&scale=3`

localhost 下载：

```bash
curl -o asset-name.png "http://localhost:PORT/path/to/asset"
file asset-name.png
```

按节点 MCP 导出：

```text
get_screenshot(fileKey=":fileKey", nodeId="3166:70211")
```

验证：
- `file asset.png` 必须报告 PNG image data
- 如果 `file` 报告 SVG、XML、ASCII text 或 PNG image data 以外的任何内容，视为资源导出失败，通过 `get_screenshot` 重新获取
- 不要将 SVG 作为可见 Figma 拥有资源的最终格式
- 绝不对保真度关键资源在本地将 SVG 转换为 PNG；使用 Figma 的渲染器

## 4. 命名和去重

遵循项目的命名约定。如果没有，使用小驼峰命名。

命名：
- 共享图标：`closeIcon`、`chevronRightIcon`、`searchIcon`
- 品牌/社交：`googleLogo`、`appleLogo`、`companyMark`
- 屏幕特定图形：`onboardingHeroArtwork`、`emptyStateIllustration`
- 避免空格、标点和原始 Figma 图层名，如 `Group 14`

去重：
- 添加新资源之前搜索 `Assets.xcassets`
- 同一源节点或相同品牌资源复用同一 Catalog 图像
- 一个资源可以在多个 SwiftUI frame 尺寸显示

## 5. 将 PNG 图像添加到 Asset Catalog

尽可能使用 3x 源，然后从 Figma 显示尺寸生成 2x 和 1x。

```bash
cp source.png assetName@3x.png
sips -z 48 48 source.png --out assetName@2x.png
sips -z 24 24 source.png --out assetName@1x.png
```

将 `48 48` 和 `24 24` 替换为资源的实际像素尺寸。目标尺寸必须匹配 Figma 显示尺寸乘以比例。例如：24pt 方形图标导出为 3x 时 72×72px、2x 时 48×48px、1x 时 24×24px。

PNG imageset：

```text
Assets.xcassets/
  assetName.imageset/
    assetName@1x.png
    assetName@2x.png
    assetName@3x.png
    Contents.json
```

`Contents.json`：

```json
{
  "images": [
    { "filename": "assetName@1x.png", "idiom": "universal", "scale": "1x" },
    { "filename": "assetName@2x.png", "idiom": "universal", "scale": "2x" },
    { "filename": "assetName@3x.png", "idiom": "universal", "scale": "3x" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

## 6. 选择渲染模式

当资源是应随 SwiftUI 着色的单色 UI 图标时使用 `template`。

模板图标：

```swift
Image("closeIcon")
    .resizable()
    .renderingMode(.template)
    .foregroundStyle(Color.primary)
    .frame(width: 24, height: 24)
```

Logo、多色图标、照片和插画使用 `original`。

原始图像：

```swift
Image("googleLogo")
    .resizable()
    .renderingMode(.original)
    .frame(width: 24, height: 24)
```

当项目偏好 Catalog 级渲染时在 `Contents.json` 中设置模板渲染：

```json
{
  "properties": {
    "template-rendering-intent": "template"
  }
}
```

## 7. 在 SwiftUI 中使用资源

下载的图像通常应明确尺寸。

图标：

```swift
Image("searchIcon")
    .resizable()
    .renderingMode(.template)
    .foregroundStyle(Color.secondary)
    .frame(width: 20, height: 20)
```

插画：

```swift
Image("onboardingHeroArtwork")
    .resizable()
    .scaledToFit()
    .frame(maxWidth: .infinity)
```

照片：

```swift
Image("profilePlaceholder")
    .resizable()
    .scaledToFill()
    .frame(width: 64, height: 64)
    .clipShape(Circle())
```

规则：
- 设置自定义 frame 时使用 `.resizable()`
- 图标用 `.frame(width:height:)` 匹配 Figma 显示尺寸
- 必须保持不裁剪的完整图形使用 `.scaledToFit()`
- 当 Figma 裁剪图像时使用 `.scaledToFill()` 加 `.clipped()` 或 `.clipShape()`
- 模板图标配对 `.foregroundStyle(...)`

## 8. 最终自检

完成实现之前：

```bash
rg 'Image\(systemName:|Text\("G"\)|Text\("f"\)|Rectangle\(\)|Circle\(\)|Shape' <generated-swift-files>
```

对每个命中：
- 仅当是系统组件、结构性 UI 几何或批准的替换时保留
- 用 Asset Catalog 图像替换 Figma 设计的图标/Logo/插画
- 确认每个视觉清单行在代码、Asset Catalog 或远程图像管道中都有表示

## 资源规则摘要

1. Figma 资源优先；SF Symbols 仅在例外时使用
2. 在 SwiftUI 实现之前构建视觉清单
3. 从 Figma 下载图标、Logo、插画和静态图像填充
4. 仅对结构性 UI 几何、渐变、材质和简单背景使用代码
5. 仅对数据驱动的内容图像使用远程加载
6. 将资源添加到 Xcode 之前验证文件格式
7. 匹配比例变体、渲染模式和项目命名约定
