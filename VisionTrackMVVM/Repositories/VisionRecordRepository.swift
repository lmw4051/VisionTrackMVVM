@MainActor
protocol VisionRecordRepository: AnyObject {
    func latestRecord() throws -> VisionRecord?
    /// Returns all records newest first, with later insertions first for equal measurement times.
    /// An empty array represents a successful read with no records.
    func fetchRecords() throws -> [VisionRecord]
    func add(_ record: VisionRecord) throws
}
