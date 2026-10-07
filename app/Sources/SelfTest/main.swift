import Foundation
import Core
import UI

var passed = 0
var failed = 0

func check(_ label: String, _ condition: Bool) {
    if condition {
        passed += 1
        print("  ✓ \(label)")
    } else {
        failed += 1
        print("  ✗ \(label)")
    }
}

func makeStore() -> TaskStore {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("yrjy-selftest-\(UUID().uuidString).json")
    return TaskStore(storeURL: url, today: "2026-10-08")
}

print("一、今日页取数")
do {
    let s = makeStore()
    let goal = s.addTopLevel("写完产品原型说明")!
    let step = s.addChild(of: goal.id, title: "整理规则条目")!
    let deep = s.addChild(of: step.id, title: "校对文案")!
    check("顶层任务进入今日页", s.todayRoots.count == 1)
    check("层级计算正确（1 / 2 / 3）", s.level(of: goal) == 1 && s.level(of: step) == 2 && s.level(of: deep) == 3)
    check("子树包含三代", s.subtree(goal.id).count == 3)
    check("上级路径可读", s.pathText(of: deep) == "写完产品原型说明 › 整理规则条目")
    check("空标题不会被添加", s.addTopLevel("   ") == nil)
}

print("\n二、勾选完成连带整棵子树 + 撤销")
do {
    let s = makeStore()
    let goal = s.addTopLevel("主目标")!
    let step = s.addChild(of: goal.id, title: "步骤一")!
    _ = s.addChild(of: step.id, title: "细节")
    s.complete(goal.id)
    check("整棵子树都已完成", s.subtree(goal.id).allSatisfy { $0.done })
    check("结束方式为勾选完成", s.task(goal.id)?.doneKind == .checked)
    check("完成后离开今日页", s.todayRoots.isEmpty)
    check("提示语说明连带数量", s.toast?.contains("连带 2 个子步骤") == true)
    s.undo()
    check("撤销后回到未完成", s.subtree(goal.id).allSatisfy { !$0.done })
    check("撤销后回到今日页", s.todayRoots.count == 1)
}

print("\n三、忽略与恢复")
do {
    let s = makeStore()
    let goal = s.addTopLevel("主目标")!
    let step = s.addChild(of: goal.id, title: "步骤")!
    s.ignore(goal.id)
    check("忽略连带子树", s.subtree(goal.id).allSatisfy { $0.done })
    check("结束方式为忽略", s.task(step.id)?.doneKind == .ignored)
    check("已结束列表可见", s.doneTasks.count == 2)
    s.revert(goal.id)
    check("恢复只恢复这一条", s.task(goal.id)?.done == false)
    check("它的子步骤仍保持已结束", s.task(step.id)?.done == true)
    check("已结束列表只剩子步骤", s.doneTasks.count == 1)
    s.revertSubtree(goal.id)
    check("恢复整棵可以把子步骤一起退回来", s.subtree(goal.id).allSatisfy { !$0.done })
    check("已结束列表清空", s.doneTasks.isEmpty)
}

print("\n四、未完成项目清单（只列一级）与重新执行")
do {
    let s = makeStore()
    let old = s.addTopLevel("两个月前的事", on: "2026-08-20")!
    _ = s.addTopLevel("十天前的事", on: "2026-09-28")
    let meeting = s.addTopLevel("上周的会", on: "2026-10-05")!
    let child = s.addChild(of: meeting.id, title: "补结论")!
    let grandchild = s.addChild(of: child.id, title: "补结论的细节")!

    s.range = .week
    check("本周只列一级：1 条", s.poolTasks().count == 1)
    s.range = .month
    check("本月只列一级：2 条", s.poolTasks().count == 2)
    s.range = .all
    check("所有只列一级：3 条", s.poolTasks().count == 3)
    check("二三级不单独进清单", !s.poolTasks().contains { $0.id == child.id || $0.id == grandchild.id })

    // 先完成一个叶子步骤，再重新执行整棵树
    s.complete(grandchild.id)
    check("叶子步骤已完成", s.task(grandchild.id)?.done == true)
    check("完成叶子不会连带上级", s.task(child.id)?.done == false && s.task(meeting.id)?.done == false)

    s.reexecute(meeting.id)
    check("整棵树都搬到今天", s.subtree(meeting.id).allSatisfy { $0.day == "2026-10-08" })
    check("三级也跟着搬", s.task(grandchild.id)?.day == "2026-10-08")
    check("原日子不再保留这条", !s.roots(of: "2026-10-05").contains { $0.id == meeting.id })
    check("已完成的叶子保持完成", s.task(grandchild.id)?.done == true)
    check("未完成的中间层仍是未完成", s.task(child.id)?.done == false)
    check("提示语说明搬了整棵树", s.toast?.contains("整棵树") == true)
    check("搬到今天后进入今日页", s.roots(of: "2026-10-08").contains { $0.id == meeting.id })

    let before = s.tasks.filter { $0.day == "2026-10-08" }.count
    s.reexecute(meeting.id)
    check("同日重复重新执行被去重", s.tasks.filter { $0.day == "2026-10-08" }.count == before)
    check("去重时给出提示", s.toast == "今天已经在清单里了")
    check("久远任务仍在所有范围", s.poolTasks().contains { $0.id == old.id })
}

print("\n五、跨天不结转")
do {
    let s = makeStore()
    let goal = s.addTopLevel("今天没做完的事")!
    s.range = .all
    let poolBefore = s.poolTasks().count
    let rolled = s.checkRollover(now: DayKey.date(from: "2026-10-09")!)
    check("跨天被检测到", rolled)
    check("今天是新的一天", s.currentDay == "2026-10-09")
    check("今日页变空（不结转）", s.todayRoots.isEmpty)
    check("旧任务进入未完成池", s.poolTasks().count == poolBefore + 1)
    check("任务本身的日期没变", s.task(goal.id)?.day == "2026-10-08")
    check("选中的日期跟随到今天", s.selectedDay == "2026-10-09")
}

