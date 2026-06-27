# visionOS 焦点和悬停管理

visionOS 使用眼睛追踪（注视）作为主要定位机制。焦点和悬停是**相关但独立的系统**。

## 核心概念：注视 vs 焦点 vs 悬停

- **注视 = 悬停定位**：看着元素触发*悬停效果*。你的应用**从不接收原始注视坐标**（隐私设计）。
- **焦点 = 键盘/顺序导航**：传统 `@FocusState` / `UIFocusEnvironment` 用于键盘、VoiceOver 或 Switch Control——非注视。
- **悬停效果在进程外运行**：系统在你的应用沙盒外合成悬停高亮。你的应用仅在用户捏合（确认）时知道*哪个*元素被定位。

### 交互模型
1. 用户**看着**元素（系统渲染悬停高亮）
2. 用户**捏合**手指（间接轻点手势）
3. 应用在目标元素上接收轻点事件

替代：直接触摸——在立体空间/沉浸空间中伸出手触摸。

### 关键隐私规则
`onHover(perform:)` 在 visionOS 上**不会**从眼睛注视触发。它仅从指针设备（通过 Mac 虚拟显示器的触控板/鼠标）触发。这是最常见的 visionOS 错误。

## 悬停效果 API（SwiftUI）

### 内置效果（visionOS 1.0+）

```swift
.hoverEffect(.automatic)  // 系统选择最佳效果（默认）
.hoverEffect(.highlight)  // 在视图后面变形托盘，显示光源
.hoverEffect(.lift)       // 滑入视图下方，缩放并加阴影
```

系统控件（Button、Toggle 等）自动获得悬停效果。带 `.onTapGesture` 的自定义视图不会——你必须显式添加 `.hoverEffect()`。

### 自定义悬停效果（visionOS 2.0+）

```swift
.hoverEffect { effect, isActive, proxy in
    effect.animation(.easeInOut) {
        $0.scaleEffect(isActive ? 1.05 : 1.0)
           .opacity(isActive ? 1.0 : 0.8)
    }
}
```

自定义效果在**视图创建时预计算**，由系统合成器执行。无注视数据泄露到你的应用。

### HoverEffectGroup（visionOS 2.0+）

协调多个悬停效果一起激活：

```swift
@Namespace var hoverGroup

HStack {
    Image(systemName: "star")
        .hoverEffect(in: HoverEffectGroup(hoverGroup))
    Text("Favorite")
        .hoverEffect(in: HoverEffectGroup(hoverGroup))
}
```

看着组中*任何*视图会同时激活所有视图的效果。

### .contentShape(.hoverEffect, shape)

自定义悬停高亮区域而不影响轻点目标：

```swift
Text("Custom Region")
    .padding()
    .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10))
    .hoverEffect()
```

### .hoverEffectDisabled()

禁用视图及其后代的悬停效果：

```swift
Button("No hover") { }
    .hoverEffectDisabled(true)
```

### .defaultHoverEffect()（visionOS 2.0+）

为子树设置默认悬停效果。子项继承除非覆盖。

## RealityKit 实体悬停

### HoverEffectComponent（visionOS 1.0+）

用于 RealityView 中的 3D 实体：

```swift
RealityView { content in
    let entity = ModelEntity(
        mesh: .generateSphere(radius: 0.2),
        materials: [SimpleMaterial(color: .blue, isMetallic: true)]
    )
    
    // 交互实体的三个要求：
    entity.components.set(InputTargetComponent())       // 1. 输入接收器
    entity.components.set(CollisionComponent(           // 2. 命中测试形状
        shapes: [ShapeResource.generateSphere(radius: 0.2)]
    ))
    entity.components.set(HoverEffectComponent())       // 3. 注视高亮
    
    content.add(entity)
}
```

缺少 `CollisionComponent` = 悬停从不激活（注视射线无物可命中）。

visionOS 2.0+：在 `ShaderGraphMaterial` 中使用 `HoverState` 实现 3D 内容的着色器驱动悬停效果。

## visionOS 上的 @FocusState

与其他平台相同工作方式——主要用于**键盘焦点**（连接 Magic Keyboard）和辅助功能：

```swift
@FocusState private var isSearchFocused: Bool

TextField("Search", text: $query)
    .focused($isSearchFocused)
```

在 visionOS 上何时使用：
- 连接外部 Magic Keyboard
- VoiceOver 或 Switch Control 活跃
- 文本字段的程序化焦点

### .focusEffectDisabled() vs .hoverEffectDisabled()

