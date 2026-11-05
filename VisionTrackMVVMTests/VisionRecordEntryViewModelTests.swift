import Foundation
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

    @Test func retryAfterFailureAddsExactlyOneRecord() {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let viewModel = makeValidViewModel(repository: repository)

        #expect(viewModel.save() == .repositoryFailure)
        repository.shouldFail = false
        #expect(viewModel.save() == .saved)

        #expect(repository.addAttempts == 2)
        #expect(repository.records.count == 1)
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

    private func makeViewModel(repository: RepositoryStub) -> VisionRecordEntryViewModel {
        VisionRecordEntryViewModel(
            repository: repository,
            locale: Locale(identifier: "fr_FR"),
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

    @MainActor
    private final class RepositoryStub: VisionRecordRepository {
        private enum StubError: Error {
            case writeFailed
        }

        var shouldFail = false
        private(set) var addAttempts = 0
        private(set) var records: [VisionRecord] = []

        func latestRecord() -> VisionRecord? {
            records.last
        }

        func add(_ record: VisionRecord) throws {
            addAttempts += 1
            if shouldFail { throw StubError.writeFailed }
            records.append(record)
        }
    }
}
