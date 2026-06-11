import SwiftUI

extension View {
    /// Floating panel glass — for borderless windows and overlay panels.
    /// macOS 26+: Liquid Glass. Older: regularMaterial + shadow.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 14) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 10)
            )
        }
    }

    /// Inline content card — for dashboard cards and list containers.
    /// macOS 26+: Liquid Glass. Older: system background + subtle border.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.secondary.opacity(0.15))
                )
        }
    }
}
