# 参考索引

Swift Testing 主题快速导航。

## 框架基础

| 文件 | 描述 |
|------|------|
| `test-organization.md` | 套件、标签、特质、并行执行 |
| `parameterized-tests.md` | 高效测试多个输入 |
| `async-testing.md` | 异步模式、confirmation、超时 |
| `migration-xctest.md` | XCTest 到 Swift Testing 迁移 |

## 测试基础设施

| 文件 | 描述 |
|------|------|
| `test-doubles.md` | 完整分类法：Dummy、Fake、Stub、Spy、SpyingStub、Mock |
| `fixtures.md` | 夹具模式、放置位置和最佳实践 |
| `integration-testing.md` | 模块交互测试模式 |
| `snapshot-testing.md` | 使用 SnapshotTesting 进行 UI 回归测试 |
| `dump-snapshot-testing.md` | 数据结构的基于文本的快照测试 |

## 按问题快速链接

### "我需要..."

- **开始使用 Swift Testing** -> `test-organization.md`
- **测试多个输入** -> `parameterized-tests.md`
- **测试异步代码** -> `async-testing.md`
- **从 XCTest 迁移** -> `migration-xctest.md`
- **创建测试替身** -> `test-doubles.md`
- **创建测试数据** -> `fixtures.md`
- **测试模块交互** -> `integration-testing.md`
- **测试 UI 回归** -> `snapshot-testing.md`
- **快照数据结构** -> `dump-snapshot-testing.md`

### "我遇到了...问题"

- **不稳定的测试** -> 检查 `fixtures.md`（日期处理）、`async-testing.md`（时序）
- **缓慢的测试** -> 检查 `test-doubles.md`（正确 mock）、`integration-testing.md`（金字塔）
- **测试组织** -> `test-organization.md`（套件、标签）
- **XCTest 语法错误** -> `migration-xctest.md`
- **选择测试替身** -> `test-doubles.md`（决策表）

### "我想了解..."

- **F.I.R.S.T. 原则** -> 主 SKILL.md
- **测试金字塔** -> 主 SKILL.md、`integration-testing.md`
- **Arrange-Act-Assert** -> 主 SKILL.md
- **Martin Fowler 的测试替身分类法** -> `test-doubles.md`

## 文件统计

| 文件 | 描述 | 关键主题 |
|------|------|----------|
| `test-organization.md` | ~180 行 | 套件、标签、特质、setup/teardown |
| `parameterized-tests.md` | ~160 行 | 参数、zip、笛卡尔积 |
| `async-testing.md` | ~200 行 | async/await、confirmation、超时 |
| `migration-xctest.md` | ~220 行 | XCTest -> Swift Testing 映射 |
| `test-doubles.md` | ~220 行 | Dummy、Fake、Stub、Spy、SpyingStub、Mock |
| `fixtures.md` | ~140 行 | 放置位置、模式、日期处理 |
| `integration-testing.md` | ~160 行 | 内存实现、工作流 |
| `snapshot-testing.md` | ~180 行 | SnapshotTesting 设置、设备、模式 |
| `dump-snapshot-testing.md` | ~200 行 | 文本快照、确定性值、customDump |
