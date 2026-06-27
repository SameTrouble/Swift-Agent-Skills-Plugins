# RealityKit 焦点和悬停（visionOS）

RealityKit 实体使用与 SwiftUI 视图分离的悬停/交互系统。让 3D 内容响应注视需要显式组件设置。

## 实体交互要求

每个交互式 RealityKit 实体需要**三个组件**：

```swift
let entity = ModelEntity(
    mesh: .generateBox(size: 0.3),
    materials: [SimpleMaterial(color: .blue, isMetallic: true)]
)

entity.components.set(InputTargetComponent())           // 接收输入事件
entity.components.set(CollisionComponent(               // 注视射线的命中测试
    shapes: [ShapeResource.generateBox(size: [0.3, 0.3, 0.3])]
))
entity.components.set(HoverEffectComponent())           // 视觉注视反馈
```

缺少任何一个 = 实体对注视交互不可见。

### 常见设置错误

**碰撞形状不匹配：** 碰撞形状必须近似视觉网格。大模型上的小碰撞形状意味着注视只在小区域注册。

```swift
// 错误——盒模型上的碰撞球
entity.components.set(CollisionComponent(
    shapes: [ShapeResource.generateSphere(radius: 0.05)]  // 太小
))

// 正确——碰撞匹配视觉几何
entity.components.set(CollisionComponent(
    shapes: [ShapeResource.generateBox(size: [0.3, 0.3, 0.3])]
))
```

**忘记子实体上的 InputTargetComponent：** 在实体层次结构中，接收手势的实体需要 `InputTargetComponent`。如果只有父级有，手势可能无法正确路由到子级。

**实体未添加到场景：** 不属于 `RealityView` 内容层次结构的实体上的组件什么也不做。

## HoverEffectComponent 样式

### 默认（visionOS 1.0+）

```swift
entity.components.set(HoverEffectComponent())  // 系统默认高亮
```

### 聚光灯效果（visionOS 2.0+）

```swift
entity.components.set(HoverEffectComponent(
    .spotlight(SpotlightHoverEffectStyle(
        color: .white,
        strength: 1.0
    ))
))
```

### 着色器效果（visionOS 2.0+）

对于自定义着色器驱动的悬停，在 `ShaderGraphMaterial` 中使用 `HoverState`：

```swift
// 在 Reality Composer Pro 中：
// 1. 向着色器图添加 HoverState 节点
// 2. 将 HoverState.isActive 输出连接到材质属性
// 3. 使用 HoverState.position 实现局部效果（光晕跟随注视点）

let material = try await ShaderGraphMaterial(
    named: "/Root/HoverGlowMaterial",
    from: "Scene.usda"
)
entity.model?.materials = [material]
entity.components.set(HoverEffectComponent(.shader(.default)))
```

`HoverState` 提供：
- `isActive`（Bool）——注视是否在实体上
- `position`（float2）——实体表面注视点的 UV 坐标

### 高亮效果（visionOS 2.0+）

```swift
entity.components.set(HoverEffectComponent(
    .highlight(HighlightHoverEffectStyle(
        color: .systemBlue,
        strength: 0.8
    ))
))
```

## 实体上的手势处理

### 轻点手势

```swift
RealityView { content in
    content.add(entity)
}
.gesture(
    SpatialTapGesture()
        .targetedToEntity(entity)
        .onEnded { value in
            // value.entity 是被轻点的实体
            // value.location3D 是场景坐标中的轻点位置
        }
)
```

### 拖拽手势

```swift
.gesture(
    DragGesture()
        .targetedToEntity(entity)
        .onChanged { value in
            entity.position = value.convert(value.location3D, from: .local, to: entity.parent!)
        }
)
```

### 长按

```swift
.gesture(
    LongPressGesture()
        .targetedToEntity(entity)
        .onEnded { _ in
            // 实体上长按完成
        }
)
```

### 手势与悬停冲突

拖拽手势在拖拽期间抑制悬停效果。这是预期行为。悬停高亮在用户捏合并开始拖拽时消失，释放时重新出现。

## 混合 SwiftUI + RealityKit 层次结构

### 附件（3D 空间中的 SwiftUI 视图）

```swift
RealityView { content, attachments in
    if let panel = attachments.entity(for: "infoPanel") {
        panel.position = [0, 0.5, 0]
        content.add(panel)
    }
} attachments: {
    Attachment(id: "infoPanel") {
        VStack {
            Text("Item Details")
            Button("Select") { }  // 自动获得 SwiftUI 悬停效果
        }
        .padding()
        .glassBackgroundEffect()
    }
}
```

