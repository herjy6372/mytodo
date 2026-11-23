import AppIntents
import UserNotifications
import WidgetKit

/// 위젯에서 할 일 체크/해제. 위젯 표시는 바로 바꾸고, 실제 데이터는
/// 앱이 열릴 때 pending_toggles 를 읽어 반영합니다(서버 동기화 포함).
struct ToggleTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "할 일 체크"
    static var isDiscoverable: Bool = false

    @Parameter(title: "할 일 ID") var todoId: String

    init() {}
    init(todoId: String) { self.todoId = todoId }

    func perform() async throws -> some IntentResult {
        guard var items = Store.json("todo_items") as? [[String: Any]] else { return .result() }
        var day: String?
        var nowDone = false
        for i in items.indices where (items[i]["id"] as? String) == todoId {
            nowDone = !((items[i]["done"] as? Bool) ?? false)
            items[i]["done"] = nowDone
            day = items[i]["day"] as? String
        }
        guard let day else { return .result() }
        Store.setJSON("todo_items", items)

        // 완료 현황 위젯도 바로 맞춤
        if var stats = Store.json("todo_stats") as? [String: [Int]], var s = stats[day], s.count == 2 {
            s[0] = max(0, min(s[1], s[0] + (nowDone ? 1 : -1)))
            stats[day] = s
            Store.setJSON("todo_stats", stats)
        }

        var pending = (Store.json("pending_toggles") as? [String]) ?? []
        pending.append(todoId)
        Store.setJSON("pending_toggles", pending)

        WidgetCenter.shared.reloadTimelines(ofKind: "DailyDoneWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "YearlyWidget")
        return .result()
    }
}

enum WidgetTimer {
    static let notificationId = "widget_timer"

    static var end: Date? {
        let ms = Store.int64("timer_end_ms")
        guard ms > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(ms) / 1000)
    }
}

/// 위젯 타이머 시작. 끝나면 알람음 알림이 울립니다.
struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "타이머 시작"
    static var isDiscoverable: Bool = false

    @Parameter(title: "분") var minutes: Int

    init() {}
    init(minutes: Int) { self.minutes = minutes }

    func perform() async throws -> some IntentResult {
        // 로그인해야 쓸 수 있음 (위젯 화면에서도 버튼을 숨기지만 한 번 더 확인)
        guard WidgetAuth.loggedIn else { return .result() }
        let end = Date().addingTimeInterval(Double(minutes * 60))
        Store.set("timer_end_ms", String(Int64(end.timeIntervalSince1970 * 1000)))
        Store.set("timer_total_s", String(minutes * 60))

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [WidgetTimer.notificationId])
        let content = UNMutableNotificationContent()
        content.title = "⏱️ 타이머 종료"
        content.body = "\(minutes)분 타이머가 끝났어요."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes * 60), repeats: false)
        try? await center.add(UNNotificationRequest(
            identifier: WidgetTimer.notificationId, content: content, trigger: trigger))
        return .result()
    }
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "타이머 정지"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        Store.set("timer_end_ms", "0")
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [WidgetTimer.notificationId])
        return .result()
    }
}

/// 앱이 App Group 에 기록한 로그인 여부.
enum WidgetAuth {
    static var loggedIn: Bool { Store.string("logged_in") == "1" }
}
