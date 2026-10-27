//
//  SnoozlyAlarmLiveActivity.swift
//  Snoozly_Widget_Extension
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

nonisolated struct SnoozlyAlarmMetadata: AlarmMetadata {}

// MARK: - Live Activity

struct SnoozlyAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SnoozlyAlarmMetadata>.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.midnightNavy)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(attributes: context.attributes, state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                MinimalView(state: context.state)
            }
            .keylineTint(Color.dreamPurple.opacity(0.5))
        }
    }
}

// MARK: - State Helpers

private extension AlarmPresentationState {
    var isCountingDown: Bool {
        switch mode {
        case .countdown, .paused: true
        default: false
        }
    }

    var accent: Color {
        isCountingDown ? Color.lavendar : Color.dreamCoral
    }

    var symbolName: String {
        isCountingDown ? "zzz" : "alarm.fill"
    }

    var timeText: String? {
        switch mode {
        case .countdown(let countdown):
            return countdown.fireDate.formatted(date: .omitted, time: .shortened)

        case .alert(let alert):
            var parts = DateComponents()
            parts.hour = alert.time.hour
            parts.minute = alert.time.minute

            guard let date = Calendar.current.date(from: parts) else {
                return nil
            }

            return date.formatted(date: .omitted, time: .shortened)

        default:
            return nil
        }
    }
}

// MARK: - Dynamic Island

private struct CompactLeadingView: View {
    let state: AlarmPresentationState

    var body: some View {
        Image(systemName: state.symbolName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(state.accent)
            .padding(.leading, 4)
    }
}

private struct CompactTrailingView: View {
    let state: AlarmPresentationState

    var body: some View {
        Group {
            if state.isCountingDown {
                SnoozeClock(state: state, size: 13, weight: .semibold, alignment: .trailing)
                    .foregroundStyle(Color.lavendar)
                    .frame(width: 32, alignment: .trailing)
            } else {
                Text("Wake")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.dreamCoral)
            }
        }
        .padding(.trailing, 2)
    }
}

private struct MinimalView: View {
    let state: AlarmPresentationState

    var body: some View {
        Image(systemName: state.symbolName)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(state.accent)
    }
}

private struct ExpandedLeading: View {
    let attributes: AlarmAttributes<SnoozlyAlarmMetadata>
    let state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 8) {
            IconBadge(
                systemName: state.symbolName,
                tint: state.accent,
                size: 26
            )

            Text(headerTitle)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(state.accent)
                .lineLimit(1)
        }
        .padding(.leading, 4)
    }

    private var headerTitle: LocalizedStringResource {
        if state.isCountingDown {
            return countdownTitle
        }

        return "Wake up"
    }

    private var countdownTitle: LocalizedStringResource {
        switch state.mode {
        case .countdown: attributes.presentation.countdown?.title ?? "Snooze"
        case .paused: attributes.presentation.paused?.title ?? "Paused"
        default: "Snooze"
        }
    }
}

private struct ExpandedTrailing: View {
    let state: AlarmPresentationState

    var body: some View {
        if let text = state.timeText {
            TimePill(
                text: text,
                systemName: state.isCountingDown ? "bell.fill" : "alarm"
            )
            .padding(.trailing, 4)
        }
    }
}

private struct ExpandedBottom: View {
    let attributes: AlarmAttributes<SnoozlyAlarmMetadata>
    let state: AlarmPresentationState

    var body: some View {
        Group {
            if state.isCountingDown {
                SnoozeExpandedCard(state: state)
            } else {
                RingingExpandedCard(attributes: attributes, state: state)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }
}

private struct SnoozeExpandedCard: View {
    let state: AlarmPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    SnoozeClock(state: state, size: 38, weight: .bold)
                        .foregroundStyle(.white)

                    Text(caption)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                StopButton(
                    alarmID: state.alarmID,
                    height: 42,
                    prominent: true
                )
            }

            SnoozeProgress(state: state, height: 6)
        }
        .padding(.bottom, 3)
    }

    private var caption: LocalizedStringResource {
        if case .paused = state.mode {
            return "Paused"
        }

        return "Until it rings again!"
    }
}

private struct RingingExpandedCard: View {
    let attributes: AlarmAttributes<SnoozlyAlarmMetadata>
    let state: AlarmPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(attributes.presentation.alert.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            AlertButtons(
                attributes: attributes,
                state: state,
                height: 42,
                prominentStop: true
            )
        }
        .padding(.bottom, 3)
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let attributes: AlarmAttributes<SnoozlyAlarmMetadata>
    let state: AlarmPresentationState

