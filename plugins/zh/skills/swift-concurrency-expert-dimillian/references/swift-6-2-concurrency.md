## Swift 6.2 中的并发编程更新

并发编程很困难，因为在多个任务之间共享内存容易出错，从而导致不可预测的行为。

## 数据竞争安全

Swift 6 的数据竞争安全在编译时防止了这些错误，因此你可以编写并发代码而不必担心引入难以调试的运行时 bug。但在许多情况下，最自然的写法容易产生数据竞争，从而导致你必须处理的编译器错误。一个带有可变状态的类，例如这个 `PhotoProcessor` 类，只要你不并发访问它就是安全的。

```swift
class PhotoProcessor {
  func extractSticker(data: Data, with id: String?) async -> Sticker? {     }
}

@MainActor
final class StickerModel {
  let photoProcessor = PhotoProcessor()

  func extractSticker(_ item: PhotosPickerItem) async throws -> Sticker? {
    guard let data = try await item.loadTransferable(type: Data.self) else {
      return nil
    }

    // Error: Sending 'self.photoProcessor' risks causing data races
    // Sending main actor-isolated 'self.photoProcessor' to nonisolated instance method 'extractSticker(data:with:)'
    // risks causing data races between nonisolated and main actor-isolated uses
    return await photoProcessor.extractSticker(data: data, with: item.itemIdentifier)
  }
}
```

它有一个 async 方法，通过计算给定图像数据的主体来提取 `Sticker`。但如果你尝试从 main actor 上的 UI 代码调用 `extractSticker`，你会收到一个错误，提示该调用有引发数据竞争的风险。这是因为语言中有几处会隐式地将工作卸载到后台，即使你从未需要代码并行运行。

Swift 6.2 改变了这一理念：默认保持单线程，直到你选择引入并发。

```swift
class PhotoProcessor {
  func extractSticker(data: Data, with id: String?) async -> Sticker? {     }
}

@MainActor
final class StickerModel {
  let photoProcessor = PhotoProcessor()

  func extractSticker(_ item: PhotosPickerItem) async throws -> Sticker? {
    guard let data = try await item.loadTransferable(type: Data.self) else {
      return nil
    }

    // No longer a data race error in Swift 6.2 because of Approachable Concurrency and default actor isolation
    return await photoProcessor.extractSticker(data: data, with: item.itemIdentifier)
  }
}
```

Swift 6.2 的语言改动使最自然的写法默认就是无数据竞争的。这为在项目中引入并发提供了一条更平易近人的路径。

当你因希望代码并行运行而选择引入并发时，数据竞争安全会保护你。

首先，我们让在带有可变状态的类型上调用 async 函数变得更容易。不再急切地卸载不绑定到特定 actor 的 async 函数，该函数将继续在调用它的 actor 上运行。这消除了数据竞争，因为传入 async 函数的值永远不会被发送到 actor 之外。async 函数仍可在其实现中卸载工作，但调用方不必担心它们自己的可变状态。

接下来，我们让在 main actor 类型上实现一致性变得更容易。这里我有一个名为 `Exportable` 的协议，我正试图为我的 main actor `StickerModel` 类实现一致性。export 要求没有 actor 隔离，因此语言假定它可以从 main actor 之外调用，并阻止 `StickerModel` 在其实现中使用 main actor 状态。

```swift
protocol Exportable {
  func export()
}

extension StickerModel: Exportable { // error: Conformance of 'StickerModel' to protocol 'Exportable' crosses into main actor-isolated code and can cause data races
  func export() {
    photoProcessor.exportAsPNG()
  }
}
```

Swift 6.2 支持这些一致性。需要 main actor 状态的一致性被称为*隔离的*一致性。这是安全的，因为编译器确保 main actor 一致性只在 main actor 上使用。

```swift
// Isolated conformances

protocol Exportable {
  func export()
}

extension StickerModel: @MainActor Exportable {
  func export() {
    photoProcessor.exportAsPNG()
  }
}
```

我可以创建一个 `ImageExporter` 类型，只要它留在 main actor 上，就可以将 `StickerModel` 添加到任何 `Exportable` 项的数组中。

```swift
 // Isolated conformances

@MainActor
struct ImageExporter {
  var items: [any Exportable]

  mutating func add(_ item: StickerModel) {
    items.append(item)
  }

  func exportAll() {
    for item in items {
      item.export()
    }
  }
}
```

但如果我允许 `ImageExporter` 从任何地方使用，编译器会阻止将 `StickerModel` 添加到数组中，因为从 main actor 之外对 `StickerModel` 调用 export 是不安全的。

```swift
// Isolated conformances

nonisolated
struct ImageExporter {
  var items: [any Exportable]

  mutating func add(_ item: StickerModel) {
    items.append(item) // error: Main actor-isolated conformance of 'StickerModel' to 'Exportable' cannot be used in nonisolated context
  }

  func exportAll() {
    for item in items {
      item.export()
    }
  }
}
```