print("\n六、拖拽（嵌套 / 重排 / 拒绝非法嵌套）")
do {
    let s = makeStore()
    let a = s.addTopLevel("A")!
    let b = s.addTopLevel("B")!
    let c = s.addTopLevel("C")!
    _ = s.addChild(of: a.id, title: "A-1")

    s.performDrop(draggedId: c.id, targetId: a.id, zone: .nest)
    check("拖到中间成为子步骤", s.task(c.id)?.parentId == a.id)
    check("子步骤层级为 2", s.level(of: s.task(c.id)!) == 2)

    s.performDrop(draggedId: c.id, targetId: a.id, zone: .before)
    check("拖到上缘回到顶层", s.task(c.id)?.parentId == nil)
    check("顺序被调整到 A 之前", s.roots().map(\.title) == ["C", "A", "B"])

    s.performDrop(draggedId: b.id, targetId: c.id, zone: .after)
    check("拖到下缘排到 C 之后", s.roots().map(\.title) == ["C", "B", "A"])

    s.performDrop(draggedId: a.id, targetId: s.children(of: a.id).first!.id, zone: .nest)
    check("拒绝把父任务拖进自己的子步骤", s.task(a.id)?.parentId == nil)

    s.moveToTopLevel(s.children(of: a.id).first!.id)
    check("拖到顶层区域升级为顶层", s.roots().count == 4)
}

print("\n七、删除可撤销 + 持久化")
do {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("yrjy-persist-\(UUID().uuidString).json")
    let s = TaskStore(storeURL: url, today: "2026-10-08")
    let goal = s.addTopLevel("会被删掉的目标")!
    _ = s.addChild(of: goal.id, title: "子步骤")
    _ = s.addTopLevel("留下的目标")
    s.save()

    let reloaded = TaskStore(storeURL: url, today: "2026-10-08")
    check("重新载入后任务数量一致", reloaded.tasks.count == 3)
    check("重新载入后标题一致", reloaded.roots().first?.title == "会被删掉的目标")

    s.delete(goal.id)
    check("删除父任务连带子树", s.tasks.count == 1)
    s.undo()
    check("删除可撤销", s.tasks.count == 3)
}

print("\n八、样例数据可用（供试看与截图）")
do {
    let s = makeStore()
    SampleData.populate(s)
    s.range = .week
    let weekCount = s.poolTasks().count
    s.range = .all
    check("样例数据生成了今日任务", s.todayRoots.count >= 2)
    check("样例数据覆盖多个时间范围", s.poolTasks().count > weekCount)
    check("样例数据含未来任务（用于验证浅灰）", s.tasks.contains { $0.day > s.currentDay })
    check("样例数据含已完成任务", !s.doneTasks.isEmpty)
}

print("\n九、设置持久化与备份往返")
do {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("yrjy-settings-\(UUID().uuidString).json")
    let s = TaskStore(storeURL: url, today: "2026-10-08")
    _ = s.addTopLevel("设置测试任务")
    s.updateSettings {
        $0.appearance = .dark
        $0.accent = .indigo
        $0.paper = .plain
        $0.fontScale = .large
    }
    let reloaded = TaskStore(storeURL: url, today: "2026-10-08")
    check("设置随数据一起落盘", reloaded.settings == s.settings)
    check("深浅色持久化", reloaded.settings.appearance == .dark)
    check("字号持久化", reloaded.settings.fontScale == .large)

    let backup = try s.exportData()
    let fresh = TaskStore(storeURL: nil, today: "2026-10-08")
    try fresh.importData(backup)
    check("备份可以导入", fresh.tasks.count == s.tasks.count)
    check("备份带上设置", fresh.settings == s.settings)
    check("导入后标题一致", fresh.roots().first?.title == "设置测试任务")

    do {
        try fresh.importData(Data("这不是备份".utf8))
        check("坏文件会被拒绝", false)
    } catch {
        check("坏文件会被拒绝", true)
    }

    fresh.clearAllTasks()
    check("清空数据", fresh.tasks.isEmpty)
    check("清空可撤销", { fresh.undo(); return !fresh.tasks.isEmpty }())
}

print("\n十、主线 / 支线角色（只由用户显式指定）")
do {
    let s = makeStore()
    let branchFirst = s.addTopLevel("先加一条支线")!
    check("没有主线也可以先添加支线", s.mainGoal(on: "2026-10-08") == nil)
    check("先加的这条是支线", s.branches(on: "2026-10-08").map(\.id) == [branchFirst.id])
    check("支线不会自己变成主线", branchFirst.isMain == false)

    let main = s.addMain("写下今天的主线")!
    check("主线由书写线显式产生", s.mainGoal(on: "2026-10-08")?.id == main.id)
    check("已有支线时主线仍然唯一", s.tasks.filter { $0.isMain && $0.day == "2026-10-08" }.count == 1)
    check("先加的支线还在支线里", s.branches(on: "2026-10-08").map(\.id) == [branchFirst.id])

    s.setMain(branchFirst.id)
    check("可以显式改主线", s.mainGoal(on: "2026-10-08")?.id == branchFirst.id)
    check("旧主线降为支线", s.branches(on: "2026-10-08").map(\.id) == [main.id])

    s.complete(branchFirst.id)
    check("主线完成后当天没有主线", s.mainGoal(on: "2026-10-08") == nil)
    check("不自动提拔支线", s.branches(on: "2026-10-08").allSatisfy { !$0.isMain })
    s.revert(branchFirst.id)
    check("撤销后主线角色回来", s.mainGoal(on: "2026-10-08")?.id == branchFirst.id)

    let anchor = s.addChild(of: main.id, title: "步骤一")!
    let sibling = s.addSibling(after: anchor.id, title: "步骤二")!
    check("同级插入层级一致", s.level(of: sibling) == s.level(of: anchor))
    check("同级插入位置在锚点之后", s.children(of: main.id).map(\.title) == ["步骤一", "步骤二"])
    check("同级插入不是主线", sibling.isMain == false)

    let topSibling = s.addSibling(after: main.id, title: "顶层再加一条")!
    check("顶层同级插入落为支线", topSibling.isMain == false)
    check("主线没有被抢走", s.mainGoal(on: "2026-10-08")?.id != topSibling.id)
}

