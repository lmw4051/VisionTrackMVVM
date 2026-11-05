import Observation

@MainActor
@Observable
final class DashboardViewModel {
    enum SyncStatus: Equatable {
        case unavailable
    }

    private(set) var latestRecord: VisionRecord?
    private let repository: any VisionRecordRepository
    let syncStatus: SyncStatus = .unavailable
    let canAddRecord = true

    init(repository: any VisionRecordRepository) {
        self.repository = repository
        refresh()
    }

    func refresh() {
        latestRecord = repository.latestRecord()
    }
}