    var body: some View {
        Group {
            if state.isCountingDown {
                SnoozeCard(
                    title: snoozeTitle,
                    state: state
                )
            } else {
                RingingCard(
                    attributes: attributes,
                    state: state
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var snoozeTitle: LocalizedStringResource? {
        switch state.mode {
        case .countdown: attributes.presentation.countdown?.title
        case .paused: attributes.presentation.paused?.title
        default: nil
        }
    }
}

private struct SnoozeCard: View {
    let title: LocalizedStringResource?
    let state: AlarmPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                IconBadge(
                    systemName: "zzz",
                    tint: Color.lavendar,
                    size: 26
                )

                Text(title ?? "Snooze")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.lavendar)

                Spacer(minLength: 8)

                if let text = state.timeText {
                    TimePill(text: text, systemName: "bell.fill")
                }
            }

            HStack(alignment: .center) {
                SnoozeClock(state: state, size: 46, weight: .bold)
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                StopButton(alarmID: state.alarmID, height: 42)
            }

            SnoozeProgress(state: state, height: 6)
        }
        .padding(16)
        .background { CardBackground(glow: Color.dreamPurple) }
    }
}

private struct RingingCard: View {
    let attributes: AlarmAttributes<SnoozlyAlarmMetadata>
    let state: AlarmPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                IconBadge(
                    systemName: "alarm.fill",
                    tint: Color.dreamCoral,
                    size: 26
                )

                Text("Wake up")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.dreamCoral)

                Spacer(minLength: 8)

                if let text = state.timeText {
                    TimePill(text: text, systemName: "alarm")
                }
            }

            Text(attributes.presentation.alert.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            AlertButtons(
                attributes: attributes,
                state: state,
                height: 46
            )
        }
        .padding(16)
        .background { CardBackground(glow: Color.dreamCoral) }
    }
}

// MARK: - Components

private struct CardBackground: View {
    let glow: Color

    var body: some View {
        ZStack {
            Color.midnightNavy

            RadialGradient(
                colors: [
                    glow.opacity(0.30),
                    glow.opacity(0)
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 240
            )
        }
    }
}

private struct IconBadge: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.18), in: Circle())
    }
}

private struct TimePill: View {
    let text: String
    let systemName: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(Color.lavendar.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}

private struct SnoozeClock: View {
    let state: AlarmPresentationState
    var size: CGFloat
    var weight: Font.Weight = .bold
    var alignment: TextAlignment = .leading

    var body: some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                let now = Date.now

                Text(
                    timerInterval: now...max(countdown.fireDate, now),
                    pauseTime: nil,
                    countsDown: true,
                    showsHours: false
                )

            case .paused(let paused):
                let remaining = max(
                    paused.totalCountdownDuration - paused.previouslyElapsedDuration,
                    0
                )

                Text(
                    Duration.seconds(remaining),
                    format: .time(pattern: .minuteSecond(padMinuteToLength: 1))
                )

            default:
                EmptyView()
            }
        }
        .font(.system(size: size, weight: weight, design: .rounded))
        .monospacedDigit()
        .multilineTextAlignment(alignment)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct SnoozeProgress: View {
    let state: AlarmPresentationState
    var height: CGFloat = 5

    var body: some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                ProgressView(
                    timerInterval: countdown.startDate...max(
                        countdown.fireDate,
                        countdown.startDate
                    ),
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }

            case .paused(let paused):
                let total = max(paused.totalCountdownDuration, 1)
                let remaining = min(
                    max(
                        paused.totalCountdownDuration - paused.previouslyElapsedDuration,
                        0
                    ),
                    total
                )

                ProgressView(value: remaining, total: total)

            default:
                EmptyView()
            }
        }
        .labelsHidden()
        .progressViewStyle(.linear)
        .tint(Color.dreamPurple)
        .frame(height: height, alignment: .top)
        .clipped()
    }
}

private struct StopButton: View {
    let alarmID: UUID
    var height: CGFloat = 40
    var fillsWidth: Bool = false
    var prominent: Bool = false

    var body: some View {
        Button(intent: StopAlarmIntent(alarmID: alarmID.uuidString)) {
            HStack(spacing: 6) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))

