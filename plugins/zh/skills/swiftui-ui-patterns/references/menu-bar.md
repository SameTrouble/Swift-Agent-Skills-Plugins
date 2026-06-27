# 菜单栏

## 意图

在使用 SwiftUI 命令添加或自定义 macOS/iPadOS 菜单栏时使用此模式。

## 核心模式

- 在 `Scene` 层级用 `.commands { ... }` 添加命令。
- 当 UI 包含导航侧边栏时用 `SidebarCommands()`。
- 用 `CommandMenu` 做应用专属菜单并分组相关操作。
- 用 `CommandGroup` 在系统组之前/之后插入项或替换它们。
- 用 `FocusedValue` 做依赖活跃场景的上下文敏感菜单项。

## 示例：基础命令菜单

```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .commands {
      CommandMenu("Actions") {
        Button("Run", action: run)
          .keyboardShortcut("R")
        Button("Stop", action: stop)
          .keyboardShortcut(".")
      }
    }
  }

  private func run() {}
  private func stop() {}
}
```

## 示例：插入和替换组

```swift
WindowGroup {
  ContentView()
}
.commands {
  CommandGroup(before: .systemServices) {
    Button("Check for Updates") { /* open updater */ }
  }

  CommandGroup(after: .newItem) {
    Button("New from Clipboard") { /* create item */ }
  }

  CommandGroup(replacing: .help) {
    Button("User Manual") { /* open docs */ }
  }
}
```

## 示例：聚焦菜单状态

```swift
@Observable
final class DataModel {
  var items: [String] = []
}

struct ContentView: View {
  @State private var model = DataModel()

  var body: some View {
    List(model.items, id: \.self) { item in
      Text(item)
    }
    .focusedSceneValue(model)
  }
}

struct ItemCommands: Commands {
  @FocusedValue(DataModel.self) private var model: DataModel?

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("New Item") {
        model?.items.append("Untitled")
      }
      .disabled(model == nil)
    }
  }
}
```

## 菜单栏与设置

- 定义 `Settings` 场景会在 macOS 上自动添加"设置"菜单项。
- 如果需要应用内的自定义入口点，用 `OpenSettingsAction` 或 `SettingsLink`。

## 陷阱

- 避免在多个命令组中注册同一键盘快捷键。
- 不要把菜单项作为关键功能的唯一可发现入口点。
