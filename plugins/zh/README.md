# Swift Agent Skills（中文版）

本目录是 Swift-Agent-Skills 的中文插件包。技能内容由维护者手动翻译，按需从英文版同步并翻译。

## 中文技能清单

| 技能名 | 分类 | 状态 | 上游同步版本 |
|--------|------|------|-------------|
| _(暂无已翻译技能)_ | | | |

> 翻译完成后，请在此表格登记。

## 翻译流程

1. **拷贝**：从 `plugins/en/skills/<name>/` 拷贝到 `plugins/zh/skills/<name>/`
2. **翻译**：逐文件翻译 `SKILL.md` 和 `references/*.md`
3. **保留 frontmatter `name` 字段不变**：技能内部标识符保持英文（如 `name: swiftui-pro`），仅 `description` 翻译为中文
4. **代码示例不翻译**：Swift 代码、命令、文件路径保持原样
5. **提交**：commit message 标注语言，如 `zh: translate swiftui-pro`
6. **登记**：在本文件上方表格更新状态

## 上游同步

`scripts/sync.sh` 更新英文版后，维护者通过以下方式同步中文版：

```bash
git diff plugins/en/skills/<name>/
```

手动将变更同步到对应中文版。sync.sh 绝不触碰本目录（`plugins/zh/`）。

## 安装

见根目录 [README.md](../../README.md) 的中文安装说明。
