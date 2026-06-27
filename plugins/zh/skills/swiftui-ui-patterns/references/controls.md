# 控件（Toggle、Slider、Picker）

## 意图

用原生控件做设置和配置屏幕，保持标签可访问且状态绑定清晰。

## 核心模式

- 将控件直接绑定到 `@State`、`@Binding` 或 `@AppStorage`。
- 布尔偏好优先用 `Toggle`。
- 数值范围用 `Slider`，并在标签中显示当前值。
- 离散选择用 `Picker`；仅当选项为 2–4 个时使用 `.pickerStyle(.segmented)`。
- 保持标签可见且具描述性；避免在控件内嵌入按钮。

## 示例：带分区的 Toggle

```swift
Form {
  Section("Notifications") {
    Toggle("Mentions", isOn: $preferences.notificationsMentionsEnabled)
    Toggle("Follows", isOn: $preferences.notificationsFollowsEnabled)
    Toggle("Boosts", isOn: $preferences.notificationsBoostsEnabled)
  }
}
```

## 示例：带值文本的 Slider

```swift
Section("Font Size") {
  Slider(value: $fontSizeScale, in: 0.5...1.5, step: 0.1)
  Text("Scale: \(String(format: \"%.1f\", fontSizeScale))")
    .font(.scaledBody)
}
```

## 示例：枚举的 Picker

```swift
Picker("Default Visibility", selection: $visibility) {
  ForEach(Visibility.allCases, id: \.self) { option in
    Text(option.title).tag(option)
  }
}
```

## 应保留的设计选择

- 在 `Form` 分区中分组相关控件。
- 用 `.disabled(...)` 反映锁定或继承的设置。
- 在 Toggle 中用 `Label` 组合图标 + 文本以增加清晰度。

## 陷阱

- 对大集合避免 `.pickerStyle(.segmented)`；改用 menu 或 inline 样式。
- 不要隐藏 Slider 的标签；始终展示上下文。
- 避免为控件硬编码颜色；节制使用主题色调。
