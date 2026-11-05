import Observation

@MainActor
@Observable
final class DashboardViewModel {
    enum SyncStatus: Equatable {
        case unavailable
    }

    enum RecordState {
        case empty
        case loaded(VisionRecord)
        case failed
    }

    private(set) var recordState: RecordState = .empty
    private let repository: any VisionRecordRepository
    let syncStatus: SyncStatus = .unavailable

    var canAddRecord: Bool {
        if case .failed = recordState { return false }
        return true
    }

    init(repository: any VisionRecordRepository) {
        self.repository = repository
        refresh()
    }

    func refresh() {
        do {
            if let record = try repository.latestRecord() {
                recordState = .loaded(record)
            } else {
                recordState = .empty
            }
        } catch {
            recordState = .failed
        }
    }
}
