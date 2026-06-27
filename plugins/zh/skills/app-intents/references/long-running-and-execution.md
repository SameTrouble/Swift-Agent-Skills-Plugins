# 长时间运行 intent 和执行目标

WWDC 2026（27 发布）添加了三个 API，改变 intent 可以运行*多长时间*、*停止时发生什么*以及*哪个进程运行它*。它们是正交的——按需混合。

## 30 秒预算

当 intent 从 Siri、Shortcuts、小组件按钮或任何系统界面运行时，系统给它 **30 秒**完成。超过则被杀死。这对日常操作（切换设置、创建笔记、获取小列表）足够，但对上传、大文件操作、数据同步或设备端 ML 推理不够。

macOS 是例外——那里的后台任务无硬性时间限制。在 iOS、iPadOS、tvOS、visionOS 和 watchOS 上，除非采纳 `LongRunningIntent`，否则 30 秒上限适用。

## `LongRunningIntent`（iOS 27+）

`LongRunningIntent` 改进 `ProgressReportingIntent`。它延长后台执行时间并为你管理 App 的后台任务生命周期。进度自动呈现为带停止按钮的 **Live Activity**。

```swift
import AppIntents

struct UploadFileIntent: LongRunningIntent {
    static let title: LocalizedStringResource = "Upload Large File"

    @Parameter(title: "File")
    var file: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 将慢工作包装在 performBackgroundTask 中以获得扩展运行时。
        let result = try await performBackgroundTask {
            progress.totalUnitCount = 100
            progress.localizedDescription = "Uploading file"

            for chunk in 0..<100 {
                try Task.checkCancellation()
                await uploadChunk(chunk)
                progress.completedUnitCount = Int64(chunk + 1)
                progress.localizedAdditionalDescription = "\(chunk + 1)% complete"
            }
            return "Upload complete!"
        }

        return .result(value: result)
    }

    private func uploadChunk(_ chunk: Int) async { /* ... */ }
}
```

规则：

- **在 `performBackgroundTask { ... }` 内做慢工作。** 该闭包是在扩展预算下运行的部分。它外面的代码仍在正常限制下运行。
- **通过继承的 `progress` 属性定期报告进度**（`totalUnitCount`、`completedUnitCount`、`localizedDescription`、`localizedAdditionalDescription`）。如果你沉默，系统假设任务停滞并**提前取消运行时扩展**。进度报告在这里不是可选装饰——它是保持扩展存活的心跳。
- `progress` 是 Foundation `Progress` 对象（来自 `ProgressReportingIntent`，iOS 17+）。同一对象驱动 Live Activity。
- `performBackgroundTask(options:operation:)` 接受可选的 `LongRunningTaskOptions`；无参数形式是常见情况。

### 后台 GPU 访问

`LongRunningIntent` 可以在支持的设备上请求**后台 GPU 访问**——用于照片处理、设备端推理或其他在后台通常会被挂起的 Metal/Core ML 工作。向 App 添加 GPU 访问 entitlement；没有 entitlement，后台时 GPU 工作被节流。

### 何时使用

在 intent 可能超过 30 秒的那一刻采纳 `LongRunningIntent`。不要试图通过将工作分块到多个 intent 或分离非托管 `Task` 来赶时间——detached task 不受后台执行扩展覆盖，在 App 后台时被挂起。

## `CancellableIntent`（iOS 26.4+）

长时间运行的 intent *会*有时被取消——用户在 Live Activity 上点击停止、系统超时或需要回收资源。`CancellableIntent` 给你带**原因**的类型化回调，以便你可以优雅清理（回滚部分上传、取消进行中请求、保存中间状态）。

```swift
struct ProcessPaymentIntent: AppIntent, ProgressReportingIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Process Payment"

    @Parameter var amount: Decimal
    @Parameter var paymentMethod: PaymentMethod

    @Dependency var paymentService: PaymentService

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let transactionID = UUID()

        return try await withIntentCancellationHandler {
            try await paymentService.initiateTransaction(transactionID, amount: amount)
            try await paymentService.authorize(transactionID, method: paymentMethod)
            try await paymentService.process(transactionID)
            return .result(dialog: "Payment of \(amount) processed successfully.")
        } onCancel: { reason in
            switch reason {
            case .timeout:        try? await paymentService.rollback(transactionID, reason: "timeout")
            case .userCancelled:  try? await paymentService.cancel(transactionID, reason: "user_cancelled")
            default:              try? await paymentService.cancel(transactionID, reason: "unknown")
            }
        }
    }
}
```

