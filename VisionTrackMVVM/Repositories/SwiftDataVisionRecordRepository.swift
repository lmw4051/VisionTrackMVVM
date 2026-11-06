import Foundation
import SwiftData

@MainActor
final class SwiftDataVisionRecordRepository: VisionRecordRepository {
    enum WriteError: Error, Equatable {
        case conflictingRecordID(UUID)
        case nonFiniteAcuity
        case insertionOrderOverflow
    }

    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func latestRecord() throws -> VisionRecord? {
        var descriptor = orderedRecordsDescriptor
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.toDomain()
    }

    func fetchRecords() throws -> [VisionRecord] {
        try context.fetch(orderedRecordsDescriptor).map { $0.toDomain() }
    }

    private var orderedRecordsDescriptor: FetchDescriptor<VisionRecordEntity> {
        FetchDescriptor(sortBy: [
            SortDescriptor(\.measuredAt, order: .reverse),
            SortDescriptor(\.insertionOrder, order: .reverse)
        ])
    }

    func add(_ record: VisionRecord) throws {
        let id = record.id
        var matchingID = FetchDescriptor<VisionRecordEntity>(predicate: #Predicate { $0.id == id })
        matchingID.fetchLimit = 1
        if let entity = try context.fetch(matchingID).first {
            let existing = entity.toDomain()
            // Domain values use exact numeric equality, including equivalence of signed zeros.
            guard existing.measuredAt == record.measuredAt,
                  existing.leftEyeAcuity == record.leftEyeAcuity,
                  existing.rightEyeAcuity == record.rightEyeAcuity else {
                throw WriteError.conflictingRecordID(id)
            }
            return
        }

        guard record.leftEyeAcuity.isFinite, record.rightEyeAcuity.isFinite else {
            throw WriteError.nonFiniteAcuity
        }

        let insertionOrder = try nextInsertionOrder()
        context.insert(VisionRecordEntity(record: record, insertionOrder: insertionOrder))
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func nextInsertionOrder() throws -> Int64 {
        var descriptor = FetchDescriptor<VisionRecordEntity>(sortBy: [
            SortDescriptor(\.insertionOrder, order: .reverse)
        ])
        descriptor.fetchLimit = 1
        let maxOrder = try context.fetch(descriptor).first?.insertionOrder ?? 0
        let (next, overflow) = maxOrder.addingReportingOverflow(1)
        guard !overflow else { throw WriteError.insertionOrderOverflow }
        return next
    }
}
