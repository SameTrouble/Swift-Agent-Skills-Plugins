# 调试焦点问题（tvOS + macOS）

## UIFocusDebugger（LLDB 命令）

tvOS 11+ 可用。在断点期间的 Xcode 调试器中使用。

### 检查当前焦点状态
```
(lldb) po UIFocusDebugger.status()
```
显示当前聚焦项目及其焦点环境链。

### 检查视图为何无法接收焦点
```
(lldb) po UIFocusDebugger.checkFocusability(for: myView)
```
返回视图可聚焦或不可聚焦原因的详细说明。检查：
- `canBecomeFocused` 返回值
- `isHidden`
- `alpha == 0`
- `isUserInteractionEnabled`
- 视图是否在窗口中
- 祖先是否阻止焦点

### 模拟焦点更新
```
(lldb) po UIFocusDebugger.simulateFocusUpdateRequest(from: myEnvironment)
```
遍历首选焦点链而不实际移动焦点。显示哪个视图*将*接收焦点。

### 检查焦点组树
```
(lldb) po UIFocusDebugger.checkFocusGroupTree(for: focusSystem)
```
打印整个焦点组层次结构。

### 列出所有命令
```
(lldb) po UIFocusDebugger.help()
```

## _whyIsThisViewNotFocusable（隐藏调试方法）

不在公共 API 中但对调试非常有价值：

```
(lldb) po [myView _whyIsThisViewNotFocusable]
```

返回人类可读的问题列表：
- "userInteractionEnabled set to NO"
- "canBecomeFocused returns NO"
- "view is hidden"
- "alpha is 0"
- "view is obscured by another view"
- "ancestor has userInteractionEnabled = NO"
- "not in a window"

## 启动参数

### -UIFocusLoggingEnabled YES

添加到方案的启动参数。将每个焦点更新记录到控制台，包含：
- 首选焦点环境搜索链
- 选择哪个视图及原因
- 考虑和拒绝的视图

### 如何添加
Xcode -> Product -> Scheme -> Edit Scheme -> Run -> Arguments -> "+" -> `-UIFocusLoggingEnabled YES`

## UIFocusUpdateContext 上的 Quick Look

在 `shouldUpdateFocus(in:)` 或 `didUpdateFocus(in:with:)` 中：
1. 设置断点
2. 选择 `context` 参数
3. 点击 Quick Look（眼睛图标）或按空格

显示可视化图表：
- **红色**：先前聚焦视图（搜索起点）
- **红色虚线**：搜索路径
- **紫色**：搜索路径中的可聚焦 UIView 区域
- **蓝色**：搜索路径中的可聚焦 UIFocusGuide 地区

## 调试焦点级联（SwiftUI）

焦点级联——焦点快速循环遍历多个项目——是最难调试的 SwiftUI 焦点 bug。添加结构化日志来跟踪确切序列：

```swift
.onChange(of: focusedIndex) { old, new in
    logger.debug("[Focus] \(old.map(String.init) ?? "nil") → \(new.map(String.init) ?? "nil") active=\(activeIndex.map(String.init) ?? "nil")")
}
```

**级联日志中需要注意的内容：**
- `nil→0→nil→0→nil→0` = 穿透导航期间的瞬态焦点弹跳（见反模式 #29）
- `10→9→8→7→6→5→4→3→2→1→0` = `.disabled()` 批量切换的快速顺序级联（见反模式 #25）
- `0→10 scrollTo 10 10→9` = `scrollTo` 反馈循环干扰焦点（见反模式 #26）
- 重复设置相同值且 `active=` 不变 = `@Observable` 同值变更（见反模式 #27）

**生产调试日志模式：**
```swift
// ViewModel——记录状态转换
logger.debug("[Focus] displayedTopicIndex \(old) → \(new)")
logger.debug("[Load] loadTopic(\(index)) start — isLoading=true, clips cleared")
logger.debug("[Load] loadTopic(\(index)) complete — clips=\(clips.count)")

// View——记录焦点及周围状态
logger.debug("[Focus] sidebarFocus \(old) → \(new), isGridFocusable=\(isGridFocusable), clips=\(clips.count)")

// 侧边栏——记录容器焦点
logger.debug("[Focus] isContainerFocused \(isFocused)")

// 网格——记录正在渲染的内容
logger.debug("[Render] clips=\(clips.count), isLoading=\(isLoading), showing=\(clips.isEmpty ? (isLoading ? "skeleton" : "empty") : "grid")")
```

在开发期间保留这些日志——它们对调试模拟器中无法复现的设备上焦点问题非常宝贵。

## 常见焦点问题检查清单

### 焦点完全不动
1. 目标视图可聚焦吗？（`canBecomeFocused`，或它是 Button/Cell？）
2. 目标视图可见吗？（非隐藏、alpha > 0、在窗口中）
3. 目标及所有祖先的 `isUserInteractionEnabled = true`？
4. 从当前焦点到目标有几何路径吗？（用 Quick Look 查看）
5. 链中某处 `shouldUpdateFocus(in:)` 返回 false？

### 焦点跳到错误项目
1. 水平 ScrollView 上缺少 `.focusSection()`？
2. 项目几何对齐了吗？焦点遵循滑动方向的最近邻。
3. `remembersLastFocusedIndexPath` 与手动焦点管理冲突？
4. `preferredFocusEnvironments` 返回陈旧引用？

### 焦点抖动 / 视觉故障
1. 你在变换计算中使用 `frame.width`？缓存静止宽度。
2. `prepareForReuse()` 重置所有焦点相关视觉状态？
3. 焦点动画使用 `addCoordinatedFocusingAnimations`（而非普通 UIView.animate）？
4. 管理 `layer.zPosition` 防止重叠？
5. 阴影动画使用 `CABasicAnimation`（而非 UIView.animate）？

