# Explore 代理简报

三个审计代理并行运行——**在单条消息中通过多次 `Agent` 工具调用发送全部三个代理**，让它们真正并行化。下方的每份简报都是模板；在发送之前填入 `{PROJECT_PATH}`、`{HOT_SPOT_FILES}` 和 `{BUILD_WARNINGS}` 占位符。

三份简报都强制使用相同的逐条发现项格式，以便综合过程机械化：

```markdown
### <简短标题>
- 位置: <path>:<line-range>
- 问题: <observed>
- 原因: <impact>
- 行动: <recommended>
- 严重性: Critical | High | Medium | Low
```

> **关于编号的说明。** 代理返回的发现项*不带* `N.M` 子章节编号——由 `SKILL.md` 第 6 步的综合步骤在把发现项排入最终 `CODE_AUDIT.md` 时分配编号。不要让代理自己发明编号（三个代理之间会产生冲突），但综合者必须在最终报告的每个标题前添加 `N.M` 前缀。编号规则见 `report-template.md`。

---

## 代理 A —— 并发与 API 现代化

```
你正在审计位于 {PROJECT_PATH} 的 iOS/macOS Swift 应用，以生成一份全面的代码质量报告。你的范围是 **Swift 并发**和 **API 现代化**。

每条发现项必须包含：文件路径、行范围、一句话的"问题"、一句话的"原因"、以及一句话的推荐"行动"。不要提出代码；只指出问题。要详尽但具体。

排除这些目录: {EXCLUDED_DIRS}

项目上下文:
- iOS 部署目标: {IOS_TARGET}（例如 17+）。macOS 目标: {MACOS_TARGET}（如适用）。
- 编译器已发出以下警告（你并发审计的权威输入）:

{BUILD_WARNINGS}

你的任务:

1. **把每条编译器警告追踪**到其周边代码并解释根因。提出架构层面的修复（把某个类标记为 `@MainActor`、改为 actor、引入 Sendable 快照类型）——不要是代码改动。

2. **找出编译器可能遗漏的并发反模式**:
   - 在 async 函数内部使用 `DispatchQueue.main.async`（应改为 `await MainActor.run` 或 `@MainActor` 注解）
   - 没有取消处理的 `Task.detached` 用法
   - 存在 async 等价物的 completion-handler API（PhotoKit、AVFoundation、URLSession）
   - 可被直接 async 重载替代的 `withCheckedContinuation` 包装
   - 应改为 actor 的 `dispatchQueue.sync` / `.async` 模式
   - `nonisolated(unsafe)` 用法
   - 跨 actor 边界访问的单例

3. **为较旧的 API 找出 iOS 目标替代方案**:
   - PhotoKit / AVFoundation 中带 async 变体的 completion-handler 方法
   - 用 AVCaptureDevice.RotationCoordinator 代替 orientation 枚举
   - `@Observable` 迁移完整性（是否有残留的 `ObservableObject` / `@Published`）
   - URLSession async-await
   - 用 `UIApplication.shared.connectedScenes` 代替 `.windows`
   - 任何 `@available(iOS X.0, *)` 守卫中 X 已低于部署目标的情况

4. **仔细阅读这些热点文件**（不要只是 grep）:
{HOT_SPOT_FILES}

5. **把回复格式化为发现项列表**，每个问题一条，使用上方模板。追求完整而非简短。如果同一个问题在多个调用点出现，在一条发现项下列出多个位置。
```

---

## 代理 B —— 死代码、重复代码、重构候选

```
你正在审计位于 {PROJECT_PATH} 的 iOS/macOS Swift 应用，以生成一份全面的代码质量报告。你的范围是 **死代码、重复代码和重构候选**。

每条发现项必须包含：文件路径、行范围、一句话的"问题"、"原因"和推荐"行动"。要详尽但具体。

排除这些目录: {EXCLUDED_DIRS}

项目上下文:
- 跨 {FILE_COUNT} 个 Swift 文件约 {LOC} LOC，多 target Xcode 项目。该代码库已增量开发了数年。
- 已知疑似过时的文件（请核实并标注）: {KNOWN_STALE_FILES}
- 已知重复的辅助工具（作为寻找其他重复项的范本）: {KNOWN_DUPLICATES}

你的任务:

1. **找出 `#if false` 块和被注释掉的替代实现。** 用 grep 定位 `#if false` 区域和连续的 `//` 注释 Swift 代码块。针对每一处：file:line、意图推测（过时 vs 有意的 A/B 方案）、建议（删除 vs 保留并加 TODO）。

