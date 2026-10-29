import SwiftUI
import UIKit

/// True black in dark mode; system grouped colours in light mode.
enum Theme {
    static let background = Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .systemGroupedBackground })
    static let surface = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.07, alpha: 1) : .secondarySystemGroupedBackground })
    static let raised = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 1) : .systemBackground })
}

extension View {
    func appListStyle() -> some View {
        scrollContentBackground(.hidden).background(Theme.background.ignoresSafeArea())
    }

    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Something Went Wrong",
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

struct AvatarView: View {
    let emoji: String
    var size: CGFloat = 36

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.raised))
            .accessibilityHidden(true)
    }
}
