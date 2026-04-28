import Foundation

public enum Filename {
    public static func build(title: String, date: Date, calendar: Calendar = .current) -> String {
        var slug = Slug.slugify(title)
        if slug.isEmpty { slug = "untitled" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date))_\(slug).md"
    }
}
