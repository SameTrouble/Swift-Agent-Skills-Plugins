# watchOS 焦点管理

watchOS 焦点主要用于将 **Digital Crown 输入**路由到正确视图。没有键盘、遥控器或光标。Digital Crown 是唯一的非触摸输入设备。

## watchOS 上焦点如何工作

- 视图有焦点时，系统在其周围绘制**绿色边框**
- 旋转 Digital Crown 更改该聚焦视图的值
- 焦点是**顺序的**（布局顺序），不像 tvOS 那样是空间/方向性的
- 系统控件（List、ScrollView、Picker、Stepper、Toggle）自动处理 Digital Crown——无需 `.focusable()`
- watchOS 上只有 SwiftUI 焦点 API——**没有 UIFocusEnvironment** 等价物（WatchKit 没有焦点协议）
- `.focusSection()` 在 watchOS 上**不可用**
- watchOS 不支持键盘焦点

## 可用 API

### @FocusState（watchOS 8.0+）

控制哪个视图接收 Digital Crown 输入。

```swift
enum Field: Hashable { case amount, tip }
@FocusState private var focusedField: Field?

Form {
    TextField("Amount", value: $amount, format: .currency(code: "USD"))
        .focused($focusedField, equals: .amount)
    Picker("Tip", selection: $tipPercent) { /* ... */ }
        .focused($focusedField, equals: .tip)
}
```

### .focusable()（watchOS 8.0+）

使自定义视图能够接收 Digital Crown 输入。聚焦时显示绿色焦点环。

```swift
Text("Value: \(crownValue, specifier: "%.1f")")
    .focusable()                              // 必须在前
    .digitalCrownRotation($crownValue,
                          from: 0.0,
                          through: 10.0,
                          sensitivity: .low,
                          isContinuous: false,
                          isHapticFeedbackEnabled: true)
```

**关键顺序规则**：`.focusable()` 必须在修饰符链中位于 `.digitalCrownRotation()` 之前。顺序反转会静默破坏 Crown 输入。

### .focusable(interactions:)（watchOS 10.0+）

细粒度控制：
- `.edit`——捕获 Digital Crown 旋转（滑块、步进器）
- `.activate`——通过焦点的主要操作（类按钮）
- `.automatic`——平台适当默认值

### .digitalCrownRotation()（watchOS 6.0+，watchOS 9.0+ 增强）

将 Digital Crown 硬件绑定到属性。

参数：`binding`、`from`/`through`（范围）、`by`（触觉停止步幅）、`sensitivity`（.low/.medium/.high）、`isContinuous`（环绕）、`isHapticFeedbackEnabled`、`onChange`、`onIdle`。

模式类型：
- **自由滚动**：无 `by` 参数——平滑连续旋转
- **Picker 风格**：带 `by` 步幅——离散触觉停止
- **循环**：带 `isContinuous: true`——在边界环绕

### .digitalCrownAccessory()（watchOS 9.0+）

添加或控制 Digital Crown 指示器附近附件视图的可见性。

### prefersDefaultFocus(_:in:)（watchOS 7.0+）

控制哪个视图最初获得 Digital Crown 焦点。

```swift
@Namespace var formScope

Form {
    Picker("Size", selection: $size) { /* ... */ }
        .prefersDefaultFocus(true, in: formScope)
    Stepper("Count", value: $count)
}
.focusScope(formScope)
```

### defaultFocus(_:_:priority:)（watchOS 9.0+）

`prefersDefaultFocus` 的现代替代方案：

```swift
@FocusState private var focusedField: Field?

Form { ... }
    .defaultFocus($focusedField, .name)
```

### focusScope(_:)（watchOS 7.0+）

`prefersDefaultFocus` 和 `resetFocus` 的必需配套。创建焦点命名空间作用域。

### resetFocus（watchOS 7.0+）

以编程方式在命名空间内重新求值默认焦点：

```swift
@Namespace var mainScope
@Environment(\.resetFocus) var resetFocus

Button("Reset") {
    resetFocus(in: mainScope)
}
```

### @Environment(\.isFocused)（watchOS 7.0+）

只读——最近可聚焦祖先有焦点时返回 true。用于自定义焦点视觉。

### .focusEffectDisabled()（watchOS 10.0+）

抑制默认绿色焦点环。在通过 `isFocused` 提供自定义焦点视觉时使用。

## Digital Crown + List/ScrollView 交互

- `List` 和 `ScrollView` 自动接收 Digital Crown 滚动输入——无需焦点修饰符
- 当 `Form` 包含可聚焦控件（Picker、Stepper）时，第一个可聚焦视图可能初始获取焦点，使 Crown 控制该视图而非滚动
- 如果用户用手指滚动，Crown 转为表单滚动——**picker 可能不会重新获得焦点**（已知 UX 痛点）
- 使用 `defaultFocus` 控制哪个元素最初接收 Crown 焦点

## 嵌套滚动和 Crown 冲突

当 `ScrollView` 或 `List` 包含可聚焦控件（Picker、Stepper）时，Digital Crown 服务双重目的——滚动容器和控制聚焦元素。这造成 UX 冲突。

### 问题

