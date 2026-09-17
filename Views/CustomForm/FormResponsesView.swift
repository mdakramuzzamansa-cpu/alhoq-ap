import SwiftUI

struct FormResponsesView: View {
    @StateObject private var viewModel: FormResponsesViewModel
    @State private var tab = 0
    @State private var shareURL: URL?

    init(listingId: Int) {
        _viewModel = StateObject(wrappedValue: FormResponsesViewModel(listingId: listingId))
    }

    var body: some View {
        VStack {
            Picker("", selection: $tab) {
                Text("অ্যানালিটিক্স").tag(0)
                Text("রেসপন্স").tag(1)
            }
            .pickerStyle(.segmented).padding()

            if let dashboard = viewModel.dashboard {
                if tab == 0 {
                    analyticsView(dashboard)
                } else {
                    responsesView(dashboard)
                }
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .navigationTitle("রেসপন্স")
        .task { await viewModel.load() }
        .sheet(item: Binding(get: { shareURL.map { ShareItem(url: $0) } }, set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func analyticsView(_ dashboard: FormResponsesDashboard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("মোট রেসপন্স: \(dashboard.responses.count)").font(.headline)
                ForEach(dashboard.form.fields) { field in
                    if let analytics = dashboard.analytics[field.id] {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(analytics.label).font(.subheadline.bold())
                            if let counts = analytics.counts {
                                ForEach(counts.sorted(by: { $0.key < $1.key }), id: \.key) { option, count in
                                    HStack {
                                        Text(option).font(.caption)
                                        Spacer()
                                        Text("\(count)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            } else if let answered = analytics.answeredCount {
                                Text("\(answered) জন উত্তর দিয়েছেন").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
        }
    }

    private func responsesView(_ dashboard: FormResponsesDashboard) -> some View {
        List {
            ForEach(dashboard.responses) { response in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(response.respondentName ?? "Guest").font(.subheadline.bold())
                        Spacer()
                        Text(response.createdAt).font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(dashboard.form.fields) { field in
                        if let answer = response.answers[field.id] {
                            answerRow(field: field, answer: answer, responseId: response.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func answerRow(field: CustomFormField, answer: FormAnswerValue, responseId: Int) -> some View {
        switch answer {
        case .text(let text):
            HStack { Text(field.label).font(.caption2).foregroundStyle(.secondary); Spacer(); Text(text).font(.caption) }
        case .choices(let choices):
            HStack { Text(field.label).font(.caption2).foregroundStyle(.secondary); Spacer(); Text(choices.joined(separator: ", ")).font(.caption) }
        case .file(let name, _):
            Button {
                Task {
                    if let url = await viewModel.downloadAttachment(responseId: responseId, fieldId: field.id) {
                        shareURL = url
                    }
                }
            } label: {
                Label(name, systemImage: "doc.badge.arrow.up")
            }
            .font(.caption)
        }
    }
}

private struct ShareItem: Identifiable { let url: URL; var id: String { url.absoluteString } }
