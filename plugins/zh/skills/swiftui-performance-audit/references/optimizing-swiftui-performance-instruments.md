# 使用 Instruments 优化 SwiftUI 性能（摘要）

背景：WWDC 讲座，介绍 Instruments 26 中的下一代 SwiftUI Instrument 以及如何诊断 SwiftUI 特有的瓶颈。

## 关键要点

- 使用 SwiftUI 模板分析 SwiftUI 问题（SwiftUI instrument + Time Profiler + Hangs/Hitches）。
- 长视图体更新是常见瓶颈；使用"Long View Body Updates"识别慢速 body。
- 在长更新上设置检查范围，并与 Time Profiler 关联以找到昂贵帧。
- 将工作移出 `body`：将格式化、排序、图片解码和其他昂贵工作移入缓存或预计算路径。
- 使用 Cause & Effect Graph 诊断更新*为什么*发生；SwiftUI 是声明式的，因此回溯通常帮助不大。
- 避免触发大量更新的广泛依赖（如 `@Observable` 数组或全局环境读取）。
- 优先使用细粒度的视图模型和限定作用域的状态，使只有受影响的视图更新。
- 环境值更新检查仍有耗时；避免将快速变化的值（计时器、几何信息）放入环境。
- 在功能开发期间尽早且频繁地分析，以捕获回归。

## 建议工作流程（精简版）

1. 在 Release 模式下使用 SwiftUI 模板录制 trace。
2. 检查"Long View Body Updates"和"Other Long Updates"。
3. 放大某个长更新，然后检查 Time Profiler 中的热点帧。
4. 通过将重度逻辑移入预计算/缓存路径来修复慢速 body 工作。
5. 使用 Cause & Effect Graph 识别意外的更新扇出。
6. 重新录制并比较更新次数和掉帧频率。

## 讲座中的示例模式

- 在位置管理器中缓存已格式化的距离字符串，而不是在 `body` 中计算。
- 用逐项视图模型替换对全局收藏数组的依赖，以减少更新扇出。
