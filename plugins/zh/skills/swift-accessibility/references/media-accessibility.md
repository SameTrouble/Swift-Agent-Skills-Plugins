# 媒体无障碍

覆盖 Captions、Audio Descriptions、Speech synthesis、图表无障碍和音频会话注意事项——两个 App Store Accessibility Nutrition Labels 所需。

## 目录
- [字幕和副标题](#字幕和副标题)
- [音频描述](#音频描述)
- [语音合成](#语音合成)
- [图表无障碍](#图表无障碍)
- [常见失败](#常见失败)

---

## 字幕和副标题

### Nutrition Label 标准

要声明支持 **Captions**：
- 系统字幕设置开启时默认启用字幕
- 所有第一方视频对话和相关声音都有字幕
- 优先使用 SDH（Subtitles for Deaf/Hard of Hearing）而非普通副标题
- 第三方内容显示 CC 或 SDH 徽章指示器
- 仅音频内容有文字转录可用

### AVPlayerViewController —— 内置支持（自动）

`AVPlayerViewController` 自动处理字幕选择、外观和系统切换。当用户在 Settings 中启用"Closed Captions + SDH"时，字幕无需任何代码即可激活。

```swift
// ✅ 内置 AVPlayerViewController——字幕自动工作
import AVKit

let player = AVPlayer(url: videoURL)
let playerVC = AVPlayerViewController()
playerVC.player = player
present(playerVC, animated: true) {
    player.play()
}
```

```swift
// SwiftUI 等价
VideoPlayer(player: AVPlayer(url: videoURL))
    .frame(height: 300)
```

### 检查系统字幕设置

```swift
import MediaAccessibility

// 检查用户是否启用了闭合字幕
let captionType = MACaptionAppearanceGetDisplayType(.user)
switch captionType {
case .alwaysOn:
    // 始终显示字幕
    break
case .automatic:
    // 系统根据内容和音频路由决定
    break
case .forcedOnly:
    // 仅强制副标题
    break
@unknown default:
    break
}
```

### 提供字幕轨道

字幕轨道必须嵌入媒体资产或通过 HLS 的 `.vtt` 或 `.srt` 副标题轨道提供。

```swift
// 编程式选择字幕轨道
let asset = AVAsset(url: videoURL)

Task {
    let characteristics = try await asset.loadMediaSelectionGroup(for: .legible)
    if let group = characteristics {
        // 查找 SDH（Subtitles for Deaf/Hard of Hearing）轨道
        let sdhOption = AVMediaSelectionGroup.mediaSelectionOptions(
            from: group.options,
            withMediaCharacteristics: [.describesVideoForAccessibility, .isSDH]
        ).first

        // 查找任何字幕轨道
        let captionOption = AVMediaSelectionGroup.mediaSelectionOptions(
            from: group.options,
            withMediaCharacteristics: [.legible]
        ).first

        // 激活首选选项
        await player.currentItem?.select(sdhOption ?? captionOption, in: group)
    }
}
```

### 字幕外观自定义

```swift
// 字幕样式默认遵循系统偏好
// 仅在需要自定义样式的品牌播放器上重写

// 检查用户首选字幕样式
let foregroundColor = MACaptionAppearanceCopyForegroundColor(.user, nil)
let fontSize = MACaptionAppearanceGetRelativeCharacterSize(.user)
let fontStyle = MACaptionAppearanceGetTextEdgeStyle(.user)
```

### SDH vs 普通副标题

| 类型 | 内容 | 使用时机 |
|---|---|---|
| SDH（Subtitles for Deaf/Hard of Hearing） | 对话 + 音效 + 说话者识别 | 无障碍首选 |
| Subtitles | 仅对话（翻译） | 外语内容 |
| Forced Subtitles | 仅未翻译的语音 | 内容中角色说外语时 |
| Closed Captions (CC) | 对话 + 音效 | 旧格式，与 SDH 同角色 |

创建自定义轨道时用 `AVMediaCharacteristic.isSDH` 标记 SDH 轨道。

---

## 音频描述

### Nutrition Label 标准

要声明支持 **Audio Descriptions**：
- 系统 AD 设置开启时默认启用音频描述
- 所有第一方视频视觉内容都有旁白（动作、场景变化、屏幕文字）
- 游戏过场动画和动画序列已覆盖
- 第三方 AD 内容显示"AD"徽章指示器
- 描述内容很少时不要声明支持

### AVPlayerViewController —— 内置支持

当用户在 Settings 中启用"Audio Descriptions"时，`AVPlayerViewController` 自动选择音频描述轨道。

```swift
// 内置：使用 AVPlayerViewController 时无需代码
// AD 轨道必须包含在媒体资产或 HLS manifest 中
```

### 检查音频描述轨道

```swift
let asset = AVAsset(url: videoURL)

Task {
    let group = try? await asset.loadMediaSelectionGroup(for: .audible)
    if let group {
        let adOptions = AVMediaSelectionGroup.mediaSelectionOptions(
            from: group.options,
            withMediaCharacteristics: [.describesVideoForAccessibility]
        )
        let hasAudioDescription = !adOptions.isEmpty
        // 如果 hasAudioDescription 在 UI 中显示"AD"徽章
    }
}
```

### 尊重语音音频会话

当你的应用播放与 VoiceOver 或 Audio Descriptions 竞争的音频时，使用 `.spokenAudio` 模式进行压低或暂停：

```swift
import AVFoundation

// 配置音频会话以尊重语音音频（VoiceOver、Audio Descriptions）
try? AVAudioSession.sharedInstance().setCategory(
    .playback,
    mode: .spokenAudio,
    options: [.duckOthers]  // 压低，不打断
)

// 对于语音本身就是主要内容的应用（有声书、播客）
try? AVAudioSession.sharedInstance().setCategory(
    .playback,
    mode: .spokenAudio
    // 无 .duckOthers——这就是不应被压低的音频
)
```

### 检测系统音频描述设置

```swift
// 没有等同于 MACaptionAppearance 的音频描述直接 API
// AVPlayerViewController 自动处理
// 对于自定义播放器，观察 AVAudioSession 变化
NotificationCenter.default.addObserver(
    forName: AVAudioSession.routeChangeNotification,
    object: nil,
    queue: .main
) { _ in
    // 路由变化后重新评估 AD 轨道选择
}
```

---

## 语音合成

用于生成语音内容的应用（阅读应用、导航、通知）。

### 基本 AVSpeechSynthesizer

```swift
import AVFoundation

let synthesizer = AVSpeechSynthesizer()

func speak(_ text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    utterance.pitchMultiplier = 1.0   // 0.5（低）到 2.0（高）
    utterance.volume = 1.0
    utterance.preUtteranceDelay = 0.1

    synthesizer.speak(utterance)
}

// 暂停和恢复
synthesizer.pauseSpeaking(at: .word)
synthesizer.continueSpeaking()

// 停止
synthesizer.stopSpeaking(at: .immediate)  // 或 .word, .sentence
```

### 基于 SSML 的语音（iOS 16+）

```swift
// 使用 SSML 进行细粒度韵律控制
let ssml = """
<speak>
    <s>Welcome to <emphasis level="strong">My App</emphasis>.</s>
    <break time="500ms"/>
    <s>Your balance is <say-as interpret-as="currency" language="en-US">$1,234.56</say-as>.</s>
</speak>
"""

if let utterance = AVSpeechUtterance(ssmlRepresentation: ssml) {
    synthesizer.speak(utterance)
}
```

### Personal Voice（iOS 17+）

```swift
import AVFoundation

// 请求 Personal Voice 访问权限
AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
    if status == .authorized {
        // 列出可用的个人语音
        let personalVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.voiceTraits.contains(.isPersonalVoice) }

        if let voice = personalVoices.first {
            let utterance = AVSpeechUtterance(string: "Hello!")
            utterance.voice = voice
            synthesizer.speak(utterance)
        }
    }
}
```

### AVSpeechSynthesizerDelegate

```swift
class NarratorController: NSObject, AVSpeechSynthesizerDelegate {
    let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didStart utterance: AVSpeechUtterance) {
        // 更新 UI——开始朗读
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        // 继续下一条语音或更新 UI
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        // 高亮当前朗读的单词
    }
}
```

### 语音应用的音频会话

```swift
// 为语音应用配置会话（有声书、旁白）
try? AVAudioSession.sharedInstance().setCategory(
    .playback,
    mode: .spokenAudio,
    options: [.allowBluetooth, .allowAirPlay]
)
try? AVAudioSession.sharedInstance().setActive(true)
```

---

## 图表无障碍

图表是视觉的；无法看到图表的用户需要结构化的数据替代方案。

### SwiftUI Charts: `.accessibilityChartDescriptor(_:)`

```swift
import Charts

struct SalesChartDescriptor: AXChartDescriptorRepresentable {
    let data: [SalesData]

    func makeChartDescriptor() -> AXChartDescriptor {
        let months = data.map(\.month)
        let maxSales = data.map(\.sales).max() ?? 0

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Month",
            categoryOrder: months
        )

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Revenue (USD)",
            range: 0...Double(maxSales),
            gridlinePositions: []
        ) { value in
            "$\(Int(value).formatted())"  // 为语音格式化
        }

        let series = AXDataSeriesDescriptor(
            name: "Monthly Sales",
            isContinuous: false,
            dataPoints: data.map { item in
                AXDataPoint(x: item.month, y: Double(item.sales))
            }
        )

        return AXChartDescriptor(
            title: "Monthly Sales Report",
            summary: "Sales increased 23% year-over-year, peaking in December.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// 应用到图表
Chart(salesData) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Sales", item.sales)
    )
}
.accessibilityChartDescriptor(SalesChartDescriptor(data: salesData))
```

### 多系列图表

```swift
let descriptor = AXChartDescriptor(
    title: "Revenue by Region",
    summary: "North America leads, followed by Europe and Asia.",
    xAxis: AXCategoricalDataAxisDescriptor(title: "Quarter", categoryOrder: ["Q1", "Q2", "Q3", "Q4"]),
    yAxis: AXNumericDataAxisDescriptor(title: "Revenue (M)", range: 0...500, gridlinePositions: []) { "\($0)M" },
    additionalAxes: [],
    series: [
        AXDataSeriesDescriptor(name: "North America", isContinuous: true,
            dataPoints: naData.map { AXDataPoint(x: $0.quarter, y: $0.revenue) }),
        AXDataSeriesDescriptor(name: "Europe", isContinuous: true,
            dataPoints: euData.map { AXDataPoint(x: $0.quarter, y: $0.revenue) })
    ]
)
```

### 自定义图表的文字替代方案

对于非 Swift Charts 可视化（Core Graphics、自定义绘制）：

```swift
// 提供数据表作为无障碍替代方案
CustomBarChartView(data: chartData)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Sales chart")
    .accessibilityValue(chartData.map { "\($0.label): \($0.value)" }.joined(separator: ", "))

// 或使用 accessibilityCustomContent 进行详细的分块传递
CustomBarChartView(data: chartData)
    .accessibilityLabel("Quarterly Revenue Chart")
    .accessibilityCustomContent("Summary", "Revenue grew 15% this year", importance: .high)
    .accessibilityCustomContent(
        "Data",
        chartData.map { "\($0.quarter): \($0.value)" }.joined(separator: "; ")
    )
```

---

## 常见失败

| 失败 | 类别 | 修复 |
|---|---|---|
| 字幕不自动启用 | Captions | 使用 `AVPlayerViewController`；通过 `MACaptionAppearanceGetDisplayType` 检查系统字幕设置 |
| 视频中无字幕轨道 | Captions | 嵌入 `.vtt`/`.srt` 轨道或在 HLS manifest 中包含 SDH |
| 音频描述从不激活 | Audio Descriptions | 使用 `AVPlayerViewController`；嵌入带 `.describesVideoForAccessibility` 特征的 AD 音轨 |
| 应用音频压低 VoiceOver | Audio Session | 设置 `.spokenAudio` 模式加 `.duckOthers` 选项 |
| 图表数据对 VoiceOver 不可访问 | Charts | 添加带有意义摘要的 `.accessibilityChartDescriptor(_:)` |
| 语音合成器打断 VoiceOver | Speech | 检查 `UIAccessibility.isVoiceOverRunning` 并暂停/排队合成 |
| 自定义媒体播放器忽略字幕设置 | Captions | 查询 `MACaptionAppearanceGetDisplayType` 并自动选择字幕轨道 |
| 仅音频内容无转录 | Captions | 在音频旁提供静态文字转录 |
