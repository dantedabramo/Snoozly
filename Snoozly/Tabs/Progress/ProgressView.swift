//
//  ProgressView.swift
//  Snoozly
//
//  Created by Dante D’Abramo on 2026-10-12.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - ProgressView

struct ProgressView: View {
    @Query(sort: \SleepCheckIn.date, order: .reverse) private var checkIns: [SleepCheckIn]
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKey.sleepGoalMinutes) private var sleepGoalMinutes = 480
    @State private var proManager = ProManager.shared
    @State private var selectedRange: TimeRange = .sevenDays
    @State private var showCheckInSheet = false
    @State private var showProSheet = false
    @State private var selectedDetailCheckIn: SleepCheckIn?
    @State private var selectedDate: Date?
    @State private var appeared = false
    @Namespace private var rangeNamespace

    enum TimeRange: String, CaseIterable, Identifiable {
        case sevenDays = "7D"
        case fourteenDays = "14D"
        case oneMonth = "1 Month"

        var id: String { rawValue }

        var isProOnly: Bool {
            self != .sevenDays
        }

        var dayCount: Int {
            switch self {
            case .sevenDays: 7
            case .fourteenDays: 14
            case .oneMonth: 30
            }
        }

        var axisStride: Int {
            switch self {
            case .sevenDays: 1
            case .fourteenDays: 2
            case .oneMonth: 7
            }
        }

        var axisFormat: Date.FormatStyle {
            switch self {
            case .sevenDays: Date.FormatStyle().weekday(.abbreviated)
            case .fourteenDays: Date.FormatStyle().day()
            case .oneMonth: Date.FormatStyle().month(.abbreviated).day()
            }
        }

        var subtitle: String {
            switch self {
            case .sevenDays: "Last 7 days"
            case .fourteenDays: "Last 14 days"
            case .oneMonth: "Last 30 days"
            }
        }
    }

    struct SleepPoint: Identifiable, Equatable {
        let id: UUID
        let day: Date
        let score: Int
        let hours: Double
    }

    struct FactorImpact: Identifiable {
        let factor: SleepFactor
        let delta: Int
        let count: Int

        var id: String { factor.id }
    }

    // MARK: - Data

    private var calendar: Calendar {
        Calendar.current
    }

    private var windowStart: Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -(selectedRange.dayCount - 1), to: today) ?? today
    }

    private var windowEnd: Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    private var points: [SleepPoint] {
        var seen = Set<Date>()
        var result: [SleepPoint] = []

        for checkIn in checkIns {
            let day = calendar.startOfDay(for: checkIn.date)
            guard day >= windowStart, day < windowEnd, seen.insert(day).inserted else { continue }
            let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
            result.append(SleepPoint(id: checkIn.id, day: noon, score: checkIn.score, hours: checkIn.hoursSlept))
        }

        return result.sorted { $0.day < $1.day }
    }

    private var todayCheckIn: SleepCheckIn? {
        checkIns.first { calendar.isDateInToday($0.date) }
    }

    private var averageScore: Int? {
        let current = points
        guard !current.isEmpty else { return nil }
        let total = current.reduce(0) { $0 + $1.score }
        return Int((Double(total) / Double(current.count)).rounded())
    }

    private var averageHours: Double? {
        let current = points
        guard !current.isEmpty else { return nil }
        return current.reduce(0) { $0 + $1.hours } / Double(current.count)
    }

    private var averageLabel: String {
        guard let averageScore else { return "No check-ins yet" }
        switch averageScore {
        case 80...: return "Optimal rest"
        case 65..<80: return "Solid rest"
        case 50..<65: return "Fair rest"
        default: return "Needs attention"
        }
    }

    private var consistencyText: String {
        let current = points
        guard current.count >= 3 else { return "–" }
        let mean = current.reduce(0) { $0 + $1.hours } / Double(current.count)
        let variance = current.reduce(0) { $0 + ($1.hours - mean) * ($1.hours - mean) } / Double(current.count)
        let deviation = variance.squareRoot()
        if deviation <= 0.75 { return "Steady" }
        if deviation <= 1.5 { return "Variable" }
        return "Irregular"
    }

    private var streak: Int {
        let days = Set(checkIns.map { calendar.startOfDay(for: $0.date) })
        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? .distantPast
        }
        return count
    }

    private var factorImpacts: [FactorImpact] {
        let recent = Array(checkIns.prefix(60))
        guard recent.count >= 6 else { return [] }

        var results: [FactorImpact] = []
        for factor in SleepFactor.allCases {
            let with = recent.filter { $0.factors.contains(factor) }
            let without = recent.filter { !$0.factors.contains(factor) }
            guard with.count >= 2, without.count >= 2 else { continue }

            let withAverage = Double(with.reduce(0) { $0 + $1.score }) / Double(with.count)
            let withoutAverage = Double(without.reduce(0) { $0 + $1.score }) / Double(without.count)
            let delta = Int((withAverage - withoutAverage).rounded())
            guard delta != 0 else { continue }

            results.append(FactorImpact(factor: factor, delta: delta, count: with.count))
        }

        return Array(results.sorted { abs($0.delta) > abs($1.delta) }.prefix(3))
    }

    private var goalScore: Int {
        80
    }

    private var goalHoursText: String {
        "\(sleepGoalMinutes.durationText) sleep goal"
    }

    private var selectedPoint: SleepPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.day.timeIntervalSince(selectedDate)) < abs($1.day.timeIntervalSince(selectedDate))
        }
    }

    private var axisDates: [Date] {
        let today = calendar.startOfDay(for: .now)
        return stride(from: 0, to: selectedRange.dayCount, by: selectedRange.axisStride).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return calendar.date(byAdding: .hour, value: 12, to: day)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NightBackground(mood: .insights)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                        .reveal(appeared, delay: 0)

                    averageScoreGoalCard
                        .reveal(appeared, delay: 0.06)

                    interactiveChartCard
                        .reveal(appeared, delay: 0.12)

                    statsRow
                        .reveal(appeared, delay: 0.18)

                    factorsSection
                        .reveal(appeared, delay: 0.24)

                    recentCheckInsSection
                        .reveal(appeared, delay: 0.30)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .revealOnAppear($appeared)
        .sheet(isPresented: $showCheckInSheet) {
            CheckInSheetView()
        }
        .sheet(isPresented: $showProSheet) {
            ProSheetView()
        }
        .sheet(item: $selectedDetailCheckIn) { checkIn in
            CheckInDetailSheet(checkIn: checkIn)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ScreenHeader("Progress", subtitle: "Smart insights built from the check-ins you log each morning.") {
            Button {
                showCheckInSheet = true
            } label: {
                Label(todayCheckIn == nil ? "Check In" : "Update",
                      systemImage: todayCheckIn == nil ? "plus" : "pencil")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.midnightNavy)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.starlightGold)
        }
    }

    // MARK: - Average Score & Goal Card

    private var goalDeltaChip: some View {
        let gap = (averageScore ?? goalScore) - goalScore
        let text: String
        let tint: Color
        let icon: String

        if gap == 0 {
            text = "Right on your goal"
            tint = Color.restfulMint
            icon = "equal.circle.fill"
        } else if gap > 0 {
            text = "\(gap) pts above goal"
            tint = Color.restfulMint
            icon = "arrow.up.right.circle.fill"
        } else {
            text = "\(-gap) pts below goal"
            tint = Color.starlightGold
            icon = "arrow.down.right.circle.fill"
        }

        return InfoChip(icon: icon, text: text, tint: tint)
    }

    private var averageScoreGoalCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ScoreRing(score: averageScore, lineWidth: 9, numberSize: 32)
                    .frame(width: 98, height: 98)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Average sleep score")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.lavendar.opacity(0.8))
                        .lineLimit(1)

                    Text(averageLabel)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(summaryCaption)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.starlightGold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if averageScore != nil {
                        goalDeltaChip
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 10) {
                RowIcon(systemName: "target", size: 30)

                Text(goalHoursText)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Text("Change in Settings")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.lavendar.opacity(0.65))
                    .lineLimit(1)
            }
        }
        .padding(20)
        .nightCard(cornerRadius: 30, tint: Color.dreamPurple, elevated: true)
    }

    private var summaryCaption: String {
        let count = points.count
        if count == 0 {
            return selectedRange.subtitle
        }
        return "\(selectedRange.subtitle) · \(count) check-in\(count == 1 ? "" : "s")"
    }

    // MARK: - Chart Card

    private var interactiveChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeaderCallout

            chartView

            rangeSelector
        }
        .padding(20)
        .nightCard(cornerRadius: 30)
    }

    private var displayedPoint: SleepPoint? {
        selectedPoint ?? points.last
    }

    private var chartSubtitle: String {
        if let selected = selectedPoint {
            let date = selected.day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            return "\(date) · \(Int(selected.hours * 60).durationText)"
        }
        if points.isEmpty {
            return "Your trend appears after your first check-in."
        }
        return "Touch and drag across the chart to scrub days."
    }

    private var chartHeaderCallout: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep Score Trend")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(chartSubtitle)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 8)

            if let displayed = displayedPoint {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(displayed.score)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ScoreTone.color(for: displayed.score))
                        .contentTransition(.numericText(value: Double(displayed.score)))

                    Text("score")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(Color.lavendar.opacity(0.8))
                }
            }
        }
        .frame(minHeight: 52)
        .animation(.easeInOut(duration: 0.2), value: selectedPoint?.id)
    }

    private var chartView: some View {
        Chart {
            RuleMark(y: .value("Goal", goalScore))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.starlightGold.opacity(0.5))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text("Goal \(goalScore)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.starlightGold.opacity(0.95))
                }

            ForEach(points) { point in
                if points.count > 1 {
                    AreaMark(
                        x: .value("Day", point.day),
                        y: .value("Score", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.dreamPurple.opacity(0.45),
                                Color.lavendar.opacity(0.12),
                                Color.midnightNavy.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Score", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.moonlightBlue, Color.lavendar, Color.starlightGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }

                if selectedPoint?.id == point.id {
                    PointMark(
                        x: .value("Day", point.day),
                        y: .value("Score", point.score)
                    )
                    .symbolSize(380)
                    .foregroundStyle(Color.starlightGold.opacity(0.2))
                }

                PointMark(
                    x: .value("Day", point.day),
                    y: .value("Score", point.score)
                )
                .symbolSize(selectedPoint?.id == point.id ? 140 : 70)
                .foregroundStyle(pointColor(for: point))
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.day))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .chartXScale(domain: windowStart...windowEnd)
        .chartYScale(domain: 0...100)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: axisDates) { _ in
                AxisValueLabel(format: selectedRange.axisFormat)
                    .foregroundStyle(Color.lavendar.opacity(0.8))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.10))
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.lavendar.opacity(0.6))
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .padding(.top, 6)
                .padding(.horizontal, 4)
        }
        .frame(height: 210)
        .overlay {
            if points.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.lavendar.opacity(0.65))

                    Text("No check-ins in this range")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.lavendar.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPoint?.id)
        .animation(.snappy, value: selectedRange)
    }

    private func pointColor(for point: SleepPoint) -> Color {
        if selectedPoint?.id == point.id { return Color.starlightGold }
        return point.score >= goalScore ? Color.restfulMint : Color.white
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases) { range in
                let isSelected = selectedRange == range
                let isLocked = range.isProOnly && !proManager.isPro

                Button {
                    if isLocked {
                        showProSheet = true
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedRange = range
                            selectedDate = nil
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(range.rawValue)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if isLocked {
                            ProTag(compact: true)
                        }
                    }
                    .foregroundStyle(isSelected ? Color.midnightNavy : Color.white.opacity(0.9))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(NightGradient.lavender)
                                .overlay {
                                    Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                                }
                                .shadow(color: Color.dreamPurple.opacity(0.5), radius: 10, y: 3)
                                .matchedGeometryEffect(id: "rangeHighlight", in: rangeNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background {
            Capsule().fill(Color.black.opacity(0.24))
        }
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "bed.double.fill",
                tint: Color.moonlightBlue,
                value: averageHours.map { Int($0 * 60).durationText } ?? "–",
                label: "Avg sleep"
            )

            statTile(
                icon: "flame.fill",
                tint: Color.starlightGold,
                value: streak == 0 ? "–" : "\(streak) day\(streak == 1 ? "" : "s")",
                label: "Streak"
            )

            statTile(
                icon: "waveform.path.ecg",
                tint: Color.restfulMint,
                value: consistencyText,
                label: "Consistency"
            )
        }
    }

    private func statTile(icon: String, tint: Color, value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            RowIcon(systemName: icon, size: 32, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.lavendar.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .nightCard(cornerRadius: 24, blurs: false)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Factors

    @ViewBuilder
    private var factorsSection: some View {
        if !checkIns.isEmpty {
            let impacts = factorImpacts
            let isLocked = !impacts.isEmpty && !proManager.isPro

            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("What shapes your sleep", showsPro: true)

                if impacts.isEmpty {
                    Text("Log a few more check-ins and tag what shaped each night. Snoozly will show which habits raise or lower your score.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 12) {
                        ForEach(impacts) { impact in
                            factorRow(impact)
                        }
                    }
                    .blur(radius: isLocked ? 6 : 0)
                    .overlay {
                        if isLocked {
                            Label("Unlock with Pro", systemImage: "lock.fill")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.starlightGold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .glassEffect(.regular.interactive(), in: Capsule())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .nightCard(cornerRadius: 28)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture {
                if isLocked {
                    showProSheet = true
                }
            }
        }
    }

    private func factorRow(_ impact: FactorImpact) -> some View {
        let isPositive = impact.delta > 0
        let tint = isPositive ? Color.restfulMint : Color.dreamCoral

        return HStack(spacing: 12) {
            RowIcon(systemName: impact.factor.icon, size: 38, tint: Color.starlightGold)

            VStack(alignment: .leading, spacing: 2) {
                Text(impact.factor.rawValue)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("Logged on \(impact.count) nights")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.lavendar.opacity(0.7))
            }

            Spacer()

            Text("\(isPositive ? "+" : "−")\(abs(impact.delta)) pts")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(tint.opacity(0.14)))
        }
    }

    // MARK: - Look Back at Recent Check-Ins

    private var recentCheckInsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Look back at your check-ins", showsPro: true)

            if checkIns.isEmpty {
                Button {
                    showCheckInSheet = true
                } label: {
                    HStack(spacing: 14) {
                        RowIcon(systemName: "plus", size: 44, tint: Color.starlightGold)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Log your first morning check-in")
                                .font(.system(.callout, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)

                            Text("Tell Snoozly how you feel and how you slept.")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.lavendar.opacity(0.8))
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 4)

                        RowChevron()
                    }
                    .padding(18)
                    .nightCard(cornerRadius: 26, tint: Color.starlightGold)
                }
                .buttonStyle(PressScaleButtonStyle())
            } else {
                VStack(spacing: 0) {
                    let items = Array(checkIns.prefix(proManager.isPro ? 14 : 3))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, checkIn in
                        let isLocked = index > 0 && !proManager.isPro

                        if index > 0 {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.leading, 78)
                        }

                        checkInRow(checkIn: checkIn, isLocked: isLocked)
                    }
                }
                .nightCard(cornerRadius: 28)
            }
        }
    }

    private func checkInRow(checkIn: SleepCheckIn, isLocked: Bool) -> some View {
        let tone = ScoreTone.color(for: checkIn.score)

        return Button {
            if isLocked {
                showProSheet = true
            } else {
                selectedDetailCheckIn = checkIn
            }
        } label: {
            HStack(spacing: 14) {
                Text("\(checkIn.score)")
                    .font(.system(.callout, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(tone)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(tone.opacity(0.14)))
                    .overlay {
                        Circle().strokeBorder(tone.opacity(0.4), lineWidth: 1.5)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(checkIn.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text("\(checkIn.feel) • \(checkIn.sleepQuality) • \(Int(checkIn.hoursSlept * 60).durationText)")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.lavendar.opacity(0.75))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if !isLocked {
                    RowChevron()
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .blur(radius: isLocked ? 4 : 0)
            .overlay {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.starlightGold)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .contextMenu {
            if !isLocked {
                Button {
                    selectedDetailCheckIn = checkIn
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }

                Button(role: .destructive) {
                    modelContext.delete(checkIn)
                } label: {
                    Label("Delete Check-In", systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    let preview = PreviewSleepPlan()

    ProgressView()
        .modelContainer(preview.container)
}
