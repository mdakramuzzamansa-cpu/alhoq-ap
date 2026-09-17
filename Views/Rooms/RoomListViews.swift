import SwiftUI

struct RoomListView: View {
    @StateObject private var viewModel = RoomListViewModel()
    @State private var showCreate = false
    @State private var showSearch = false
    @State private var showJoinByToken = false

    var body: some View {
        List {
            Section("আমার তৈরি করা রুম") {
                ForEach(viewModel.created) { room in
                    NavigationLink(room.name) { RoomThreadView(token: room.token) }
                }
            }
            Section("জয়েন করা রুম") {
                ForEach(viewModel.joined) { room in
                    NavigationLink(room.name) { RoomThreadView(token: room.token) }
                }
            }
        }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .navigationTitle("প্রাইভেট রুম")
        .toolbar {
            toolbarItemGroup(placement: .topBarTrailing) {
                Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                Button { showCreate = true } label: { Image(systemName: "plus") }
                Button { showJoinByToken = true } label: { Image(systemName: "link") }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await viewModel.load() } }) { RoomCreateView() }
        .sheet(isPresented: $showSearch) { RoomSearchView() }
        .sheet(isPresented: $showJoinByToken) { JoinByTokenView() }
    }
}

struct RoomCreateView: View {
    @StateObject private var viewModel = RoomCreateViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let created = viewModel.createdRoom {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
                    Text("রুম তৈরি হয়েছে!").font(.title3.bold())
                    if let pin = created.plainPin {
                        VStack {
                            Text("PIN — এটা শুধু একবারই দেখানো হবে").font(.caption).foregroundStyle(.secondary)
                            Text(pin).font(.system(size: 32, weight: .bold, design: .monospaced))
                        }
                        .padding().background(Color.gray.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button("রুমে যান") { dismiss() }.buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                Form {
                    TextField("রুমের নাম", text: $viewModel.name)
                    if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                    Button {
                        Task { await viewModel.create() }
                    } label: {
                        if viewModel.isCreating { ProgressView().frame(maxWidth: .infinity) } else { Text("তৈরি করুন").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .navigationTitle("নতুন রুম")
                .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
            }
        }
    }
}

struct RoomSearchView: View {
    @StateObject private var viewModel = RoomSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.results) { room in
                VStack(alignment: .leading) {
                    Text(room.name).font(.subheadline.bold())
                    Button("জয়েনের অনুরোধ পাঠান") { Task { await viewModel.requestToJoin(room) } }
                        .font(.caption)
                }
            }
            .searchable(text: $viewModel.query, prompt: "রুমের নাম/হ্যান্ডেল দিয়ে খুঁজুন")
            .onChange(of: viewModel.query) { _, _ in viewModel.queryChanged() }
            .navigationTitle("রুম খুঁজুন")
            .toolbar { cancelToolbarItem("বন্ধ করুন") { dismiss() } }
        }
    }
}

/// শেয়ার করা রুম লিংক থেকে token বের করে PIN এন্ট্রি স্ক্রিনে নিয়ে যায়
struct JoinByTokenView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tokenText = ""
    @State private var navigateToken: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("রুম লিংক অথবা টোকেন পেস্ট করুন", text: $tokenText)
                    .textInputAutocapitalization(.never)
                Button("জয়েন করুন") {
                    // লিংক হলে শেষ path component-টাই token
                    navigateToken = tokenText.split(separator: "/").last.map(String.init) ?? tokenText
                }
                .buttonStyle(.borderedProminent)
                .disabled(tokenText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("লিংক দিয়ে জয়েন")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
            .navigationDestination(item: $navigateToken) { token in
                RoomJoinView(token: token)
            }
        }
    }
}
