import Foundation

enum VisionAcuityInputValidator {
    enum ValidationError: Error, Equatable {
        case required
        case invalidFormat
        case tooManyFractionDigits
        case outOfRange
    }

    static func validate(
        _ input: String,
        locale: Locale
    ) -> Result<Double, ValidationError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.required) }

        let separator = locale.decimalSeparator ?? "."
        let normalized = trimmed.replacingOccurrences(of: separator, with: ".")
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, parts.allSatisfy(isASCIIDigits) else {
            return .failure(.invalidFormat)
        }

        let fraction = parts.count == 2 ? parts[1] : nil
        if let fraction, fraction.count > 2 {
            return .failure(.tooManyFractionDigits)
        }

        // Strip leading zeros before parsing so they do not use Decimal's precision.
        let significantDigits = parts[0].drop(while: { $0 == "0" })
        let integer = significantDigits.isEmpty ? "0" : String(significantDigits)
        let decimalText = fraction.map { integer + "." + $0 } ?? integer
        let minimum = Decimal(sign: .plus, exponent: -2, significand: 1)
        guard let value = Decimal(string: decimalText, locale: Locale(identifier: "en_US_POSIX")),
              value >= minimum, value <= 2 else {
            return .failure(.outOfRange)
        }

        return .success(NSDecimalNumber(decimal: value).doubleValue)
    }

    private static func isASCIIDigits(_ part: Substring) -> Bool {
        !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) }
    }
}
