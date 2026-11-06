//
//  VisionTrackMVVMTests.swift
//  VisionTrackMVVMTests
//
//  Created by David Lee on 11/2/26.
//

import Foundation
import SwiftData
import Testing
@testable import VisionTrackMVVM

@MainActor
struct VisionTrackMVVMTests {

    #if DEBUG
    @Test func appHostUsesInMemoryContainer() throws {
        let environment = ProcessInfo.processInfo.environment
        #expect(try VisionRecordStartup.destination(environment: environment) == .hostedUnitTests)

        let startup = VisionRecordStartup()
        startup.startIfNeeded()
        guard case .ready(let container, _) = startup.state else {
            Issue.record("Expected the App host to open an isolated container")
            return
        }
        #expect(!container.configurations.isEmpty)
        let usesOnlyMemory = container.configurations.allSatisfy(\.isStoredInMemoryOnly)
        #expect(usesOnlyMemory)
    }
    #endif

    @Test func startupRetryOpensARealContainerAndReusesItAfterSuccess() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("VisionRecordStartupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer {
            do {
                try FileManager.default.removeItem(at: parent)
            } catch {
                Issue.record("Could not remove the test-owned startup directory: \(error)")
            }
        }
        let storeDirectory = parent.appendingPathComponent("store")
        try Data().write(to: storeDirectory)
        var attempts = 0

        do {
            let startup = VisionRecordStartup {
                attempts += 1
                return try VisionRecordStore.onDisk(at: storeDirectory.appendingPathComponent("VisionRecords.store"))
            }
            startup.startIfNeeded()
            guard case .failed = startup.state else {
                Issue.record("Expected opening a store beneath a file to fail")
                return
            }
            startup.startIfNeeded()
            #expect(attempts == 1)

            try FileManager.default.removeItem(at: storeDirectory)
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: false)
            startup.retry()
            guard case .ready(_, let repository) = startup.state else {
                Issue.record("Expected retry to open the store")
                return
            }
            #expect(try repository.latestRecord() == nil)
            startup.startIfNeeded()
            startup.retry()
            #expect(attempts == 2)
        }
    }

    @Test func dashboardStartsWithoutRecordsAndCanAddRecord() {
        let viewModel = DashboardViewModel(repository: InMemoryVisionRecordRepository())

        guard case .empty = viewModel.recordState else {
            Issue.record("Expected an empty record state")
            return
        }
        #expect(viewModel.syncStatus == .unavailable)
        #expect(viewModel.canAddRecord)
    }

    @Test func dashboardLoadsLatestRecordByMeasurementTime() throws {
        let repository = InMemoryVisionRecordRepository()
        let newest = Date(timeIntervalSince1970: 2_000)
        let older = Date(timeIntervalSince1970: 1_000)
        let latest = VisionRecord(id: UUID(), measuredAt: newest, leftEyeAcuity: 1.2, rightEyeAcuity: 1)
        try repository.add(latest)
        try repository.add(VisionRecord(id: UUID(), measuredAt: older, leftEyeAcuity: 0.5, rightEyeAcuity: 0.6))

        let viewModel = DashboardViewModel(repository: repository)

        guard case .loaded(let record) = viewModel.recordState else {
            Issue.record("Expected a loaded record state")
            return
        }
        #expect(record.id == latest.id)
        #expect(record.measuredAt == newest)
        #expect(record.leftEyeAcuity == 1.2)
        #expect(record.rightEyeAcuity == 1)
        #expect(viewModel.canAddRecord)
    }

    @Test func dashboardRefreshesAfterEntrySavesToSharedRepository() {
        let repository = InMemoryVisionRecordRepository()
        let dashboard = DashboardViewModel(repository: repository)
        let measuredAt = Date(timeIntervalSince1970: 2_000)
        let entry = VisionRecordEntryViewModel(
            repository: repository,
            locale: Locale(identifier: "en_US"),
            now: { measuredAt }
        )
        entry.leftEyeInput = "1.2"
        entry.rightEyeInput = "0.8"

        #expect(entry.save() == .saved)
        guard case .empty = dashboard.recordState else {
            Issue.record("Expected an empty state before refreshing")
            return
        }

        dashboard.refresh()

        guard case .loaded(let record) = dashboard.recordState else {
            Issue.record("Expected a loaded state after refreshing")
            return
        }
        #expect(record.measuredAt == measuredAt)
        #expect(record.leftEyeAcuity == 1.2)
        #expect(record.rightEyeAcuity == 0.8)
    }

    @Test func dashboardReadFailureDisablesAddingRecords() {
        let repository = ReadRepositoryStub()
        let viewModel = DashboardViewModel(repository: repository)

        guard case .failed = viewModel.recordState else {
            Issue.record("Expected a read failure, not an empty state")
            return
        }
        #expect(!viewModel.canAddRecord)
        #expect(repository.readAttempts == 1)
        #expect(repository.addAttempts == 0)
    }

    @Test func dashboardRetryCanLoadARecordWithoutWriting() {
        let repository = ReadRepositoryStub()
        let viewModel = DashboardViewModel(repository: repository)
        let record = VisionRecord(id: UUID(), measuredAt: Date(timeIntervalSince1970: 2_000),
                                  leftEyeAcuity: 1.2, rightEyeAcuity: 0.8)
        repository.readResult = .success(record)

        viewModel.refresh()

        guard case .loaded(let latest) = viewModel.recordState else {
            Issue.record("Expected a loaded record after retry")
            return
        }
        #expect(latest.id == record.id)
        #expect(viewModel.canAddRecord)
        #expect(repository.readAttempts == 2)
        #expect(repository.addAttempts == 0)
    }

    @Test func dashboardRetryCanRecoverToEmptyWithoutWriting() {
        let repository = ReadRepositoryStub()
        let viewModel = DashboardViewModel(repository: repository)
        repository.readResult = .success(nil)

        viewModel.refresh()

        guard case .empty = viewModel.recordState else {
            Issue.record("Expected an empty state after a successful retry")
            return
        }
        #expect(viewModel.canAddRecord)
        #expect(repository.readAttempts == 2)
        #expect(repository.addAttempts == 0)
    }

    @MainActor
    private final class ReadRepositoryStub: VisionRecordRepository {
        enum ReadError: Error {
            case unavailable
        }

        var readResult: Result<VisionRecord?, ReadError> = .failure(.unavailable)
        private(set) var readAttempts = 0
        private(set) var addAttempts = 0

        func latestRecord() throws -> VisionRecord? {
            readAttempts += 1
            return try readResult.get()
        }

        func fetchRecords() throws -> [VisionRecord] {
            try readResult.get().map { [$0] } ?? []
        }

        func add(_ record: VisionRecord) throws {
            addAttempts += 1
        }
    }
}
