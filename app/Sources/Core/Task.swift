import Foundation

/// 任务的结束方式：勾选完成（做到了）或忽略（决定不再做）。
public enum DoneKind: String, Codable, Equatable {
    case checked
    case ignored

    public var label: String {
        switch self {
        case .checked: return "勾选完成"
        case .ignored: return "忽略"
        }
    }
}

/// 任务。树形结构通过 parentId 表达；order 是同级内的排序值。
public struct Task: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var parentId: UUID?
    public var order: Int
    /// 任务所属的那一天（yyyy-MM-dd），用于判断是否属于「今天」。
    public var day: String
    /// 是否是当天的主线（一天最多一个，由 store 保证）。
    public var isMain: Bool
    public var done: Bool
    public var doneKind: DoneKind?
    public var endedAt: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        parentId: UUID? = nil,
        order: Int = 0,
        day: String,
        isMain: Bool = false,
        done: Bool = false,
        doneKind: DoneKind? = nil,
        endedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.parentId = parentId
        self.order = order
        self.day = day
        self.isMain = isMain
        self.done = done
        self.doneKind = doneKind
        self.endedAt = endedAt
        self.createdAt = createdAt
    }
}

/// 落盘的数据结构。
public struct AppData: Codable {
    public var currentDay: String
    public var tasks: [Task]
    public var settings: AppSettings

    public init(currentDay: String, tasks: [Task], settings: AppSettings = AppSettings()) {
        self.currentDay = currentDay
        self.tasks = tasks
        self.settings = settings
    }

    /// 容错解码：老数据文件没有 settings 字段时用默认外观。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentDay = try c.decode(String.self, forKey: .currentDay)
        tasks = try c.decode([Task].self, forKey: .tasks)
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }
}
