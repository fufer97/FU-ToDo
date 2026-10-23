import SwiftUI
import Core

/// 完成印章（4.0）：日课盖一枚朱砂「日」章；夜之城落一块黄色切角 DONE。
struct CompletionStamp: View {
    let style: CardStyle
    let date: String

    var body: some View {
        content
            .rotationEffect(.degrees(style == .rike ? -6 : -3))
            .shadow(color: Theme.ink.opacity(0.16), radius: 0, x: 2, y: 3)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .rike:
            ZStack {
                Circle()
                    .strokeBorder(Theme.stamp, lineWidth: 1.6)
                Text("日")
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.stamp)
            }
            .frame(width: 34, height: 34)
            .opacity(0.9)
        case .night:
            Text("DONE · \(date)")
                .font(Theme.mono(8, .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.fillInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Theme.stamp)
                .clipShape(CutCornerShape(radius: 5))
        }
    }
}
