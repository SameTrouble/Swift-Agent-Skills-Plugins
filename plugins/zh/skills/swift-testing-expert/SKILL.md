---
name: swift-testing-expert
description: 'Swift Testing 专家指南：测试结构、#expect/#require 宏、Trait 与 Tag、参数化测试、测试计划、并行执行、异步等待模式以及 XCTest 迁移。在编写新的 Swift 测试、现代化 XCTest 套件、调试不稳定测试或提升 Apple 平台/Swift 服务端项目的测试质量与可维护性时使用。'
---

# Swift Testing

## 概述

使用此技能来编写、评审、迁移和调试使用现代 Swift Testing API 的 Swift 测试。优先考虑测试的可读性、健壮的并行执行、清晰的诊断，以及按需从 XCTest 进行增量迁移。

## 代理行为契约（遵循以下规则）

1. Swift 单元测试和集成测试优先使用 Swift Testing，但 UI 自动化（`XCUIApplication`）、性能指标（`XCTMetric`）以及仅 Objective-C 的测试代码仍保留 XCTest。
2. 将 `#expect` 作为默认断言，当后续行依赖于某个前置值时使用 `#require`。
3. 默认采用并行安全的指导原则。如果测试未隔离，优先建议修复共享状态，再考虑使用 `.serialized`。
4. 优先使用 Trait 来表达行为和元数据（`.enabled`、`.disabled`、`.timeLimit`、`.bug`、tag），而非命名约定或临时注释。
5. 当多个测试共享相同逻辑、仅输入值不同时，推荐使用参数化测试。
6. 对测试函数使用 `@available` 来处理系统版本限制的行为，而非在测试体内做运行时 `#available` 检查；绝不使用 `@available` 标注套件类型。
7. 保持迁移建议的增量性：先转换断言，再组织套件，最后引入参数化/Trait。
8. 仅在测试 target 中导入 `Testing`，绝不在 app/library/binary target 中导入。

## 前 60 秒（分诊模板）

- 明确目标：新测试、迁移、不稳定失败、性能、CI 过滤，还是异步等待。
- 收集最小必要信息：
  - Xcode/Swift 版本及目标平台
  - 当前测试使用的是 XCTest、Swift Testing 还是两者混合
  - 失败是确定性的还是不稳定的
  - 测试是否访问共享资源（数据库、文件、网络、全局状态）
- 快速分流：
  - 重复性测试 -> 参数化测试
  - 噪声多或不稳定的失败 -> 已知问题处理与测试隔离
  - 迁移问题 -> XCTest 映射与共存策略
  - 异步回调复杂度 -> continuation/await 模式

## 路由地图（快速找到正确的参考文档）

- 测试构建块与套件组织 -> `references/fundamentals.md`
- `#expect`、`#require` 与抛出期望 -> `references/expectations.md`
- Trait、Tag 与 Xcode 测试计划过滤 -> `references/traits-and-tags.md`
- 参数化测试设计与组合 -> `references/parameterized-testing.md`
- 默认并行执行、`.serialized`、隔离策略 -> `references/parallelization-and-isolation.md`
- 测试速度、确定性及防止不稳定 -> `references/performance-and-best-practices.md`
- 异步等待与回调桥接 -> `references/async-testing-and-waiting.md`
- XCTest 共存与迁移工作流 -> `references/migration-from-xctest.md`
- 测试导航器/报告工作流与诊断 -> `references/xcode-workflows.md`
- 索引与快速导航 -> `references/_index.md`

## 常见陷阱 -> 最佳应对

- 重复的 `testFooCaseA/testFooCaseB/...` 方法 -> 替换为一个参数化的 `@Test(arguments:)`。
- 隐藏在后续断言中失败的可选前置条件 -> 先 `try #require(...)` 再对解包后的值断言。
- 在共享数据库上的不稳定集成测试 -> 隔离依赖或使用内存仓储；仅在过渡阶段使用 `.serialized`。
- 被禁用而悄悄腐坏的测试 -> 对临时已知失败优先使用 `withKnownIssue` 以保留信号。
- 复杂类型失败值不清晰 -> 让类型遵循 `CustomTestStringConvertible` 以获得聚焦的测试诊断。
- 按名称包含/排除测试计划 -> 改用 Tag 和基于 Tag 的过滤器。

## 验证清单

- 确认每个测试具有单一明确的行为，并在需要时具有富有表现力的显示名称。
- 确认前置条件在失败应中止测试时使用 `#require`。
- 确认重复逻辑已参数化而非复制粘贴。
- 确认测试是并行安全的，或有意地序列化并附有理由。
- 确认异步代码已被 await，且回调 API 已安全桥接。
- 确认迁移中仅 Swift Testing 不支持的 XCTest 专属场景仍留在 XCTest。

## 参考文档

- `references/_index.md`
- `references/fundamentals.md`
- `references/expectations.md`
- `references/traits-and-tags.md`
- `references/parameterized-testing.md`
- `references/parallelization-and-isolation.md`
- `references/performance-and-best-practices.md`
- `references/async-testing-and-waiting.md`
- `references/migration-from-xctest.md`
- `references/xcode-workflows.md`
