import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Vision Health Records")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        if let record = viewModel.latestRecord {
                            LabeledContent("Left Eye") {
                                Text(record.leftEyeAcuity, format: .number)
                            }
                            LabeledContent("Right Eye") {
                                Text(record.rightEyeAcuity, format: .number)
                            }
                        } else {
                            Text("No examination records yet")
                        }
                    }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } label: {
                    Label("Latest Examination", systemImage: "eye")
                }

                GroupBox {
                    Group {
                        switch viewModel.syncStatus {
                        case .noPendingData:
                            Text("No data pending sync")
                        }
                    }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } label: {
                    Label("Data Sync Status", systemImage: "arrow.triangle.2.circlepath")
                }

                VStack(spacing: 8) {
                    Button {
                        // 新增功能尚未開放。
                    } label: {
                        Label("Add Vision Examination Record", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAddRecord)

                    Text("Not Available Yet")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("VisionTrack")
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
