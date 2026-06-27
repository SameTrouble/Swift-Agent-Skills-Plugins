# 夹具

夹具是工厂方法，通过合理的默认值简化测试对象的创建。

## 夹具放置位置

将夹具放在**模型附近**，而非测试 target 中：

```swift
// 在 Sources/Models/PersonalRecord.swift

public struct PersonalRecord: Equatable, Sendable {
    public let id: UUID
    public let liftType: LiftType
    public let weight: Double
    public let reps: Int
    public let date: Date
    public let isPersonalBest: Bool

    public init(
        id: UUID,
        liftType: LiftType,
        weight: Double,
        reps: Int,
        date: Date,
        isPersonalBest: Bool = false
    ) {
        self.id = id
        self.liftType = liftType
        self.weight = weight
        self.reps = reps
        self.date = date
        self.isPersonalBest = isPersonalBest
    }
}

// 夹具与模型放在一起
#if DEBUG
extension PersonalRecord {
    public static func fixture(
        id: UUID = UUID(),
        liftType: LiftType = .snatch,
        weight: Double = 100.0,
        reps: Int = 1,
        date: Date = Date(),
        isPersonalBest: Bool = false
    ) -> PersonalRecord {
        PersonalRecord(
            id: id,
            liftType: liftType,
            weight: weight,
            reps: reps,
            date: date,
            isPersonalBest: isPersonalBest
        )
    }
}
#endif
```

## 优势

1. **测试展示相关数据**：只指定重要的属性
2. **减少样板代码**：不重要的属性使用默认值
3. **一致的测试数据**：整个套件使用相同的默认值
4. **自动可用**：无需导入模型模块之外的内容
5. **零生产开销**：`#if DEBUG` 在 release 中剥离

## 使用模式

### 最小规格

```swift
@Test("returns nickname when present")
func returnsNicknameWhenPresent() {
    // 只指定对本测试重要的部分
    let user = User.fixture(nickname: "Johnny")
    let sut = ProfileViewModel(user: user)

    let displayName = sut.getUserName()

    #expect(displayName == "Johnny")
}
```

### 多个夹具

```swift
@Test("sorts records by date")
func sortsRecordsByDate() {
    let oldRecord = PersonalRecord.fixture(
        date: Date().addingTimeInterval(-86400)
    )
    let newRecord = PersonalRecord.fixture(
        date: Date()
    )

    let sorted = sut.sort([oldRecord, newRecord])

    #expect(sorted.first?.id == newRecord.id)
}
```

### 夹具集合

```swift
#if DEBUG
extension PersonalRecord {
    public static func fixtures(count: Int) -> [PersonalRecord] {
        (0..<count).map { _ in .fixture() }
    }

    public static var sampleCollection: [PersonalRecord] {
        [
            .fixture(liftType: .snatch, weight: 80),
            .fixture(liftType: .cleanAndJerk, weight: 100),
            .fixture(liftType: .squat, weight: 150),
        ]
    }
}
#endif
```

### 嵌套夹具

```swift
#if DEBUG
extension User {
    public static func fixture(
        id: UUID = UUID(),
        profile: Profile = .fixture(),
        settings: Settings = .fixture()
    ) -> User {
        User(id: id, profile: profile, settings: settings)
    }
}

extension Profile {
    public static func fixture(
        name: String = "Test User",
        email: String = "test@example.com"
    ) -> Profile {
        Profile(name: name, email: email)
    }
}
#endif
```

## 夹具指南

### 应该

- 为所有属性提供合理的默认值
- 使默认值代表典型数据
- 使用 `#if DEBUG` 从生产中排除
- 使夹具方法为 `public static`
- 镜像初始化器参数顺序

### 不应该

- 使用随机值（破坏可重复性）
- 在生产构建中包含夹具
- 在测试 target 中创建夹具（难以共享）
- 使用 `Date()` 等日期而不允许覆盖

## 日期处理

```swift
#if DEBUG
extension PersonalRecord {
    public static func fixture(
        // 使用固定参考日期，而非 Date()
        date: Date = Date(timeIntervalSince1970: 1704067200)  // 2024-01-01
    ) -> PersonalRecord {
        // ...
    }
}
#endif
```

或使用测试时钟依赖：

```swift
@Dependency(\.date) var date

// 在测试中
let fixedDate = Date(timeIntervalSince1970: 1704067200)
withDependencies {
    $0.date = .constant(fixedDate)
} operation: {
    // 测试使用固定日期
}
```