                Text("Stop")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(prominent ? Color.midnightNavy : Color.white)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(
                maxWidth: fillsWidth ? CGFloat.infinity : nil,
                minHeight: height
            )
            .background(
                prominent ? Color.white : Color.white.opacity(0.14),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    Color.white.opacity(prominent ? 0 : 0.10),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SnoozeButton: View {
    let alarmID: UUID
    let button: AlarmButton
    var height: CGFloat = 40

    var body: some View {
        Button(intent: SnoozeAlarmIntent(alarmID: alarmID.uuidString)) {
            HStack(spacing: 6) {
                Image(systemName: button.systemImageName)
                    .font(.system(size: 14, weight: .bold))

                Text(button.text)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                LinearGradient(
                    colors: [Color.lavendar, Color.dreamPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AlertButtons: View {
    let attributes: AlarmAttributes<SnoozlyAlarmMetadata>
    let state: AlarmPresentationState
    var height: CGFloat = 42
    var prominentStop: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if let snooze = attributes.presentation.alert.secondaryButton {
                SnoozeButton(
                    alarmID: state.alarmID,
                    button: snooze,
                    height: height
                )
            }

            StopButton(
                alarmID: state.alarmID,
                height: height,
                fillsWidth: true,
                prominent: prominentStop
            )
        }
    }
}

// MARK: - Previews

private extension AlarmAttributes<SnoozlyAlarmMetadata> {
    static var previewAttributes: AlarmAttributes<SnoozlyAlarmMetadata> {
        let stopButton = AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "stop.fill"
        )

        let snoozeButton = AlarmButton(
            text: "Snooze",
            textColor: .white,
            systemImageName: "zzz"
        )

        let pauseButton = AlarmButton(
            text: "Pause",
            textColor: .white,
            systemImageName: "pause.fill"
        )

        let resumeButton = AlarmButton(
            text: "Resume",
            textColor: .white,
            systemImageName: "play.fill"
        )

        let alert = AlarmPresentation.Alert(
            title: "Good morning",
            stopButton: stopButton,
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .countdown
        )

        let countdown = AlarmPresentation.Countdown(
            title: "Snooze",
            pauseButton: pauseButton
        )

        let paused = AlarmPresentation.Paused(
            title: "Paused",
            resumeButton: resumeButton
        )

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: countdown,
            paused: paused
        )

        return AlarmAttributes(
            presentation: presentation,
            metadata: SnoozlyAlarmMetadata(),
            tintColor: Color.dreamPurple
        )
    }
}

private extension AlarmPresentationState {
    static var previewCountdown: AlarmPresentationState {
        AlarmPresentationState(
            alarmID: UUID(),
            mode: .countdown(
                AlarmPresentationState.Mode.Countdown(
                    totalCountdownDuration: 9 * 60,
                    previouslyElapsedDuration: 120,
                    startDate: .now.addingTimeInterval(-120),
                    fireDate: .now.addingTimeInterval(7 * 60)
                )
            )
        )
    }

    static var previewAlert: AlarmPresentationState {
        AlarmPresentationState(
            alarmID: UUID(),
            mode: .alert(
                AlarmPresentationState.Mode.Alert(
                    time: Alarm.Schedule.Relative.Time(hour: 7, minute: 30)
                )
            )
        )
    }
}

#Preview(
    "Dynamic Island Expanded",
    as: .dynamicIsland(.expanded),
    using: AlarmAttributes<SnoozlyAlarmMetadata>.previewAttributes
) {
    SnoozlyAlarmLiveActivity()
} contentStates: {
    AlarmPresentationState.previewCountdown
    AlarmPresentationState.previewAlert
}

#Preview(
    "Dynamic Island Compact",
    as: .dynamicIsland(.compact),
    using: AlarmAttributes<SnoozlyAlarmMetadata>.previewAttributes
) {
    SnoozlyAlarmLiveActivity()
} contentStates: {
    AlarmPresentationState.previewCountdown
    AlarmPresentationState.previewAlert
}

#Preview(
    "Dynamic Island Minimal",
    as: .dynamicIsland(.minimal),
    using: AlarmAttributes<SnoozlyAlarmMetadata>.previewAttributes
) {
    SnoozlyAlarmLiveActivity()
} contentStates: {
    AlarmPresentationState.previewCountdown
    AlarmPresentationState.previewAlert
}

#Preview(
    "Lock Screen",
    as: .content,
    using: AlarmAttributes<SnoozlyAlarmMetadata>.previewAttributes
) {
    SnoozlyAlarmLiveActivity()
} contentStates: {
    AlarmPresentationState.previewCountdown
    AlarmPresentationState.previewAlert
}
