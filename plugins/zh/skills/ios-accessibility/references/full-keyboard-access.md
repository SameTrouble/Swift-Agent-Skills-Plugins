# Full Keyboard Access

Full Keyboard Access 让用户仅使用硬件键盘就能导航和交互 iOS。

## 工作原理

用户用 Tab 在可聚焦元素间导航，用 Space 激活。可见的焦点指示器显示当前元素。

Full Keyboard Access 在 iPadOS 上使用硬件键盘时尤为重要。

## 启用 Full Keyboard Access

**设置 > 无障碍 > 键盘 > Full Keyboard Access**

## 按键命令

| 按键 | 操作 |
|-----|--------|
| Tab | 移动到下一个元素 |
| Shift + Tab | 移动到上一个元素 |
| Space | 激活聚焦元素 |
| Escape | 关闭或返回 |
| Tab + Z | 显示自定义操作 |
| 方向键 | 在控件内导航 |

## 开发影响

与 VoiceOver 配合使用的元素通常也能与 Full Keyboard Access 配合。重点关注：
- 合理的聚焦顺序
- 可见的聚焦指示器
- 关键操作的键盘快捷键

## 聚焦顺序

聚焦遵循无障碍顺序。使用与 VoiceOver 相同的技巧：

**UIKit**:
```swift
view.accessibilityElements = [headerLabel, searchField, listView]
```

**SwiftUI**:
```swift
VStack {
    Text("First").accessibilitySortPriority(2)
    Text("Second").accessibilitySortPriority(1)
}
```

## 键盘快捷键

为常用操作提供快捷键。

### UIKit

```swift
override var keyCommands: [UIKeyCommand]? {
    [
        UIKeyCommand(
            title: "Refresh",
            action: #selector(refresh),
            input: "r",
            modifierFlags: .command
        ),
        UIKeyCommand(
            title: "Search",
            action: #selector(search),
            input: "f",
            modifierFlags: .command
        )
    ]
}
```

### SwiftUI

```swift
Button("Refresh", action: refresh)
    .keyboardShortcut("r", modifiers: .command)
```

用户按住 Command 键时会出现快捷键。

## 输入标签

通过替代名称帮助用户找到元素：

**UIKit**:
```swift
button.accessibilityUserInputLabels = ["Settings", "Preferences", "Config"]
```

**SwiftUI**:
```swift
.accessibilityInputLabels(["Settings", "Preferences", "Config"])
```

这帮助按名称搜索的键盘用户。

## 自定义操作

自定义操作可通过 Tab + Z 访问：

```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Delete", actionHandler: { _ in
        self.delete()
        return true
    })
]
```

## 分组

将相关元素分组以减少 Tab 停靠点：

**UIKit**:
```swift
containerView.isAccessibilityElement = true
containerView.accessibilityLabel = "\(title), \(subtitle)"
```

**SwiftUI**:
```swift
.accessibilityElement(children: .combine)
```

## 测试

### 模拟器

在模拟器的设置应用中启用 Full Keyboard Access。使用 Mac 键盘导航。

### 设备

连接硬件键盘（蓝牙或 Smart Connector）。

### 验证内容

1. 所有交互元素都可聚焦
2. 聚焦顺序合理
3. 聚焦指示器可见
4. Space 激活聚焦元素
5. Escape 关闭模态
6. 键盘快捷键工作正常

## 常见问题

| 问题 | 解决方案 |
|---------|----------|
| 元素不可聚焦 | 确保 `isAccessibilityElement = true` |
| 聚焦顺序混乱 | 设置 `accessibilityElements` 顺序 |
| 聚焦指示器被隐藏 | 避免裁剪或覆盖 |
| 操作需要触摸 | 添加键盘快捷键或自定义操作 |

## 清单

- [ ] 所有交互元素可聚焦
- [ ] 聚焦顺序遵循任务流程
- [ ] 主要操作有键盘快捷键
- [ ] 自定义操作通过 Tab + Z 暴露
- [ ] 在模拟器和设备上测试

## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
- https://accessibilityupto11.com/blog/
