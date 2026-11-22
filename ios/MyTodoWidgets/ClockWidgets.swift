import SwiftUI
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
}

/// 1분마다 다시 그리는 타임라인 (1시간 분량).
struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let now = Date()
        let minute = Day.calendar.dateInterval(of: .minute, for: now)!.start
        var entries = [ClockEntry(date: now)]
        for i in 1...60 {
            entries.append(ClockEntry(date: minute.addingTimeInterval(Double(i * 60))))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct CityClock: View {
    let date: Date
    let name: String
    let tz: TimeZone
    var big: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.sub).lineLimit(1)
            Spacer(minLength: 0)
            Text(formatDate(date, "a h:mm", timeZone: tz))
                .font(.system(size: big, weight: .bold)).foregroundStyle(Palette.text)
                .minimumScaleFactor(0.6).lineLimit(1)
            Spacer(minLength: 0)
            Text(formatDate(date, "M월 d일 (E)", timeZone: tz))
                .font(.system(size: 12)).foregroundStyle(Palette.sub).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func city(_ prefix: String, defaultTz: String, defaultName: String) -> (String, TimeZone) {
    let id = Store.string("clock_\(prefix)_tz")
    let name = Store.string("clock_\(prefix)_name")
    return (name.isEmpty ? defaultName : name,
            TimeZone(identifier: id.isEmpty ? defaultTz : id) ?? .current)
}

struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorldClockWidget", provider: ClockProvider()) { entry in
            let (name, tz) = city("main", defaultTz: "Asia/Seoul", defaultName: "서울")
            CityClock(date: entry.date, name: name, tz: tz)
                .widgetURL(openURL("worldclock"))
                .containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("세계시각")
        .description("메인 도시의 현재 시각")
        .supportedFamilies([.systemSmall])
    }
}

struct WorldClockDualWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorldClockDualWidget", provider: ClockProvider()) { entry in
            let (mainName, mainTz) = city("main", defaultTz: "Asia/Seoul", defaultName: "서울")
            let (subName, subTz) = city("sub", defaultTz: "America/Los_Angeles", defaultName: "로스앤젤레스")
            HStack(spacing: 12) {
                CityClock(date: entry.date, name: mainName, tz: mainTz, big: 26)
                Rectangle().fill(Palette.chip).frame(width: 1)
                CityClock(date: entry.date, name: subName, tz: subTz, big: 26)
            }
            .widgetURL(openURL("worldclock"))
            .containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("세계시각 (메인 | 서브)")
        .description("두 도시의 시각을 나란히")
        .supportedFamilies([.systemMedium])
    }
}
