import Foundation
import Observation
import Testing
@testable import VisionTrackMVVM

@MainActor
struct VisionRecordEntryViewModelTests {
    private let recordID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let timestamp = Date(timeIntervalSince1970: 1_000)

    @Test func initiallyCannotSave() {
        let viewModel = makeViewModel(repository: RepositoryStub())

        #expect(viewModel.leftEyeValidation == .failure(.required))
        #expect(viewModel.rightEyeValidation == .failure(.required))
        #expect(viewModel.submissionState == .editing)
        #expect(!viewModel.canSave)
    }

    @Test func bothEyesMustBeValidToSave() {
        let viewModel = makeViewModel(repository: RepositoryStub())
        viewModel.leftEyeInput = "0,8"
        #expect(!viewModel.canSave)

        viewModel.rightEyeInput = "1.20"
        #expect(viewModel.leftEyeValidation == .success(0.8))
        #expect(viewModel.rightEyeValidation == .success(1.2))
        #expect(viewModel.canSave)

        viewModel.leftEyeInput = "2.01"
        #expect(!viewModel.canSave)
    }

    @Test func savingInvalidInputDoesNotCallRepository() {
        let repository = RepositoryStub()
        let viewModel = makeViewModel(repository: repository)
        viewModel.leftEyeInput = "0,8"
        viewModel.rightEyeInput = "NaN"

        #expect(viewModel.save() == .invalidInput)
        #expect(repository.addAttempts == 0)
        #expect(repository.records.isEmpty)
    }

    @Test func savingCreatesRecordWithInjectedIDAndDate() throws {
        let repository = RepositoryStub()
        let viewModel = makeValidViewModel(repository: repository)

        #expect(viewModel.save() == .saved)
        #expect(viewModel.submissionState == .saved)
        #expect(repository.records.count == 1)
        let record = try #require(repository.records.first)
        #expect(record.id == recordID)
        #expect(record.measuredAt == timestamp)
        #expect(record.leftEyeAcuity == 0.8)
        #expect(record.rightEyeAcuity == 1.2)
    }

    @Test func repositoryFailurePreservesInput() {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let viewModel = makeValidViewModel(repository: repository)

        #expect(viewModel.save() == .repositoryFailure)
        #expect(viewModel.submissionState == .saveFailed)
        #expect(viewModel.leftEyeInput == "0,8")
        #expect(viewModel.rightEyeInput == "1.20")
        #expect(viewModel.canSave)
        #expect(repository.records.isEmpty)
    }

    @Test func repeatedRetriesReuseOneSnapshotAndAddExactlyOneRecord() throws {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let generators = SnapshotGenerators()
        let viewModel = makeRetryViewModel(repository: repository, generators: generators)

        #expect(viewModel.save() == .repositoryFailure)
        #expect(viewModel.save() == .repositoryFailure)
        #expect(viewModel.save() == .repositoryFailure)
        repository.shouldFail = false
        #expect(viewModel.save() == .saved)

        #expect(repository.addAttempts == 4)
        #expect(repository.records.count == 1)
        #expect(generators.idCalls == 1)
        #expect(generators.clockCalls == 1)
        let first = try #require(repository.attemptedRecords.first)
        for attempt in repository.attemptedRecords.dropFirst() {
            expectSameRecord(attempt, as: first)
        }
    }

    @Test(arguments: [true, false])
    func changingEitherValidEyeValueCreatesANewSnapshot(changeLeftEye: Bool) throws {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let generators = SnapshotGenerators()
        let viewModel = makeRetryViewModel(repository: repository, generators: generators)
        #expect(viewModel.save() == .repositoryFailure)

        if changeLeftEye {
            viewModel.leftEyeInput = "0.9"
        } else {
            viewModel.rightEyeInput = "1.1"
        }
        repository.shouldFail = false
        #expect(viewModel.save() == .saved)

        let first = try #require(repository.attemptedRecords.first)
        let saved = try #require(repository.records.first)
        #expect(saved.id != first.id)
        #expect(saved.measuredAt != first.measuredAt)
        #expect(saved.leftEyeAcuity == (changeLeftEye ? 0.9 : 0.8))
        #expect(saved.rightEyeAcuity == (changeLeftEye ? 1 : 1.1))
        #expect(generators.idCalls == 2)
        #expect(generators.clockCalls == 2)
    }

