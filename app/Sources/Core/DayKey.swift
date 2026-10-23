import Foundation

/// 日期键工具：统一使用 yyyy-MM-dd（本地时区）。
public enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current
        f.dateFormat = "M 月 d 日 · EEEE"
        return f
    }()

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current
        f.dateFormat = "M 月 d 日"
        return f
    }()

    public static func key(for date: Date = Date()) -> String {
        formatter.string(from: date)
    }

    public static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }

    /// 「10 月 8 日 · 星期三」
    public static func label(for key: String) -> String {
        guard let d = date(from: key) else { return key }
        return displayFormatter.string(from: d)
    }

    /// 「10 月 8 日」
    public static func shortLabel(for key: String) -> String {
        guard let d = date(from: key) else { return key }
        return shortFormatter.string(from: d)
    }

    /// 中文数字（1–39）：四、十二、二十四……
    public static func cnNumber(_ n: Int) -> String {
        let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if n < 10 { return digits[n] }
        if n == 10 { return "十" }
        if n < 20 { return "十" + digits[n - 10] }
        if n % 10 == 0 { return digits[n / 10] + "十" }
        return digits[n / 10] + "十" + digits[n % 10]
    }

    /// 「十月二十四日」（中文数字日期，用于刊头与清单的日期组头）。
    public static func cnLabel(for key: String) -> String {
        guard let d = date(from: key) else { return key }
        let cal = Calendar(identifier: .gregorian)
        return "\(cnNumber(cal.component(.month, from: d)))月\(cnNumber(cal.component(.day, from: d)))日"
    }

    /// from 到 to 相差的天数（to - from），用于未完成池的本周 / 本月筛选。
    public static func daysBetween(_ from: String, _ to: String) -> Int {
        guard let a = date(from: from), let b = date(from: to) else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: a)
        let end = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 日期键前进一天。
    public static func advance(_ key: String, by days: Int = 1) -> String {
        guard let d = date(from: key) else { return key }
        let cal = Calendar(identifier: .gregorian)
        guard let next = cal.date(byAdding: .day, value: days, to: d) else { return key }
        return formatter.string(from: next)
    }
}
