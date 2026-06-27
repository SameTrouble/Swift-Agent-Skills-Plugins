# 在 SwiftData 中使用 CloudKit

**这些规则仅适用于项目配置为在 SwiftData 中使用 CloudKit 的情况。**

- 永远不要使用 `@Attribute(.unique)` 或 `#Unique`；它们在 CloudKit 中*不*受支持，使用时会导致本地数据也失败。
- 所有模型属性必须始终要么有默认值，要么标记为可选型。
- 所有关系必须标记为可选型。
- 只要使用了正确的操作系统版本，CloudKit 中支持索引和子类。

请记住，CloudKit 专为*最终一致性*设计——任何以 CloudKit 支持编写的 SwiftData 代码，都必须能够在数据尚未同步时正常运行。
