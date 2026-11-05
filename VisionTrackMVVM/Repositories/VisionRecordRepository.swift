@MainActor
protocol VisionRecordRepository: AnyObject {
    func latestRecord() -> VisionRecord?
    func add(_ record: VisionRecord) throws
}
