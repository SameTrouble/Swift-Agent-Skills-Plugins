# 架构选择指南

当用户请求架构推荐时使用本参考。

## 决策矩阵

| 因素 | MVVM | MVI | TCA | Clean | VIPER | Reactive | MVP | Coordinator |
|--------|------|-----|-----|-------|-------|----------|-----|-------------|
| 状态复杂度 | 低–中 | 高 | 高 | 中–高 | 中 | 中 | 低–中 | N/A（导航层） |
| 单向数据流 | 可选 | 严格 | 严格 | N/A | N/A | 基于流 | 可选 | N/A |
| 组合 / 模块化 | 功能级 | 功能级 | 强（Scope/forEach） | 层级 | 模块级 | 操作符级 | 功能级 | 流级 |
| 测试确定性 | 良好 | 很高 | 很高（TestStore） | 良好 | 良好 | 良好（需调度器） | 良好 | 良好 |
| 样板代码 | 低 | 中 | 中–高 | 中–高 | 高 | 低–中 | 中 | 低–中 |
| SwiftUI 适配 | 优秀 | 良好 | 优秀 | 良好 | 一般（UIKit 原生） | 良好 | 一般 | 良好 |
| UIKit 适配 | 良好 | 良好 | 良好 | 良好 | 优秀 | 良好 | 优秀 | 优秀 |
| 团队学习曲线 | 低 | 中 | 高 | 中 | 中–高 | 中 | 低 | 低 |
| 异步/副作用编排 | 手动 | 结构化 | 内建 | 手动 | 手动 | 操作符驱动 | 手动 | N/A |
| 框架依赖 | 无 | 无 | swift-composable-architecture | 无 | 无 | Combine 或 RxSwift | 无 | 无 |

## 各架构的 UI 技术栈差异

- **MVVM**：SwiftUI 倾向直接状态绑定；UIKit/混合倾向 coordinator 驱动的导航。
- **MVI**：SwiftUI 使用绑定 store 的视图；UIKit 将事件映射为 intent，并从 store 状态渲染。
- **TCA**：SwiftUI 在视图中使用 `StoreOf`；UIKit 通过 `ViewStore` 驱动控制器的渲染循环。
- **Clean Architecture**：Domain/data 层保持一致；仅表现层适配器不同。
- **VIPER**：UIKit 原生适配；SwiftUI 通常使用适配器加 `UIHostingController`。
- **Reactive**：SwiftUI 将管道放在 observable 模型中；UIKit 放在 Presenter/ViewModel 中。
- **MVP**：UIKit 原生适配；Presenter 通过协议命令驱动被动视图；SwiftUI 使用 observable 适配器。
- **Coordinator**：两种技术栈都适用；UIKit 使用 `UINavigationController` 封装；SwiftUI 将导航建模为绑定到 `NavigationStack` 的值类型状态。

## 快速决策流程

```text
1. 该功能是否流密集（搜索、实时推送、实时更新）？
   是 -> 考虑 Reactive（references/reactive.md）。若同时需要严格的 reducer/状态机流程，继续第 2 步，通常会组合使用模式。
   否 -> 继续

2. 是否需要严格的单向数据流和状态机建模？
   是 -> 应用是否已基于 TCA，或可接受引入 TCA 依赖？
        是 -> TCA（references/tca.md）
        否 -> MVI（references/mvi.md）
   否 -> 继续

3. 代码库是否需要严格的层隔离与可替换的基础设施？
   是 -> Clean Architecture（references/clean-architecture.md）
   否 -> 继续

4. 是否是大型 UIKit 代码库，需要严格的按功能分离？
   是 -> VIPER（references/viper.md）
   否 -> 继续

5. 主要目标是否是将导航与屏幕解耦（深度链接、可复用流程）？
   是 -> Coordinator（references/coordinator.md）——与下面的表现层模式搭配使用
   否 -> 继续

6. 是否以 UIKit 为主，且希望完全被动、零逻辑的视图？
   是 -> MVP（references/mvp.md）
   否 -> 继续

7. 默认推荐：
   -> MVVM（references/mvvm.md）
```

## 从用户约束推断

使用以下请求信号：

### 指向 MVVM 的信号
- "简单功能"、"屏幕级状态"、"标准 iOS 模式"
- 小/中型功能，无严格状态机需求

### 指向 MVI 的信号
- "状态机"、"确定性转换"、"单向"
- 需要重放/序列化状态转换

### 指向 TCA 的信号
- "可组合"、"TestStore"、"pointfree"、提及 TCA
- 现有 TCA 代码库或有强烈的子功能组合需求

### 指向 Clean Architecture 的信号
- "分层"、"用例"、"依赖规则"、"六边形"
- 稳定的模块边界和可替换基础设施是优先项

### 指向 VIPER 的信号
- "模块"、"router"、"presenter"、遗留 UIKit 代码库
- 大型 UIKit 模块中的严格角色分离

### 指向 Reactive 的信号
- "流"、"Combine"、"RxSwift"、"实时"、"搜索"
- 功能行为由事件管道驱动（typeahead、WebSocket、实时推送）

### 指向 MVP 的信号
- "被动视图"、"presenter 驱动视图"、"无 observable 状态的 UIKit"
- 从 MVC 迁移，尽量减少框架改动
- 团队偏好显式命令分发而非状态绑定

### 指向 Coordinator 的信号
- "导航"、"深度链接"、"流程"、"路由"、"解耦导航"
- 多个屏幕需要在不同流程中复用
- 视图控制器或 ViewModel 当前包含 push/present 调用

## 校验用户指定的架构

当用户预先选定某架构时，在最终确定前进行校验：

1. 跨以下维度检查适配性：
   - UI 技术栈（SwiftUI/UIKit/混合）
   - 功能复杂度与状态模型需求
   - 副作用编排需求
   - 团队熟悉度与依赖容忍度
   - 与现有代码库约定的一致性
2. 判定该请求是 `fit` 还是 `mismatch`。
3. 根据结果回应：
   - `fit`：按请求的架构推进
   - `mismatch`：推荐最接近的替代方案并说明原因

如果用户坚持不匹配的选择，按请求的架构推进，但附带风险缓解计划。

## 组合架构

一些项目使用多种模式。常见的有效组合：

- **MVVM + Reactive**：MVVM 结构，ViewModel 内部使用 Combine/Rx 管道
- **Clean Architecture + MVVM**：Clean 分层用于 domain/data，MVVM 用于表现层
- **Clean Architecture + TCA**：Clean 分层用于 domain/data，TCA 用于功能表现层
- **VIPER + Reactive**：VIPER 模块结构，配合响应式 Interactor
- **MVVM + Coordinator**：MVVM 用于屏幕级状态，Coordinator 用于导航流
- **MVP + Coordinator**：MVP 用于表现层逻辑，Coordinator 用于导航与路由
- **Clean Architecture + MVP**：Clean 分层用于 domain/data，MVP 用于表现层

组合使用时，需明确哪个模式治理哪一层，并保持边界一致。

## 推荐格式

推荐时：

1. 命名一个模式并给出适配结果（`fit` 或 `mismatch`）。
2. 提供 1-2 条基于用户约束的简明理由。
3. 引用参考文件。
4. 若为 `mismatch`，附上最接近的替代方案及一项权衡。
5. 将所选手册应用到用户的功能。
