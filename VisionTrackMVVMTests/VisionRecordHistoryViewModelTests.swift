import Foundation
import Testing
@testable import VisionTrackMVVM

@MainActor
struct VisionRecordHistoryViewModelTests {
    @Test func startsIdleWithoutReading() {
        let repository = RepositoryStub()
        let viewModel = VisionRecordHistoryViewModel(repository: repository)

        guard case .idle = viewModel.state else {
            Issue.record("Expected idle before the first read")
            return
        }
        #expect(repository.readAttempts == 0)
    }

    @Test func emptyRepositoryLoadsEmptyState() {
        let repository = RepositoryStub()
        let viewModel = VisionRecordHistoryViewModel(repository: repository)

        viewModel.reload()

        guard case .empty = viewModel.state else {
            Issue.record("Expected an empty result")
            return
        }
        #expect(repository.readAttempts == 1)
    }

    @Test func singleRecordLoadsWithAllFields() throws {
        let record = makeRecord(seconds: 1_000)
        let repository = RepositoryStub(records: [record])
        let viewModel = VisionRecordHistoryViewModel(repository: repository)

        viewModel.reload()

        let records = try loadedRecords(in: viewModel)
        #expect(records.count == 1)
        let actual = try #require(records.first)
        #expect(actual.id == record.id)
        #expect(actual.measuredAt == record.measuredAt)
        #expect(actual.leftEyeAcuity == record.leftEyeAcuity)
        #expect(actual.rightEyeAcuity == record.rightEyeAcuity)
    }

    @Test func preservesRepositoryOrder() throws {
        let records = [makeRecord(seconds: 1_000), makeRecord(seconds: 2_000), makeRecord(seconds: 2_000)]
        let viewModel = VisionRecordHistoryViewModel(repository: RepositoryStub(records: records))

        viewModel.reload()

        #expect(try loadedRecords(in: viewModel).map(\.id) == records.map(\.id))
    }

    @Test func readFailureShowsFailedState() {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let viewModel = VisionRecordHistoryViewModel(repository: repository)

        viewModel.reload()

        guard case .failed = viewModel.state else {
            Issue.record("Expected a failure rather than an empty result")
            return
        }
        #expect(repository.readAttempts == 1)
        #expect(repository.addAttempts == 0)
    }

    @Test func retryLoadsRecordsWithoutWriting() throws {
        let record = makeRecord(seconds: 1_000)
        let repository = RepositoryStub(records: [record])
        repository.shouldFail = true
        let viewModel = VisionRecordHistoryViewModel(repository: repository)
        viewModel.reload()

        repository.shouldFail = false
        viewModel.reload()

        #expect(try loadedRecords(in: viewModel).map(\.id) == [record.id])
        #expect(repository.readAttempts == 2)
        #expect(repository.addAttempts == 0)
    }

    @Test func retryCanRecoverToEmptyWithoutWriting() {
        let repository = RepositoryStub()
        repository.shouldFail = true
        let viewModel = VisionRecordHistoryViewModel(repository: repository)
        viewModel.reload()

        repository.shouldFail = false
        viewModel.reload()

        guard case .empty = viewModel.state else {
            Issue.record("Expected an empty result after retry")
            return
        }
        #expect(repository.readAttempts == 2)
        #expect(repository.addAttempts == 0)
    }

    @Test func reloadReadsNewRecordsFromRepository() throws {
        let older = makeRecord(seconds: 1_000)
        let newer = makeRecord(seconds: 2_000)
        let repository = RepositoryStub(records: [older])
        let viewModel = VisionRecordHistoryViewModel(repository: repository)
        viewModel.reload()

        repository.add(newer)
        viewModel.reload()

        #expect(try loadedRecords(in: viewModel).map(\.id) == [newer.id, older.id])
        #expect(repository.readAttempts == 2)
        #expect(repository.addAttempts == 1)
    }

    private func loadedRecords(in viewModel: VisionRecordHistoryViewModel) throws -> [VisionRecord] {
        let records: [VisionRecord]?
        if case .loaded(let loaded) = viewModel.state {
            records = loaded
        } else {
            records = nil
        }
        return try #require(records)
    }

    private func makeRecord(seconds: TimeInterval) -> VisionRecord {
        VisionRecord(id: UUID(), measuredAt: Date(timeIntervalSince1970: seconds), leftEyeAcuity: 0.8, rightEyeAcuity: 1.2)
    }

    @MainActor
    private final class RepositoryStub: VisionRecordRepository {
        enum ReadError: Error {
            case unavailable
        }

        private var records: [VisionRecord]
        var shouldFail = false
        private(set) var readAttempts = 0
        private(set) var addAttempts = 0

        init(records: [VisionRecord] = []) {
            self.records = records
        }

        func latestRecord() -> VisionRecord? {
            records.first
        }

        func fetchRecords() throws -> [VisionRecord] {
            readAttempts += 1
            if shouldFail { throw ReadError.unavailable }
            return records
        }

        func add(_ record: VisionRecord) {
            addAttempts += 1
            records.insert(record, at: 0)
        }
    }
}
