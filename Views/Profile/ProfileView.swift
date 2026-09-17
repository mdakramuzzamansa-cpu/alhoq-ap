import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var viewModel: ProfileViewModel
    @State private var showEdit = false

    init(user: AlhoqUser) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // TODO: cover_photo + avatar আসল URL দিয়ে AsyncImage/Kingfisher বসাতে হবে
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 140)
                        .overlay(Text("Cover Photo").foregroundStyle(.secondary))

                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 88, height: 88)
                    .overlay(Text(viewModel.user.name.prefix(1)).font(.title))

                Text(viewModel.user.name).font(.title3.bold())
                if let handle = viewModel.user.handle {
                    Text(handle).foregroundStyle(.secondary)
                }
                if let bio = viewModel.user.bio, !bio.isEmpty {
                    Text(bio).multilineTextAlignment(.center)
                }

                HStack(spacing: 16) {
                    if let city = viewModel.user.city {
                        Label(city, systemImage: "mappin.and.ellipse")
                    }
                    if let occupation = viewModel.user.occupation {
                        Label(occupation, systemImage: "briefcase")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button("প্রোফাইল এডিট করুন") { showEdit = true }
                    .buttonStyle(.bordered)

                NavigationLink {
                    DashboardView()
                } label: {
                    Label("ড্যাশবোর্ড", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.borderedProminent)

                NavigationLink {
                    SettingsView(user: viewModel.user)
                } label: {
                    Label("সেটিংস", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    KycView(isIdentityVerified: viewModel.user.identityVerifiedAt != nil)
                } label: {
                    Label(
                        viewModel.user.identityVerifiedAt != nil ? "পরিচয় ভেরিফাইড ✅" : "পরিচয় যাচাই করুন (KYC)",
                        systemImage: "checkmark.shield"
                    )
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Label("ব্লক করা ইউজার", systemImage: "person.crop.circle.badge.xmark")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    MyAppointmentsView()
                } label: {
                    Label("আমার বুকিং", systemImage: "calendar")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    ProviderBookingsView()
                } label: {
                    Label("আমার লিস্টিং-এ বুকিং", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    OrdersListView(currentUserId: viewModel.user.id)
                } label: {
                    Label("Direct-Deal অর্ডার", systemImage: "shippingbox")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    EscrowMarketBrowseView()
                } label: {
                    Label("Escrow মার্কেটপ্লেসে কিনুন", systemImage: "cart.badge.plus")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    EscrowOrdersListView(currentUserId: viewModel.user.id)
                } label: {
                    Label("আমার Escrow অর্ডার", systemImage: "shield")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    PackagesView()
                } label: {
                    Label("প্যাকেজ কিনুন", systemImage: "creditcard")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    CallHistoryView()
                } label: {
                    Label("কল হিস্ট্রি", systemImage: "phone.arrow.up.right")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    LiveBrowseView()
                } label: {
                    Label("লাইভ দেখুন", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    RoomListView()
                } label: {
                    Label("প্রাইভেট রুম", systemImage: "lock.rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    AnonymousBoardView()
                } label: {
                    Label("Anonymous বোর্ড", systemImage: "theatermasks")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    HandshakesPanelView()
                } label: {
                    Label("Handshake", systemImage: "hand.raised")
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    AiAssistantView()
                } label: {
                    Label("AI সহকারী", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)

                NavigationLink { StaticPageView(slug: .aboutUs) } label: { Label("আমাদের সম্পর্কে", systemImage: "info.circle") }
                    .buttonStyle(.bordered)
                NavigationLink { StaticPageView(slug: .faq) } label: { Label("সচরাচর জিজ্ঞাসা", systemImage: "questionmark.circle") }
                    .buttonStyle(.bordered)
                NavigationLink { StaticPageView(slug: .privacyPolicy) } label: { Label("প্রাইভেসি পলিসি", systemImage: "hand.raised.square") }
                    .buttonStyle(.bordered)
                NavigationLink { ContactFormView() } label: { Label("যোগাযোগ করুন", systemImage: "envelope") }
                    .buttonStyle(.bordered)

                Button(role: .destructive) {
                    Task { await session.logout() }
                } label: {
                    Text("লগ আউট")
                }
                .padding(.top, 8)
            }
            .padding()
            }
        }
        .sheet(isPresented: $showEdit) {
            ProfileEditView(viewModel: viewModel)
        }
    }
}

private struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("ছবি") {
                    photoField(
                        label: "কভার ফটো",
                        pendingURL: viewModel.pendingCoverURL,
                        isUploading: viewModel.isUploadingCover
                    ) { fileURL in
                        Task { await viewModel.pickedCover(fileURL: fileURL) }
                    }
                    photoField(
                        label: "প্রোফাইল ছবি",
                        pendingURL: viewModel.pendingAvatarURL,
                        isUploading: viewModel.isUploadingAvatar
                    ) { fileURL in
                        Task { await viewModel.pickedAvatar(fileURL: fileURL) }
                    }
                }

                Section("সাধারণ তথ্য") {
                    TextField("নাম", text: $viewModel.form.name)

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("ইউজারনেম (@handle)", text: $viewModel.form.username)
                            .textInputAutocapitalization(.never)
                            .onChange(of: viewModel.form.username) { _, newValue in
                                viewModel.usernameChanged(newValue)
                            }
                        usernameStatusLabel
                    }

                    TextField("ইমেইল", text: $viewModel.form.email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField("ফোন নম্বর", text: $viewModel.form.phone)
                        .keyboardType(.phonePad)
                    Text("ইমেইল অথবা ফোন — অন্তত একটা থাকতে হবে।")
                        .font(.caption2).foregroundStyle(.secondary)

                    Picker("অ্যাকাউন্টের ধরন", selection: $viewModel.form.accountType) {
                        Text("ব্যক্তিগত").tag(AlhoqUser.AccountType.personal)
                        Text("ব্যবসায়িক").tag(AlhoqUser.AccountType.business)
                    }
                    .pickerStyle(.segmented)
                    if viewModel.form.accountType == .business {
                        TextField("প্রতিষ্ঠানের নাম", text: $viewModel.form.companyName)
                    }

                    TextField("বায়ো", text: $viewModel.form.bio, axis: .vertical)
                    TextField("পেশা", text: $viewModel.form.occupation)
                }

                Section("যোগাযোগ") {
                    TextField("ঠিকানা", text: $viewModel.form.address)
                    TextField("ওয়েবসাইট", text: $viewModel.form.website)
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let success = viewModel.successMessage {
                    Text(success).foregroundStyle(.green)
                }

                Button {
                    Task {
                        await viewModel.save()
                        if viewModel.errorMessage == nil { dismiss() }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("সেভ করুন").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving || viewModel.usernameStatus == .taken)
            }
            .navigationTitle("প্রোফাইল এডিট")
            .toolbar {
                cancelToolbarItem("বাতিল") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func photoField(
        label: String, pendingURL: URL?, isUploading: Bool, onPicked: @escaping (URL) -> Void
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            if isUploading {
                ProgressView()
            } else if pendingURL != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            PhotosPicker(selection: Binding(
                get: { nil },
                set: { (item: PhotosPickerItem?) in
                    guard let item else { return }
                    Task {
                        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                        // PhotosPicker থেকে সরাসরি Data আসে, কিন্তু MediaUploader ফাইল থেকে পড়ে
                        // (multipart এর জন্য), তাই একটা temp ফাইলে লিখে সেটার URL পাঠানো হচ্ছে।
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".jpg")
                        try? data.write(to: tempURL)
                        onPicked(tempURL)
                    }
                }
            ), matching: .images) {
                Text("বেছে নিন")
            }
        }
    }

    @ViewBuilder
    private var usernameStatusLabel: some View {
        switch viewModel.usernameStatus {
        case .idle: EmptyView()
        case .checking:
            Text("যাচাই করা হচ্ছে…").font(.caption2).foregroundStyle(.secondary)
        case .available:
            Text("এই ইউজারনেম পাওয়া যাচ্ছে ✅").font(.caption2).foregroundStyle(.green)
        case .taken:
            Text("এই ইউজারনেম আগে থেকেই ব্যবহৃত ❌").font(.caption2).foregroundStyle(.red)
        }
    }
}