print("\n十一、跨天移动与拖拽角色规则")
do {
    let s = makeStore()
    let main = s.addMain("今天的主线")!
    let other = s.addTopLevel("今天的支线")!
    _ = s.addChild(of: other.id, title: "支线的一步")

    s.moveToDay(other.id, day: "2026-10-12", asMain: true)
    check("整棵子树都移到那天", s.subtree(other.id).allSatisfy { $0.day == "2026-10-12" })
    check("落到没有主线的日子可以成为主线", s.mainGoal(on: "2026-10-12")?.id == other.id)
    check("原日子只剩主线", s.roots(of: "2026-10-08").map(\.id) == [main.id])

    let another = s.addTopLevel("另一条要搬的")!
    _ = s.addChild(of: another.id, title: "它的一步")
    s.moveToDay(another.id, day: "2026-10-12", asMain: true)
    check("目标日已有主线时不会出现第二个主线", s.tasks.filter { $0.isMain && $0.day == "2026-10-12" }.count == 1)
    check("它落为支线", s.branches(on: "2026-10-12").contains { $0.id == another.id })
    check("整棵子步骤跟着搬", s.subtree(another.id).allSatisfy { $0.day == "2026-10-12" })

    let s2 = makeStore()
    let main2 = s2.addMain("主线")!
    let child2 = s2.addChild(of: main2.id, title: "子步骤")!
    s2.moveToTopLevel(child2.id)
    check("拖回顶层不会自动成为主线", s2.mainGoal(on: "2026-10-08")?.id == main2.id)
    check("拖回顶层落为支线", s2.branches(on: "2026-10-08").contains { $0.id == child2.id })
    s2.setMain(child2.id)
    check("显式设为主线可以换主线", s2.mainGoal(on: "2026-10-08")?.id == child2.id)

    // 目标日没有主线 → 直接成为那天的主线，并带走整棵子树
    let s3 = makeStore()
    let a = s3.addMain("要搬走的事")!
    let aChild = s3.addChild(of: a.id, title: "它的子步骤")!
    let aGrand = s3.addChild(of: aChild.id, title: "更细的一步")!
    s3.requestMoveToDay(a.id, day: "2026-11-01")
    check("目标日没有主线时直接搬过去", s3.task(a.id)?.day == "2026-11-01")
    check("二级子步骤一起过去", s3.task(aChild.id)?.day == "2026-11-01")
    check("三级子步骤也一起过去", s3.task(aGrand.id)?.day == "2026-11-01")
    check("目标日没有主线时它成为主线", s3.mainGoal(on: "2026-11-01")?.id == a.id)

    // 目标日已有主线 → 落为支线，同样带走整棵子树
    let s4 = makeStore()
    _ = s4.addMain("目标日已有的主线", on: "2026-11-05")
    let moved = s4.addMain("被搬走的主线")!
    let movedChild = s4.addChild(of: moved.id, title: "被搬走的子步骤")!
    s4.requestMoveToDay(moved.id, day: "2026-11-05")
    check("目标日已有主线时直接搬过去", s4.task(moved.id)?.day == "2026-11-05")
    check("它的子步骤一起过去", s4.task(movedChild.id)?.day == "2026-11-05")
    check("目标日主线没有被顶掉", s4.mainGoal(on: "2026-11-05")?.title == "目标日已有的主线")
    check("搬过去的落为支线", s4.branches(on: "2026-11-05").contains { $0.id == moved.id })

    // 拖的是中间层：它和它的子孙一起走，上级留在原处
    let s5 = makeStore()
    let top = s5.addMain("留在原处的上级")!
    let mid = s5.addChild(of: top.id, title: "被搬走的中间层")!
    let deep = s5.addChild(of: mid.id, title: "它的下级")!
    s5.requestMoveToDay(mid.id, day: "2026-11-09")
    check("中间层搬走了", s5.task(mid.id)?.day == "2026-11-09")
    check("它的下级跟着走", s5.task(deep.id)?.day == "2026-11-09")
    check("上级留在原处", s5.task(top.id)?.day == "2026-10-08")
    check("搬到新日子后成为顶层", s5.task(mid.id)?.parentId == nil)
}

