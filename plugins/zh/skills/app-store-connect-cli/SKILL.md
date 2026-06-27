---
name: asc-cli-usage
description: 在本仓库中使用 asc cli 的指导（标志、输出格式、分页、认证与命令发现）。当被要求运行或设计 asc 命令、或通过 CLI 与 App Store Connect 交互时使用。
---

# asc cli 使用指南

当你需要为 App Store Connect 运行或设计 `asc` 命令时，使用此技能。

## 命令发现
- 始终使用 `--help` 来发现命令和标志。
  - `asc --help`
  - `asc builds --help`
  - `asc builds list --help`
- 当你了解工作流程但不清楚命令路径时，使用 `asc search` 进行本地、确定性的命令发现。
  - `asc search "submit app for review"`
  - `asc search --output table "upload build"`
- 在设计面向 API 的命令之前，使用 `asc schema` 检查内置的 App Store Connect 端点架构以及请求/查询字段。
  - `asc schema --pretty "GET /v1/apps"`
  - `asc schema --method POST appStoreVersions`
- 使用 `asc capabilities` 查看 CLI 支持的、部分支持的、仅网页端的以及受公共 API 限制的工作流程覆盖范围。
  - `asc capabilities --area release --output table`
  - `asc capabilities --status not-public-api --output markdown`

## 规范动词（当前 asc）
- 在文档和自动化中，只读命令优先使用 `view` 而非旧版 `get` 别名。
  - `asc apps view --id "APP_ID"`
  - `asc versions view --version-id "VERSION_ID"`
  - `asc pricing availability view --app "APP_ID"`
- 仅更新可用性范围及其他规范编辑流程优先使用 `edit`。
  - `asc pricing availability edit --app "APP_ID" --territory "USA,GBR" --available true`
  - `asc app-setup availability edit --app "APP_ID" --territory "USA,GBR" --available true`
  - `asc xcode version edit --build-number "42"`
- 当 CLI 有意建模更高层的替换/配置流程，且 `--help` 仍将 `set` 显示为规范动词时，保留 `set`。

## 标志约定
- 使用显式的长标志（例如 `--app`、`--output`）。
- 在自动化中优先使用显式标志；一些较新的命令在交互式运行时可能会提示输入缺失字段。
- 破坏性操作需要 `--confirm`。
- 当用户需要所有分页时使用 `--paginate`。

## 输出格式
- 输出默认值支持 TTY 感知：交互式终端中使用 `table`，管道或非交互式环境下使用 `json`。
- 仅在需要人类可读输出时使用 `--output table` 或 `--output markdown`。
- `--pretty` 仅对 JSON 输出有效。

## 认证与默认值
- 优先通过 `asc auth login` 使用钥匙串认证。
- 回退环境变量：`ASC_KEY_ID`、`ASC_ISSUER_ID`、`ASC_PRIVATE_KEY_PATH`、`ASC_PRIVATE_KEY`、`ASC_PRIVATE_KEY_B64`。
- `ASC_APP_ID` 可提供默认的 App ID。
- 当权限不明确时，使用 `asc web auth capabilities` 检查 API 密钥角色的确切覆盖范围。
  - 它位于实验性网页认证接口下。
  - 默认可解析当前本地认证，或通过 `--key-id` 检查特定密钥。

## Apple Ads
- 在选择命令之前使用 `asc ads --help`。
- Apple Ads 使用 `asc ads auth`、`--ads-profile` 和 `ASC_ADS_*` 变量。它不使用 App Store Connect API 凭证。
- 除非已知组织 ID，否则使用 `asc ads acls --output json` 解析组织访问权限。
- 大多数端点命令需要 `--org` 或 `ASC_ADS_ORG_ID`。
- Body 命令使用 `--file` 传入 Apple Ads JSON 载荷。对象端点需要 JSON 对象。批量端点通常需要 JSON 数组。
- 仅在 help 显示该标志时使用 `--paginate`。报告和选择器载荷在 JSON 文件内部携带分页信息。
- 破坏性命令和批量删除命令需要 `--confirm`。
- 对于实时变更测试，使用明确的测试名称创建暂停状态的资源，并在完成后删除父级广告系列。

## 超时
- `ASC_TIMEOUT` / `ASC_TIMEOUT_SECONDS` 控制请求超时。
- `ASC_UPLOAD_TIMEOUT` / `ASC_UPLOAD_TIMEOUT_SECONDS` 控制上传超时。
