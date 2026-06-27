# Switch Control

Switch Control 让运动障碍用户使用外部开关、头部动作或其他自适应硬件导航 iOS。

## 工作原理

Switch Control 逐个扫描元素。当所需元素被高亮时，用户激活开关以选择它。

### 扫描模式

| 模式 | 行为 |
|------|----------|
| Auto Scan | 光标自动在元素间移动 |
| Manual Scan | 用户触发每次移动 |
| Step Scan | 多开关导航（下一个/上一个/选择） |

## 启用 Switch Control

**设置 > 无障碍 > Switch Control**

## 对开发的影响

良好的 VoiceOver 支持通常意味着良好的 Switch Control 支持。相同的无障碍属性适用：
- 标签
- 特质
- 分组
- 自定义操作

## 减少扫描步骤

### 分组相关元素

更少的元素意味着到达目标需要更少的扫描步骤。

**UIKit**:
```swift
containerView.isAccessibilityElement = true
containerView.accessibilityLabel = "\(title), \(subtitle)"
```

**SwiftUI**:
```swift
HStack {
    Image(systemName: "star.fill")
    Text("Favorite")
}
.accessibilityElement(children: .combine)
```

### 语义分组

使用容器类型组织控件：

```swift
toolbar.accessibilityContainerType = .semanticGroup
```

Switch Control 识别组并提供"扫描此组"操作。

## 自定义操作

Switch Control 通过其菜单系统展示自定义操作。

```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(
        name: "Delete",
        image: UIImage(systemName: "trash"),
        actionHandler: { _ in
            self.delete()
            return true
        }
    ),
    UIAccessibilityCustomAction(
        name: "Share",
        image: UIImage(systemName: "square.and.arrow.up"),
        actionHandler: { _ in
            self.share()
            return true
        }
    )
]
```

图像出现在 Switch Control 菜单中（iOS 14+），使用 [`UIAccessibilityCustomAction.init(name:image:actionHandler:)`](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction/init(name:image:actionhandler:))。

## 特质

确保特质正确：
- `.button` 用于可点击元素
- `.selected` 用于当前选择
- `.notEnabled` 用于禁用控件
- `.adjustable` 用于步进器和滑块

缺失的特质会混淆导航。

## 测试

最简单的低摩擦选项是使用蓝牙键盘：

1. 前往**设置 > 无障碍 > Switch Control**
2. 添加开关，选择**键盘**作为源
3. 将**空格键**映射到"选择项目" — 一个键扫描；按下选择
4. 或配置两个键：一个用于"移动到下一项"，另一个用于"选择项目"

如果没有蓝牙键盘，可以使用头部动作测试：

- **设置 > 无障碍 > Switch Control > 开关**：使用**向左头部移动**（下一个）和**向右头部移动**（选择）添加开关
- 注意：启用此功能会禁用其他屏幕触摸，所以保持无障碍快捷方式方便以退出

启用后：
1. 让 Switch Control 扫描你的应用
2. 验证所有元素都可到达且顺序合理
3. 确认自定义操作出现在菜单中（减少步骤数）
4. 检查分组是否减少了不必要的扫描步骤

### 验证内容

- 所有交互元素都可到达
- 分组减少了不必要的扫描步骤
- 自定义操作可发现（复杂操作出现在 Switch Control 菜单中，而非需要手动导航）
- 特质与元素行为匹配

## visionOS

Switch Control 在 visionOS 中受支持。构建无障碍空间体验受益于相同的模式：
- 清晰的标签
- 合理的分组
- 暴露的操作

## 常见问题

| 问题 | 解决方案 |
|---------|----------|
| 扫描步骤太多 | 分组相关元素 |
| 操作隐藏在手势后 | 添加自定义操作 |
| 元素不可到达 | 设置 `isAccessibilityElement = true` |
| 缺失特质 | 添加适当的特质 |

## 清单

- [ ] 元素已分组以减少扫描步骤
- [ ] 为次要功能提供自定义操作
- [ ] 特质与行为匹配
- [ ] 启用 Switch Control 测试

## 来源

- https://accessibilityupto11.com/365-days-ios-accessibility/
- https://accessibilityupto11.com/blog/