print("\n十二、层级与拖动的完整盘法（主线一条一级 / 支线 N 条一级 / 各自分 2·3·N 级）")
do {
    let s = makeStore()
    let main = s.addMain("主线")!
    let branch = s.addTopLevel("支线一")!
    let branch2 = s.addTopLevel("支线二")!

    check("顶层：1 条主线 + 2 条支线", s.mainGoal(on: "2026-10-08")?.id == main.id && s.branches(on: "2026-10-08").count == 2)

    // 主线、支线各自都有二级、三级
    let mainStep = s.addChild(of: main.id, title: "主线的二级")!
    let mainStep2 = s.addChild(of: mainStep.id, title: "主线的三级")!
    let branchStep = s.addChild(of: branch.id, title: "支线的二级")!
    check("主线的子级是二级", s.level(of: mainStep) == 2)
    check("主线可以继续分三级", s.level(of: mainStep2) == 3)
    check("支线的子级也是二级", s.level(of: branchStep) == 2)

    // 拖到某行中间 = 成为它的子级（支线的二级 → 主线的二级）
    s.performDrop(draggedId: branchStep.id, targetId: main.id, zone: .nest)
    check("支线的二级拖到主线中间 → 成为主线的二级", s.task(branchStep.id)?.parentId == main.id && s.level(of: s.task(branchStep.id)!) == 2)
    check("主线的二级因此有两条", s.children(of: main.id).count == 2)

    // 拖到栏内空白（有主线时）= 一级支线
    s.moveToTopLevel(mainStep.id)
    check("拖到空白处 → 成为一级", s.task(mainStep.id)?.parentId == nil && s.level(of: s.task(mainStep.id)!) == 1)
    check("有主线时它落为支线", s.branches(on: "2026-10-08").contains { $0.id == mainStep.id })
    check("没有产生第二个主线", s.tasks.filter { $0.isMain && $0.day == "2026-10-08" }.count == 1)

    // 主线在同层重排，身份不变
    s.performDrop(draggedId: main.id, targetId: branch2.id, zone: .after)
    check("主线同级重排后仍是主线", s.mainGoal(on: "2026-10-08")?.id == main.id)

    // 主线被拖成子级 → 主线身份解除
    s.performDrop(draggedId: main.id, targetId: branch.id, zone: .nest)
    check("主线被拖成子级后解除主线身份", s.task(main.id)?.isMain == false)
    check("当天因此没有主线", s.mainGoal(on: "2026-10-08") == nil)
    check("支线仍在顶层等着补位", !s.branches(on: "2026-10-08").isEmpty)

    // 显式取消主线
    let s2 = makeStore()
    let m2 = s2.addMain("主线")!
    _ = s2.addTopLevel("支线")!
    s2.unsetMain(m2.id)
    check("可以主动取消主线", s2.mainGoal(on: "2026-10-08") == nil)
    check("取消主线的任务仍在顶层", s2.task(m2.id)?.parentId == nil)

    // 没有主线时拖到空白处也不会自动成为主线
    s2.moveToTopLevel(m2.id)
    check("没主线时拖到空白处也不自动成为主线", s2.mainGoal(on: "2026-10-08") == nil)
    s2.setMain(m2.id)
    check("要成为主线必须显式指定", s2.mainGoal(on: "2026-10-08")?.id == m2.id)
}

print("\n十三、恢复的粒度：只恢复这一条 + 上级链")
do {
    let s = makeStore()
    let main = s.addMain("主线")!
    let a = s.addChild(of: main.id, title: "A")!
    let a1 = s.addChild(of: a.id, title: "A1")!
    let a2 = s.addChild(of: a.id, title: "A2")!
    let b = s.addChild(of: main.id, title: "B")!
    s.complete(main.id)
    check("完成后整棵都结束", s.subtree(main.id).allSatisfy { $0.done })

    s.revert(a1.id)
    check("恢复三级：这一条回来了", s.task(a1.id)?.done == false)
    check("上级链一并恢复（A 与主线）", s.task(a.id)?.done == false && s.task(main.id)?.done == false)
    check("它的兄弟子步骤不动", s.task(a2.id)?.done == true)
    check("上级的其他分支不动", s.task(b.id)?.done == true)
    check("当天重新有主线", s.mainGoal(on: "2026-10-08")?.id == main.id)
    check("恢复后它的上级在今日页可见", s.roots(of: "2026-10-08").contains { $0.id == main.id })

    s.revert(a2.id)
    check("再恢复兄弟，同样只带上级链", s.task(a2.id)?.done == false && s.task(a1.id)?.done == false)

    s.revert(b.id)
    check("恢复 B 时不会顺带恢复 A1/A2", s.task(a1.id)?.done == false && s.task(b.id)?.done == false)

    s.complete(main.id)
    s.revertSubtree(main.id)
    check("恢复整棵把所有子步骤一起退回", s.subtree(main.id).allSatisfy { !$0.done })

    // 只恢复父任务时，子步骤保持已结束
    let s2 = makeStore()
    let m2 = s2.addMain("主线")!
    let step = s2.addChild(of: m2.id, title: "步骤")!
    s2.complete(m2.id)
    s2.revert(m2.id)
    check("恢复顶层只恢复它自己", s2.task(m2.id)?.done == false && s2.task(step.id)?.done == true)
    check("挂在未完成上级下的已完成子步骤不重复进完成清单",
          !s2.doneTasks(on: "2026-10-08").contains { $0.id == step.id })
    check("整天的已结束清单仍能看到它", s2.doneTasks.contains { $0.id == step.id })
}

print("\n十四、连续新建：锚点跟着刚创建的那一条走")
do {
    let s = makeStore()
    let main = s.addMain("主线")!

    // 第一次：Tab 切到下级 → 创建 2 级
    let c1 = s.addChild(of: main.id, title: "步骤一")!
    check("第一条是 2 级", s.level(of: c1) == 2)

    // 回车后的下一次：锚点已经是 c1，所以「同级」应仍在 2 级
    let c2 = s.addSibling(after: c1.id, title: "步骤二")!
    check("继续回车仍停在同一层（2 级）", s.level(of: c2) == 2)
    check("父任务相同", s.task(c2.id)?.parentId == main.id)
    check("顺序跟在刚创建的那条后面", s.children(of: main.id).map(\.title) == ["步骤一", "步骤二"])

    // 再 Tab 往下一级：锚点是 c2，所以下级应挂在 c2 之下（3 级）
    let d1 = s.addChild(of: c2.id, title: "细节")!
    check("Tab 后新建的是 3 级", s.level(of: d1) == 3)
    check("它挂在刚创建的那条下面", s.task(d1.id)?.parentId == c2.id)

    // 再回车：锚点变成 d1，同级仍是 3 级
    let d2 = s.addSibling(after: d1.id, title: "细节二")!
    check("继续回车仍是 3 级", s.level(of: d2) == 3)
    check("同一父任务下", s.children(of: c2.id).map(\.title) == ["细节", "细节二"])

    // 在 2 级上回车：同级不应跳回 1 级
    let c3 = s.addSibling(after: c2.id, title: "步骤三")!
    check("2 级上继续回车不会跳回 1 级", s.level(of: c3) == 2)
    check("主线仍然只有一条", s.tasks.filter { $0.isMain && $0.day == "2026-10-08" }.count == 1)
}

