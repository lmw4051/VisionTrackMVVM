import Foundation
import SwiftData
import Testing
@testable import VisionTrackMVVM

@MainActor
struct SwiftDataVisionRecordRepositoryTests {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    @Test func emptyStoreReturnsNil() throws {
        let repository = SwiftDataVisionRecordRepository(container: try VisionRecordStore.inMemory())
        #expect(try repository.latestRecord() == nil)
    }

    @Test func recordRoundTripsThroughSwiftData() throws {
        let repository = SwiftDataVisionRecordRepository(container: try VisionRecordStore.inMemory())
        let record = makeRecord(id: firstID)
        try repository.add(record)
        try expectLatest(record, in: repository)
    }

    @Test func measurementTimeTakesPrecedenceOverInsertionOrder() throws {
        let repository = SwiftDataVisionRecordRepository(container: try VisionRecordStore.inMemory())
        let newest = makeRecord(id: firstID, seconds: 2_000)
        try repository.add(newest)
        try repository.add(makeRecord(id: secondID, seconds: 1_000))
        try expectLatest(newest, in: repository)
    }

    @Test func equalMeasurementTimesFavorTheLaterInsertion() throws {
        let repository = SwiftDataVisionRecordRepository(container: try VisionRecordStore.inMemory())
        let latest = makeRecord(id: secondID)
        try repository.add(makeRecord(id: firstID))
        try repository.add(latest)
        try expectLatest(latest, in: repository)
    }

    @Test func resubmissionDoesNotInsertOrChangeOrder() throws {
        let container = try VisionRecordStore.inMemory()
        let repository = SwiftDataVisionRecordRepository(container: container)
        let first = makeRecord(id: firstID, left: -0.0)
        let second = makeRecord(id: secondID)
        try repository.add(first)
        try repository.add(second)
        try repository.add(makeRecord(id: firstID, left: 0.0))

        let records = try ModelContext(container).fetch(FetchDescriptor<VisionRecordEntity>())
        #expect(records.count == 2)
        #expect(records.first { $0.id == firstID }?.insertionOrder == 1)
        try expectLatest(second, in: repository)
    }

    @Test func conflictingContentDoesNotOverwriteTheOriginal() throws {
        let container = try VisionRecordStore.inMemory()
        let repository = SwiftDataVisionRecordRepository(container: container)
        let original = makeRecord(id: firstID)
        try repository.add(original)

        let conflicts = [
            makeRecord(id: firstID, seconds: 2_000),
            makeRecord(id: firstID, left: original.leftEyeAcuity.nextUp),
            makeRecord(id: firstID, right: original.rightEyeAcuity.nextUp)
        ]
        for conflict in conflicts {
            #expect(throws: SwiftDataVisionRecordRepository.WriteError.conflictingRecordID(firstID)) {
                try repository.add(conflict)
            }
        }

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<VisionRecordEntity>()) == 1)
        try expectLatest(original, in: repository)
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func nonFiniteValuesAreRejected(_ value: Double) throws {
        let repository = SwiftDataVisionRecordRepository(container: try VisionRecordStore.inMemory())
        #expect(throws: SwiftDataVisionRecordRepository.WriteError.nonFiniteAcuity) {
            try repository.add(makeRecord(id: firstID, left: value))
        }
        #expect(try repository.latestRecord() == nil)
    }

    @Test func insertionOrderOverflowThrowsWithoutInserting() throws {
        let container = try VisionRecordStore.inMemory()
        let original = makeRecord(id: firstID)
        try seed(original, insertionOrder: .max, in: container)

        let repository = SwiftDataVisionRecordRepository(container: container)
        #expect(throws: SwiftDataVisionRecordRepository.WriteError.insertionOrderOverflow) {
            try repository.add(makeRecord(id: secondID))
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<VisionRecordEntity>()) == 1)
        try expectLatest(original, in: repository)
    }

    @Test func reopeningDiskStorePreservesRecordsAndContinuesInsertionOrder() throws {
        let first = makeRecord(id: firstID, seconds: 2_000)
        let second = makeRecord(id: secondID, seconds: 2_000, left: 0.9)
        let older = makeRecord(id: thirdID, seconds: 1_000)
        let next = makeRecord(id: UUID(), seconds: 2_000, right: 1.5)

        try withTemporaryStore { url in
            do {
                let repository = SwiftDataVisionRecordRepository(container: try VisionRecordStore.onDisk(at: url))
                try repository.add(first)
                try repository.add(second)
                try repository.add(older)
            }

            let reopened = try VisionRecordStore.onDisk(at: url)
            let repository = SwiftDataVisionRecordRepository(container: reopened)
            try expectLatest(second, in: repository)
            try repository.add(next)
            try expectLatest(next, in: repository)

            let records = try ModelContext(reopened).fetch(FetchDescriptor<VisionRecordEntity>())
            #expect(records.count == 4)
            #expect(records.first { $0.id == next.id }?.insertionOrder == 4)
        }
    }

    @Test func readOnlyDiskStoreThrowsOnSaveAndRollsBackPendingInsert() throws {
        let existing = makeRecord(id: firstID, seconds: 1_000)
        let attempted = makeRecord(id: secondID, seconds: 2_000)

        try withTemporaryStore { url in
            do {
                let repository = SwiftDataVisionRecordRepository(container: try VisionRecordStore.onDisk(at: url))
                try repository.add(existing)
            }

            do {
                let readOnly = try VisionRecordStore.onDisk(at: url, allowsSave: false)
                let repository = SwiftDataVisionRecordRepository(container: readOnly)
                try expectLatest(existing, in: repository)
                // These reads and the UUID/sequence queries are valid on the read-only store.
                #expect(throws: (any Error).self) {
                    try repository.add(attempted)
                }
                try expectLatest(existing, in: repository)
            }

            let reopened = try VisionRecordStore.onDisk(at: url)
            #expect(try ModelContext(reopened).fetchCount(FetchDescriptor<VisionRecordEntity>()) == 1)
            try expectLatest(existing, in: SwiftDataVisionRecordRepository(container: reopened))
        }
    }

    private func seed(_ record: VisionRecord, insertionOrder: Int64, in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.insert(VisionRecordEntity(record: record, insertionOrder: insertionOrder))
        try context.save()
    }

    private func withTemporaryStore(_ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VisionRecordRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Could not remove the test-owned store directory: \(error)")
            }
        }
        try operation(directory.appendingPathComponent("VisionRecords.store"))
    }

    private func expectLatest(_ expected: VisionRecord, in repository: SwiftDataVisionRecordRepository) throws {
        let latest = try repository.latestRecord()
        let actual = try #require(latest)
        #expect(actual.id == expected.id)
        #expect(actual.measuredAt == expected.measuredAt)
        #expect(actual.leftEyeAcuity == expected.leftEyeAcuity)
        #expect(actual.rightEyeAcuity == expected.rightEyeAcuity)
    }

    private func makeRecord(id: UUID, seconds: TimeInterval = 1_000,
                            left: Double = 0.8, right: Double = 1.2) -> VisionRecord {
        VisionRecord(id: id, measuredAt: Date(timeIntervalSince1970: seconds),
                     leftEyeAcuity: left, rightEyeAcuity: right)
    }
}
