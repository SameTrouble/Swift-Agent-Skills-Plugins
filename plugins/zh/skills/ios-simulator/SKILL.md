---
name: ios-simulator-skill
version: 1.5.0
description: 29 个生产级脚本，用于 iOS 应用测试、构建与自动化。提供语义化 UI 导航、构建自动化、无障碍测试与模拟器生命周期管理。针对 AI 代理优化，输出精简、token 占用低。
---

# iOS 模拟器技能

使用基于无障碍树的导航和结构化数据来构建、测试和自动化 iOS 应用，而非依赖像素坐标。

## 快速开始

```bash
# 1. 检查环境
bash scripts/sim_health_check.sh

# 2. 启动应用
python scripts/app_launcher.py --launch com.example.app

# 3. 映射屏幕以查看元素
python scripts/screen_mapper.py

# 4. 点击按钮
python scripts/navigator.py --find-text "Login" --tap

# 5. 输入文本
python scripts/navigator.py --find-type TextField --enter-text "user@example.com"
```

所有脚本都支持 `--help` 查看详细选项，支持 `--json` 输出机器可读格式。

## 导航策略

**导航时始终优先使用无障碍树而非截图。** 无障碍树提供元素类型、标签、坐标框和点击目标——这些结构化数据比图像分析更廉价、更可靠。

按以下优先级使用：
1. `screen_mapper.py` → 结构化元素列表（5-7 行，约 10 tokens）
2. `navigator.py --find-text/--find-type/--find-id` → 语义化交互
3. 截图 → 仅用于视觉验证、缺陷报告或视觉差异对比

截图根据尺寸消耗 1,600–6,300 tokens。无障碍树在默认模式下仅消耗 10–50 tokens。

## 29 个生产级脚本

### 构建与开发（2 个脚本）

1. **build_and_test.py** - 构建 Xcode 项目、运行测试，通过渐进式信息披露解析结果
   - 实时流式构建结果
   - 从 xcresult 包中解析错误和警告
   - 按需获取详细构建日志
   - 选项：`--project`、`--scheme`、`--clean`、`--test`、`--verbose`、`--json`

2. **log_monitor.py** - 带智能过滤的实时日志监控
   - 流式输出日志或按时长捕获
   - 按严重级别过滤（error/warning/info/debug）
   - 重复消息去重
   - 选项：`--app`、`--severity`、`--follow`、`--duration`、`--output`、`--json`

### 设备状态（2 个脚本）

3. **appearance.py** - 控制模拟器外观：深色模式、Dynamic Type 字号、语言/地区
   - 通过 `xcrun simctl ui` 切换浅色/深色主题
   - 使用友好别名设置 Dynamic Type 字号（XS 至 AX5）
   - 写入语言和地区 defaults；可通过 `--bundle-id` 可选重启应用
   - 对 ar/he/fa/ur/yi 语言自动标记 RTL
   - 选项：`--theme`、`--text-size`、`--locale`、`--region`、`--reset`、`--bundle-id`、`--udid`、`--json`、`--verbose`

4. **location.py** - 模拟 GPS 坐标、命名城市预设和 GPX 场景回放
   - 通过 `--lat`/`--lng` 固定坐标，或通过 `--city` 选择城市
   - 通过 `--gpx <scenario>` 回放内置场景（City Run、Freeway Drive 等）
   - 通过 `--waypoints` 和 `--speed` 动画化多点路径，速度可配置
   - 通过 `--clear` 清除模拟位置；通过 `--list-scenarios` 列出可用场景
   - 选项：`--lat`、`--lng`、`--city`、`--gpx`、`--waypoints`、`--speed`、`--clear`、`--list-scenarios`、`--udid`、`--json`、`--verbose`

### 导航与交互（5 个脚本）

5. **screen_mapper.py** - 分析当前屏幕并列出可交互元素
   - 元素类型分类
   - 可交互按钮列表
   - 文本框状态
   - 选项：`--verbose`、`--hints`、`--json`

6. **navigator.py** - 语义化查找并交互元素
   - 按文本查找（模糊匹配）
   - 按元素类型查找
   - 按无障碍 ID 查找
   - 输入文本或点击元素
   - 选项：`--find-text`、`--find-type`、`--find-id`、`--tap`、`--enter-text`、`--json`