### 数据重载后焦点丢失
1. 动画期间调用 `reloadData()`？
2. `remembersLastFocusedIndexPath` + 离屏重载导致陈旧索引？
3. 重载期间 `shouldUpdateFocus(in:)` 阻止？
4. 重载后调用了 `setNeedsFocusUpdate()` + `updateFocusIfNeeded()`？
5. 从正确的焦点环境（包含聚焦视图的）调用？

### SwiftUI 焦点不工作
1. 使用 `focused($binding, equals:)` 时 `@FocusState` 是 Optional？
2. `.focusScope(namespace)` 在 `prefersDefaultFocus` 的祖先上？
3. `.focusSection()` 应用于容器，而非单个按钮？
4. 使用了 `.disabled()`？它从 tvOS 焦点链移除视图。改为在闭包内门控操作，或使用双重 `@FocusState` 门控（反模式 #25）。
5. 向 Button 添加了 `.focusable()`？移除它。

## 测试焦点

### UI 测试工具

```swift
extension XCUIRemote {
    func press(_ button: XCUIRemote.Button, times: Int) {
        for _ in 0..<times {
            press(button)
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
}

extension XCUIApplication {
    func focusedElement() -> XCUIElement {
        return descendants(matching: .any).element(matching: NSPredicate(format: "hasFocus == true"))
    }
}
```

### 焦点导航测试模式

```swift
func testFocusNavigationBetweenRows() {
    let remote = XCUIRemote.shared
    let app = XCUIApplication()

    // 导航到第一行项目
    remote.press(.select)
    XCTAssertTrue(app.buttons["Row 0 Item 0"].hasFocus)

    // 向下移动到第二行
    remote.press(.down)
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Row 1'")).firstMatch.hasFocus)

    // 向上移回
    remote.press(.up)
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Row 0'")).firstMatch.hasFocus)
}
```

### 重要：模拟器 vs 硬件

焦点行为在模拟器和 Apple TV 硬件之间不同：
- 模拟器允许方向键"按住"——硬件使用滑动手势
- 焦点动画时序不同
- 某些焦点边缘情况只在硬件上复现
- 始终在物理设备上验证关键焦点流程

## macOS 焦点调试

### 检查第一响应者

```
(lldb) po NSApp.keyWindow?.firstResponder
// 显示当前聚焦视图

(lldb) po NSApp.keyWindow?.firstResponder?.nextResponder
// 显示响应者链中的下一个
```

### 调试键视图循环

打印整个 Tab 顺序以验证正确性：

```swift
// 调试辅助——从 lldb 或调试按钮调用
func printKeyViewLoop(from window: NSWindow) {
    guard let first = window.initialFirstResponder ?? window.contentView else { return }
    var current: NSView? = first
    var visited = Set<ObjectIdentifier>()
    repeat {
        guard let view = current else { break }
        let id = ObjectIdentifier(view)
        if visited.contains(id) {
            print("→ (循环完成，回到 \(type(of: view)))")
            break
        }
        visited.insert(id)
        print("→ \(type(of: view)) canBecomeKeyView=\(view.canBecomeKeyView) acceptsFirstResponder=\(view.acceptsFirstResponder)")
        current = view.nextValidKeyView
    } while current != nil
}
```

### NSWindow.initialFirstResponder

```
(lldb) po window.initialFirstResponder
// 窗口首次打开时接收焦点的视图
// nil = 无视图获得自动焦点
```

如果 `initialFirstResponder` 为 nil，窗口打开时无聚焦视图。在 Interface Builder 或编程方式设置：

```swift
override func windowDidLoad() {
    super.windowDidLoad()
    window?.initialFirstResponder = searchField
}
```

### 常见 macOS 焦点调试检查清单

**视图不接受 Tab 焦点：**
1. `acceptsFirstResponder` 重写返回 `true`？
2. `canBecomeKeyView` 返回 `true`？
3. 视图隐藏、零 alpha 或不在窗口中？
4. 祖先的 `isHidden` 为 true？
5. 视图在键视图循环中？检查 `nextKeyView` 链。
6. `recalculatesKeyViewLoop` 启用且可能几何排除视图？

**焦点环不出现：**
1. `focusRingType` 设为 `.none`？
2. 应用了 `.focusEffectDisabled()`（SwiftUI）？
3. 非文本控件的完全键盘访问启用？
4. 视图实际是第一响应者？检查 `window.firstResponder`。

**sheet/alert 后焦点跳到错误视图：**
1. 显示 sheet 前保存了先前第一响应者？
2. 在完成处理器中调用了 `makeFirstResponder`？
3. 保存的视图仍在层次结构中？

**菜单项不响应聚焦内容：**
1. 视图层次结构上设置了 `focusedValue`？
2. Commands 中 `@FocusedValue` 读取正确键？
3. 视图在关键窗口中（非面板后面的主窗口）？
4. 多窗口需要 `focusedSceneValue`？

### 辅助功能检查器

使用辅助功能检查器（Xcode > Open Developer Tool > Accessibility Inspector）验证：
- 哪个元素有键盘焦点
- VoiceOver 正在读取哪个元素
- 元素是否正确标记
- 完全键盘访问的焦点顺序

### 使用通知调试

```swift
// 跟踪窗口中所有焦点更改
NotificationCenter.default.addObserver(
    forName: NSWindow.didBecomeKeyNotification,
    object: nil, queue: .main
) { note in
    let window = note.object as? NSWindow
    print("Key window: \(window?.title ?? "nil"), firstResponder: \(window?.firstResponder ?? "nil" as Any)")
}
```
