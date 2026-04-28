import Foundation

public enum ReadTime {
    /// Estimates reading time in minutes for the given body using a 200 wpm
    /// baseline. Returns 0 when there are no whitespace-separated tokens,
    /// otherwise rounds up to the nearest minute.
    public static func minutes(body: String) -> Int {
        let words = body.split(whereSeparator: { $0.isWhitespace }).count
        if words == 0 { return 0 }
        let wpm = 200
        return (words + wpm - 1) / wpm
    }
}
