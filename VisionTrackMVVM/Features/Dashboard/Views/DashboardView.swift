import SwiftUI

struct DashboardView: View {
    private struct EntryPresentation: Identifiable {
        let id = UUID()
        let viewModel: VisionRecordEntryViewModel
    }

    @Environment(\.locale) private var locale
    @State private var viewModel: DashboardViewModel
    @State private var entryPresentation: EntryPresentation?
    private let repository: any VisionRecordRepository

    init(repository: any VisionRecordRepository) {
        self.repository = repository
        _viewModel = State(initialValue: DashboardViewModel(repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Vision Health Records")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        switch viewModel.recordState {
                        case .loaded(let record):
                            LabeledContent("Left Eye") {
                                Text(record.leftEyeAcuity, format: .number.locale(locale))
                            }
                            LabeledContent("Right Eye") {
                                Text(record.rightEyeAcuity, format: .number.locale(locale))
                            }
                            LabeledContent("Examination Date and Time") {
                                Text(record.measuredAt, format: .dateTime.year().month().day().hour().minute().locale(locale))
                            }
                        case .empty:
                            Text("No examination records yet")
                        case .failed:
                            Text("Unable to Load Records")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text("Please try again.")
                            Button("Retry", action: viewModel.refresh)
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("dashboard.retryLoadRecordsButton")
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
                        case .unavailable:
                            Text("Not Available Yet")
                        }
                    }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } label: {
                    Label("Data Sync Status", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    entryPresentation = EntryPresentation(
                        viewModel: VisionRecordEntryViewModel(repository: repository, locale: locale)
                    )
                } label: {
                    Label("Add Vision Examination Record", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canAddRecord)
                .accessibilityIdentifier("dashboard.addVisionRecordButton")

                NavigationLink {
                    VisionRecordHistoryView(repository: repository)
                } label: {
                    Label("Vision Record History", systemImage: "clock")
                }
                .accessibilityIdentifier("dashboard.historyButton")
            }
            .padding()
        }
        .navigationTitle("VisionTrack")
        .sheet(item: $entryPresentation) { entry in
            NavigationStack {
                VisionRecordEntryView(viewModel: entry.viewModel, onSaveSuccess: viewModel.refresh)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(repository: InMemoryVisionRecordRepository())
    }
}