2. **找出跨文件的重复辅助工具。** 具体寻找:
   - 图像编码/解码辅助（CIImage → JPEG/PNG、UIImage 解码/方向）
   - 缩略图创建
   - 方向转换（CGImagePropertyOrientation ↔ UIImage.Orientation）
   - 调色板 / 模型序列化
   - 文件路径 / Documents 目录构造
   - JSON 编码/解码包装
   - 相册相簿查找 / 创建
   - 其他在 2 个以上文件中逐字出现的内容

3. **找出超大文件**（>500 行）。针对每个，提出合理的拆分方案（例如"把 delegate 方法抽到 `Foo+AVCaptureDelegate.swift`"）。

4. **找出 TODO/FIXME/HACK/XXX/`#warning` 标记。** 每个都要有 file:line 和一行关于待办内容的摘要。

5. **找出过时文件 / 未使用代码**:
   - 文件名中带 `_OLD`、`Old_`、`_v1`/`_v2`、`Legacy`、`Deprecated` 的文件
   - 大部分/全部内容被 `#if false` 掉的文件
   - 任何地方都没有被引用的类型/方法（通过 grep 快速交叉引用）
   - 文件名拼写错误（例如 `Extensinos.swift` 应为 `Extensions.swift`）

6. **找出命名 / 组织不一致。** 符号名拼写错误、文件放错文件夹、文件组织约定混乱。

7. **找出未受 `#if DEBUG` 保护的 `print()` 调用。** 按文件分组并附计数；标注任何包裹敏感数据的。

8. **找出应被命名的临时魔法常量**（图像尺寸、JPEG 质量、重试次数、硬编码 URL 字符串、相簿名称）。

9. **把回复格式化为发现项列表**，使用上方模板。如果某个类别有许多实例，列出最具体的 5-10 个示例加上其余的计数。
```

---

## 代理 C —— 缺陷、逻辑错误、安全、性能

```
你正在审计位于 {PROJECT_PATH} 的 iOS/macOS Swift 应用，以生成一份全面的代码质量报告。你的范围是 **缺陷、逻辑错误、安全和性能**。

每条发现项必须包含：文件路径、行范围、一句话的"问题"、"原因"和推荐"行动"。要详尽但具体。

排除这些目录: {EXCLUDED_DIRS}

项目上下文:
- 应用类型: {APP_TYPE}（例如带抖动的相机应用、效率应用等）
- Targets: {TARGET_LIST}
- API: {API_LAYER_DESCRIPTION}（例如与 dev/prod 端点通信的 tRPC 客户端）
- IAP: {IAP_DESCRIPTION}（例如 StoreKit 2 / RevenueCat）
- 用户标注需额外审查的子系统: {USER_FLAGGED_SUBSYSTEMS}

你的任务:

1. **缺陷和逻辑错误。** 仔细阅读这些热点文件（不要只是 grep）:

{HOT_SPOT_FILES}

   寻找:
   - 对可选值的**强制解包（`!`）**——尤其在 init 路径、`UIImage(data:)!`、`URL(string:)!`、`Bundle.main.url(forResource:)!`
   - **强制 try（`try!`）**和**强制转换（`as!`）**，尤其在静态初始化器中
   - 非调试代码路径中的 **`fatalError`**
   - **未检查的数组索引**（例如 `arr[0]`、`palette[i]` 没有边界检查）
   - **吞掉错误的 `catch { }`** 块
   - **缺失的授权处理**——`.limited` Photos 授权、`.denied`、`.notDetermined`
   - 闭包中的**循环引用**（本应加 `[weak self]` 却没加）
   - **竞态条件**——本应在主线程却不在（或反之）的工作；创建后立即获取的竞态
   - **异步取消**——长运行 Task 本应是可取消的
   - PhotoKit 内容编辑中的**格式 / UTI 不匹配**
   - **状态初始化路径**——对传入值声明的 `@State`（会静默忽略更新）

