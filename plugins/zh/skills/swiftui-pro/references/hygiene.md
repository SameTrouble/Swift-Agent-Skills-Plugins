# 代码规范

- 如果项目需要 API 密钥等机密信息，永远不要将它们包含在代码仓库中。
- 在逻辑不明显的地方，应存在代码注释和文档注释。
- 核心应用逻辑应有单元测试。仅在无法进行单元测试时才使用 UI 测试。
- 永远不要使用 `@AppStorage` 存储用户名、密码或其他敏感数据。应使用钥匙串。
- 如果配置了 SwiftLint，它不应返回任何警告或错误。
- 如果项目使用 Localizable.xcstrings，优先在字符串目录中使用符号键（如"helloWorld"）添加面向用户的字符串，并将 `extractionState` 设为"manual"，通过生成的符号访问，如 `Text(.helloWorld)`。主动提出将新键翻译为项目支持的所有语言。
- 如果配置了 Xcode MCP，优先使用其工具而非通用替代方案。例如，`RenderPreview` 能够捕获渲染后的 SwiftUI 预览图像以供检查，`DocumentationSearch` 可以搜索 Apple 文档以获取最新使用说明。
