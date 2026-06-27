# 无障碍

- 尊重用户在字体、颜色、动画等方面的无障碍设置。
- 不要强制指定特定字体大小。优先使用 Dynamic Type（`.font(.body)`、`.font(.headline)` 等）。
- 如果你*确实需要*自定义字体大小，在面向 iOS 18 及更早版本时使用 `@ScaledMetric`。面向 iOS 26 或更高版本时，也可以使用 `.font(.body.scaled(by:))` 来获得字体大小调整。
- 标记图像的 VoiceOver 朗读内容不清晰或无帮助的情况，例如 `Image(.newBanner2026)`。如果它们是装饰性的，建议使用 `Image(decorative:)` 或 `accessibilityHidden()`，否则附加 `accessibilityLabel()`。
- 如果用户启用了"Reduce Motion"，应将大幅度的基于运动的动画替换为透明度变化。
- 如果按钮的标签复杂或频繁变化，建议使用 `accessibilityInputLabels()` 来提供更好的语音控制命令。例如，如果一个按钮显示苹果公司实时更新的股价"AAPL $271.68"，为"Apple"添加一个输入标签将是一个很大的改进。
- 带有图像标签的按钮必须始终包含文本，即使文本是不可见的：`Button("Label", systemImage: "plus", action: myAction)`。标记缺少文本标签的仅图标按钮，因为它们对 VoiceOver 不友好。通常 SwiftUI 会根据上下文为标签使用正确的标签样式——例如 iOS 工具栏中的按钮默认会自动仅显示图标——但如果出于特定原因需要按钮在视觉上保持仅图标，应用 `.labelStyle(.iconOnly)` 来保留视觉效果，同时保留可供 VoiceOver 使用的文本。
- 如果颜色是用户界面的重要区分因素，请确保通过显示颜色之外的变化（图标、图案、描边等）来尊重环境的 `.accessibilityDifferentiateWithoutColor` 设置。
- `Menu` 也是同理：使用 `Menu("Options", systemImage: "ellipsis.circle") { }` 比仅使用图像要好得多。在极少数情况下菜单触发器确实应仅显示图标，可以使用 `.labelStyle(.iconOnly)`。
- 除非你特别需要点击位置或点击次数，否则永远不要使用 `onTapGesture()`。所有其他可点击元素都应该是 `Button`。
- 如果必须使用 `onTapGesture()`，请确保添加 `.accessibilityAddTraits(.isButton)` 或类似修饰符，以便 VoiceOver 能正确朗读。