7. **gesture.py** - 执行滑动、滚动、缩放和复杂手势
   - 方向性滑动（上/下/左/右）
   - 多次滑动滚动
   - 捏合缩放
   - 长按
   - 下拉刷新
   - 选项：`--swipe`、`--scroll`、`--pinch`、`--long-press`、`--refresh`、`--json`

8. **keyboard.py** - 文本输入和硬件按键控制
   - 输入文本（快速或慢速）
   - 特殊键（回车、删除、制表、空格、方向键）
   - 硬件按键（主屏幕、锁屏、音量、截屏）
   - 组合键
   - 选项：`--type`、`--key`、`--button`、`--slow`、`--clear`、`--dismiss`、`--json`

9. **app_launcher.py** - 应用生命周期管理
   - 按 bundle ID 启动应用
   - 终止应用
   - 从 .app 包安装/卸载
   - 深度链接导航
   - 列出已安装应用
   - 检查应用状态
   - 在启动/重启时传递启动参数（`--args`）和环境变量（`--env KEY=VALUE`，以 `SIMCTL_CHILD_*` 注入）
   - 选项：`--launch`、`--terminate`、`--restart`、`--install`、`--uninstall`、`--open-url`、`--list`、`--state`、`--args`、`--env`、`--wait-for-debugger`

### 测试与分析（9 个脚本）

10. **accessibility_audit.py** - 检查当前屏幕的 WCAG 合规性
    - 严重问题（缺少标签、空按钮、无替代文本）
    - 警告（缺少提示、点击目标过小）
    - 信息（缺少 ID、嵌套过深）
    - 选项：`--verbose`、`--output`、`--json`

11. **visual_diff.py** - 比较两张截图的视觉差异
    - 逐像素比较
    - 基于阈值的通过/失败
    - 生成差异图像
    - 选项：`--threshold`、`--output`、`--details`、`--json`

12. **test_recorder.py** - 自动记录测试执行过程
    - 每步捕获截图和无障碍树
    - 生成带计时数据的 Markdown 报告
    - 选项：`--test-name`、`--output`、`--verbose`、`--json`

13. **app_state_capture.py** - 创建全面的调试快照
    - 截图、UI 层级、应用日志、设备信息
    - 用于缺陷报告的 Markdown 摘要
    - 选项：`--app-bundle-id`、`--output`、`--log-lines`、`--json`

14. **sim_health_check.sh** - 验证环境是否正确配置
    - 检查 macOS、Xcode、simctl、IDB、Python
    - 列出可用和已启动的模拟器
    - 验证 Python 包（Pillow）

15. **model_inspector.py** - 从项目文件检查 Core Data 和 SwiftData 模型
    - 解析 .xcdatamodeld 包（实体、属性、关系）
    - 检测模型版本和当前活跃版本
    - 尽力提取 SwiftData @Model 类
    - 按需转储任意模型的原始源码（`--raw ModelName`）
    - 选项：`--project-path`、`--core-data-only`、`--swiftdata-only`、`--show-versions`、`--raw`、`--verbose`、`--json`

16. **container.py** - 检查应用沙盒：文件、UserDefaults 和 Core Data 存储路径
    - 通过 `--ls` 列出数据容器文件，深度可配置
    - 通过 `--cat` 读取文件，自动检测 plist 解码（大文件缓存）
    - 通过 `--userdefaults` 以 key=value 或 JSON 格式转储 UserDefaults
    - 通过 `--core-data-path` 定位 `.sqlite` / `.sqlite-wal` / `.sqlite-shm` 存储
    - 通过 `--export` 导出完整容器快照
    - 选项：`--ls`、`--cat`、`--userdefaults`、`--core-data-path`、`--export`、`--udid`、`--json`、`--verbose`

