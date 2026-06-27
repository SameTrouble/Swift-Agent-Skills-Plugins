# 导航和呈现

- 根据情况使用 `NavigationStack` 或 `NavigationSplitView`；标记所有使用已弃用 `NavigationView` 的情况。
- 强烈优先使用 `navigationDestination(for:)` 来指定目标；标记所有应被替换的旧 `NavigationLink(destination:)` 模式的使用。
- 永远不要在同一个导航层级中混用 `navigationDestination(for:)` 和 `NavigationLink(destination:)`；这会导致严重问题。
- `navigationDestination(for:)` 必须每种数据类型只注册一次；标记重复项。


## 提醒、确认对话框和表单

- 始终将 `confirmationDialog()` 附加到触发对话框的用户界面上。这允许 Liquid Glass 动画从正确的源头开始。
- 如果提醒只有一个"OK"按钮，且该按钮仅用于关闭提醒，则可以完全省略：`.alert("Dismiss Me", isPresented: $isShowingAlert) { }`。
- 如果表单用于呈现可选数据，优先使用 `sheet(item:)` 而非 `sheet(isPresented:)`，以便安全解包可选值。
- 使用 `sheet(item:)` 配合一个将该项作为唯一初始化参数的视图时，优先使用 `sheet(item: $someItem, content: SomeView.init)` 而非 `sheet(item: $someItem) { someItem in SomeView(item: someItem) }`。
