import SwiftUI
import WidgetKit

// MARK: - 기분 한 줄

struct MoodView: View {
    let entry: DailyEntry

    var body: some View {
        let day = Store.string("mood_day")
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "기분 한 줄",
                         trailing: day.isEmpty ? "" : (day == Day.key(entry.date) ? "오늘" : Day.monthDayLabel(day)))
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Text(day.isEmpty ? "📝" : Store.string("mood_emoji")).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.isEmpty ? "오늘 기분은 어때요?" : Store.string("mood_label"))
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.text).lineLimit(1)
                    Text(day.isEmpty ? "눌러서 기분 한 줄을 남겨 보세요" : Store.string("mood_note"))
                        .font(.system(size: 12)).foregroundStyle(Palette.sub).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(openURL("mood"))
    }
}

struct MoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoodWidget", provider: DailyProvider()) { entry in
            MoodView(entry: entry).containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("기분 한 줄")
        .description("최근 기록한 기분")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 가계부

struct LedgerView: View {
    let entry: DailyEntry

    var body: some View {
        let monthPrefix = String(Day.key(entry.date).prefix(7))
        let todayKey = Day.key(entry.date)
        let days = (Store.json("ledger_days") as? [String: [NSNumber]]) ?? [:]
        var income: Int64 = 0, expense: Int64 = 0, todayOut: Int64 = 0
        for (k, v) in days where v.count == 2 {
            if k.hasPrefix(monthPrefix) { income += v[0].int64Value; expense += v[1].int64Value }
            if k == todayKey { todayOut += v[1].int64Value }
        }
        let balance = income - expense
        let month = Day.calendar.component(.month, from: entry.date)

        return VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: "이번 달 가계부", trailing: "\(month)월")
            Spacer(minLength: 0)
            Text((balance < 0 ? "-" : "") + won(abs(balance)))
                .font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.text)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("입금 " + won(income)).font(.system(size: 11)).foregroundStyle(Palette.income).lineLimit(1)
            Text("출금 " + won(expense)).font(.system(size: 11)).foregroundStyle(Palette.expense).lineLimit(1)
            Spacer(minLength: 0)
            Text("오늘 지출 " + won(todayOut)).font(.system(size: 11)).foregroundStyle(Palette.sub).lineLimit(1)
        }
        .widgetURL(openURL("ledger"))
    }
}

struct LedgerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LedgerWidget", provider: DailyProvider()) { entry in
            LedgerView(entry: entry).containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("가계부")
        .description("이번 달 입금·출금 요약")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 메모

struct MemoView: View {
    let entry: DailyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let title = Store.string("memo_title")
        let count = Store.int64("memo_count")
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.isEmpty ? "메모" : title)
                    .font(.system(size: 14, weight: .bold)).lineLimit(1)
                Spacer(minLength: 4)
                if family != .systemSmall {
                    Link(destination: openURL("memo_new")) {
                        Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            Text(title.isEmpty ? "눌러서 첫 메모를 남겨 보세요" : Store.string("memo_body"))
                .font(.system(size: 12)).opacity(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if count > 0 {
                Text("메모 \(count)개").font(.system(size: 10)).opacity(0.6)
            }
        }
        .foregroundStyle(Color(argb: 0xFF2B2A33))
        .widgetURL(openURL("memo"))
    }
}

struct MemoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MemoWidget", provider: DailyProvider()) { entry in
            let c = UInt32(truncatingIfNeeded: Store.int64("memo_color"))
            MemoView(entry: entry)
                .containerBackground(c == 0 ? Color(argb: 0xFFFFF7C2) : Color(argb: c), for: .widget)
        }
        .configurationDisplayName("메모")
        .description("고정하거나 최근 수정한 메모")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 타이머

struct TimerEntry: TimelineEntry {
    let date: Date
    let end: Date?
}

struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry { TimerEntry(date: Date(), end: nil) }
    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        completion(TimerEntry(date: Date(), end: WidgetTimer.end))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let now = Date()
        if let end = WidgetTimer.end, end > now {
            // 끝나는 순간 한 번 더 그려서 00:00 으로 바꿈
            completion(Timeline(entries: [TimerEntry(date: now, end: end),
                                          TimerEntry(date: end, end: nil)], policy: .never))
        } else {
            completion(Timeline(entries: [TimerEntry(date: now, end: nil)], policy: .never))
        }
    }
}

struct TimerView: View {
    let entry: TimerEntry

    var body: some View {
        let running = entry.end.map { $0 > entry.date } ?? false
        VStack(spacing: 6) {
            WidgetHeader(title: "타이머", trailing: running ? "진행 중" : "")
            Spacer(minLength: 0)
            Group {
                if running, let end = entry.end {
                    Text(end, style: .timer)
                } else {
                    Text("00:00")
                }
            }
            .font(.system(size: 36, weight: .bold).monospacedDigit())
            .foregroundStyle(Palette.text)
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach([5, 10, 25], id: \.self) { m in
                    Button(intent: StartTimerIntent(minutes: m)) { chip("\(m)분") }.buttonStyle(.plain)
                }
                Button(intent: StopTimerIntent()) { chip("정지") }.buttonStyle(.plain)
            }
        }
        .widgetURL(openURL("timer"))
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.primary)
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .background(Capsule().fill(Palette.chip))
    }
}

struct TimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimerWidget", provider: TimerProvider()) { entry in
            TimerView(entry: entry).containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("타이머")
        .description("버튼 한 번으로 집중 타이머 시작")
        .supportedFamilies([.systemMedium])
    }
}
