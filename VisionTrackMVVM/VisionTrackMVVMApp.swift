//
//  VisionTrackMVVMApp.swift
//  VisionTrackMVVM
//
//  Created by David Lee on 11/2/26.
//

import SwiftUI

@main
struct VisionTrackMVVMApp: App {
    @State private var startup = VisionRecordStartup()

    var body: some Scene {
        WindowGroup {
            Group {
                switch startup.state {
                case .idle:
                    ProgressView()
                case .ready(_, let repository):
                    ContentView(repository: repository)
                case .failed:
                    ContentUnavailableView {
                        Label("Unable to Open Record Storage", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Please try again.")
                    } actions: {
                        Button("Retry", action: startup.retry)
                            .accessibilityIdentifier("visionRecordStore.retryButton")
                    }
                }
            }
            .task {
                startup.startIfNeeded()
            }
        }
    }
}
