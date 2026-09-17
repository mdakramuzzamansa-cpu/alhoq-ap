import SwiftUI

struct CategoryVerificationView: View {
    @StateObject private var viewModel: CategoryVerificationViewModel
    let categoryName: String

    init(categoryId: Int, categoryName: String) {
        _viewModel = StateObject(wrappedValue: CategoryVerificationViewModel(categoryId: categoryId))
        self.categoryName = categoryName
    }

    var body: some View {
        content
            .navigationTitle("'\(categoryName)'-এ Get Trusted")
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.screenState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            Text(message).foregroundStyle(.red).padding()

        case .alreadyApproved:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(.blue)
                Text("আপনি এই ক্যাটাগরিতে ইতিমধ্যে Trusted।").font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .pending:
            VStack(spacing: 12) {
                Image(systemName: "clock.fill").font(.system(size: 48)).foregroundStyle(.orange)
                Text("আপনার আবেদন রিভিউয়ের অপেক্ষায় আছে।").font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .form(let fields, let previousRejection):
            form(fields: fields, previousRejection: previousRejection)
        }
    }

    private func form(fields: [VerificationFieldDefinition], previousRejection: CategoryVerification?) -> some View {
        Form {
            if let note = previousRejection?.adminNote {
                Section {
                    Label("আগের আবেদন প্রত্যাখ্যাত হয়েছে", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("অ্যাকাউন্টের ধরন") {
                Picker("অ্যাকাউন্টের ধরন", selection: $viewModel.accountType) {
                    Text("ব্যক্তিগত").tag(AlhoqUser.AccountType.personal)
                    Text("ব্যবসায়িক").tag(AlhoqUser.AccountType.business)
                }
                .pickerStyle(.segmented)

                if viewModel.accountType == .business {
                    TextField("ব্যবসার ধরন", text: $viewModel.businessType)
                    fieldError("business_type")
                }
            }

            // Section 7: প্রতিটা ফিল্ড সম্পূর্ণ backend থেকে আসা definition অনুযায়ী রেন্ডার হচ্ছে —
            // কোনো ফিল্ড iOS কোডে হার্ডকোড করা নেই, categoryId ভেদে সংখ্যা/ধরন বদলাবে
            Section("প্রয়োজনীয় তথ্য") {
                ForEach(fields) { field in
                    dynamicField(field)
                    fieldError(field.key)
                }
            }

            if let error = viewModel.generalError {
                Text(error).foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.submit(fields: fields) }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("জমা দিন").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSubmitting)
        }
    }

    @ViewBuilder
    private func dynamicField(_ field: VerificationFieldDefinition) -> some View {
        switch field.type {
        case .text:
            TextField(field.label, text: binding(for: field.key))
        case .url:
            TextField(field.label, text: binding(for: field.key))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
        case .textarea:
            TextField(field.label, text: binding(for: field.key), axis: .vertical)
                .lineLimit(3...8)
        case .file, .video:
            MediaPickerField(
                label: field.label,
                isVideo: field.type == .video,
                isUploaded: viewModel.uploadedFileValues[field.key] != nil,
                isUploading: viewModel.uploadingFieldKeys.contains(field.key)
            ) { url in
                Task { await viewModel.uploadFile(fileURL: url, for: field) }
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { viewModel.textValues[key] ?? "" },
            set: { viewModel.textValues[key] = $0 }
        )
    }

    @ViewBuilder
    private func fieldError(_ key: String) -> some View {
        if let message = viewModel.fieldErrors[key] {
            Text(message).font(.caption2).foregroundStyle(.red)
        }
    }
}
