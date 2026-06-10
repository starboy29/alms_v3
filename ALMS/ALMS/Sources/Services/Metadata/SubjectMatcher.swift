import Foundation

enum SubjectMatcher {
    static func extract(from text: String, subjects: [Subject]) -> ExtractedMetadata {
        let lower = text.lowercased()

        var matched: Subject?
        for subject in subjects {
            if let code = subject.code, !code.isEmpty,
               lower.range(of: "\\b\(NSRegularExpression.escapedPattern(for: code.lowercased()))\\b",
                            options: .regularExpression) != nil {
                matched = subject
                break
            }
        }
        if matched == nil {
            for subject in subjects {
                if lower.contains(subject.name.lowercased()) {
                    matched = subject
                    break
                }
            }
        }

        let detectedType = detectType(from: lower)
        let dueDate = DateParser.extractDate(from: text)
        let title = buildTitle(from: text, subjectCode: matched?.code, detectedType: detectedType)

        var unmatched: [String] = []
        if matched == nil { unmatched.append("subject") }
        if detectedType == nil { unmatched.append("type") }

        let confidence: ExtractedMetadata.Confidence = unmatched.isEmpty ? .high
            : unmatched.count == 1 ? .medium : .low

        return ExtractedMetadata(
            subjectId: matched?.id,
            subjectCode: matched?.code,
            unitId: nil,
            type: detectedType,
            title: title,
            dueDate: dueDate,
            confidence: confidence,
            unmatchedFields: unmatched
        )
    }

    static func detectType(from lower: String) -> ItemType? {
        let keywords: [(String, ItemType)] = [
            ("assignment", .assignment), ("homework", .assignment),
            ("exam", .exam), ("quiz", .exam), ("test", .exam),
            ("lab", .lab), ("practical", .lab),
            ("project", .project),
            ("notes", .notes), ("note", .notes),
            ("resource", .resource), ("material", .resource),
            ("event", .event)
        ]
        for (kw, type) in keywords {
            if lower.range(of: "\\b\(kw)\\b", options: .regularExpression) != nil {
                return type
            }
        }
        return nil
    }

    private static func buildTitle(from text: String, subjectCode: String?, detectedType: ItemType?) -> String {
        var result = text

        if let code = subjectCode {
            result = result.replacingOccurrences(
                of: "\\b\(NSRegularExpression.escapedPattern(for: code))\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        let datePattern = #"(?i)(due\s+)?(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}|\d{4}-\d{2}-\d{2}|next\s+\w+|tomorrow"#
        if let regex = try? NSRegularExpression(pattern: datePattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        result = result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return result.isEmpty ? text : result
    }
}
