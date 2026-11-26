import SwiftUI
import WidgetKit

/// 앱(Flutter WidgetService)과 위젯이 함께 쓰는 App Group.
let appGroupId = "group.com.terablack.mytodo"

/// Flutter 쪽이 문자열로 저장한 위젯 데이터를 읽고 씁니다.
enum Store {
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroupId) ?? .standard }

    static func string(_ key: String) -> String {
        if let s = defaults.string(forKey: key) { return s }
        if let n = defaults.object(forKey: key) as? NSNumber { return n.stringValue }
        return ""
    }

    static func int64(_ key: String) -> Int64 { Int64(string(key)) ?? 0 }

    static func set(_ key: String, _ value: String) { defaults.set(value, forKey: key) }

    static func json(_ key: String) -> Any? {
        guard let data = string(key).data(using: .utf8), !data.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    static func setJSON(_ key: String, _ value: Any) {
        if let data = try? JSONSerialization.data(withJSONObject: value),
           let s = String(data: data, encoding: .utf8) {
            set(key, s)
        }
    }

    /// 날짜별 [완료, 전체] 통계.
    static func stats() -> [String: (done: Int, total: Int)] {
        guard let o = json("todo_stats") as? [String: [Int]] else { return [:] }
        return o.mapValues { ($0.count > 0 ? $0[0] : 0, $0.count > 1 ? $0[1] : 0) }
    }
}

enum Day {
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date = Date()) -> String { keyFormatter.string(from: date) }

    static var calendar: Calendar { Calendar.current }

    static func nextMidnight(after date: Date = Date()) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(5)
    }

    static func monthDayLabel(_ key: String) -> String {
        let p = key.split(separator: "-")
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]) else { return key }
        return "\(m)월 \(d)일"
    }
}

/// 위젯을 누르면 앱의 해당 화면을 엽니다. (home_widget 은 homeWidget 파라미터가 있는 URL 만 전달)
func openURL(_ screen: String) -> URL {
    URL(string: "mytodo://open/\(screen)?homeWidget=1")!
}

func won(_ amount: Int64) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "ko_KR")
    return (f.string(from: NSNumber(value: amount)) ?? "\(amount)") + "원"
}

extension Color {
    /// 라이트/다크 모드별 색상.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { trait in
            UIColor(argb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(argb: UInt32) { self.init(UIColor(argb: argb)) }
}

extension UIColor {
    convenience init(argb: UInt32) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255
        let r = CGFloat((argb >> 16) & 0xFF) / 255
        let g = CGFloat((argb >> 8) & 0xFF) / 255
        let b = CGFloat(argb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: a == 0 ? 1 : a)
    }
}

enum Palette {
    static let background = Color(light: 0xFFFFFFFF, dark: 0xFF1E1D24)
    static let text = Color(light: 0xFF1F1D2B, dark: 0xFFF2F1F7)
    static let sub = Color(light: 0xFF6E6A80, dark: 0xFFA9A6B8)
    static let primary = Color(light: 0xFF5B5592, dark: 0xFFB3ABF2)
    static let chip = Color(light: 0xFFEFEDF8, dark: 0xFF35333F)
    static let accent = Color(argb: 0xFFFFA94D)
    static let income = Color(argb: 0xFF22B6A0)
    static let expense = Color(argb: 0xFFF0657D)
    static let heat: [Color] = [
        Color(light: 0xFFEFEDF8, dark: 0xFF35333F),
        Color(light: 0xFFCFC9F0, dark: 0xFF4A4580),
        Color(light: 0xFFA59CE3, dark: 0xFF6A62B8),
        Color(light: 0xFF7B71CC, dark: 0xFF8F86E0),
        Color(light: 0xFF5B5592, dark: 0xFFB3ABF2),
    ]
}

/// 위젯 제목 줄.
struct WidgetHeader: View {
    let title: String
    var trailing: String = ""

    var body: some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            if !trailing.isEmpty {
                Text(trailing).font(.system(size: 12)).foregroundStyle(Palette.sub).lineLimit(1)
            }
        }
    }
}

/// 날짜가 바뀔 때만 다시 그리는 기본 타임라인.
struct DailyEntry: TimelineEntry {
    let date: Date
}

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry { DailyEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(DailyEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        completion(Timeline(entries: [DailyEntry(date: Date())], policy: .after(Day.nextMidnight())))
    }
}

/// 고정 형식 날짜 문자열 (한국어). timeZone 을 주면 그 도시 기준.
func formatDate(_ date: Date, _ pattern: String, timeZone: TimeZone = .current) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.timeZone = timeZone
    f.dateFormat = pattern
    return f.string(from: date)
}
