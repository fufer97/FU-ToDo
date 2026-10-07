import Foundation

/// 示例数据：用于试看模式与界面评审截图，不写入正式数据文件。
public enum SampleData {

    public static func populate(_ store: TaskStore) {
        let today = store.currentDay
        func day(_ offset: Int) -> String {
            DayKey.advance(today, by: -offset)
        }

        // 今天：一个主目标 + 一条顺带的事
        let goal = store.addMain("写完产品原型说明", on: today)
        if let goal {
            if let step1 = store.addChild(of: goal.id, title: "整理阶段 1 的规则条目") {
                store.addChild(of: step1.id, title: "校对文案与标点")
            }
            store.addChild(of: goal.id, title: "画出三个界面的草图")
        }
        store.addTopLevel("回一封邮件", on: today)
        store.addTopLevel("整理本月会议记录", on: today)
        if let done = store.addTopLevel("把今天的截图归档", on: today) {
            store.complete(done.id)
        }

        // 昨天
        if let weekly = store.addTopLevel("写周报", on: day(1)) {
            store.complete(weekly.id)
        }
        store.addTopLevel("整理收件箱", on: day(1))

        // 更早
        store.addTopLevel("读完《卡片笔记写作法》第 3 章", on: day(2))

        if let meeting = store.addTopLevel("整理上周会议记录", on: day(3)) {
            store.addChild(of: meeting.id, title: "补上遗漏的结论")
        }
        store.addTopLevel("预约体检", on: day(3))

        store.addTopLevel("学习 SwiftUI 布局", on: day(6))

        store.addTopLevel("备份照片", on: day(9))

        if let icloud = store.addTopLevel("研究 iCloud 同步方案", on: day(21)) {
            store.ignore(icloud.id)
        }
        store.addTopLevel("整理去年的体检报告", on: day(38))

        // 未来：还没到的日子（用浅灰显示）
        store.addTopLevel("下周开始整理照片", on: DayKey.advance(today, by: 4))

        store.toast = nil
        store.toastHasUndo = false
    }
}
