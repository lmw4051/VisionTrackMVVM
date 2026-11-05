import Foundation
import SwiftData

@MainActor
enum VisionRecordStore {
    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: VisionRecordEntity.self, configurations: configuration)
    }

    static func onDisk(at url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: url, allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: VisionRecordEntity.self, configurations: configuration)
    }
}