    @Test func equivalentTextAndLocaleChangesKeepTheSnapshot() throws {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let generators = SnapshotGenerators()
        let viewModel = makeRetryViewModel(repository: repository, generators: generators)
        #expect(viewModel.save() == .repositoryFailure)

        viewModel.rightEyeInput = "1.00"
        viewModel.updateLocale(Locale(identifier: "en_US"))
        #expect(!viewModel.canSave)
        #expect(viewModel.save() == .invalidInput)
        #expect(repository.addAttempts == 1)
        viewModel.leftEyeInput = "0.80"
        #expect(viewModel.canSave)
        viewModel.updateLocale(Locale(identifier: "zh_TW"))
        #expect(viewModel.canSave)
        repository.shouldFail = false
        #expect(viewModel.save() == .saved)

        let first = try #require(repository.attemptedRecords.first)
        let saved = try #require(repository.records.first)
        expectSameRecord(saved, as: first)
        #expect(generators.idCalls == 1)
        #expect(generators.clockCalls == 1)
    }

    @Test func invalidInputCannotSubmitTheSnapshotButCanBeCorrected() throws {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let generators = SnapshotGenerators()
        let viewModel = makeRetryViewModel(repository: repository, generators: generators)
        #expect(viewModel.save() == .repositoryFailure)

        viewModel.rightEyeInput = "2.01"
        #expect(!viewModel.canSave)
        #expect(viewModel.save() == .invalidInput)
        #expect(repository.addAttempts == 1)
        #expect(viewModel.submissionState == .saveFailed)
        viewModel.rightEyeInput = "1.0"
        repository.shouldFail = false
        #expect(viewModel.save() == .saved)

        let first = try #require(repository.attemptedRecords.first)
        let saved = try #require(repository.records.first)
        expectSameRecord(saved, as: first)
        #expect(generators.idCalls == 1)
        #expect(generators.clockCalls == 1)
    }

    @Test func changingAValidValueAndRevertingStillCreatesANewSnapshot() throws {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let generators = SnapshotGenerators()
        let viewModel = makeRetryViewModel(repository: repository, generators: generators)
        #expect(viewModel.save() == .repositoryFailure)

        viewModel.leftEyeInput = "0.9"
        viewModel.leftEyeInput = "0,8"
        repository.shouldFail = false
        #expect(viewModel.save() == .saved)

        let first = try #require(repository.attemptedRecords.first)
        let saved = try #require(repository.records.first)
        #expect(saved.id != first.id)
        #expect(saved.measuredAt != first.measuredAt)
        #expect(saved.leftEyeAcuity == first.leftEyeAcuity)
        #expect(saved.rightEyeAcuity == first.rightEyeAcuity)
        #expect(generators.idCalls == 2)
        #expect(generators.clockCalls == 2)
    }

    @Test func successfulSubmissionCannotBeRepeated() {
        let repository = RepositoryStub()
        let viewModel = makeValidViewModel(repository: repository)

        #expect(viewModel.save() == .saved)
        #expect(!viewModel.canSave)
        #expect(viewModel.save() == .alreadySubmittingOrSaved)
        #expect(repository.addAttempts == 1)
        #expect(repository.records.count == 1)
    }

    @Test func updatingLocaleRevalidatesBothEyesWithoutChangingInputs() {
        let repository = RepositoryStub()
        let english = Locale(identifier: "en_US")
        let viewModel = makeViewModel(repository: repository, locale: english)
        viewModel.leftEyeInput = "1,25"
        viewModel.rightEyeInput = "0,8"

        #expect(viewModel.leftEyeValidation == .failure(.invalidFormat))
        #expect(viewModel.rightEyeValidation == .failure(.invalidFormat))
        #expect(!viewModel.canSave)

        viewModel.updateLocale(Locale(identifier: "fr_FR"))

        #expect(viewModel.leftEyeValidation == .success(1.25))
        #expect(viewModel.rightEyeValidation == .success(0.8))
        #expect(viewModel.canSave)
        #expect(viewModel.leftEyeInput == "1,25")
        #expect(viewModel.rightEyeInput == "0,8")

        viewModel.updateLocale(english)

        #expect(viewModel.leftEyeValidation == .failure(.invalidFormat))
        #expect(viewModel.rightEyeValidation == .failure(.invalidFormat))
        #expect(!viewModel.canSave)
        #expect(viewModel.leftEyeInput == "1,25")
        #expect(viewModel.rightEyeInput == "0,8")
        #expect(repository.addAttempts == 0)
    }

