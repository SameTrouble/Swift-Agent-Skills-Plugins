# 参考索引

Swift Concurrency 技能的快速导航。

## 基础

| 文件 | 用途 |
|---|---|
| `async-await-basics.md` | 闭包到 async 桥接和基础 async/await 用法 |
| `tasks.md` | `Task`、取消、任务组、结构化与非结构化工作 |
| `actors.md` | actor 隔离、`@MainActor`、重入、隔离的一致性 |
| `sendable.md` | `Sendable`、`@Sendable`、区域隔离、逃生舱 |
| `threading.md` | 执行模型、挂起点、Swift 6.2 隔离行为 |

## 流

| 文件 | 用途 |
|---|---|
| `async-sequences.md` | 在 `AsyncSequence`、`AsyncStream` 和一次性 async API 之间做选择 |
| `async-algorithms.md` | debounce、throttle、merge、`combineLatest`、channels、计时器 |

## 应用主题

| 文件 | 用途 |
|---|---|
| `testing.md` | Swift Testing 优先、XCTest 回退、泄漏检查 |
| `performance.md` | Instruments 工作流、actor 跳转、挂起成本 |
| `memory-management.md` | 循环引用、长期运行任务、清理 |
| `core-data.md` | `NSManagedObjectID`、`perform`、默认隔离冲突 |

## 迁移和工具

| 文件 | 用途 |
|---|---|
| `migration.md` | 推出顺序、构建设置、迁移护栏 |
| `linting.md` | 聚焦并发的 lint 规则 |
| `glossary.md` | 快速定义 |

## 问题路由器

- "我需要快速修复编译器错误" → `../SKILL.md`
- "我需要用 async/await 替换回调" → `async-await-basics.md`
- "我需要保护共享可变状态" → `actors.md`
- "我需要安全地跨边界传递数据" → `sendable.md`
- "我需要流操作符" → `async-algorithms.md`
- "我需要理解代码为何在那里执行" → `threading.md`
- "我需要停止泄漏或生命周期问题" → `memory-management.md`
- "我需要迁移到 Swift 6" → `migration.md`
- "我需要测试异步代码" → `testing.md`
- "我需要优化慢速异步代码" → `performance.md`
