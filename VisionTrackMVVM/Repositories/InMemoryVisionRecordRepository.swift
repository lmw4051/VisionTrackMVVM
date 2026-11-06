@MainActor
final class InMemoryVisionRecordRepository: VisionRecordRepository {
    private var records: [VisionRecord] = []

    func latestRecord() -> VisionRecord? {
        var latest: VisionRecord?

        for record in records {
            if let current = latest {
                // Equal timestamps favor the record inserted later.
                if record.measuredAt >= current.measuredAt {
                    latest = record
                }
            } else {
                latest = record
            }
        }

        return latest
    }

    func fetchRecords() -> [VisionRecord] {
        records.indices.sorted { lhs, rhs in
            let leftDate = records[lhs].measuredAt
            let rightDate = records[rhs].measuredAt
            return leftDate == rightDate ? lhs > rhs : leftDate > rightDate
        }.map { records[$0] }
    }

    func add(_ record: VisionRecord) throws {
        records.append(record)
    }
}
