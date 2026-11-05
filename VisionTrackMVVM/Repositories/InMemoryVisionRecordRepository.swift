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

    func add(_ record: VisionRecord) throws {
        records.append(record)
    }
}
