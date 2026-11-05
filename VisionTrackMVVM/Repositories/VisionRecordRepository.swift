@MainActor
protocol VisionRecordRepository: AnyObject {
    func latestRecord() throws -> VisionRecord?
    func add(_ record: VisionRecord) throws
}
