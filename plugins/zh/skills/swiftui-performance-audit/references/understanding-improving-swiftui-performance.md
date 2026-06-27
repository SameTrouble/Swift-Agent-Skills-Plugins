# 理解和改进 SwiftUI 性能（摘要）

背景：Apple 关于使用 Instruments 诊断 SwiftUI 性能并应用设计模式来减少长或频繁更新的指导。

## 核心概念

- SwiftUI 是声明式的；视图更新由状态、环境和可观察数据依赖驱动。
- 视图体必须快速计算以满足帧截止时间；慢或频繁的更新会导致掉帧。
- Instruments 是查找长时间运行更新和过多更新频率的主要工具。

## Instruments 工作流程

1. 通过 Product > Profile 进行分析。
2. 选择 SwiftUI 模板并录制。
3. 执行目标交互。
4. 停止录制并检查 SwiftUI 轨道 + Time Profiler。

## SwiftUI 时间线泳道

- Update Groups：SwiftUI 计算更新所花时间的概览。
- Long View Body Updates：橙色 >500 微秒，红色 >1000 微秒。
- Long Platform View Updates：SwiftUI 中的 AppKit/UIKit 托管。
- Other Long Updates：几何/文本/布局和其他 SwiftUI 工作。
- Hitches：UI 未及时就绪导致的丢帧。

## 诊断长视图体更新

- 展开 SwiftUI 轨道；检查模块特定的子轨道。
- 设置检查范围并与 Time Profiler 关联。
- 使用调用树或火焰图识别昂贵帧。
- 重复更新以收集足够的样本进行分析。
- 过滤到特定更新（Show Calls Made by `MySwiftUIView.body`）。

## 诊断频繁更新

- 使用 Update Groups 查找没有长更新但长时间活跃的组。
- 在组上设置检查范围并分析更新次数。
- 使用 Cause 图（"Show Causes"）查看触发更新的原因。
- 将原因与预期数据流对比；优先处理频率最高的原因。

## 修复模式

- 将昂贵工作移出 `body` 并缓存结果。
- 使用 `Observable()` 宏将依赖限定到实际读取的属性。
- 避免将更新扇出到许多视图的广泛依赖。
- 减少布局抖动；将依赖状态的子树与布局读取器隔离。
- 避免存储捕获父状态的闭包；预计算子视图。
- 通过阈值门控频繁更新（如几何变化）。

## 验证

- 变更后重新录制，确认更新次数减少且掉帧减少。