print("\n十五、输入会话：编辑与新建同一套高亮和按键")
MainActor.assumeIsolated {
    let s = makeStore()
    let main = s.addMain("主线")!

    // 从主线往下写：Tab → 下级
    let session = InputSession()
    session.startCreate(store: s, at: main.id, mode: .child)
    session.text = "步骤一"
    session.commit(store: s)
    check("新建下级落在主线下面", s.children(of: main.id).map(\.title) == ["步骤一"])
    let step1 = s.children(of: main.id)[0]
    check("锚点移到刚创建的那一条", session.targetId == step1.id)
    check("下一次默认同级", session.createMode == .sibling)

    // 回车继续：仍是 2 级
    session.text = "步骤二"
    session.commit(store: s)
    check("回车继续同级，仍是 2 级", s.children(of: main.id).map(\.title) == ["步骤一", "步骤二"])
    let step2 = s.children(of: main.id)[1]
    check("新条目层级为 2", s.level(of: step2) == 2)

    // Tab → 在刚创建的那条下面开 3 级
    session.toggleMode()
    check("Tab 后模式变成下级", session.createMode == .child)
    session.text = "细节"
    session.commit(store: s)
    check("Tab 新建的是 3 级", s.children(of: step2.id).map(\.title) == ["细节"])

    // 编辑：带出原文；回车提交后接着往下写
    let edit = InputSession()
    edit.startEdit(store: s, at: main.id, currentTitle: "主线")
    check("编辑时带出原文字", edit.text == "主线")
    check("编辑状态可识别", edit.isEditing)
    edit.text = "主线（改过）"
    edit.commit(store: s, editContinue: .child)
    check("编辑提交后文字更新", s.task(main.id)?.title == "主线（改过）")
    check("编辑后自动进入新建状态", edit.isCreating)
    check("编辑后锚点仍是这一条", edit.targetId == main.id)
    edit.text = "接下来的下级"
    edit.commit(store: s)
    check("编辑后接着回车可以继续写", s.children(of: main.id).contains { $0.title == "接下来的下级" })

    // 点空白：把内容落下并结束
    edit.startCreate(store: s, at: main.id, mode: .child)
    edit.text = "点到空白前写的"
    edit.finishByClickingAway(store: s)
    check("点空白会把内容落下去", s.children(of: main.id).contains { $0.title == "点到空白前写的" })
    check("点空白后会话结束", edit.isActive == false)

    // 点空白时内容为空：直接结束，不创建
    let blank = InputSession()
    blank.startCreate(store: s, at: main.id, mode: .child)
    blank.finishByClickingAway(store: s)
    check("空内容点空白不会创建任务", blank.isActive == false)

    // 正在写 A 时点到 B：A 的内容要先落下，不能丢
    let s2 = makeStore()
    let goalA = s2.addMain("目标 A")!
    let goalB = s2.addTopLevel("目标 B")!
    let session2 = InputSession()
    session2.startCreate(store: s2, at: goalA.id, mode: .child)
    session2.text = "给 A 写的步骤"
    session2.startEdit(store: s2, at: goalB.id, currentTitle: "目标 B")
    check("切到另一行时上一条会被落下", s2.children(of: goalA.id).map(\.title) == ["给 A 写的步骤"])
    check("现在编辑的是新那一行", session2.targetId == goalB.id && session2.isEditing)

    // 同一行重复点不会重复提交
    session2.startEdit(store: s2, at: goalB.id, currentTitle: "目标 B")
    check("同一行重复点击不会重复提交", s2.children(of: goalA.id).count == 1)

    // Esc = close：不落内容
    let cancelled = InputSession()
    cancelled.startCreate(store: s, at: main.id, mode: .child)
    cancelled.text = "这条不要了"
    cancelled.close()
    check("Esc 结束不会创建", !s.children(of: main.id).contains { $0.title == "这条不要了" })
}

print("\n十六、跨天拖动应带整棵子树")
do {
    let s = makeStore()
    let main = s.addMain("主线")!
    let a = s.addChild(of: main.id, title: "A")!
    let a1 = s.addChild(of: a.id, title: "A1")!
    let b = s.addChild(of: main.id, title: "B")!
    s.moveToDay(main.id, day: "2026-10-12", asMain: false)
    check("二级 A 跟着走", s.task(a.id)?.day == "2026-10-12")
    check("三级 A1 也跟着走", s.task(a1.id)?.day == "2026-10-12")
    check("另一个二级 B 也跟着走", s.task(b.id)?.day == "2026-10-12")
    check("整棵子树都在新日子", s.subtree(main.id).allSatisfy { $0.day == "2026-10-12" })

    let s2 = makeStore()
    let m2 = s2.addMain("主线")!
    let c2 = s2.addChild(of: m2.id, title: "步骤")!
    s2.requestMoveToDay(m2.id, day: "2026-10-20")
    check("requestMoveToDay 也带子树", s2.task(c2.id)?.day == "2026-10-20")
}

