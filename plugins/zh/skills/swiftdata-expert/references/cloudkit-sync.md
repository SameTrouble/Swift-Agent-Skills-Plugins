# CloudKit 同步

## 所需能力

SwiftData 自动同步需要：

- 带 CloudKit 容器的 iCloud 能力，
- 带远程通知的 Background Modes。

两者缺一，自动的服务器驱动更新就不完整。

## 兼容性约束

CloudKit 支持并非覆盖所有 SwiftData 功能。

- 启用同步前审查 schema 兼容性。
- 唯一性约束和非可选关系是已记录的限制，需加以考虑。
- 在推进到生产前仔细规划 schema。

重要生产规则：

- CloudKit 生产 schema 在推广后仅支持增量式变更。

## 容器选择

默认行为：

- SwiftData 读取 entitlements 并使用第一个发现的容器。

显式选择：

```swift
let config = ModelConfiguration(
    cloudKitDatabase: .private("iCloud.com.example.MyApp")
)
```

禁用 SwiftData 自动同步：

```swift
let config = ModelConfiguration(cloudKitDatabase: .none)
```

对于已使用 CloudKit 且 schema 假设不兼容的应用，使用 `.none`。

## 开发 Schema 初始化

对于开发中的初始化工作流：

1. 从 SwiftData 存储 URL 构建存储描述。
2. 配置 `NSPersistentCloudKitContainerOptions`。
3. 同步加载存储。
4. 初始化 CloudKit schema。
5. 在构造 SwiftData `ModelContainer` 之前卸载存储。

仅在 debug/非生产代码路径中运行此工作流。

## 验证清单

- CloudKit 容器在 Apple Developer 配置中可见且正确。
- 设备能接收后台远程通知。
- 开发 schema 已初始化并在 CloudKit Dashboard 中检查。
- 在生产推广前验证多设备写入/读取场景。

## 主要文档

- https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
- https://developer.apple.com/documentation/swiftdata/modelconfiguration
- https://developer.apple.com/documentation/swiftdata/modelcontainer
