import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    enum SyncStatus: Equatable {
        case noPendingData
    }

    private(set) var latestRecord: VisionRecord? = nil

    // Syncing and new features are not yet available.
    // There is currently no data waiting to be synced.
    private(set) var syncStatus: SyncStatus = .noPendingData
    let canAddRecord = false
}
