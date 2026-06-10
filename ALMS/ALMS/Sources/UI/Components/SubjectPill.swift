import SwiftUI

struct SubjectPill: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(pillColor.opacity(0.15))
            .foregroundStyle(pillColor)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var pillColor: Color {
        switch code.uppercased() {
        case "ANN":  return .purple
        case "ML":   return .green
        case "CN":   return .red
        case "FLA":  return .orange
        case "MATH": return .blue
        case "SRW":  return .pink
        case "IAF":  return .teal
        case "CC":   return .indigo
        default:
            // Deterministic color from string hash
            let colors: [Color] = [.purple, .blue, .green, .orange, .red, .teal, .indigo, .pink]
            let idx = abs(code.hashValue) % colors.count
            return colors[idx]
        }
    }
}