这些是**不同的东西**：
- `.focusEffectDisabled()`——隐藏键盘焦点环（蓝色轮廓）
- `.hoverEffectDisabled()`——禁用注视悬停高亮

## 窗口焦点 vs 内容焦点

### 共享空间

多个应用窗口共存。注视激活正在看的窗口。窗口边框（标题栏、关闭按钮）自动获得系统悬停效果。

### 装饰

附加到窗口边缘的类工具栏控件。参与相同的悬停系统：

```swift
.ornament(attachmentAnchor: .scene(.bottom)) {
    HStack {
        Button("Play") { }
        Button("Pause") { }
    }
    .glassBackgroundEffect()  // 必须——装饰不会自动获得玻璃效果
}
```

### 立体空间
- 固定缩放（不像窗口那样随距离缩放）
- 3D 内容：RealityKit 实体上的 `HoverEffectComponent`
- SwiftUI 覆盖层：标准 `.hoverEffect()`
- 默认无窗口栏

### 沉浸空间
- 一次一个；其他应用隐藏
- 所有交互通过注视 + 捏合或直接触摸
- 无系统窗口边框——所有焦点/悬停反馈必须显式添加
- `RealityView` 中的 SwiftUI 附件支持 `.hoverEffect()`

## Vision Pro 上的外部键盘

当连接 Magic Keyboard 时：
- Tab/方向键导航激活
- `@FocusState` 和 `.focused()` 控制键盘输入目标
- 键盘焦点环（蓝色）与注视悬停高亮并排出现
- 两个系统共存——不同元素可以同时显示悬停高亮和键盘焦点

## 辅助功能

### VoiceOver
- 不同手上的不同手指捏合用于导航
- 辅助功能标签和特征在 SwiftUI 视图和 RealityKit 实体上都至关重要

### 指针控制
替代眼睛的定位方式：
- 头部位置、手腕位置、食指指向
- 设置 > 辅助功能 > 交互 > 指针控制

### 注视控制
通过注视控件设定时长来交互（无需捏合）：
- 设置 > 辅助功能 > 辅助触控 > 注视控制

### Switch Control
与外部开关配合使用。RealityKit 实体需要辅助功能属性。

## visionOS 上的 UIKit 焦点引擎

`UIFocusEnvironment`、`UIFocusSystem`、`UIFocusGuide` 在 visionOS 上**确实有效**：
- 通过键盘导航、VoiceOver 或 Switch Control 激活
- 标准注视交互绕过焦点引擎（改用悬停系统）
- 支持跨框架焦点（UIKit + SpriteKit + SceneKit）

## 常见错误

### 1. 期望 onHover 从注视触发
`onHover(perform:)` 仅从指针设备（触控板/鼠标）触发。使用 `.hoverEffect()` 获取注视反馈。

### 2. 忘记 RealityKit 实体上的 CollisionComponent
`HoverEffectComponent` 单独使用没有碰撞形状进行射线投射则什么也不做。

### 3. 不向自定义视图添加 .hoverEffect()
系统控件自动获得，但带 `.onTapGesture` 的自定义 `View` 需要显式 `.hoverEffect()`，否则看起来不可交互。

### 4. 混淆 .focusEffectDisabled() 和 .hoverEffectDisabled()
它们禁用不同的东西（键盘焦点环 vs 注视悬停高亮）。

### 5. 使悬停效果过于突出
眼睛快速移动——分散注意力的动画造成视觉噪音。使用适当延迟的微妙效果。

### 6. 仅在模拟器中测试
悬停效果响应实际眼睛注视，模拟器无法复制。始终在设备上测试。

### 7. 忘记装饰上的 .glassBackgroundEffect()
自定义装饰不会自动获得玻璃材质。

## WWDC 会议

| 会议 | 年份 | 关键内容 |
|---------|------|-------------|
| 为空间输入设计 | WWDC23 | 眼 + 手交互、悬停设计、隐私 |
| 为空间计算提升窗口应用 | WWDC23 | 悬停效果、材质、装饰 |
| 遇见 SwiftUI for 空间计算 | WWDC23 | 窗口、立体空间、hoverEffect |
| 创建无障碍空间体验 | WWDC23 | VoiceOver、Switch Control、指针控制 |
| 在 visionOS 中创建自定义悬停效果 | WWDC24 | CustomHoverEffect、HoverEffectGroup |
| 为 visionOS 设计悬停交互 | WWDC25 | 高级悬停、持久性、媒体控制 |
