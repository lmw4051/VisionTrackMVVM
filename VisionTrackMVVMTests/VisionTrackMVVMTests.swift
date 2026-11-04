//
//  VisionTrackMVVMTests.swift
//  VisionTrackMVVMTests
//
//  Created by David Lee on 11/2/26.
//

import Testing
@testable import VisionTrackMVVM

struct VisionTrackMVVMTests {

    @MainActor
    @Test func dashboardStartsWithoutRecordsOrPendingSync() {
        let viewModel = DashboardViewModel()

        #expect(viewModel.latestRecord == nil)
        #expect(viewModel.syncStatus == .noPendingData)
        #expect(!viewModel.canAddRecord)
    }

}
