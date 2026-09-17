import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct FormFillView: View {
    @StateObject private var viewModel: FormFillViewModel
    @Environment(\.dismiss) private var dismiss

    init(listingId: Int) {
        _viewModel = StateObject(wrappedValue: FormFillViewModel(listingId: listingId))
    }

    var body: some View {
        NavigationStack {
            if viewModel.didSubmit {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
                    Text("জমা দেওয়া হয়েছে!").font(.title3.bold())
                    Button("বন্ধ করুন") { dismiss() }.buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let form = viewModel.form {
                Form {
                    if let description = form.description, !description.isEmpty {
                        Section { Text(description).font(.footnote).foregroundStyle(.secondary) }
                    }
                    ForEach(form.fields) { field in
                        Section {
                            dynamicField(field)
                            if let error = viewModel.fieldErrors[field.id] {
                                Text(error).font(.caption2).foregroundStyle(.red)
                            }
                        } header: {
                            Text(field.label + (field.required ? " *" : ""))
                        }
                    }
                    if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isSubmitting { ProgressView().frame(maxWidth: .infinity) } else { Text(form.buttonLabel).frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSubmitting)
                }
                .navigationTitle(form.formTitle)
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                Text("এই লিস্টিংয়ে কোনো ফর্ম নেই।").foregroundStyle(.secondary)
            }
        }
        .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func dynamicField(_ field: CustomFormField) -> some View {
        switch field.type {
        case .shortAnswer:
            TextField("উত্তর লিখুন", text: binding(field.id))
        case .paragraph:
            TextField("উত্তর লিখুন", text: binding(field.id), axis: .vertical).lineLimit(3...8)
        case .multipleChoice, .dropdown:
            Picker(field.label, selection: binding(field.id)) {
                Text("বেছে নিন").tag("")
                ForEach(field.options ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        case .checkboxes:
            ForEach(field.options ?? [], id: \.self) { option in
                let isSelected = viewModel.choiceValues[field.id]?.contains(option) ?? false
                Button {
                    var set = viewModel.choiceValues[field.id] ?? []
                    if isSelected { set.remove(option) } else { set.insert(option) }
                    viewModel.choiceValues[field.id] = set
                } label: {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        Text(option)
                    }
                }
                .foregroundStyle(.primary)
            }
        case .fileUpload:
            FormFilePickerRow(fieldId: field.id, fileValues: $viewModel.fileValues)
        }
    }

    private func binding(_ fieldId: String) -> Binding<String> {
        Binding(get: { viewModel.textValues[fieldId] ?? "" }, set: { viewModel.textValues[fieldId] = $0 })
    }
}

private struct FormFilePickerRow: View {
    let fieldId: String
    @Binding var fileValues: [String: URL]
    @State private var showImporter = false

    var body: some View {
        HStack {
            Text(fileValues[fieldId] != nil ? "ফাইল বেছে নেওয়া হয়েছে ✅" : "PDF/DOC/ছবি বেছে নিন (সর্বোচ্চ ১০MB)")
                .font(.caption)
            Spacer()
            Button { showImporter = true } label: { Image(systemName: "paperclip") }
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [.pdf, .image, UTType(filenameExtension: "doc") ?? .data, UTType(filenameExtension: "docx") ?? .data]
                ) { result in
                    // zip: mimes:pdf,doc,docx,jpg,jpeg,png,webp | max:10240KB (10MB)
                    if case .success(let url) = result {
                        _ = url.startAccessingSecurityScopedResource()
                        fileValues[fieldId] = url
                    }
                }
        }
    }
}