有了隔离的一致性，你只需在代码表明它并发使用该一致性时解决数据竞争安全问题。

## 全局状态

全局和静态变量容易产生数据竞争，因为它们允许从任何地方访问可变状态。

```swift
final class StickerLibrary {
  static let shared: StickerLibrary = .init() // error: Static property 'shared' is not concurrency-safe because non-'Sendable' type 'StickerLibrary' may have shared mutable state
}
```

保护全局状态最常见的方式是使用 main actor。

```swift
final class StickerLibrary {
  @MainActor
  static let shared: StickerLibrary = .init()
}
```

用 main actor 标注整个类来保护其所有可变状态也很常见，尤其是在没有太多并发任务的项目中。

```swift
@MainActor
final class StickerLibrary {
  static let shared: StickerLibrary = .init()
}
```

你可以通过在项目中的所有内容上写 `@MainActor` 来建模一个完全单线程的程序。

```swift
@MainActor
final class StickerLibrary {
  static let shared: StickerLibrary = .init()
}

@MainActor
final class StickerModel {
  let photoProcessor: PhotoProcessor

  var selection: [PhotosPickerItem]
}

extension StickerModel: @MainActor Exportable {
  func export() {
    photoProcessor.exportAsPNG()
  }
}
```

为了更方便地建模单线程代码，我们引入了一种默认推断 main actor 的模式。

```swift
// Mode to infer main actor by default in Swift 6.2

final class StickerLibrary {
  static let shared: StickerLibrary = .init()
}

final class StickerModel {
  let photoProcessor: PhotoProcessor

  var selection: [PhotosPickerItem]
}

extension StickerModel: Exportable {
  func export() {
    photoProcessor.exportAsPNG()
  }
}
```

这消除了关于不安全全局和静态变量、对其他 main actor 函数（如来自 SDK 的函数）的调用等的数据竞争安全错误，因为 main actor 默认保护所有可变状态。它还减少了大部分为单线程的代码中的并发标注。这种模式非常适合在 main actor 上完成大部分工作的项目，且并发代码封装在特定类型或文件中。它是可选启用的，并推荐用于应用、脚本和其他可执行目标。

## 将工作卸载到后台

出于性能考虑，将工作卸载到后台仍然很重要，例如在执行 CPU 密集型任务时保持应用响应。

我们来看 `PhotoProcessor` 上 `extractSticker` 方法的实现。

```swift
// Explicitly offloading async work

class PhotoProcessor {
  var cachedStickers: [String: Sticker]

  func extractSticker(data: Data, with id: String) async -> Sticker {
      if let sticker = cachedStickers[id] {
        return sticker
      }

      let sticker = await Self.extractSubject(from: data)
      cachedStickers[id] = sticker
      return sticker
  }

  // Offload expensive image processing using the @concurrent attribute.
  @concurrent
  static func extractSubject(from data: Data) async -> Sticker { }
}
```

它首先检查是否已经为某张图像提取过贴纸，以便能立即返回缓存的贴纸。如果贴纸尚未缓存，它就从图像数据中提取主体并创建新贴纸。`extractSubject` 方法执行昂贵的图像处理，我不希望它阻塞 main actor 或任何其他 actor。

我可以使用 `@concurrent` 标注来卸载这项工作。`@concurrent` 确保函数始终运行在并发线程池上，从而释放 actor 以同时运行其他任务。

### 一个示例

假设你有一个名为 `process` 的函数，希望它在后台线程上运行。要在后台线程上调用该函数，你需要：

- 确保结构体或类是 `nonisolated`
- 为希望在后运行的函数添加 `@concurrent` 标注
- 如果函数还不是异步的，添加 `async` 关键字
- 然后为所有调用方添加 `await` 关键字

像这样：

```swift
nonisolated struct PhotoProcessor {

    @concurrent
    func process(data: Data) async -> ProcessedPhoto? { ... }
}

// Callers with the added await
processedPhotos[item.id] = await PhotoProcessor().process(data: data)
```


## 总结

这些语言改动协同工作，使并发更加平易近人。

你从编写默认在 main actor 上运行的代码开始，那里没有数据竞争风险。当你开始使用 async 函数时，这些函数在调用它们的地方运行。仍然没有数据竞争风险，因为你所有的代码仍运行在 main actor 上。当你准备好拥抱并发以提升性能时，可以轻松地将特定代码卸载到后台并行运行。

其中一些语言改动是可选启用的，因为它们需要项目做出更改才能采用。你可以在 Xcode 构建设置的 Swift Compiler - Concurrency 部分下找到并启用所有 approachable concurrency 语言改动。你也可以使用 SwiftSettings API 在 Swift 包清单文件中启用这些功能。

Swift 6.2 包含迁移工具，帮助你自动完成必要的代码改动。你可以在 swift.org/migration 了解更多关于迁移工具的信息。
