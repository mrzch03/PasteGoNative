import Foundation

/// Formats ISO 8601 date strings into relative time descriptions
enum RelativeTimeFormatter {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateStyle = .short
        return f
    }()

    static func format(_ isoString: String) -> String {
        guard let date = isoFormatter.date(from: isoString)
                ?? isoFormatterNoFraction.date(from: isoString) else {
            return isoString
        }

        let diff = Date().timeIntervalSince(date)
        let minutes = Int(diff / 60)

        if minutes < 1 { return "刚刚" }
        if minutes < 60 { return "\(minutes)分钟前" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours)小时前" }

        let days = hours / 24
        if days < 7 { return "\(days)天前" }

        return dateFormatter.string(from: date)
    }
}