print("\n十七、清单范围以系统今天为基准往回算")
do {
    let s = makeStore()   // today = 2026-10-08

    _ = s.addTopLevel("昨天的事", on: "2026-10-07")
    _ = s.addTopLevel("六天前的事", on: "2026-10-02")
    _ = s.addTopLevel("三十天前的事", on: "2026-09-08")
    _ = s.addTopLevel("三十一天前的事", on: "2026-09-07")
    _ = s.addTopLevel("明天的事", on: "2026-10-09")
    _ = s.addTopLevel("下个月的事", on: "2026-11-20")

    check("默认范围是「所有」，不会藏东西", s.range == .all && s.poolTasks().count == 4)

    s.range = .week
    check("本周 = 今天往前 7 天内", s.poolTasks().map(\.title) == ["昨天的事", "六天前的事"])
    s.range = .month
    check("恰好 30 天前的仍在「本月」里", s.poolTasks().contains { $0.title == "三十天前的事" })
    s.range = .month
    check("本月 = 今天往前 30 天内", s.poolTasks().count == 3)
    check("明天的事不进本周", !s.poolTasks().contains { $0.title == "明天的事" })
    s.range = .all
    check("所有也不含未来日期", !s.poolTasks().contains { $0.title == "明天的事" })
    check("所有也不含下个月", !s.poolTasks().contains { $0.title == "下个月的事" })
    check("所有包含很久以前的", s.poolTasks().contains { $0.title == "三十一天前的事" })
    check("所有数量正确", s.poolTasks().count == 4)

    // 今天的任务不在清单里（在今日页）
    _ = s.addMain("今天的主线")
    check("今天的任务不进清单", s.poolTasks().allSatisfy { $0.day != "2026-10-08" })

    // 未来任务被拖回今天之后就不再出现在清单
    let future = s.tasks.first { $0.title == "明天的事" }!
    s.reexecute(future.id)
    check("拖回今天后离开清单", s.poolTasks().allSatisfy { $0.id != future.id })
}

print("\n十八、主线永远排在最前（日历小格与右栏顺序一致）")
do {
    let s = makeStore()
    _ = s.addTopLevel("先写的支线", on: "2026-10-08")
    _ = s.addTopLevel("后写的支线", on: "2026-10-08")
    let late = s.addTopLevel("最后才定为主线", on: "2026-10-08")!
    s.setMain(late.id)
    check("setMain 后主线排最前", s.orderedRoots(of: "2026-10-08").first?.id == late.id)

    // 跨天搬过来成为主线的情况
    let s2 = makeStore()
    _ = s2.addTopLevel("目标日已有的支线", on: "2026-10-20")
    let incoming = s2.addTopLevel("从别处搬来", on: "2026-10-08")!
    s2.moveToDay(incoming.id, day: "2026-10-20", asMain: true)
    check("跨天成为主线后排最前", s2.orderedRoots(of: "2026-10-20").first?.id == incoming.id)
    check("主线确实换了", s2.mainGoal(on: "2026-10-20")?.id == incoming.id)

    // 没有主线时按 order
    let s3 = makeStore()
    _ = s3.addTopLevel("第一", on: "2026-10-08")
    _ = s3.addTopLevel("第二", on: "2026-10-08")
    check("没有主线时按顺序排", s3.orderedRoots(of: "2026-10-08").map(\.title) == ["第一", "第二"])
}

print("\n十九、跨层级拖动：随意上下搬迁，层级自动重算")
do {
    // 1 级拖进 2 级
    let s = makeStore()
    let main = s.addMain("主线")!
    let step1 = s.addChild(of: main.id, title: "主线的步骤一")!
    let branch = s.addTopLevel("支线")!
    check("拖动前支线是 1 级", s.level(of: branch) == 1)
    s.performDrop(draggedId: branch.id, targetId: step1.id, zone: .nest)
    check("1 级可以拖进 2 级", s.task(branch.id)?.parentId == step1.id)
    check("进去之后它变成 3 级（目标层级 + 1）", s.level(of: s.task(branch.id)!) == 3)

    // 2 级（带 2 个 3 级）拖进 3 级 → 整棵子树重算
    let s2 = makeStore()
    let m2 = s2.addMain("主线")!
    let two = s2.addChild(of: m2.id, title: "二级")!
    let c1 = s2.addChild(of: two.id, title: "三级甲")!
    let c2 = s2.addChild(of: two.id, title: "三级乙")!
    let c3 = s2.addChild(of: c1.id, title: "四级")!
    let stepA = s2.addChild(of: m2.id, title: "另一条二级")!
    let stepA1 = s2.addChild(of: stepA.id, title: "另一条三级")!

    check("拖动前：二级/三级/四级", s2.level(of: two) == 2 && s2.level(of: c1) == 3 && s2.level(of: c3) == 4)
    s2.performDrop(draggedId: two.id, targetId: stepA1.id, zone: .nest)
    check("二级搬进三级后，自己变成 4 级", s2.level(of: s2.task(two.id)!) == 4)
    check("它的两个三级子项变成 5 级", s2.level(of: s2.task(c1.id)!) == 5 && s2.level(of: s2.task(c2.id)!) == 5)
    check("它下面的四级变成 6 级", s2.level(of: s2.task(c3.id)!) == 6)
    check("整棵子树都跟在它下面", s2.subtree(two.id).count == 4)

    // 再拖回 1 级
    s2.moveToTopLevel(two.id)
    check("再拖回顶层时整棵子树跟着回到 1/2/3 级",
          s2.level(of: s2.task(two.id)!) == 1 &&
          s2.level(of: s2.task(c1.id)!) == 2 &&
          s2.level(of: s2.task(c3.id)!) == 3)

    // 不允许拖进自己的子孙
    let before = s2.subtree(two.id).map(\.id).sorted()
    s2.performDrop(draggedId: two.id, targetId: c1.id, zone: .nest)
    check("拖进自己的子步骤会被拒绝", s2.subtree(two.id).map(\.id).sorted() == before)
}

print("\n二十、完成栏只列顶层：一棵完成树 = 一张卡片")
do {
    let s = makeStore()
    let branch = s.addTopLevel("船电蓝图", on: "2026-10-08")!
    let a = s.addChild(of: branch.id, title: "ppt")!
    let b = s.addChild(of: branch.id, title: "测试")!
    let deep = s.addChild(of: a.id, title: "更细的一步")!

    // 完成中间那一条：只完成它自己和子树
    s.complete(a.id)
    check("只完成子步骤时，完成栏不列它（它在上级卡片里）", s.doneTasks(on: "2026-10-08").isEmpty)

    // 完成整棵树
    s.complete(branch.id)
    let done = s.doneTasks(on: "2026-10-08")
    check("整棵树完成后，完成栏只列一条", done.map(\.title) == ["船电蓝图"])
    check("不会把子步骤也单独列出来", !done.contains { $0.title == "ppt" || $0.title == "测试" })
    check("子步骤仍然挂在这条下面", s.children(of: branch.id).count == 2)
    check("三级也还在树上", s.subtree(branch.id).count == 4)
    _ = deep
}