注意：

- 将工作包装在 `withIntentCancellationHandler(operation:onCancel:isolation:)` 中。`onCancel` 闭包接收 `IntentCancellationReason`（`.timeout`、`.userCancelled`、...）。
- 如果你**不**关心原因，Swift 标准的 `withTaskCancellationHandler(handler:operation:)` 就够了——`CancellableIntent` 专门用于你需要原因*和*额外清理时间时。
- 系统可能因两种值得围绕设计的原因取消：intent 超过 30 秒未报告进度，或有人在 Siri / Live Activity / Shortcuts 中点击取消。
- **保持取消处理快速。** 除 macOS 外，进程在取消后不久仍可能被挂起——采纳协议买额外时间，但不是无限时间。做最少的事（回滚、持久化、记录）并返回。

`CancellableIntent` 和 `LongRunningIntent` 组合：一个也想优雅取消的长时间运行上传遵循两者。当 intent 采纳两者时，你不需要单独的 `withIntentCancellationHandler`——`performBackgroundTask` 本身接受尾随 `onCancel:` 闭包，因此扩展运行时工作及其清理位于一个调用中：

```swift
struct UploadPhotoIntent: LongRunningIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Upload Photo"

    @Parameter var photo: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await performBackgroundTask {
            let chunks = calculateChunks(for: photo)
            progress.totalUnitCount = Int64(chunks)

            for chunk in 1...chunks {
                try Task.checkCancellation()
                try await uploadChunk(chunk)
                progress.completedUnitCount = Int64(chunk)
            }
            return "Upload complete!"
        } onCancel: { reason in
            cleanup(for: reason)   // reason 是 IntentCancellationReason
        }
        return .result(dialog: "\(result)")
    }
}
```

## 执行目标：`allowedExecutionTargets`（iOS 27+）

随着 App 增长，intent 通常位于主 App *和*小组件扩展*和* App Intents 扩展都导入的**共享 Swift package 或框架**中。当请求到来时，系统必须选择一个进程来运行 intent。其默认启发式：如果主 App 已在运行则优先；否则启动更轻的扩展。

有时那是错的。经典案例：小组件对共享数据存储有只读访问权，主 App 拥有所有写入（两个进程写同一存储导致冲突）。小组件中的"favorite this"按钮*必须*在**主 App** 中运行其 intent，使写入落在正确位置。

`allowedExecutionTargets` 覆盖启发式：

```swift
struct FavoritePhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "Favorite Photo"
    static let isDiscoverable: Bool = false

    // 强制此 intent 在主 App 中运行，绝不在小组件扩展中，
    // 因为只有主 App 允许写共享存储。
    static var allowedExecutionTargets: IntentExecutionTargets { [.app] }

    @Parameter var photo: PhotoEntity
    @Dependency var library: PhotoLibrary

    func perform() async throws -> some IntentResult {
        try await library.toggleFavorite(photo.id)
        return .result()
    }
}
```

`IntentExecutionTargets` 让你针对主 App、App Intents 扩展、WidgetKit 扩展或任何组合。默认 intent 可针对任何 target 运行；仅设置此属性以约束它。

在以下情况决定 target：

- **写入所有权重要** - 将修改路由到拥有数据存储的单一进程；将读取留在最便宜的进程上。
- **依赖只在一个进程中存在** - 如果 intent 需要只在主 App 的 `App.init()` 中注册的东西，它不能在从未构建它的小组件扩展中运行。
- **成本重要** - 保持廉价只读 intent 对扩展合格（不启动 App），将主 App 保留给真正需要它的 intent。

参见 `dependencies.md` 了解这些 target 依赖的 App vs 扩展进程边界规则，以及 `open-and-snippet-intents.md` 了解小组件触发 intent 和小组件时间线提供者在不同进程中运行时的 App Group 共享模式。

## 快速参考

| 需求 | API | 最低 OS |
|---|---|---|
| 显示进度条；30 秒内完成 | `ProgressReportingIntent` | iOS 17 |
| 后台运行超过 30 秒 | `LongRunningIntent`（+ `performBackgroundTask`） | iOS 27 |
| 用取消原因清理 | `CancellableIntent`（+ `withIntentCancellationHandler`） | iOS 26.4 |
| 将 intent 固定到特定进程 | `allowedExecutionTargets` | iOS 27 |
| 有条件前台化 App | `supportedModes` + `continueInForeground`（参见 `fundamentals.md`） | iOS 26 |
