import SwiftUI

struct VisionRecordDetailView: View {
    @Environment(\.locale) private var locale
    let record: VisionRecord

    var body: some View {
        List {
            LabeledContent("Examination Date and Time") {
                Text(record.measuredAt, format: .dateTime.year().month().day().hour().minute().second().locale(locale))
            }
            .accessibilityIdentifier("visionRecordDetail.measuredAt")

            LabeledContent("Left Eye") {
                Text(record.leftEyeAcuity, format: .number.locale(locale))
            }
            .accessibilityIdentifier("visionRecordDetail.leftEye")

            LabeledContent("Right Eye") {
                Text(record.rightEyeAcuity, format: .number.locale(locale))
            }
            .accessibilityIdentifier("visionRecordDetail.rightEye")
        }
        .accessibilityIdentifier("visionRecordDetail.content")
        .navigationTitle("Vision Record Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