17. **hang_watcher.py**（HangBuster）- 通过渐进式信息披露记录并汇总 os_log 卡顿事件
    - **会话模式（HangBuster，代理原生）：** 启动一个分离的记录器，与模拟器交互，停止后获取精简 token 摘要
      - `--start` → 返回会话 ID；分离工作进程实时归一化并阈值过滤事件
      - `--stop SESSION_ID` → 输出约 80–120 token 的 L1 摘要（表头 + 前 N 个聚类 + 下钻提示）
      - `--get-details SESSION_ID [--cluster N | --raw]` → L2 完整聚类或 L3 单事件详情
      - `--list-sessions` / `--clear-sessions [--older-than 24h]` / `--diff A B`（跨会话回归报告）
      - 过滤管道：解析 → 归一化 → 阈值 → 分桶 → 聚类 → 聚合 → 排序 → 格式化（位于 `common/hang_pipeline.py`）
      - `--budget-tokens N` 选择能装下的最密集级别（L0/L1/L2）；`--terse` 强制 L0
      - `--auto-sample` 在每个聚类的首个事件时捕获主线程堆栈（软依赖：`main_thread_sampler.py` #62；不存在时优雅降级）
    - **原始捕获模式（完整保真度，便于 `jq` 探索）：** 跳过聚类管道，逐行原样转储所有匹配的日志到 `raw.ndjson`
      - `--start --raw-capture [--max-size-mb 10] [--no-gzip]` — 启动 `log stream --style ndjson`
      - 每会话大小上限（`--max-size-mb`，默认 10）— 达到上限时工作进程干净停止；`extras.truncated=true`
      - `--stop` 将 `raw.ndjson` gzip 压缩为 `raw.ndjson.gz`（约 15–19 倍压缩率；`--no-gzip` 可跳过）
      - 对原始会话执行 `--get-details SESSION_ID` 会打印路径并附带 `zcat | jq ...` 提示
    - **韧性（流死亡时自动重启）：** EOF 或子进程死亡会触发 `stream_died` 事件，然后以 2 秒退避进行有界重启。达到 `IOS_SIM_HANG_MAX_RESTARTS`（默认 3）后会话标记为 `crashed`，绝不会停留在过期的 `running` 状态。`--list-sessions` 会显示 `capture=Xs` 和 `restarts=N`。
    - **清理是自动的：** TTL 清理（`IOS_SIM_HANG_SESSION_TTL_HOURS`，默认 24 小时）+ 总量上限（`IOS_SIM_HANG_TOTAL_CAP_MB`，默认 100 MB，按最旧优先淘汰）在每次 `--start` 时都会运行。
    - **遗留模式（向后兼容，保持不变）：** `--watch [--duration N]`（实时流）和 `--since 5m`（历史）
    - 过滤器：`--bundle-id`（解析后过滤——卡顿捕获保持模拟器全局，以便保留 RunningBoard/SpringBoard 事件）、`--predicate`（也可通过 `IOS_SIM_HANG_PREDICATE` 设置）
    - 所有输出支持 `--json`；会话存储位于 `~/.ios-simulator-skill/sessions/<id>/{meta.json,events.jsonl,summary.json,raw.ndjson.gz}`

    **快速开始（摘要模式）：**
    ```bash
    SID=$(python scripts/hang_watcher.py --start --min-hang-ms 200)
    # ... 与模拟器交互（打开表单、滚动、导航）...
    python scripts/hang_watcher.py --stop $SID                  # 精简 token 的 L1 摘要
    python scripts/hang_watcher.py --get-details $SID --cluster 1  # 下钻到聚类 1
    python scripts/hang_watcher.py --diff $SID_BASELINE $SID    # 跨会话回归
    ```

    **快速开始（原始捕获 + `jq` 探索）：**
    ```bash
    SID=$(python scripts/hang_watcher.py --start --raw-capture --max-size-mb 5)
    # ... 与模拟器交互 ...
    python scripts/hang_watcher.py --stop $SID
    # → "Session ...: raw mode, 737 lines, 0.96 MB → 0.05 MB gzipped"

    # 按事件数排名的前几个进程：
    zcat ~/.ios-simulator-skill/sessions/$SID/raw.ndjson.gz \
      | jq -s 'group_by(.processImagePath) | map({proc: (.[0].processImagePath | split("/") | last), n: length}) | sort_by(-.n) | .[:5]'

    # 所有 RunningBoard 断言失效：
    zcat .../raw.ndjson.gz | jq -c 'select(.subsystem == "com.apple.runningboard" and (.eventMessage | startswith("Invalidating")))'

    # 每分钟卡顿数：
    zcat .../raw.ndjson.gz | jq -r '.timestamp[:16]' | sort | uniq -c
    ```

