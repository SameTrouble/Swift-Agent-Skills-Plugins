# Dump 快照测试

Dump 快照测试捕获数据结构的基于文本的表示，非常适合测试模型、状态对象和非视觉组件。

## 设置

使用 [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing)：

```swift
// Package.swift
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
```

## 基本用法

```swift
import SnapshotTesting
import Testing
@testable import Domain

@Suite("PersonalRecord Snapshots")
struct PersonalRecordSnapshotTests {

    @Test("captures record structure correctly")
    func recordStructure() {
        let record = PersonalRecord.fixture(
            liftType: .snatch,
            weight: 120.0,
            date: Date(timeIntervalSince1970: 1704067200) // 固定日期
        )

        assertSnapshot(of: record, as: .dump)
    }
}
```

## 何时使用 Dump 快照

| 用例 | 为何使用 Dump 快照 |
|------|---------------------|
| **数据模型** | 无需为每个属性编写断言即可验证所有属性 |
| **API 响应** | 捕获解码结构中的意外变更 |
| **状态对象** | 跟踪复杂的状态转换 |
| **转换** | 验证映射/转换逻辑的输出 |
| **配置** | 确保设置对象被正确构建 |

## 参数化 Dump 快照

测试多个配置：

```swift
@Test("captures different lift types", arguments: LiftType.allCases)
func liftTypeSnapshots(liftType: LiftType) {
    let record = PersonalRecord.fixture(
        liftType: liftType,
        weight: 100.0
    )

    assertSnapshot(of: record, as: .dump, named: "\(liftType)")
}
```

## 复杂对象快照

```swift
@Test("captures workout session state")
func workoutSessionState() {
    let session = WorkoutSession(
        id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!,
        exercises: [
            Exercise.fixture(name: "Snatch", sets: 5, reps: 3),
            Exercise.fixture(name: "Clean & Jerk", sets: 4, reps: 2)
        ],
        startedAt: Date(timeIntervalSince1970: 1704067200),
        status: .inProgress
    )

    assertSnapshot(of: session, as: .dump)
}
```

## 集合和数组

```swift
@Test("captures record history")
func recordHistory() {
    let records = [
        PersonalRecord.fixture(liftType: .snatch, weight: 100.0),
        PersonalRecord.fixture(liftType: .snatch, weight: 105.0),
        PersonalRecord.fixture(liftType: .snatch, weight: 110.0)
    ]

    assertSnapshot(of: records, as: .dump)
}
```

## 嵌套结构

```swift
@Test("captures user profile with nested data")
func userProfileSnapshot() {
    let profile = UserProfile(
        user: User.fixture(name: "Alice"),
        settings: Settings.fixture(
            notifications: true,
            theme: .dark
        ),
        recentRecords: [
            PersonalRecord.fixture(liftType: .snatch)
        ]
    )

    assertSnapshot(of: profile, as: .dump)
}
```

## 对比 Dump 与 Custom Dump

SnapshotTesting 提供两种文本策略：

```swift
// 标准 Swift dump - 使用 Mirror API
assertSnapshot(of: object, as: .dump)

// Custom dump - 更易读的输出（推荐）
assertSnapshot(of: object, as: .customDump)
```

**优先使用 `.customDump`** 以获得更好的可读性：
- 排序的字典键
- 简单值的精简输出
- 更好的枚举表示

## 录制模式

首次运行录制基线。重新录制：

```swift
// 重新录制此快照
assertSnapshot(of: record, as: .dump, record: true)
```

或使用环境变量：

```bash
SNAPSHOT_TESTING_RECORD=1 swift test
```

## 确定性快照

通过控制可变数据确保输出一致：

```swift
@Test("captures record with deterministic values")
func deterministicSnapshot() {
    // 使用固定 UUID
    let id = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!

    // 使用固定日期
    let date = Date(timeIntervalSince1970: 1704067200) // 2024-01-01

    let record = PersonalRecord(
        id: id,
        liftType: .snatch,
        weight: 120.0,
        date: date
    )

    assertSnapshot(of: record, as: .dump)
}
```

## 组织

```
Tests/
└── DomainTests/
    ├── Snapshots/
    │   ├── PersonalRecordSnapshotTests.swift
    │   └── __Snapshots__/
    │       └── PersonalRecordSnapshotTests/
    │           ├── recordStructure.txt
    │           └── liftTypeSnapshots-snatch.txt
```

## 最佳实践

### 使用固定值的夹具

```swift
// 好 - 确定性
let record = PersonalRecord.fixture(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    date: Date(timeIntervalSince1970: 0)
)

// 坏 - 非确定性
let record = PersonalRecord.fixture() // 随机 UUID，当前日期
```

### 为参数化快照命名

```swift
// 好 - 清晰的文件名
assertSnapshot(of: record, as: .dump, named: "snatch-120kg")

// 避免 - 通用名称
assertSnapshot(of: record, as: .dump)
```

### 仔细审查差异

Dump 快照捕获所有属性。审查时：
1. 验证有意的变更
2. 捕获意外的副作用
3. 仅在仔细审查后更新基线

### 与单元测试结合

Dump 快照补充而非替代单元测试：

```swift
@Test("validates and snapshots transformation")
func transformRecord() {
    let input = APIResponse.fixture()
    let output = RecordMapper.map(input)

    // 关键行为的单元断言
    #expect(output.weight == input.weightKg)

    // 完整结构的快照
    assertSnapshot(of: output, as: .dump)
}
```

## 故障排除

### 非确定性失败

如果快照间歇性失败：
- 检查是否使用了不带固定值的 `UUID()` 或 `Date()`
- 确保字典顺序一致
- 使用 `.customDump` 获取排序的键

### 大型快照

对于属性较多的对象：

```swift
// 快照特定部分
assertSnapshot(of: session.exercises, as: .dump, named: "exercises")
assertSnapshot(of: session.metadata, as: .dump, named: "metadata")
```

### 不可读的输出

切换到 custom dump 获取更清晰的输出：

```swift
// 之前：标准 dump
assertSnapshot(of: complex, as: .dump)

// 之后：更清晰的格式
assertSnapshot(of: complex, as: .customDump)
```
