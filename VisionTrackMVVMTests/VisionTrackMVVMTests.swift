//
//  VisionTrackMVVMTests.swift
//  VisionTrackMVVMTests
//
//  Created by David Lee on 11/2/26.
//

import Foundation
import Testing
@testable import VisionTrackMVVM

@MainActor
struct VisionTrackMVVMTests {

    @Test func dashboardStartsWithoutRecordsAndCanAddRecord() {
        let viewModel = DashboardViewModel(repository: InMemoryVisionRecordRepository())

        #expect(viewModel.latestRecord == nil)
        #expect(viewModel.syncStatus == .unavailable)
        #expect(viewModel.canAddRecord)
    }

    @Test func dashboardLoadsLatestRecordByMeasurementTime() throws {
        let repository = InMemoryVisionRecordRepository()
        let newest = Date(timeIntervalSince1970: 2_000)
        let older = Date(timeIntervalSince1970: 1_000)
        try repository.add(VisionRecord(id: UUID(), measuredAt: newest, leftEyeAcuity: 1.2, rightEyeAcuity: 1))
        try repository.add(VisionRecord(id: UUID(), measuredAt: older, leftEyeAcuity: 0.5, rightEyeAcuity: 0.6))

        let viewModel = DashboardViewModel(repository: repository)

        #expect(viewModel.latestRecord?.measuredAt == newest)
        #expect(viewModel.latestRecord?.leftEyeAcuity == 1.2)
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
        #expect(dashboard.latestRecord == nil)

        dashboard.refresh()

        #expect(dashboard.latestRecord?.measuredAt == measuredAt)
        #expect(dashboard.latestRecord?.leftEyeAcuity == 1.2)
        #expect(dashboard.latestRecord?.rightEyeAcuity == 0.8)
    }
}