18. **localization_audit.py** - 检测字符串目录缺失、缺失键和占位符不匹配
    - 报告 `.xcstrings` 目录中每个语言的缺失键和 `needs_review`/`new` 键
    - 通过 `--source` 将目录键与 Swift 源码（`String(localized:)` / `NSLocalizedString`）交叉引用
    - 标记跨语言的占位符数量不匹配（`%d`、`%@`、`%s`、`%lld`）
    - 通过 `plistlib` 支持遗留的 `.strings` 和 `.stringsdict`
    - CI 友好的 `--strict` 在发现任何问题时以退出码 2 退出
    - 选项：`--catalog`、`--source`、`--locale`、`--strict`、`--json`、`--verbose`

### 高级测试与权限（4 个脚本）

19. **clipboard.py** - 管理模拟器剪贴板，用于粘贴测试
    - 复制文本到剪贴板
    - 无需手动输入即可测试粘贴流程
    - 选项：`--copy`、`--test-name`、`--expected`、`--json`

20. **status_bar.py** - 覆盖模拟器状态栏外观
    - 预设：clean（9:41，100% 电量）、testing（11:11，50%）、low-battery（20%）、airplane（离线）
    - 自定义时间、网络、电量、WiFi 设置
    - 选项：`--preset`、`--time`、`--data-network`、`--battery-level`、`--clear`、`--json`

21. **push_notification.py** - 发送模拟推送通知
    - 简单模式（标题 + 正文 + 角标）
    - 自定义 JSON 负载
    - 测试通知处理和深度链接
    - 选项：`--bundle-id`、`--title`、`--body`、`--badge`、`--payload`、`--json`

22. **privacy_manager.py** - 授予、撤销和重置应用权限
    - 支持 13 种服务（相机、麦克风、定位、通讯录、照片、日历、健康等）
    - 批量操作（逗号分隔的服务）
    - 带测试场景跟踪的审计日志
    - 选项：`--bundle-id`、`--grant`、`--revoke`、`--reset`、`--list`、`--json`

### 模拟器发现（2 个脚本）

23. **sim_list.py** - 通过渐进式信息披露列出模拟器
    - 默认输出简洁摘要（总数 / 可用 / 已启动）
    - 按需通过缓存 ID 获取完整详情
    - 按设备类型过滤
    - 通过 `--suggest` 推荐合适的模拟器
    - 相比原始 `simctl list` 减少 96% token（57k → 2k tokens）
    - 选项：`--get-details`、`--suggest`、`--device-type`、`--json`

24. **simulator_selector.py** - 为任务推荐最佳模拟器
    - 按最近使用（来自 `config.json`）、最新 iOS、常用测试机型和启动状态对候选者排名
    - 通过 `--list` 列出所有可用模拟器
    - 通过 `--boot` 直接启动选中的模拟器
    - JSON 输出，便于编程使用
    - 选项：`--suggest`、`--list`、`--boot`、`--json`

### 设备生命周期管理（5 个脚本）

25. **simctl_boot.py** - 启动模拟器，可选就绪验证
    - 按 UDID 或设备名称启动
    - 等待设备就绪，带超时
    - 批量启动操作（--all、--type）
    - 性能计时
    - 选项：`--udid`、`--name`、`--wait-ready`、`--timeout`、`--all`、`--type`、`--json`

26. **simctl_shutdown.py** - 优雅关闭模拟器
    - 按 UDID 或设备名称关闭
    - 可选验证关闭完成
    - 批量关闭操作
    - 选项：`--udid`、`--name`、`--verify`、`--timeout`、`--all`、`--type`、`--json`

27. **simctl_create.py** - 动态创建模拟器
    - 按设备类型和 iOS 版本创建
    - 列出可用设备类型和运行时
    - 自定义设备命名
    - 返回 UDID，便于 CI/CD 集成
    - 选项：`--device`、`--runtime`、`--name`、`--list-devices`、`--list-runtimes`、`--json`

28. **simctl_delete.py** - 永久删除模拟器
    - 按 UDID 或设备名称删除
    - 默认安全确认（用 --yes 跳过）
    - 批量删除操作
    - 智能删除（--old N 保留每种设备类型 N 个）
    - 选项：`--udid`、`--name`、`--yes`、`--all`、`--type`、`--old`、`--json`

