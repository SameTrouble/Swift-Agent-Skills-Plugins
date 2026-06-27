# Figma MCP 参考

假设 Figma MCP 服务器已连接并正常工作。

## 远程 vs 桌面 MCP

**远程 MCP**（mcp.figma.com）——标准设置。需要 Figma URL 中的 fileKey 和 nodeId。

**桌面 MCP** ——直接连接 Figma 桌面应用：
- 无需 fileKey（使用当前打开的文件）
- 支持基于选区的提示（在 Figma 中选择节点，然后调用工具）
- 需要 Figma 桌面应用运行
- 仅适用于当前打开的文件

## 排障

get_design_context 返回空：
- 验证 nodeId 在文件中存在
- 先尝试 get_metadata 确认结构
- 检查文件权限

资源未下载：
- MCP 在活跃会话期间通过 localhost 提供资源
- 如果 localhost URL 失败，会话可能已过期
- 重新运行 get_design_context 刷新

响应太大：
- 先使用 get_metadata 查看节点结构
- 逐个获取子节点
- 每次专注于一个区块
