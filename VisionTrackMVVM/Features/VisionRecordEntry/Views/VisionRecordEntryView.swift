import SwiftUI

struct VisionRecordEntryView: View {
    private enum Field: Hashable {
        case leftEye
        case rightEye
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var focusedField: Field?
    @State private var visitedFields: Set<Field> = []
    @State private var showsSaveError = false

    @Bindable var viewModel: VisionRecordEntryViewModel
    let onSaveSuccess: () -> Void

    var body: some View {
        Form {
            Section {
                acuityField(
                    "Left Eye Acuity",
                    text: $viewModel.leftEyeInput,
                    field: .leftEye,
                    validation: viewModel.leftEyeValidation,
                    identifier: "visionRecordEntry.leftEyeField"
                )
                acuityField(
                    "Right Eye Acuity",
                    text: $viewModel.rightEyeInput,
                    field: .rightEye,
                    validation: viewModel.rightEyeValidation,
                    identifier: "visionRecordEntry.rightEyeField"
                )
            } footer: {
                Text("This form is for simulated data and does not provide a medical diagnosis.")
            }
        }
        .navigationTitle("New Vision Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(viewModel.submissionState == .saving)
                    .accessibilityIdentifier("visionRecordEntry.cancelButton")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("visionRecordEntry.saveButton")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .accessibilityIdentifier("visionRecordEntry.keyboardDoneButton")
            }
        }
        .onChange(of: locale, initial: true) { _, newLocale in
            viewModel.updateLocale(newLocale)
        }
        .onChange(of: focusedField) { previousField, _ in
            if let previousField {
                visitedFields.insert(previousField)
            }
        }
        .alert("Save Failed", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your entries are still here. Please try saving again.")
                .accessibilityIdentifier("visionRecordEntry.saveErrorAlert")
        }
    }

    private func acuityField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        field: Field,
        validation: Result<Double, VisionAcuityInputValidator.ValidationError>,
        identifier: String
    ) -> some View {
        let error = visibleError(for: field, validation: validation)

        return VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .accessibilityIdentifier(identifier)
                .accessibilityHint(error.map { Text($0) } ?? Text(verbatim: ""))

            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func visibleError(
        for field: Field,
        validation: Result<Double, VisionAcuityInputValidator.ValidationError>
    ) -> LocalizedStringKey? {
        guard visitedFields.contains(field), case let .failure(error) = validation else {
            return nil
        }

        switch error {
        case .required: return "Required Field"
        case .invalidFormat: return "Invalid Format"
        case .tooManyFractionDigits: return "Too Many Decimal Places"
        case .outOfRange: return "Out of Range"
        }
    }

    private func save() {
        focusedField = nil

        switch viewModel.save() {
        case .saved:
            onSaveSuccess()
            dismiss()
        case .repositoryFailure:
            showsSaveError = true
        case .invalidInput:
            visitedFields.formUnion([.leftEye, .rightEye])
        case .alreadySubmittingOrSaved:
            break
        }
    }
}