29. **simctl_erase.py** - 恢复出厂设置而不删除模拟器
    - 保留设备 UUID（比删除+创建更快）
    - 擦除全部、按类型或已启动的模拟器
    - 可选验证
    - 选项：`--udid`、`--name`、`--verify`、`--timeout`、`--all`、`--type`、`--booted`、`--json`

## 通用模式

**自动 UDID 检测**：大多数脚本在未提供 --udid 时会自动检测已启动的模拟器。

**设备名称解析**：使用设备名称（如 "iPhone 16 Pro"）代替 UDID——脚本会自动解析。

**批量操作**：许多脚本支持 `--all` 操作所有模拟器，或 `--type iPhone` 按设备类型过滤。

**输出格式**：默认为简洁的人类可读输出。在 CI/CD 中使用 `--json` 获取机器可读输出。

**帮助**：所有脚本支持 `--help` 查看详细选项和示例。

**截图尺寸**：截图会调整大小以节省 token。预设：`full`（3-4 块，约 5K tokens）、`half`（1 块，约 1.6K tokens，默认）、`quarter`（1 块，约 800 tokens，细节较少）。快速视觉检查用 `quarter`，可读 UI 用 `half`，仅在需要像素级细节时用 `full`。捕获截图的脚本（`app_state_capture.py`、`test_recorder.py`）默认使用 `half`。

## 典型工作流

1. 验证环境：`bash scripts/sim_health_check.sh`
2. 启动应用：`python scripts/app_launcher.py --launch com.example.app`
3. 分析屏幕：`python scripts/screen_mapper.py`
4. 交互：`python scripts/navigator.py --find-text "Button" --tap`
5. 验证：`python scripts/accessibility_audit.py`
6. 按需调试：`python scripts/app_state_capture.py --app-bundle-id com.example.app`

## 配置

大多数操作限制可通过环境变量调整。默认值适用于典型的本地开发；对于缓慢的 CI 运行器、大型单仓库构建或复杂屏幕的无障碍审计，请适当调高。