SwiftUI 附件使用 SwiftUI 悬停系统（`.hoverEffect()`），而非 `HoverEffectComponent`。它们是两个独立系统。

### 焦点协调

- SwiftUI `@FocusState` 控制 SwiftUI 附件的键盘焦点
- RealityKit 实体不参与 `@FocusState` / `UIFocusEnvironment`
- 注视悬停在两者上独立工作：SwiftUI 视图通过 `.hoverEffect()`，实体通过 `HoverEffectComponent`
- 没有以编程方式移动注视悬停的 API（隐私设计）

## 立体空间 vs 沉浸空间

### 立体空间

- 固定缩放（不随距离调整大小）
- 实体需要所有三个组件才能交互
- SwiftUI 覆盖层使用标准 `.hoverEffect()`
- 有界——内容被裁剪到立体空间边界

```swift
WindowGroup(id: "modelViewer") {
    RealityView { content in
        let model = try! await ModelEntity(named: "Trophy")
        model.components.set(InputTargetComponent())
        model.components.set(CollisionComponent(shapes: [.generateConvex(from: model.model!.mesh)]))
        model.components.set(HoverEffectComponent())
        content.add(model)
    }
}
.windowStyle(.volumetric)
```

### 沉浸空间

- 无系统窗口边框——所有反馈必须显式
- 实体交互的相同组件要求
- 手部跟踪可用于直接触摸（无需注视）
- 空间音频可提供悬停反馈提示

```swift
ImmersiveSpace(id: "gallery") {
    RealityView { content in
        // 沉浸空间中的实体
        // 仍必须有 InputTargetComponent + CollisionComponent + HoverEffectComponent
    }
}
```

## 碰撞形状生成

### 从网格（最准确）

```swift
let shape = try await ShapeResource.generateConvex(from: entity.model!.mesh)
entity.components.set(CollisionComponent(shapes: [shape]))
```

对复杂网格开销大。用于最终生产实体。

### 基本体（最佳性能）

```swift
// 盒
ShapeResource.generateBox(size: [width, height, depth])

// 球
ShapeResource.generateSphere(radius: r)

// 胶囊
ShapeResource.generateCapsule(height: h, radius: r)
```

对有多个实体的性能关键场景使用基本体。

### 复合形状

```swift
let head = ShapeResource.generateSphere(radius: 0.1)
    .offsetBy(translation: [0, 0.3, 0])
let body = ShapeResource.generateBox(size: [0.2, 0.4, 0.2])

entity.components.set(CollisionComponent(shapes: [head, body]))
```

## 性能注意事项

- **碰撞复杂度：** 凸包生成是异步且昂贵的。为已知模型预生成。
- **实体数量：** 每个带 `HoverEffectComponent` 的实体由系统合成器评估。数百个悬停启用实体可能影响帧率。
- **着色器效果：** 自定义 `ShaderGraphMaterial` 悬停效果在 GPU 上运行，但增加加载时的着色器编译开销。
- **InputTargetComponent 作用域：** 仅添加到需要交互的实体。每个 `InputTargetComponent` 增加每帧输入评估成本。

## 常见错误

### 1. 碰撞形状不匹配视觉边界
注视看起来错过实体，因为碰撞形状太小或偏离视觉网格。

### 2. 向非叶子实体添加 HoverEffectComponent
在层次结构中，向用户应定位的特定子实体添加悬停效果，而非父组实体。否则整个组作为一个高亮。

### 3. 忘记 .generateConvex 是异步的
`ShapeResource.generateConvex(from:)` 是异步的。同步调用或忘记 await 会导致崩溃或缺少碰撞形状。

### 4. 未在设备上用眼睛追踪测试
visionOS 模拟器支持基于点击的交互，非实际注视。悬停时序、注视精度和眼睛疲劳效果只在真实硬件上出现。

### 5. 将 SwiftUI .hoverEffect() 应用于 RealityView
`RealityView` 容器上的 `.hoverEffect()` 会在注视时高亮整个视图，而非单个实体。改为在每个实体上使用 `HoverEffectComponent`。

### 6. 透明材质阻挡注视
带透明材质的实体如果有 `CollisionComponent` 仍会阻挡注视射线。用户无法透过透明实体注视后面的实体，除非前面的实体没有碰撞。