2. **安全:**
   - 硬编码的密钥、API key、令牌——grep `Bearer`、`apiKey`、`secret`、`Authorization`、base64 数据块
   - 授权令牌存储（Keychain vs UserDefaults vs 内存）
   - 调试与生产 URL 切换机制——是否仅由 `#if DEBUG` 控制？（危险——发布构建可能发到 dev）
   - 写入磁盘的用户数据——位置是否合理（Documents vs Caches vs Application Support）？
   - 调试日志 / zip 导出——验证它们不包含 PII、设备 ID、IAP 凭证
   - 各 target 的 entitlements 文件

3. **性能:**
   - 渲染管线中的**每帧分配**（每次 `outputImage` 调用都分配缓冲区的 Metal/CoreImage 滤镜）
   - **`CIContext` 生命周期**——每次渲染都新建 `CIContext()` 很昂贵
   - 滑块拖动 / 实时编辑期间的**重复 JPEG/PNG 重编码**
   - **仅为元数据做全图解码**（用 `UIImage(data:)` 提取方向，而 `CGImageSource` 更便宜）
   - 主线程上的**同步 PhotoKit / 大集合获取**
   - 参数变更时的 **AVCapture 会话重配置抖动**
   - **SwiftUI 视图 body 中的重工作**（本应缓存的格式化器、排序、解码）

4. **把回复格式化为发现项列表**，使用上方模板。

严重性指南:
- **Critical** = 很可能导致崩溃、数据丢失或安全暴露。
- **High** = 用户能触发的真实缺陷；安全问题（令牌泄漏等）；阻塞未来构建的已弃用 API。
- **Medium** = 性能问题、重构候选、缺失的现代化。
- **Low** = 代码风格、命名、单次出现的清理。

如果单一根因在多个位置出现，在一条发现项下列出多个位置。
```

---

## 占位符发现（如何填充模板）

| 占位符 | 如何获取 |
|---|---|
| `{PROJECT_PATH}` | 当前工作目录。 |
| `{EXCLUDED_DIRS}` | 阅读 `CLAUDE.md` 中的"请勿编辑"/归档目录；常见项：`Dead/`、`Pods/`、`.build/`。 |
| `{IOS_TARGET}` / `{MACOS_TARGET}` | `grep -h "IPHONEOS_DEPLOYMENT_TARGET\|MACOSX_DEPLOYMENT_TARGET" *.xcodeproj/project.pbxproj \| sort -u` |
| `{BUILD_WARNINGS}` | `mcp__xcode__XcodeListNavigatorIssues` 或 `xcodebuild ... 2>&1 \| grep warning:` 去重后的输出。 |
| `{LOC}` / `{FILE_COUNT}` | `find . -name "*.swift" -not -path "./Dead/*" \| xargs wc -l \| tail -1` |
| `{KNOWN_STALE_FILES}` | `find . -name '*OLD*' -o -name '*_OLD*' -o -name 'Old_*'` 加上对文件顶部 `#if false` 的快速 grep。 |
| `{KNOWN_DUPLICATES}` | 可选——首次运行时留空。如果你之前审计过该代码库，用已知的重复路径作为代理 B 的种子。 |
| `{HOT_SPOT_FILES}` | `find . -name '*.swift' -exec wc -l {} \; \| sort -rn \| head -10` 的前 10 项，加上 CLAUDE.md 中点名的核心状态文件。 |
| `{APP_TYPE}` / `{TARGET_LIST}` / `{API_LAYER_DESCRIPTION}` / `{IAP_DESCRIPTION}` | 阅读 CLAUDE.md 和项目 README。 |
| `{USER_FLAGGED_SUBSYSTEMS}` | 用户请求审计时提到的任何内容。如未指定，留空。 |
