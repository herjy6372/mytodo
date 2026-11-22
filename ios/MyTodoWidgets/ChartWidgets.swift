import SwiftUI
import WidgetKit

// MARK: - 일별 완료 현황 (최근 7일)

struct DailyDoneView: View {
    let entry: DailyEntry

    var body: some View {
        let stats = Store.stats()
        let cal = Day.calendar
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0 - 6, to: entry.date)! }
        let today = stats[Day.key(entry.date)] ?? (0, 0)
        let summary = today.total == 0 ? "오늘 예정된 할 일이 없어요"
            : "오늘 \(today.done)/\(today.total) 완료 · \(today.done * 100 / today.total)%"

        VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: "일별 완료 현황")
            Text(summary).font(.system(size: 11)).foregroundStyle(Palette.sub)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    let s = stats[Day.key(d)] ?? (0, 0)
                    let ratio = s.total == 0 ? 0 : CGFloat(s.done) / CGFloat(s.total)
                    VStack(spacing: 4) {
                        GeometryReader { g in
                            ZStack(alignment: .bottom) {
                                Capsule().fill(Palette.chip)
                                if ratio > 0 {
                                    Capsule().fill(i == 6 ? Palette.accent : Palette.primary)
                                        .frame(height: max(g.size.width, g.size.height * ratio))
                                }
                            }
                        }
                        .frame(width: 16)
                        Text(i == 6 ? "오늘" : formatDate(d, "E"))
                            .font(.system(size: 10)).foregroundStyle(Palette.sub)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
        }
        .widgetURL(openURL("graph"))
    }
}

struct DailyDoneWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyDoneWidget", provider: DailyProvider()) { entry in
            DailyDoneView(entry: entry).containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("일별 완료 현황")
        .description("최근 7일 할 일 완료율")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 연간 활동 기록 (잔디)

struct YearlyView: View {
    let entry: DailyEntry
    private let weeks = 53

    var body: some View {
        let stats = Store.stats()
        let cal = Day.calendar
        let today = cal.startOfDay(for: entry.date)
        let weekday = cal.component(.weekday, from: today) // 일요일=1
        let start = cal.date(byAdding: .day, value: -(weekday - 1) - (weeks - 1) * 7, to: today)!
        var cells: [(col: Int, row: Int, level: Int)] = []
        var months: [(col: Int, label: String)] = []
        var total = 0
        var lastMonth = -1
        var lastLabelCol = -10
        for col in 0..<weeks {
            let weekStart = cal.date(byAdding: .day, value: col * 7, to: start)!
            let m = cal.component(.month, from: weekStart)
            if m != lastMonth {
                if lastMonth != -1 && col - lastLabelCol >= 4 && col < weeks - 2 {
                    months.append((col, "\(m)월")); lastLabelCol = col
                }
                lastMonth = m
            }
            for row in 0..<7 {
                let d = cal.date(byAdding: .day, value: row, to: weekStart)!
                if d > today { break }
                let done = stats[Day.key(d)]?.done ?? 0
                total += done
                let level = done <= 0 ? 0 : done == 1 ? 1 : done == 2 ? 2 : done <= 4 ? 3 : 4
                cells.append((col, row, level))
            }
        }

        return VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "연간 활동 기록", trailing: "최근 1년 완료 \(total)개")
            Spacer(minLength: 0)
            GeometryReader { g in
                let step = g.size.width / CGFloat(weeks)
                let cell = step * 0.8
                Canvas { ctx, _ in
                    for c in cells {
                        let rect = CGRect(x: CGFloat(c.col) * step, y: CGFloat(c.row) * step,
                                          width: cell, height: cell)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.25),
                                 with: .color(Palette.heat[c.level]))
                    }
                }
                .frame(height: step * 7)
                ZStack(alignment: .topLeading) {
                    ForEach(months, id: \.col) { m in
                        Text(m.label).font(.system(size: 9)).foregroundStyle(Palette.sub)
                            .fixedSize()
                            .offset(x: CGFloat(m.col) * step)
                    }
                }
                .offset(y: step * 7 + 2)
            }
            .frame(height: 62)
            HStack(spacing: 3) {
                Spacer()
                Text("적음").font(.system(size: 9)).foregroundStyle(Palette.sub)
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Palette.heat[i]).frame(width: 8, height: 8)
                }
                Text("많음").font(.system(size: 9)).foregroundStyle(Palette.sub)
            }
        }
        .widgetURL(openURL("calendar"))
    }
}

struct YearlyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YearlyWidget", provider: DailyProvider()) { entry in
            YearlyView(entry: entry).containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("연간 활동 기록")
        .description("1년 동안 완료한 할 일을 잔디로 보여줘요.")
        .supportedFamilies([.systemMedium])
    }
}
