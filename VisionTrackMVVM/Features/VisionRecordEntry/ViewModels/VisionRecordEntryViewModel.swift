import Foundation
import Observation

@MainActor
@Observable
final class VisionRecordEntryViewModel {
    enum SubmissionState: Equatable {
        case editing
        case saving
        case saved
        case saveFailed
    }

    enum SaveResult: Equatable {
        case saved
        case invalidInput
        case repositoryFailure
        case alreadySubmittingOrSaved
    }

    var leftEyeInput = ""
    var rightEyeInput = ""
    private(set) var submissionState: SubmissionState = .editing

    private let repository: any VisionRecordRepository
    private var locale: Locale
    private let makeID: () -> UUID
    private let now: () -> Date

    init(
        repository: any VisionRecordRepository,
        locale: Locale,
        makeID: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.locale = locale
        self.makeID = makeID
        self.now = now
    }

    func updateLocale(_ newLocale: Locale) {
        locale = newLocale
    }

    var leftEyeValidation: Result<Double, VisionAcuityInputValidator.ValidationError> {
        VisionAcuityInputValidator.validate(leftEyeInput, locale: locale)
    }

    var rightEyeValidation: Result<Double, VisionAcuityInputValidator.ValidationError> {
        VisionAcuityInputValidator.validate(rightEyeInput, locale: locale)
    }

    var canSave: Bool {
        guard acceptsSubmission,
              case .success = leftEyeValidation,
              case .success = rightEyeValidation else { return false }
        return true
    }

    func save() -> SaveResult {
        guard acceptsSubmission else { return .alreadySubmittingOrSaved }
        guard case let .success(left) = leftEyeValidation,
              case let .success(right) = rightEyeValidation else {
            return .invalidInput
        }

        submissionState = .saving
        let record = VisionRecord(
            id: makeID(),
            measuredAt: now(),
            leftEyeAcuity: left,
            rightEyeAcuity: right
        )

        do {
            try repository.add(record)
            submissionState = .saved
            return .saved
        } catch {
            submissionState = .saveFailed
            return .repositoryFailure
        }
    }

    private var acceptsSubmission: Bool {
        submissionState == .editing || submissionState == .saveFailed
    }
}
