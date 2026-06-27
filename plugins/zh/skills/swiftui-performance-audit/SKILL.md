---
name: swiftui-performance-audit
description: 从代码审查和架构层面审查并改进 SwiftUI 运行时性能。用于诊断 SwiftUI 应用中的慢渲染、滚动卡顿、CPU/内存占用过高、视图更新过多或布局抖动等问题，并在仅靠代码审查无法定位问题时，指导用户使用 Instruments 进行性能分析。
---

# SwiftUI 性能审查

## 快速开始

使用此技能优先从代码层面诊断 SwiftUI 性能问题，当代码审查无法解释症状时，再要求提供性能分析证据。

## 工作流程

1. 对症状进行分类：慢渲染、滚动卡顿、CPU 占用高、内存增长、卡死，或视图更新过多。
2. 如果有代码可读，优先使用 `references/code-smells.md` 进行代码优先审查。
3. 如果没有代码，要求提供最小可用切片：目标视图、数据流、复现步骤和部署目标。
4. 如果代码审查无法得出结论或需要运行时证据，通过 `references/profiling-intake.md` 指导用户进行性能分析。
5. 使用 `references/report-template.md` 总结可能的原因、证据、修复方案和验证步骤。

## 1. 信息收集

收集以下信息：
- 目标视图或功能代码。
- 症状和精确的复现步骤。
- 数据流：`@State`、`@Binding`、环境依赖和可观察模型。
- 问题出现在真机还是模拟器，以及是在 Debug 还是 Release 配置下观察到的。

如果可能，请用户对问题进行分类：
- CPU 飙升或耗电过快
- 滚动卡顿或掉帧
- 内存或图片压力过高
- 卡死或交互无响应
- 视图更新过多或范围异常扩大

完整的性能分析收集清单请阅读 `references/profiling-intake.md`。

## 2. 代码优先审查

重点关注：
- 由广泛观察或环境读取引发的失效风暴。
- 列表和 `ForEach` 中的标识不稳定。
- `body` 或视图构建器中的重度派生计算。
- 由复杂层级、`GeometryReader` 或偏好链引发的布局抖动。
- 主线程上的大图解码或缩放。
- 动画或转场范围应用过大。

详细的代码异味目录和修复指导请使用 `references/code-smells.md`。

提供：
- 带代码引用的可能根因。
- 建议的修复和重构方案。
- 如有需要，提供最小复现或插桩建议。

## 3. 指导用户进行性能分析

如果代码审查无法解释问题，要求提供运行时证据：
- SwiftUI 时间线和 Time Profiler 调用树的 trace 导出或截图。
- 设备/系统/构建配置。
- 正在分析的确切交互。
- 如果用户在比较变更，提供变更前后的指标。

精确的清单和收集步骤请使用 `references/profiling-intake.md`。

## 4. 分析与诊断

- 将证据映射到最可能的类别：失效、标识抖动、布局抖动、主线程工作、图片开销或动画开销。
- 按影响程度排序问题，而不是按解释难易度排序。
- 区分代码层面的怀疑和有 trace 支撑的证据。
- 指出当前分析仍不充分的情况，以及哪些额外证据可以降低不确定性。

## 5. 修复

应用针对性修复：
- 收窄状态作用域，减少广泛的观察扇出。
- 为 `ForEach` 和列表稳定标识。
- 将重度工作移出 `body`，改为由输入更新的派生状态、模型层预计算、记忆化辅助方法或后台预处理。`@State` 仅用于视图自有状态，不要用作任意计算的临时缓存。
- 仅当相等性比较比重新计算子树更廉价、且输入真正具备值语义时才使用 `equatable()`。
- 渲染前对图片进行降采样。
- 降低布局复杂度或尽可能使用固定尺寸。

示例、Observation 特有的扇出指导和修复模式请使用 `references/code-smells.md`。

## 6. 验证

请用户重新运行相同的捕获并与基线指标对比。
如果提供了数据，总结差异（CPU、掉帧、内存峰值）。

## 输出

提供：
- 简短的指标表格（如有变更前后数据）。
- 主要问题（按影响排序）。
- 提出的修复及预估工作量。

格式化最终审查报告时请使用 `references/report-template.md`。

## 参考资料

- 性能分析收集清单：`references/profiling-intake.md`
- 常见代码异味和修复模式：`references/code-smells.md`
- 审查输出模板：`references/report-template.md`
- 随着用户提供，在 `references/` 下补充 Apple 文档和 WWDC 资源。
- 使用 Instruments 优化 SwiftUI 性能：`references/optimizing-swiftui-performance-instruments.md`
- 理解和改进 SwiftUI 性能：`references/understanding-improving-swiftui-performance.md`
- 理解应用中的卡死：`references/understanding-hangs-in-your-app.md`
- 揭秘 SwiftUI 性能（WWDC23）：`references/demystify-swiftui-performance-wwdc23.md`