    @Test func savingUsesUpdatedLocale() throws {
        let repository = RepositoryStub()
        let viewModel = makeViewModel(repository: repository, locale: Locale(identifier: "en_US"))
        viewModel.leftEyeInput = "1,25"
        viewModel.rightEyeInput = "0,8"

        #expect(viewModel.save() == .invalidInput)
        #expect(repository.addAttempts == 0)

        viewModel.updateLocale(Locale(identifier: "fr_FR"))
        #expect(repository.addAttempts == 0)
        #expect(viewModel.save() == .saved)
        #expect(repository.addAttempts == 1)
        let record = try #require(repository.records.first)
        #expect(record.id == recordID)
        #expect(record.measuredAt == timestamp)
        #expect(record.leftEyeAcuity == 1.25)
        #expect(record.rightEyeAcuity == 0.8)
    }

    @Test func observationTracksLocaleThroughCanSave() async {
        let viewModel = makeViewModel(repository: RepositoryStub(), locale: Locale(identifier: "en_US"))
        viewModel.leftEyeInput = "1,25"
        viewModel.rightEyeInput = "0.8"

        await confirmation { changed in
            let initiallyCanSave = withObservationTracking {
                viewModel.canSave
            } onChange: {
                changed()
            }
            #expect(!initiallyCanSave)

            viewModel.updateLocale(Locale(identifier: "fr_FR"))
            #expect(viewModel.canSave)
        }
    }

    private func makeViewModel(
        repository: RepositoryStub,
        locale: Locale = Locale(identifier: "fr_FR")
    ) -> VisionRecordEntryViewModel {
        VisionRecordEntryViewModel(
            repository: repository,
            locale: locale,
            makeID: { recordID },
            now: { timestamp }
        )
    }

    private func makeValidViewModel(repository: RepositoryStub) -> VisionRecordEntryViewModel {
        let viewModel = makeViewModel(repository: repository)
        viewModel.leftEyeInput = "0,8"
        viewModel.rightEyeInput = "1.20"
        return viewModel
    }

    private func makeRetryViewModel(
        repository: RepositoryStub,
        generators: SnapshotGenerators
    ) -> VisionRecordEntryViewModel {
        let viewModel = VisionRecordEntryViewModel(
            repository: repository,
            locale: Locale(identifier: "fr_FR"),
            makeID: generators.makeID,
            now: generators.now
        )
        viewModel.leftEyeInput = "0,8"
        viewModel.rightEyeInput = "1.0"
        return viewModel
    }

    private func expectSameRecord(_ actual: VisionRecord, as expected: VisionRecord) {
        #expect(actual.id == expected.id)
        #expect(actual.measuredAt == expected.measuredAt)
        #expect(actual.leftEyeAcuity == expected.leftEyeAcuity)
        #expect(actual.rightEyeAcuity == expected.rightEyeAcuity)
    }

    @MainActor
    private final class SnapshotGenerators {
        private(set) var idCalls = 0
        private(set) var clockCalls = 0

        func makeID() -> UUID {
            idCalls += 1
            return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(idCalls)))
        }

        func now() -> Date {
            clockCalls += 1
            return Date(timeIntervalSince1970: TimeInterval(clockCalls))
        }
    }

    @MainActor
    private final class RepositoryStub: VisionRecordRepository {
        private enum StubError: Error {
            case writeFailed
        }

        var shouldFail = false
        private(set) var attemptedRecords: [VisionRecord] = []
        var addAttempts: Int { attemptedRecords.count }
        private(set) var records: [VisionRecord] = []

        func latestRecord() -> VisionRecord? {
            records.last
        }

        func add(_ record: VisionRecord) throws {
            attemptedRecords.append(record)
            if shouldFail { throw StubError.writeFailed }
            records.append(record)
        }
    }
}
