import SwiftUI

struct RoomParticipantsSheet: View {
    let token: String
    let initialRoom: PrivateRoom?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var participantsVM: RoomParticipantsViewModel
    @StateObject private var requestsVM: RoomJoinRequestsViewModel
    @State private var tab = 0

    init(token: String, initialRoom: PrivateRoom? = nil) {
        self.token = token
        self.initialRoom = initialRoom
        _participantsVM = StateObject(wrappedValue: RoomParticipantsViewModel(token: token))
        _requestsVM = StateObject(wrappedValue: RoomJoinRequestsViewModel(token: token))
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $tab) {
                    Text("সদস্য").tag(0)
                    if participantsVM.isAdmin {
                        Text("অনুরোধ").tag(1)
                        Text("সেটিংস").tag(2)
                    }
                }
                .pickerStyle(.segmented).padding()

                switch tab {
                case 0: membersList
                case 1: requestsList
                default: RoomSettingsPanel(token: token, initialRoom: initialRoom)
                }
            }
            .navigationTitle("রুম ম্যানেজমেন্ট")
            .toolbar { cancelToolbarItem("বন্ধ করুন") { dismiss() } }
            .task {
                await participantsVM.load()
                if participantsVM.isAdmin { await requestsVM.load() }
            }
        }
    }

    private var membersList: some View {
        List {
            Text("অ্যাডমিন সিট: \(participantsVM.adminSeatsUsed)/\(participantsVM.adminSeatsMax)")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(participantsVM.participants) { p in
                HStack {
                    VStack(alignment: .leading) {
                        Text(p.name).font(.subheadline.bold())
                        Text(p.role.label).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if p.isBlocked {
                        Text("ব্লকড").font(.caption2).foregroundStyle(.red)
                    }
                    if participantsVM.isAdmin && p.role != .owner {
                        Menu {
                            if p.role == .member {
                                Button("অ্যাডমিন বানান") { Task { await participantsVM.promote(p) } }
                            } else {
                                Button("অ্যাডমিন সরান") { Task { await participantsVM.demote(p) } }
                            }
                            if p.isBlocked {
                                Button("আনব্লক করুন") { Task { await participantsVM.unblock(p) } }
                            } else {
                                Button("ব্লক করুন") { Task { await participantsVM.block(p) } }
                            }
                            Button("রুম থেকে বের করুন", role: .destructive) { Task { await participantsVM.kick(p) } }
                        } label: { Image(systemName: "ellipsis") }
                    }
                }
            }
        }
    }

    private var requestsList: some View {
        List(requestsVM.requests) { request in
            HStack {
                VStack(alignment: .leading) {
                    Text(request.name).font(.subheadline.bold())
                    Text(request.requestedAt).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("গ্রহণ") { Task { await requestsVM.accept(request) } }.buttonStyle(.borderedProminent)
                Button("প্রত্যাখ্যান") { Task { await requestsVM.reject(request) } }.buttonStyle(.bordered)
            }
        }
        .overlay { if requestsVM.requests.isEmpty { Text("কোনো অনুরোধ নেই").foregroundStyle(.secondary) } }
    }
}

private struct RoomSettingsPanel: View {
    let token: String
    let initialRoom: PrivateRoom?
    @State private var hideMemberList: Bool
    @State private var showHistory: Bool
    private let api: RoomAPIProtocol = RoomAPI()

    init(token: String, initialRoom: PrivateRoom?) {
        self.token = token
        self.initialRoom = initialRoom
        _hideMemberList = State(initialValue: initialRoom?.hideMemberList ?? false)
        _showHistory = State(initialValue: initialRoom?.showHistoryToNewMembers ?? true)
    }

    var body: some View {
        Form {
            Toggle("সদস্য তালিকা লুকান (সাধারণ সদস্যদের থেকে)", isOn: $hideMemberList)
                .onChange(of: hideMemberList) { _, value in
                    Task { try? await api.updateSettings(token: token, RoomSettingsUpdate(hideMemberList: value)) }
                }
            Toggle("নতুন সদস্যদের পুরনো মেসেজ দেখাও", isOn: $showHistory)
                .onChange(of: showHistory) { _, value in
                    Task { try? await api.updateSettings(token: token, RoomSettingsUpdate(showHistoryToNewMembers: value)) }
                }
        }
    }
}
