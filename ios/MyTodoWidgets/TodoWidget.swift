import SwiftUI
import WidgetKit

struct TodoItem: Identifiable {
    let id: String
    let title: String
    let due: Date
    let done: Bool
}

struct TodoEntry: TimelineEntry {
    let date: Date
    let items: [TodoItem]
}

struct TodoProvider: TimelineProvider {
    static func load(for date: Date = Date()) -> TodoEntry {
        let today = Day.key(date)
        let raw = (Store.json("todo_items") as? [[String: Any]]) ?? []
        let items = raw.compactMap { o -> TodoItem? in
            guard (o["day"] as? String) == today, let id = o["id"] as? String else { return nil }
            let due = (o["due"] as? NSNumber)?.doubleValue ?? 0
            return TodoItem(id: id, title: (o["title"] as? String) ?? "",
                            due: Date(timeIntervalSince1970: due / 1000),
                            done: (o["done"] as? Bool) ?? false)
        }
        // 안 한 일 먼저, 그다음 시간 순
        let sorted = items.sorted { a, b in a.done != b.done ? !a.done : a.due < b.due }
        return TodoEntry(date: date, items: sorted)
    }

    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), items: [
            TodoItem(id: "1", title: "아침 운동", due: Date(), done: true),
            TodoItem(id: "2", title: "장보기", due: Date(), done: false),
        ])
    }
    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(context.isPreview && Store.json("todo_items") == nil ? placeholder(in: context) : Self.load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        completion(Timeline(entries: [Self.load()], policy: .after(Day.nextMidnight())))
    }
}

struct TodoWidgetView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) var family

    private var maxRows: Int { family == .systemLarge ? 10 : 4 }

    var body: some View {
        let done = entry.items.filter(\.done).count
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "오늘 할 일",
                         trailing: entry.items.isEmpty ? "" : "\(done)/\(entry.items.count) 완료")
            if entry.items.isEmpty {
                Spacer()
                Text("오늘 할 일이 없어요 🎉").font(.system(size: 13)).foregroundStyle(Palette.sub)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items.prefix(maxRows)) { item in
                    Button(intent: ToggleTodoIntent(todoId: item.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17))
                                .foregroundStyle(item.done ? Palette.primary : Palette.sub)
                            Text(item.title).font(.system(size: 13))
                                .strikethrough(item.done)
                                .foregroundStyle(item.done ? Palette.sub : Palette.text)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(formatDate(item.due, "HH:mm"))
                                .font(.system(size: 11)).foregroundStyle(Palette.sub)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if entry.items.count > maxRows {
                    Text("외 \(entry.items.count - maxRows)개 더 있어요")
                        .font(.system(size: 11)).foregroundStyle(Palette.sub)
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(openURL("todo"))
    }
}

struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodoWidget", provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry).containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("할 일 체크")
        .description("오늘 할 일을 보고 바로 체크해요.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
