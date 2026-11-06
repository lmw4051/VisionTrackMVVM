import SwiftUI

struct VisionRecordHistoryView: View {
    @Environment(\.locale) private var locale
    @State private var viewModel: VisionRecordHistoryViewModel

    init(repository: any VisionRecordRepository) {
        _viewModel = State(initialValue: VisionRecordHistoryViewModel(repository: repository))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear
            case .empty:
                ContentUnavailableView("No examination records yet", systemImage: "clock")
                    .accessibilityIdentifier("visionRecordHistory.emptyState")
            case .loaded(let records):
                List(records) { record in
                    NavigationLink {
                        VisionRecordDetailView(record: record)
                    } label: {
                        row(for: record)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilitySummary(for: record))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("visionRecordHistory.record.\(record.id.uuidString)")
                }
                .accessibilityIdentifier("visionRecordHistory.list")
            case .failed:
                ContentUnavailableView {
                    Label("Unable to Load Records", systemImage: "exclamationmark.circle")
                        .accessibilityIdentifier("visionRecordHistory.errorState")
                } description: {
                    Text("Please try again.")
                } actions: {
                    Button("Retry", action: viewModel.reload)
                        .accessibilityIdentifier("visionRecordHistory.retryButton")
                }
            }
        }
        .navigationTitle("Vision Record History")
        .onAppear {
            if case .idle = viewModel.state {
                viewModel.reload()
            }
        }
    }

    private func row(for record: VisionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.measuredAt, format: dateStyle)
                .font(.headline)
            LabeledContent("Left Eye") {
                Text(record.leftEyeAcuity, format: numberStyle)
            }
            LabeledContent("Right Eye") {
                Text(record.rightEyeAcuity, format: numberStyle)
            }
        }
    }

    private var dateStyle: Date.FormatStyle {
        .dateTime.year().month().day().hour().minute().locale(locale)
    }

    private var numberStyle: FloatingPointFormatStyle<Double> {
        .number.locale(locale)
    }

    private func accessibilitySummary(for record: VisionRecord) -> Text {
        Text(verbatim: [
            record.measuredAt.formatted(dateStyle),
            String(localized: "Left Eye", locale: locale) + " " + record.leftEyeAcuity.formatted(numberStyle),
            String(localized: "Right Eye", locale: locale) + " " + record.rightEyeAcuity.formatted(numberStyle)
        ].joined(separator: ", "))
    }
}
