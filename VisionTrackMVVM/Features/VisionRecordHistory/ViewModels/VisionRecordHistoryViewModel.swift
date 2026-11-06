import Observation

@MainActor
@Observable
final class VisionRecordHistoryViewModel {
    enum State {
        case idle
        case empty
        case loaded([VisionRecord])
        case failed
    }

    private(set) var state: State = .idle
    private let repository: any VisionRecordRepository

    init(repository: any VisionRecordRepository) {
        self.repository = repository
    }

    func reload() {
        do {
            let records = try repository.fetchRecords()
            state = records.isEmpty ? .empty : .loaded(records)
        } catch {
            state = .failed
        }
    }
}
