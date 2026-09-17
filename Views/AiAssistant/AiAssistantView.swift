import SwiftUI

struct AiAssistantView: View {
    @StateObject private var viewModel = AiAssistantViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if viewModel.messages.isEmpty {
                            Text(viewModel.lang == "en" ? "Hello! How can I help you?" : "হ্যালো স্যার, কী সাহায্য করতে পারি?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                        }
                        ForEach(viewModel.messages) { message in
                            bubble(message)
                                .id(message.id)
                        }
                        if viewModel.isSending {
                            HStack { ProgressView(); Text("লিখছে…").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            composer
        }
        .navigationTitle("AI সহকারী")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            languageToolbarItem
        }
    }

    @ToolbarContentBuilder
    private var languageToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Picker("ভাষা", selection: $viewModel.lang) {
                Text("বাং").tag("bn")
                Text("EN").tag("en")
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
    }

    private func bubble(_ message: AiMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }
            Text(message.text)
                .padding(10)
                .background(message.role == "user" ? Color.accentColor : Color.gray.opacity(0.15))
                .foregroundStyle(message.role == "user" ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if message.role == "model" { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack {
            Button {
                viewModel.toggleRecording()
            } label: {
                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                    .foregroundStyle(viewModel.isRecording ? .red : .primary)
            }
            TextField(viewModel.lang == "en" ? "Type a message…" : "মেসেজ লিখুন…", text: $viewModel.inputText)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await viewModel.sendText() }
            } label: { Image(systemName: "paperplane.fill") }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
        }
        .padding()
        .background(.thinMaterial)
    }
}
