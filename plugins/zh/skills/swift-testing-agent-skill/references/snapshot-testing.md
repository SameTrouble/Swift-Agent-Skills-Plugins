# 快照测试

快照测试通过将渲染的 UI 与录制的基线进行比较来捕获视觉回归。

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
import SwiftUI
@testable import DesignSystem

@Suite("PRCelebrationToast Snapshots")
struct PRCelebrationToastSnapshotTests {

    @Test("renders correctly for new PR")
    func newPRLayout() {
        let record = PersonalRecord.fixture(liftType: .snatch, weight: 120.0)
        let toast = PRCelebrationToast(
            newPR: record,
            quote: "New personal best!"
        )

        assertSnapshot(
            of: toast,
            as: .image(layout: .device(config: .iPhone15Pro))
        )
    }
}
```

## 参数化快照

测试多个配置：

```swift
@Test("renders correctly for different lift types", arguments: LiftType.allCases)
func differentLiftTypes(liftType: LiftType) {
    let record = PersonalRecord.fixture(liftType: liftType, weight: 100.0)
    let toast = PRCelebrationToast(newPR: record, quote: "Great lift!")

    assertSnapshot(
        of: toast,
        as: .image(layout: .sizeThatFits),
        named: "\(liftType)"
    )
}
```

## 布局选项

```swift
// 特定设备
.image(layout: .device(config: .iPhone15Pro))
.image(layout: .device(config: .iPadPro12_9))

// 适应内容大小
.image(layout: .sizeThatFits)

// 固定大小
.image(layout: .fixed(width: 300, height: 200))
```

## 录制模式

首次运行录制基线。重新录制：

```swift
// 重新录制此测试中的所有快照
assertSnapshot(of: view, as: .image, record: true)
```

或使用环境变量：

```bash
SNAPSHOT_TESTING_RECORD=1 swift test
```

## 多种设备尺寸

```swift
@Test("adapts to different screen sizes")
func multipleDevices() {
    let view = SettingsScreen()

    let devices: [(String, ViewImageConfig)] = [
        ("iPhoneSE", .iPhoneSe),
        ("iPhone15Pro", .iPhone15Pro),
        ("iPadPro", .iPadPro12_9),
    ]

    for (name, config) in devices {
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: config)),
            named: name
        )
    }
}
```

## 深色模式测试

```swift
@Test("renders correctly in dark mode")
func darkModeAppearance() {
    let view = SettingsRow(title: "Notifications", isEnabled: true)
        .preferredColorScheme(.dark)

    assertSnapshot(
        of: view,
        as: .image(layout: .sizeThatFits),
        named: "dark"
    )
}
```

## 无障碍测试

```swift
@Test("supports Dynamic Type")
func dynamicTypeSupport() {
    let sizes: [ContentSizeCategory] = [.small, .large, .accessibilityExtraExtraLarge]

    for size in sizes {
        let view = SettingsRow(title: "Notifications", isEnabled: true)
            .environment(\.sizeCategory, size)

        assertSnapshot(
            of: view,
            as: .image(layout: .sizeThatFits),
            named: "\(size)"
        )
    }
}
```

## 最佳实践

### 一致性

- **同一模拟器**：在相同设备/模拟器上录制所有快照
- **匹配 CI**：使用与 CI 流水线相同的配置
- **提交基线**：将参考图像存储在版本控制中

### 组织

```
Tests/
└── DesignSystemTests/
    ├── Snapshots/
    │   ├── PRCelebrationToastSnapshotTests.swift
    │   └── __Snapshots__/           # 生成的基线图像
    │       └── PRCelebrationToastSnapshotTests/
    │           ├── newPRLayout.png
    │           └── differentLiftTypes-snatch.png
```

### 审查流程

1. PR 前在本地运行测试
2. 仔细审查快照差异
3. 重新录制有意的变更
4. 随代码变更提交新基线

## 故障排除

### 不稳定的测试

```swift
// 为抗锯齿差异添加精度容差
assertSnapshot(
    of: view,
    as: .image(precision: 0.99)
)
```

### CI 失败

- 确保 CI 使用相同的模拟器版本
- 考虑对轻微渲染差异使用 `perceptualPrecision`
- 在 README 中记录预期的模拟器

### 大文件

```swift
// 对大型视图使用较小的比例
assertSnapshot(
    of: view,
    as: .image(layout: .fixed(width: 375, height: 812), scale: 1)
)
```
