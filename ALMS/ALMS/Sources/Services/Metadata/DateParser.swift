import Foundation

enum DateParser {
    static func extractDate(from text: String) -> String? {
        let lower = text.lowercased()
        let calendar = Calendar.current
        let today = Date()

        if lower.contains("tomorrow") {
            return iso8601Date(from: calendar.date(byAdding: .day, value: 1, to: today)!)
        }

        let weekdays: [(String, Int)] = [
            ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7), ("sunday", 1)
        ]
        for (name, weekday) in weekdays {
            if lower.contains("next \(name)") {
                var comps = DateComponents()
                comps.weekday = weekday
                if let date = calendar.nextDate(
                    after: today, matching: comps,
                    matchingPolicy: .nextTimePreservingSmallerComponents
                ) {
                    return iso8601Date(from: date)
                }
            }
        }

        let isoPattern = #"\d{4}-\d{2}-\d{2}"#
        if let regex = try? NSRegularExpression(pattern: isoPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }

        let monthPattern = #"(?i)(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})|(\d{1,2})\s+(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"#
        if let regex = try? NSRegularExpression(pattern: monthPattern, options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            if let date = parseMonthDay(String(text[range])) {
                return iso8601Date(from: date)
            }
        }

        return nil
    }

    private static func parseMonthDay(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let currentYear = Calendar.current.component(.year, from: Date())
        for format in ["MMMM d", "MMM d", "d MMMM", "d MMM"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: str.trimmingCharacters(in: .whitespaces)) {
                var comps = Calendar.current.dateComponents([.month, .day], from: date)
                comps.year = currentYear
                if let result = Calendar.current.date(from: comps) {
                    return result < Date()
                        ? Calendar.current.date(byAdding: .year, value: 1, to: result)
                        : result
                }
            }
        }
        return nil
    }

    static func iso8601Date(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
