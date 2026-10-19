import SwiftUI
import Core

/// 完成印章：同一个完成动作，在每套主题里盖自己的章。
struct CompletionStamp: View {
    let style: CardStyle
    let date: String

    var body: some View {
        content
            .rotationEffect(.degrees(-7))
            .shadow(color: Theme.ink.opacity(0.18), radius: 0, x: 3, y: 4)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .atelier:
            Text("已交付")
                .font(Theme.display(13))
                .foregroundStyle(Theme.canvas)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Circle().fill(Theme.stamp))
        case .herbarium:
            Text("DRIED & MOUNTED · \(date)")
                .font(Theme.mono(7)).tracking(0.6)
                .foregroundStyle(Theme.stamp)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1.1))
        case .acid:
            Text("DONE")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.cardBackground)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Rectangle().fill(Theme.stamp))
                .rotationEffect(.degrees(-4))
        case .blueprint:
            Text("REV. A")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.stamp)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Rectangle().strokeBorder(Theme.stamp, lineWidth: 1.2))
        }
    }
}
