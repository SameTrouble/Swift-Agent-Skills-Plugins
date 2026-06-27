# 参考索引

Swift 架构技能的快速导航。

## 核心路由

| 文件 | 用途 |
|---|---|
| `selection-guide.md` | 根据用户约束选择最合适的架构 |
| `mvvm.md` | 低到中等复杂度功能，需轻量状态绑定 |
| `mvi.md` | 无需引入框架依赖的 reducer 风格状态机 |
| `tca.md` | 复杂、高度可组合的功能，需严格副作用编排 |
| `clean-architecture.md` | 严格的层边界与可替换的基础设施 |
| `viper.md` | 需要明确角色分离的大型 UIKit 模块 |
| `reactive.md` | Combine 或 RxSwift 流密集型功能与事件管道 |
| `mvp.md` | UIKit 优先的被动视图，由 presenter 驱动渲染 |
| `coordinator.md` | 解耦的导航流与可深度链接的屏幕编排 |

## 问题路由

- "我需要帮助选择架构" → `selection-guide.md`
- "功能简单，限定在单个屏幕" → `mvvm.md`
- "我想要无需 TCA 的确定性状态转换" → `mvi.md`
- "功能具有复杂状态、子模块组合和严格副作用" → `tca.md`
- "我需要用例、仓库和清晰的边界" → `clean-architecture.md`
- "这是一个大型 UIKit 模块，有明确的 presenter/interactor/router 角色" → `viper.md`
- "问题是流密集型或由 Combine/RxSwift 驱动" → `reactive.md`
- "我想要带 presenter 的被动 UIKit 视图" → `mvp.md`
- "主要问题是导航流和屏幕协调" → `coordinator.md`
