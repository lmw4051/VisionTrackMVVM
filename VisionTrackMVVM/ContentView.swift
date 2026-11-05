//
//  ContentView.swift
//  VisionTrackMVVM
//
//  Created by David Lee on 11/2/26.
//

import SwiftUI

struct ContentView: View {
    let repository: any VisionRecordRepository

    var body: some View {
        NavigationStack {
            DashboardView(repository: repository)
        }
    }
}

#Preview {
    ContentView(repository: InMemoryVisionRecordRepository())
}
