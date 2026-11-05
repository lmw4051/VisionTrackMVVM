import Foundation
import Testing
@testable import VisionTrackMVVM

@MainActor
struct InMemoryVisionRecordRepositoryTests {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    @Test("Empty repository returns nil")
    func emptyRepositoryReturnsNil() {
        let repository = InMemoryVisionRecordRepository()

        #expect(repository.latestRecord() == nil)
    }

    @Test("Adding one record returns that record")
    func addingOneRecordReturnsThatRecord() throws {
        let repository = InMemoryVisionRecordRepository()
        let record = makeRecord(id: firstID, timestamp: 1_000)

        try repository.add(record)

        let latest = try #require(repository.latestRecord())
        #expect(latest.id == record.id)
        #expect(latest.measuredAt == record.measuredAt)
        #expect(latest.leftEyeAcuity == record.leftEyeAcuity)
        #expect(latest.rightEyeAcuity == record.rightEyeAcuity)
    }

    @Test("Latest record is determined by measuredAt")
    func latestRecordIsDeterminedByMeasuredAt() throws {
        let repository = InMemoryVisionRecordRepository()
        let newest = makeRecord(id: secondID, timestamp: 3_000)

        try repository.add(makeRecord(id: firstID, timestamp: 1_000))
        try repository.add(newest)
        try repository.add(makeRecord(id: thirdID, timestamp: 2_000))

        #expect(repository.latestRecord()?.id == newest.id)
    }

    @Test("Same timestamp returns the most recently inserted record")
    func sameTimestampReturnsMostRecentlyInsertedRecord() throws {
        let repository = InMemoryVisionRecordRepository()
        let first = makeRecord(id: firstID, timestamp: 2_000)
        let second = makeRecord(id: secondID, timestamp: 2_000)

        try repository.add(first)
        #expect(repository.latestRecord()?.id == first.id)

        try repository.add(second)
        #expect(repository.latestRecord()?.id == second.id)

        // A later insertion with an older measurement must not replace it.
        try repository.add(makeRecord(id: thirdID, timestamp: 1_000))
        #expect(repository.latestRecord()?.id == second.id)
    }

    private func makeRecord(id: UUID, timestamp: TimeInterval) -> VisionRecord {
        VisionRecord(
            id: id,
            measuredAt: Date(timeIntervalSince1970: timestamp),
            leftEyeAcuity: 0.8,
            rightEyeAcuity: 1.2
        )
    }
}
