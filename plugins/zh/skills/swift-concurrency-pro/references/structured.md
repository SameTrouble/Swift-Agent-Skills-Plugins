# 结构化并发

## `async let` 与任务组

当你有固定数量的、返回不同类型的独立操作时使用 `async let`，例如同时获取新闻、天气和应用更新。当你有动态数量的同类型操作时使用任务组，例如下载 URL 数组中的所有图片。


## 任务组优于循环

在循环中使用非结构化任务通常是个坏主意；优先使用任务组。

```swift
// 错误：没有取消传播，无法 await 所有结果，失败时泄漏任务。
for url in urls {
    Task { try await fetch(url) }
}

// 正确：结构化、可取消、收集结果。
let results = try await withThrowingTaskGroup { group in
    for url in urls {
        group.addTask { try await fetch(url) }
    }

    var collected = [Data]()
    for try await result in group {
        collected.append(result)
    }
    return collected
}
```


## `withDiscardingTaskGroup`（Swift 5.9+）

当子任务不返回有意义的结果（即发即弃）时，使用 `withDiscardingTaskGroup` 替代 `withTaskGroup`。它避免在内存中累积未使用的结果。

```swift
// 适用于仅有副作用的子任务
await withDiscardingTaskGroup { group in
    for connection in connections {
        group.addTask { await connection.sendHeartbeat() }
    }
}
```


## 限制并发

任务组会急切地启动所有子任务，这可能并不理想。在合适时考虑手动限制并发：

```swift
try await withThrowingTaskGroup { group in
    let maxConcurrent = 4
    var iterator = urls.makeIterator()

    // 启动初始批次
    for _ in 0..<maxConcurrent {
        guard let url = iterator.next() else { break }
        group.addTask { try await fetch(url) }
    }

    // 每完成一个，启动下一个
    for try await result in group {
        process(result)
        if let url = iterator.next() {
            group.addTask { try await fetch(url) }
        }
    }
}
```


## 带部分结果的错误处理

当一个子任务抛出错误时，任务组会取消所有剩余子任务。如果你需要部分结果，在每个子任务内部捕获错误：

```swift
await withTaskGroup(of: (URL, Result<Data, Error>).self) { group in
    for url in urls {
        group.addTask {
            do {
                return (url, .success(try await fetch(url)))
            } catch {
                return (url, .failure(error))
            }
        }
    }

    for await (url, result) in group {
        switch result {
        case .success(let data): handle(data)
        case .failure(let error): log(error, for: url)
        }
    }
}
```


## 推断任务组的类型

Swift 通常能够推断任务组的类型，但并非总是如此。像 `String`、`URL`、`Data` 等简单类型通常没问题，但上面的示例使用了 `withTaskGroup(of: (URL, Result<Data, Error>).self)`，这是一个需要显式指定类型的例子——Swift 无法推断出它。