```swift
Form {
    Picker("Size", selection: $size) { /* 选项 */ }  // 聚焦时 Crown 控制这个
    Stepper("Count", value: $count)                     // 或这个
    Text("Description...")                               // 无聚焦时 Crown 滚动 Form
    // ... 更多内容在折叠下方
}
```

当用户聚焦 Picker 时，Crown 控制 Picker。如果他们手指滚过它，Picker 可能失去焦点且 Crown 切换到滚动。Picker 可能不会在没有显式轻点的情况下重新获得 Crown 焦点。

### 解决方案：显式焦点管理

```swift
@FocusState private var focusedControl: FormControl?

Form {
    Picker("Size", selection: $size) { /* 选项 */ }
        .focused($focusedControl, equals: .size)
    
    Stepper("Count", value: $count)
        .focused($focusedControl, equals: .count)
    
    // 显式"完成"将 Crown 释放回滚动
    Button("Done Editing") {
        focusedControl = nil
    }
}
```

### 最佳实践
- 将可聚焦控件保持在可滚动表单顶部
- 提供清晰方式解除焦点（释放 Crown 到滚动）
- 每屏限制可聚焦控件 2-3 个以避免混淆
- 使用 `defaultFocus` 设置哪个控件最初获得 Crown

## .digitalCrownAccessory() 模式

Digital Crown 附件（watchOS 9+）在 Crown 区域附近添加小视觉指示器显示当前值或状态。

### 基本用法

```swift
Text("Volume: \(Int(volume))%")
    .focusable()
    .digitalCrownRotation($volume, from: 0, through: 100)
    .digitalCrownAccessory(.automatic)  // 系统决定可见性
```

### 自定义附件内容

```swift
.digitalCrownAccessory {
    Image(systemName: volume > 50 ? "speaker.wave.3" : "speaker.wave.1")
        .foregroundColor(.blue)
}
```

### 可见性控制

```swift
.digitalCrownAccessory(isVisible ? .visible : .hidden)
```

当 Crown 控制滚动位置而非离散值时使用 `.hidden`——附件对滚动偏移无意义。

## 管理多个可聚焦控件

当 Form 有 3+ 可聚焦控件时，用户对 Crown 控制哪个感到困惑。

### 模式：带视觉反馈的顺序焦点

```swift
enum Control: Hashable { case hours, minutes, seconds }
@FocusState private var active: Control?

VStack {
    TimeControl(label: "Hours", value: $hours)
        .focused($active, equals: .hours)
        .foregroundColor(active == .hours ? .blue : .primary)
    
    TimeControl(label: "Minutes", value: $minutes)
        .focused($active, equals: .minutes)
        .foregroundColor(active == .minutes ? .blue : .primary)
    
    TimeControl(label: "Seconds", value: $seconds)
        .focused($active, equals: .seconds)
        .foregroundColor(active == .seconds ? .blue : .primary)
}
.toolbar {
    ToolbarItem(placement: .confirmationAction) {
        Button("Next") {
            switch active {
            case .hours: active = .minutes
            case .minutes: active = .seconds
            case .seconds: active = nil
            case nil: active = .hours
            }
        }
    }
}
```

### UX 指南
- 绿色焦点环是主要指示器——但多个控件时难以发现
- 添加次要颜色或尺寸更改使活动控件明显
- 提供工具栏按钮或手势在控件间循环
- 如果有 4+ Crown 控制项目考虑拆分为多个屏幕

## 常见错误

### 1. 修饰符顺序错误
`.digitalCrownRotation()` 在 `.focusable()` 之前会静默破坏 Crown 输入。`.focusable()` 必须在前。

### 2. 向系统控件添加 .focusable()
导致双重绿色焦点环并需要额外轻点导航。Picker、Stepper、Toggle、TextField 已经处理焦点。

### 3. Form 中多个 Stepper
多个 Stepper 可能同时显示绿色焦点边框，混淆用户 Crown 控制哪个。

### 4. 可滚动 Form 中焦点丢失
可滚动 Form 内的 Picker 在用户手指滚动后可能永久失去焦点。

### 5. 不使用 focusScope
没有作用域，`prefersDefaultFocus` 和 `resetFocus` 在整个窗口上操作——意外行为。

## watchOS 上不可用

| API | 原因 |
|-----|---------|
| `.focusSection()` | 无方向导航——watchOS 焦点是顺序的 |
| `UIFocusEnvironment` | WatchKit 没有焦点协议 |
| `UIFocusGuide` | 无空间导航模型 |
| `focusGroupIdentifier` | iOS 专有概念 |
| `UIFocusHaloEffect` | 仅 iOS/Catalyst |
| 键盘导航 | 无键盘支持 |

## WWDC 会议

| 会议 | 年份 | watchOS 内容 |
|---------|------|----------------|
| SwiftUI on watchOS | WWDC19 | 引入 .focusable() + .digitalCrownRotation() |
| SwiftUI 中的直接和反射焦点 | WWDC21 | watchOS 上的 @FocusState、prefersDefaultFocus |
| SwiftUI 焦点手册 | WWDC23 | FocusInteractions（.edit 用于 Digital Crown） |
