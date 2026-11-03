import Foundation

/// Describe a single binocular vision test using decimal visual acuity values.
struct VisionRecord: Identifiable {
    let id: UUID
    let measuredAt: Date
    let leftEyeAcuity: Double
    let rightEyeAcuity: Double
}
