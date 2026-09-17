import SwiftUI

struct FormBuilderView: View {
    @StateObject private var viewModel: FormBuilderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddField = false

    init(listingId: Int) {
        _viewModel = StateObject(wrappedValue: FormBuilderViewModel(listingId: listingId))
    }

    var body: some View {
        Form {
            Section("ফর্মের তথ্য") {
                TextField("ফর্মের শিরোনাম", text: $viewModel.formTitle)
                TextField("বাটনের লেখা (যেমন: Apply Now)", text: $viewModel.buttonLabel)
                TextField("বিবরণ (ঐচ্ছিক)", text: $viewModel.description, axis: .vertical)
            }

            Section("প্রশ্ন") {
                ForEach(Array(viewModel.fields.enumerated()), id: \.element.id) { index, field in
                    fieldEditor(index: index)
                }
                .onDelete { viewModel.removeField(at: $0) }
                .onMove { viewModel.moveField(from: $0, to: $1) }

                Menu {
                    ForEach(CustomFieldType.allCases, id: \.self) { type in
                        Button(type.label) { viewModel.addField(type: type) }
                    }
                } label: {
                    Label("প্রশ্ন যোগ করুন", systemImage: "plus")
                }
            }

            if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }

            Button {
                Task { await viewModel.save(); if viewModel.didSave { dismiss() } }
            } label: {
                if viewModel.isSaving { ProgressView().frame(maxWidth: .infinity) } else { Text("সেভ করুন").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSaving)

            if !viewModel.fields.isEmpty {
                Button("ফর্ম মুছে ফেলুন", role: .destructive) {
                    Task { await viewModel.deleteForm(); dismiss() }
                }
            }
        }
        .navigationTitle("Apply Form বানান")
        .toolbar { EditButton() }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func fieldEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.fields[index].type.label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("আবশ্যক", isOn: Binding(
                    get: { viewModel.fields[index].required },
                    set: { viewModel.fields[index].required = $0 }
                ))
                .labelsHidden()
                Text("আবশ্যক").font(.caption2)
            }
            TextField("প্রশ্নের লেবেল", text: Binding(
                get: { viewModel.fields[index].label },
                set: { viewModel.fields[index].label = $0 }
            ))

            if viewModel.fields[index].type.isChoiceType {
                let options = viewModel.fields[index].options ?? []
                ForEach(options.indices, id: \.self) { optIndex in
                    HStack {
                        TextField("অপশন \(optIndex + 1)", text: Binding(
                            get: { viewModel.fields[index].options?[optIndex] ?? "" },
                            set: { viewModel.fields[index].options?[optIndex] = $0 }
                        ))
                        if options.count > 1 {
                            Button(role: .destructive) {
                                viewModel.fields[index].options?.remove(at: optIndex)
                            } label: { Image(systemName: "xmark.circle") }
                        }
                    }
                }
                Button("অপশন যোগ করুন") {
                    if viewModel.fields[index].options == nil { viewModel.fields[index].options = [] }
                    viewModel.fields[index].options?.append("")
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
