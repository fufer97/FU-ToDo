import AppKit

/// 轻音效与触感。只在完成、翻页这类明确的动作上出现。
enum Feedback {
    static func complete() {
        guard Theme.soundEnabled else { return }
        NSSound(named: NSSound.Name("Tink"))?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func page() {
        guard Theme.soundEnabled else { return }
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    static func open() {
        guard Theme.soundEnabled else { return }
        NSSound(named: NSSound.Name("Purr"))?.play()
    }
}
