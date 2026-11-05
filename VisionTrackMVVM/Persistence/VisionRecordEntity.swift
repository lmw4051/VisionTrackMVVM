import Foundation
import SwiftData

@Model
nonisolated final class VisionRecordEntity {
    var id: UUID
    var measuredAt: Date
    var leftEyeAcuity: Double
    var rightEyeAcuity: Double
    var insertionOrder: Int64

    @MainActor
    init(record: VisionRecord, insertionOrder: Int64) {
        id = record.id
        measuredAt = record.measuredAt
        leftEyeAcuity = record.leftEyeAcuity
        rightEyeAcuity = record.rightEyeAcuity
        self.insertionOrder = insertionOrder
    }

    @MainActor
    func toDomain() -> VisionRecord {
        VisionRecord(
            id: id,
            measuredAt: measuredAt,
            leftEyeAcuity: leftEyeAcuity,
            rightEyeAcuity: rightEyeAcuity
        )
    }
}
