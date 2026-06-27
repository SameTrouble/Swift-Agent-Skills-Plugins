# Voice Control

Voice Control 让用户仅用语音就能导航和交互。

## 工作原理

Voice Control 识别无障碍标签，让用户通过说出它们来激活控件。

```
用户："Tap Settings"
→ 激活 accessibilityLabel 为"Settings"的按钮
```

Voice Control 可以离线工作，严重依赖你提供的标签。清晰、简洁的标签带来更快、更可靠的激活。

## 启用 Voice Control

**设置 > 无障碍 > Voice Control**

或对 Siri 说"Turn on Voice Control"。

## 关键命令

| 命令 | 操作 |
|---------|--------|
| "Show names" | 在所有元素上覆盖标签 |
| "Show numbers" | 在所有元素上覆盖数字 |
| "Tap [label]" | 按名称激活元素 |
| "Tap [number]" | 激活编号元素 |
| "Show grid" | 显示网格以精确点击 |
| "Show actions" | 显示聚焦元素的自定义操作 |
| "Scroll down/up" | 滚动屏幕 |
| "Go back" | 向后导航 |

## 标签最佳实践

### 匹配可见文本

如果按钮显示"Submit"，无障碍标签应该是"Submit"——而不是"Send"或"Submit button"。

```swift
// 按钮显示"Settings"
settingsButton.accessibilityLabel = "Settings" // ✓ 匹配
```

### 避免重复

多个元素有相同标签会造成歧义。Voice Control 会回退到显示数字。

### 使用输入标签提供替代方案

当可见文本与用户可能说的不匹配时：

**UIKit**:
```swift
gearButton.accessibilityLabel = "Settings"
gearButton.accessibilityUserInputLabels = ["Settings", "Preferences", "Options", "Gear", "Cog"]
```

**SwiftUI**:
```swift
Button(action: openSettings) {
    Image(systemName: "gear")
}
.accessibilityLabel("Settings")
.accessibilityInputLabels(["Settings", "Preferences", "Options", "Gear", "Cog"])
```

用户可以说出这些替代方案中的任何一个。

## 用 Voice Control 测试

### "Show names"

在屏幕上覆盖显示所有无障碍标签。快速识别：
- 缺失标签（无覆盖出现）
- 重复标签（多个元素有相同文本）
- 令人困惑的标签（文本与视觉不匹配）

在开发期间使用此命令验证用户实际会说的标签。

### "Show actions"

聚焦元素并说"Show actions"以查看自定义无障碍操作。

## 自定义操作

Voice Control 暴露自定义操作。用户可以说"Show actions for [元素]"然后按名称激活。

```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Delete", actionHandler: { _ in
        self.delete()
        return true
    })
]
```

用户："Show actions for Message"
→ "Delete" 出现
用户："Tap Delete"

## 无障碍值

值改善有状态控件的 Voice Control 可用性：

```swift
slider.accessibilityLabel = "Volume"
slider.accessibilityValue = "50 percent"
```

用户："What is Volume?"
→ Voice Control 公告"50 percent"

## 常见问题

| 问题 | 解决方案 |
|---------|----------|
| 元素没有标签 | 添加 `accessibilityLabel` |
| 标签与可见文本不匹配 | 更新标签或使用输入标签 |
| 多个元素有相同标签 | 使标签唯一或使用上下文 |
| 仅图标按钮 | 添加描述性标签 |
| 需要自定义手势 | 提供无障碍替代方案 |

## 清单

- [ ] 标签尽可能匹配可见文本
- [ ] 不同控件没有重复标签
- [ ] 仅图标按钮有描述性标签
- [ ] 为不显而易见的名称提供输入标签
- [ ] 为次要功能暴露自定义操作
- [ ] 用"Show names"命令测试

## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
- https://accessibilityupto11.com/blog/
