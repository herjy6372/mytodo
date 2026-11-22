import SwiftUI
import WidgetKit

@main
struct MyTodoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
        DailyDoneWidget()
        YearlyWidget()
        MoodWidget()
        LedgerWidget()
        MemoWidget()
        TimerWidget()
        WorldClockWidget()
        WorldClockDualWidget()
    }
}
