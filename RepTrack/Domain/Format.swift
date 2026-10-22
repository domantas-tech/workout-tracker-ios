import Foundation

/// Number and text formatting shared by the UI and the export, with the same rounding as the
/// Android app (Kotlin `roundToInt` / `Math.round` round halves up, toward +∞).
enum Format {

    /// `Math.round` semantics: 2.5 -> 3, -2.5 -> -2.
    static func roundHalfUp(_ value: Double) -> Double {
        (value + 0.5).rounded(.down)
    }

    /// Shortest plain decimal without trailing zeros and without exponent: 60.0 -> "60", 62.5 -> "62.5".
    static func plainNumber(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        let text = "\(value)"
        guard text.contains("e") || text.contains("E") else { return text }
        // Very large or tiny values: expand the exponent
        var expanded = String(format: "%.15f", value)
        while expanded.hasSuffix("0") { expanded.removeLast() }
        if expanded.hasSuffix(".") { expanded.removeLast() }
        return expanded
    }

    /// 60.0 -> "60", 62.5 -> "62.5"
    static func weight(_ weight: Double) -> String { plainNumber(weight) }

    /// 12450.0 -> "12,450" (locale grouping)
    static func volume(_ volume: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        let rounded = roundHalfUp(volume)
        return formatter.string(from: NSNumber(value: rounded)) ?? String(Int64(rounded))
    }

    /// 95 -> "1:35"
    static func duration(_ seconds: Int) -> String {
        let secs = seconds % 60
        return "\(seconds / 60):\(secs < 10 ? "0" : "")\(secs)"
    }

    /// Parses user-typed decimals, accepting either "," or "." as the separator.
    static func parseDecimal(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        return value
    }

    /// "+12%", "−4%", "0%"; nil baseline -> nil.
    static func percentChange(_ percent: Double?) -> String? {
        guard let percent else { return nil }
        let rounded = Int(roundHalfUp(percent))
        if rounded > 0 { return "+\(rounded)%" }
        if rounded < 0 { return "\u{2212}\(abs(rounded))%" }
        return "0%"
    }

    /// Signed difference with the same formatting as weights: "+2.5", "−1", "±0".
    static func signedDelta(_ delta: Double) -> String {
        let rounded = roundHalfUp(delta * 10) / 10
        if rounded > 0 { return "+\(weight(rounded))" }
        if rounded < 0 { return "\u{2212}\(weight(-rounded))" }
        return "\u{00B1}0"
    }

    /// 12450.0 -> "12.5k", 830.0 -> "830"
    static func compact(_ value: Double, locale: Locale = .current) -> String {
        if value >= 1000 {
            return "\(weight(roundHalfUp(value / 100) / 10))k"
        }
        return volume(value, locale: locale)
    }

    /// e1RM rounded to 0.1 kg: "92.5 kg"
    static func oneRepMax(_ value: Double) -> String {
        "\(weight(roundHalfUp(value * 10) / 10)) kg"
    }
}