| 变量 | 默认值 | 控制 |
|---|---|---|
| `IOS_SIM_A11Y_LABEL_MAX` | `80` | 无障碍审计输出中保留的 `AXLabel` 最大字符数 |
| `IOS_SIM_A11Y_TOP_ISSUES` | `10` | 每次审计呈现的前 N 个无障碍问题 |
| `IOS_SIM_APPS_PREVIEW` | `30` | `app_launcher.py` 列出的应用条目数（超出截断） |
| `IOS_SIM_BOOT_SUBPROCESS_TIMEOUT` | `60` | `simctl boot` 子进程本身的超时时间（秒） |
| `IOS_SIM_BOOT_TIMEOUT` | `300` | 启动后等待就绪的超时时间（秒） |
| `IOS_SIM_BUILD_JSON_CAP` | `50` | JSON 输出中最大构建错误/失败测试数 |
| `IOS_SIM_BUILD_LOG_PREVIEW` | `4000` | 默认输出中构建日志预览的字符数 |
| `IOS_SIM_BUILD_TIMEOUT` | `1800` | `xcodebuild build` 调用在被杀死前的最大秒数 |
| `IOS_SIM_INTROSPECT_TIMEOUT` | `60` | `xcodebuild -list` 和 `simctl list` 查询超时（秒） |
| `IOS_SIM_TEST_TIMEOUT` | `2700` | `xcodebuild test` 调用在被杀死前的最大秒数 |
| `IOS_SIM_BUILD_SUMMARY_CAP` | `15` | 默认构建摘要中的错误/失败数 |
| `IOS_SIM_BUILD_VERBOSE_CAP` | `100` | 详细构建输出中的错误/警告数 |
| `IOS_SIM_CACHE_MAX_ENTRIES` | `500` | 渐进式信息披露缓存的最大条目数（LRU 淘汰） |
| `IOS_SIM_CACHE_TTL_HOURS` | `1` | 缓存条目过期时间 |
| `IOS_SIM_ERASE_TIMEOUT` | `90` | 等待擦除完成的超时时间（秒） |
| `IOS_SIM_HANG_PREDICATE` | _(默认)_ | 覆盖 `hang_watcher.py` 使用的 `os_log` 谓词（默认捕获 RunningBoard 终止 + "Hang detected" + 主线程卡顿）。卡顿事件源自系统守护进程（RunningBoard、SpringBoard），因此谓词保持模拟器全局——`--bundle-id` 在解析后应用，而非 AND 进去。 |
| `IOS_SIM_HANG_MIN_MS` | `250` | HangBuster 阈值——低于此时长的事件永不落盘（值越小越敏感，摘要越大） |
| `IOS_SIM_HANG_SESSION_TTL_HOURS` | `24` | HangBuster 会话清理时长；清理在每次 `--start` 时运行 |
| `IOS_SIM_HANG_DEFAULT_TOP_N` | `3` | `--stop` L1 输出中默认的前 N 个聚类 |
| `IOS_SIM_HANG_BUDGET_TOKENS` | _(未设置)_ | `--stop` 的默认 token 预算（选择能装下的 L0/L1/L2） |
| `IOS_SIM_HANG_MAX_RESTARTS` | `3` | HangBuster 工作进程：EOF/子进程死亡时最大 `log stream` 重启次数，超出后会话标记为 `crashed` |
| `IOS_SIM_HANG_TOTAL_CAP_MB` | `100` | HangBuster 总磁盘上限。当 `--start` 时总会话状态超过此值，最旧的会话优先被删除。设为 `0` 禁用。 |
| `IOS_SIM_LOG_JSON_CAP` | `100` | `log_monitor.py` JSON 输出中最大错误/警告数 |
| `IOS_SIM_LOG_LINE_MAX` | `300` | 日志摘要中每行截断长度 |
| `IOS_SIM_LOG_TAIL` | `200` | 详细/示例输出中的日志尾部行数 |
| `IOS_SIM_LOG_TEXT_SUMMARY` | `15` | 文本模式日志摘要中显示的错误/警告数 |
| `IOS_SIM_MAX_ELEMENTS` | `25` | `navigator.py` 列出的可点击元素数 |
| `IOS_SIM_POLL_INTERVAL` | `0.5` | 启动/擦除状态轮询间隔（秒） |
| `IOS_SIM_RELAUNCH_DELAY_MS` | `1000` | `app_launcher.py` 中终止与重启之间的延迟 |
| `IOS_SIM_SCREEN_BUTTONS_PREVIEW` | `15` | `screen_mapper.py` 列出的按钮名称数 |
| `IOS_SIM_SCREEN_SECTION_ITEMS` | `10` | `screen_mapper.py` 每个分区显示的条目数 |
| `IOS_SIM_STATE_SUBPROCESS_TIMEOUT` | `15` | `app_state_capture.py` 中的子进程超时（秒） |
| `IOS_SIM_TAP_SETTLE_MS` | `500` | `navigator.py` 中点击后的稳定延迟 |

示例：

```bash
# 慢速 GitHub Actions 运行器：给启动 10 分钟
IOS_SIM_BOOT_TIMEOUT=600 python scripts/simctl_boot.py --wait-ready
```

## 依赖要求

- macOS 12+
- Xcode Command Line Tools
- Python 3
- IDB（可选，用于交互功能）

## 文档

- **SKILL.md**（本文件）- 脚本参考与快速开始
- **README.md** - 安装与示例
- **CLAUDE.md** - 架构与实现细节
- **references/** - 特定主题的深度文档
- **examples/** - 完整的自动化工作流

## 核心设计原则

**语义化导航**：按含义（文本、类型、ID）而非像素坐标查找元素。能适应 UI 变更。

**Token 效率**：默认输出简洁（3-5 行），可选详细和 JSON 模式获取详细结果。

**无障碍优先**：基于标准无障碍 API 构建，确保可靠性和兼容性。

**零配置**：在任何装有 Xcode 的 macOS 上立即可用。无需安装设置。

**结构化数据**：脚本输出 JSON 或格式化文本，而非原始日志。易于解析和集成。

**自动学习**：构建系统会记住你的设备偏好。配置按项目存储。

---

可直接使用这些脚本，或当你的请求匹配本技能描述时，让 Claude Code 自动调用它们。
