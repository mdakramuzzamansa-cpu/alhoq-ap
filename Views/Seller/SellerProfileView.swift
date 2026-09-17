import SwiftUI

struct SellerProfileView: View {
    @StateObject private var viewModel: SellerProfileViewModel
    @State private var showHandshakeSheet = false
    @State private var openConversationId: Int?

    init(userId: Int) {
        _viewModel = StateObject(wrappedValue: SellerProfileViewModel(userId: userId))
    }

    var body: some View {
        ScrollView {
            if let profile = viewModel.profile {
                VStack(alignment: .leading, spacing: 16) {
                    header(profile)
                    trustBadges(profile)
                    actionButtons(profile)
                    listingsSection(profile)
                    postsSection(profile)
                }
                .padding()
            } else if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).padding()
            }
        }
        .navigationTitle(viewModel.profile?.user.name ?? "প্রোফাইল")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .sheet(isPresented: $showHandshakeSheet) {
            if let profile = viewModel.profile {
                SendHandshakeSheet(userId: profile.user.id, userName: profile.user.name)
            }
        }
        .navigationDestination(item: $openConversationId) { id in ChatThreadView(conversationId: id) }
    }

    private func header(_ profile: SellerProfile) -> some View {
        VStack(spacing: 8) {
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 88, height: 88)
                .overlay(Text(profile.user.name.prefix(1)).font(.title))
            Text(profile.user.name).font(.title3.bold())
            if let handle = profile.user.handle { Text(handle).foregroundStyle(.secondary) }
            if let bio = profile.user.bio, !bio.isEmpty { Text(bio).multilineTextAlignment(.center) }
            Text("সদস্য: \(profile.memberSince) ধরে").font(.caption).foregroundStyle(.secondary)
            Text("\(profile.totalListings)টা প্রকাশিত লিস্টিং").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func trustBadges(_ profile: SellerProfile) -> some View {
        if !profile.trustedBadges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(profile.trustedBadges) { badge in
                        Label(badge.category.name, systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func actionButtons(_ profile: SellerProfile) -> some View {
        HStack {
            Button {
                Task { openConversationId = try? await ChatAPI().startWithUser(userId: profile.user.id) }
            } label: {
                Label("মেসেজ", systemImage: "message")
            }
            .buttonStyle(.borderedProminent)

            Button { showHandshakeSheet = true } label: {
                Text("🤝 Handshake")
            }
            .buttonStyle(.bordered)
        }
    }

    private func listingsSection(_ profile: SellerProfile) -> some View {
        VStack(alignment: .leading) {
            Text("লিস্টিং").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(profile.listings) { listing in
                    NavigationLink {
                        ListingDetailView(slug: listing.slug)
                    } label: {
                        ListingCardView(listing: listing)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func postsSection(_ profile: SellerProfile) -> some View {
        if !profile.posts.isEmpty {
            VStack(alignment: .leading) {
                Text("পোস্ট").font(.headline)
                ForEach(profile.posts) { post in
                    if let body = post.body {
                        Text(body).font(.caption).padding(8)
                            .background(Color.gray.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
