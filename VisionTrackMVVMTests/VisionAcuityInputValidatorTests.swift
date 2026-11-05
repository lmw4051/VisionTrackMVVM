import Foundation
import Testing
@testable import VisionTrackMVVM

@MainActor
struct VisionAcuityInputValidatorTests {
    private let english = Locale(identifier: "en_US")
    private let french = Locale(identifier: "fr_FR")
    private let traditionalChineseTW = Locale(identifier: "zh_TW")

    @Test(arguments: ["", " \t\n"])
    func requiresInput(_ input: String) {
        #expect(VisionAcuityInputValidator.validate(input, locale: english) == .failure(.required))
    }

    @Test(arguments: [
        ("0.01", 0.01), ("2.00", 2.0), ("1", 1.0), ("1.2", 1.2),
        ("1.20", 1.2), (" \t01.20\n", 1.2)
    ])
    func acceptsValidValues(_ example: (input: String, expected: Double)) {
        #expect(VisionAcuityInputValidator.validate(example.input, locale: english) == .success(example.expected))
    }

    @Test(arguments: ["0", "2.01"])
    func rejectsValuesOutsideRange(_ input: String) {
        #expect(VisionAcuityInputValidator.validate(input, locale: english) == .failure(.outOfRange))
    }

    @Test(arguments: ["1.234", "1.000"])
    func rejectsTooManyFractionDigits(_ input: String) {
        #expect(VisionAcuityInputValidator.validate(input, locale: english) == .failure(.tooManyFractionDigits))
    }

    @Test(arguments: [
        ".5", "1.", "abc", "1e0", "NaN", "Infinity", "1,25", "1,000",
        "1,2.3", "1.2.3", "1 2", "+1", "-1", "１.２", "١.٢", "1.2abc"
    ])
    func rejectsInvalidFormats(_ input: String) {
        #expect(VisionAcuityInputValidator.validate(input, locale: english) == .failure(.invalidFormat))
    }

    @Test(arguments: ["1,25", "1.25"])
    func acceptsLocaleSeparatorAndASCIIPeriod(_ input: String) {
        #expect(VisionAcuityInputValidator.validate(input, locale: french) == .success(1.25))
    }

    @Test func rejectsGroupingAndMixedSeparatorsInCommaLocale() {
        #expect(VisionAcuityInputValidator.validate("1,000", locale: french) == .failure(.tooManyFractionDigits))
        #expect(VisionAcuityInputValidator.validate("1,2.3", locale: french) == .failure(.invalidFormat))
        #expect(VisionAcuityInputValidator.validate("1\u{202F}000", locale: french) == .failure(.invalidFormat))
    }

    @Test(arguments: [("1.25", 1.25), ("0.01", 0.01), ("2.00", 2.0)])
    func acceptsValidValuesInTraditionalChineseTW(_ example: (input: String, expected: Double)) {
        let result = VisionAcuityInputValidator.validate(example.input, locale: traditionalChineseTW)
        #expect(result == .success(example.expected))
    }

    @Test(arguments: [
        ("1,25", VisionAcuityInputValidator.ValidationError.invalidFormat),
        ("0", .outOfRange),
        ("2.01", .outOfRange),
        ("1.234", .tooManyFractionDigits)
    ])
    func rejectsInvalidValuesInTraditionalChineseTW(
        _ example: (input: String, expected: VisionAcuityInputValidator.ValidationError)
    ) {
        let result = VisionAcuityInputValidator.validate(example.input, locale: traditionalChineseTW)
        #expect(result == .failure(example.expected))
    }
}