print("\n二十一、跨树的同级搬迁：所有任务都一样，主线只是多一个标签")
do {
    let s = makeStore()
    let main = s.addMain("主线")!
    let m1 = s.addChild(of: main.id, title: "主线的二级甲")!
    let m2 = s.addChild(of: main.id, title: "主线的二级乙")!
    let branch = s.addTopLevel("支线")!
    let b1 = s.addChild(of: branch.id, title: "支线的二级")!

    // 拖到主线二级的后面 → 成为主线这棵树里的二级
    s.performDrop(draggedId: b1.id, targetId: m1.id, zone: .after)
    check("支线二级可以搬进主线这棵树", s.task(b1.id)?.parentId == main.id)
    check("搬过去仍是二级", s.level(of: s.task(b1.id)!) == 2)
    check("排在被瞄准的那条后面", s.children(of: main.id).map(\.title) == ["主线的二级甲", "支线的二级", "主线的二级乙"])

    // 拖到主线二级的右边高亮区 → 成为它的子级
    s.performDrop(draggedId: b1.id, targetId: m2.id, zone: .nest)
    check("也可以成为主线二级的子级", s.task(b1.id)?.parentId == m2.id)
    check("层级变成 3", s.level(of: s.task(b1.id)!) == 3)

    // 再拖回支线那棵树
    s.performDrop(draggedId: b1.id, targetId: branch.id, zone: .nest)
    check("还能搬回支线", s.task(b1.id)?.parentId == branch.id)
    check("层级回到 2", s.level(of: s.task(b1.id)!) == 2)

    // 主线标签只属于它自己，搬进来不等于变成主线
    check("搬进主线的子步骤不会变主线", s.task(b1.id)?.isMain == false)
    check("每天只有一个主线", s.mainGoal(on: "2026-10-08")?.id == main.id)

    // 跨天：子步骤跟着上级所在的那天走，而不是跳到今天
    let s2 = makeStore()
    let m = s2.addMain("今天的主线")!
    let child = s2.addChild(of: m.id, title: "今天的子步骤")!
    let future = s2.addTopLevel("月底的事", on: "2026-10-28")!
    let f2 = s2.addChild(of: future.id, title: "月底的子步骤")!
    s2.performDrop(draggedId: child.id, targetId: f2.id, zone: .after)
    check("跨天搬同级：日子跟目标走", s2.task(child.id)?.day == "2026-10-28")
    check("跨天搬同级：上级也换了", s2.task(child.id)?.parentId == future.id)
    _ = m1
}

print("\n二十二、支线一级拖到主线一级：变成主线的二级")
do {
    let s = makeStore()
    let main = s.addMain("主线")!
    let branch = s.addTopLevel("支线")!
    let b2 = s.addChild(of: branch.id, title: "支线的二级")!

    // 落到主线行的「衔接」区
    s.performDrop(draggedId: branch.id, targetId: main.id, zone: .nest)
    check("支线一级接进主线后成为二级", s.task(branch.id)?.parentId == main.id && s.level(of: s.task(branch.id)!) == 2)
    check("它原来的二级变成三级", s.level(of: s.task(b2.id)!) == 3)
    check("整棵子树跟着进去", s.subtree(main.id).count == 3)
    check("它不再是主线", s.task(branch.id)?.isMain == false)
    check("今天的主线还是原来那条", s.mainGoal(on: "2026-10-08")?.id == main.id)

    // 落到主线行左半边且拖动的是顶层任务 → 设为主线
    let s2 = makeStore()
    let m2 = s2.addMain("原主线")!
    let b_ = s2.addTopLevel("想当主线")!
    if s2.mainGoal(on: "2026-10-08")?.id == m2.id {
        s2.setMain(b_.id)
    }
    check("设为主线后原来那条让位", s2.mainGoal(on: "2026-10-08")?.id == b_.id)
    check("原主线变成支线", s2.branches(on: "2026-10-08").contains { $0.id == m2.id })
}

print("\n二十三、编辑与拖动互斥：开始拖动先把编辑落下")
MainActor.assumeIsolated {
    let s = makeStore()
    let a = s.addTopLevel("第一行", on: "2026-10-08")!
    _ = s.addTopLevel("第二行", on: "2026-10-08")

    let session = InputSession()
    session.startEdit(store: s, at: a.id, currentTitle: "第一行")
    session.text = "第一行（改过了）"
    check("编辑中", session.isActive && session.isEditing)

    // 相当于用户按下第二行开始拖动：拖动开始时先落下编辑
    session.finishByClickingAway(store: s)
    check("开始拖动后编辑状态结束", !session.isActive)
    check("编辑内容已经保存，不会丢", s.task(a.id)?.title == "第一行（改过了）")

    // 新建中输入到一半去拖动，同样先落下
    let session2 = InputSession()
    session2.startCreate(store: s, at: a.id, mode: .child)
    session2.text = "写了一半的下级"
    session2.finishByClickingAway(store: s)
    check("拖动前写了一半的新任务也会落下", s.children(of: a.id).map(\.title) == ["写了一半的下级"])
    check("落下后输入状态结束", !session2.isActive)
}

