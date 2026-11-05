import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class VisionRecordStartup {
    enum State {
        case idle
        case ready(ModelContainer, SwiftDataVisionRecordRepository)
        case failed
    }

    enum Destination: Equatable {
        case production
        #if DEBUG
        case hostedUnitTests
        case uiTests(UUID)
        #endif
    }

    private enum ConfigurationError: Error {
        case invalidTestStoreID
    }

    private(set) var state: State = .idle
    private let openContainer: () throws -> ModelContainer

    init(openContainer: (() throws -> ModelContainer)? = nil) {
        self.openContainer = openContainer ?? Self.openConfiguredContainer
    }

    func startIfNeeded() {
        guard case .idle = state else { return }
        open()
    }

    func retry() {
        guard case .failed = state else { return }
        open()
    }

    private func open() {
        do {
            let container = try openContainer()
            state = .ready(container, SwiftDataVisionRecordRepository(container: container))
        } catch {
            state = .failed
        }
    }

    static func destination(environment: [String: String]) throws -> Destination {
        #if DEBUG
        if let id = environment["VISIONTRACK_UI_TEST_STORE_ID"] {
            guard id.utf8.count == 36, let uuid = UUID(uuidString: id),
                  uuid.uuidString.lowercased() == id.lowercased() else {
                throw ConfigurationError.invalidTestStoreID
            }
            return .uiTests(uuid)
        }
        // XCTest injects these into the hosted App before SwiftUI initializes it.
        if environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil {
            return .hostedUnitTests
        }
        #endif
        return .production
    }

    static func openConfiguredContainer() throws -> ModelContainer {
        switch try destination(environment: ProcessInfo.processInfo.environment) {
        case .production:
            return try openDiskContainer(directory: "VisionTrackMVVM")
        #if DEBUG
        case .hostedUnitTests:
            return try VisionRecordStore.inMemory()
        case .uiTests(let id):
            return try openDiskContainer(directory: "VisionTrackMVVMUITests", testID: id)
        #endif
        }
    }

    private static func openDiskContainer(directory name: String, testID: UUID? = nil) throws -> ModelContainer {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        var directory = support.appendingPathComponent(name, isDirectory: true)
        if let testID {
            directory.appendPathComponent(testID.uuidString, isDirectory: true)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try VisionRecordStore.onDisk(at: directory.appendingPathComponent("VisionRecords.store"))
    }
}
