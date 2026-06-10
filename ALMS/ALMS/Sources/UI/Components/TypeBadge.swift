import SwiftUI

struct TypeBadge: View {
    let type: String

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.13))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch type {
        case "assignment": return "Assignment"
        case "exam":       return "Exam"
        case "lab":        return "Lab"
        case "project":    return "Project"
        case "notes":      return "Notes"
        case "resource":   return "Resource"
        case "event":      return "Event"
        default:           return type.capitalized
        }
    }

    var color: Color {
        switch type {
        case "assignment": return .blue
        case "exam":       return .red
        case "lab":        return .green
        case "project":    return .purple
        case "notes":      return .orange
        case "resource":   return .teal
        case "event":      return .indigo
        default:           return .secondary
        }
    }
}