print("\n二十四、卡片按位置换位：落在卡片之间 / 下方都有效")
do {
    let s = makeStore()
    let main = s.addMain("主线")!
    let a = s.addTopLevel("甲", on: "2026-10-08")!
    let b = s.addTopLevel("乙", on: "2026-10-08")!
    let c = s.addTopLevel("丙", on: "2026-10-08")!

    check("初始支线顺序", s.branches(on: "2026-10-08").map(\.title) == ["甲", "乙", "丙"])

    // 把第一张卡片拖到最下面（等于落在最后一张卡片下方）
    s.moveRootToBranchIndex(a.id, 3)
    check("甲拖到最下方", s.branches(on: "2026-10-08").map(\.title) == ["乙", "丙", "甲"])

    // 把最后一张拖到最上面
    s.moveRootToBranchIndex(a.id, 0)
    check("甲拖回最上方", s.branches(on: "2026-10-08").map(\.title) == ["甲", "乙", "丙"])

    // 插到中间
    s.moveRootToBranchIndex(c.id, 1)
    check("丙插到中间", s.branches(on: "2026-10-08").map(\.title) == ["甲", "丙", "乙"])

    // 主线拖进支线列表 = 解除主线身份
    s.moveRootToBranchIndex(main.id, 0)
    check("主线拖进支线后不再是主线", s.task(main.id)?.isMain == false)
    check("它出现在支线列表里", s.branches(on: "2026-10-08").first?.id == main.id)
    check("这天可以没有主线", s.mainGoal(on: "2026-10-08") == nil)

    // 子步骤拖到支线列表 = 升为一级
    let s2 = makeStore()
    let m2 = s2.addMain("主线")!
    let child = s2.addChild(of: m2.id, title: "二级")!
    s2.moveRootToBranchIndex(child.id, 0)
    check("子步骤被拖出来变成一级", s2.task(child.id)?.parentId == nil && s2.level(of: s2.task(child.id)!) == 1)
    check("它出现在支线里", s2.branches(on: "2026-10-08").contains { $0.id == child.id })

    // 越界下标不会崩
    s2.moveRootToBranchIndex(child.id, 999)
    check("越界下标被夹住", s2.branches(on: "2026-10-08").count == 1)
}

print("\n二十五、栏标题只在「这一放会改变什么」时才响应")
do {
    let s = makeStore()
    let main = s.addMain("工作交接")!
    let branch = s.addTopLevel("船电蓝图")!
    let child = s.addChild(of: branch.id, title: "ppt")!

    // 今日主线栏：只有"其它一级任务"过来才算有效
    check("支线拖到主线栏：有效", s.canBecomeMain(branch.id, on: "2026-10-08"))
    check("主线自己拖到主线栏：无效", !s.canBecomeMain(main.id, on: "2026-10-08"))
    check("二级拖到主线栏：无效", !s.canBecomeMain(child.id, on: "2026-10-08"))
    check("别的日子的一级任务拖到今天主线栏：无效", !s.canBecomeMain(branch.id, on: "2026-10-09"))

    // 今日支线栏：只有"当前主线"过来才算有效
    check("主线拖到支线栏：有效", s.canBecomeBranch(main.id, on: "2026-10-08"))
    check("支线自己拖到支线栏：无效", !s.canBecomeBranch(branch.id, on: "2026-10-08"))
    check("二级拖到支线栏：无效", !s.canBecomeBranch(child.id, on: "2026-10-08"))

    // 真的换一次主线，判定也随之翻转
    s.setMain(branch.id)
    check("换过主线后：新主线不能再设为主线", !s.canBecomeMain(branch.id, on: "2026-10-08"))
    check("原主线现在可以再设回来", s.canBecomeMain(main.id, on: "2026-10-08"))
    check("新主线可以降为支线", s.canBecomeBranch(branch.id, on: "2026-10-08"))
}

print("\n二十六、拖动收尾：任何没有落到地方的拖动都必须清干净")
MainActor.assumeIsolated {
    let s = makeStore()
    let a = s.addTopLevel("甲", on: "2026-10-08")!
    _ = s.addTopLevel("乙", on: "2026-10-08")

    // 模拟一次拖动进行中
    let drag = DragController()
    drag.draggingId = a.id
    drag.target = DragState(draggedId: a.id, targetId: a.id, zone: .after)
    drag.insertIndex = 0
    check("拖动中：三个状态都在", drag.isDragging && drag.target != nil && drag.insertIndex != nil)
    check("拖动中：判定为有落点", drag.hasActiveTarget)

    drag.end()
    check("收尾后拖动源被清掉（卡片不会一直透明）", drag.draggingId == nil)
    check("收尾后落点状态被清掉", drag.target == nil)
    check("收尾后插入位被清掉", drag.insertIndex == nil)
    check("收尾后不再认为有落点", !drag.hasActiveTarget)

    // 对数据没有副作用
    check("收尾不改变任务", s.branches(on: "2026-10-08").map(\.title) == ["甲", "乙"])
}

print("\n二十七、卡片投放到深层行：按位置换位，而不是接进去")
do {
    let s = makeStore()
    _ = s.addMain("主线")!
    let a = s.addTopLevel("甲", on: "2026-10-08")!
    let b = s.addTopLevel("乙", on: "2026-10-08")!
    let b1 = s.addChild(of: b.id, title: "乙的子步骤")!

    // 甲这张卡片拖到「乙的子步骤」行上：应插到乙这张卡片后面，而不是变成乙的子步骤
    let index = s.branchInsertIndex(containing: b1.id, after: false)
    check("深层行能定位到它所属卡片的位置", index == 1)
    s.moveRootToBranchIndex(a.id, index)
    check("甲插到乙后面", s.branches(on: "2026-10-08").map(\.title) == ["乙", "甲"])
    check("甲没有变成乙的子步骤", s.task(b1.id)?.parentId == b.id && s.task(a.id)?.parentId == nil)

    // 落在下半部分 = 插到那张卡片后面（此时顺序是 [乙, 甲]，乙在下标 0）
    check("下半部分＝插到卡片后面", s.branchInsertIndex(containing: b1.id, after: true) == 1)

    // 顶层祖先
    check("顶层祖先定位正确", s.topLevelAncestor(of: b1.id) == b.id)
    check("自己是顶层时返回自己", s.topLevelAncestor(of: a.id) == a.id)
}

print("\n结果：\(passed) 项通过 / \(failed) 项失败")
exit(failed == 0 ? 0 : 1)
