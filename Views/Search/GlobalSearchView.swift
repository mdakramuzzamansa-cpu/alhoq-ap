import SwiftUI

struct GlobalSearchView: View {
    @StateObject private var viewModel = GlobalSearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $viewModel.type) {
                    ForEach(GlobalSearchType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: viewModel.type) { _, _ in viewModel.typeChanged() }

                if !viewModel.suggestions.isEmpty {
                    suggestionsList
                } else {
                    resultsList
                }
            }
            .searchable(text: $viewModel.query, prompt: "নাম, @username, ফোন নম্বর দিয়ে খুঁজুন")
            .onChange(of: viewModel.query) { _, _ in viewModel.queryChanged() }
            .onSubmit(of: .search) { viewModel.submitSearch() }
            .navigationTitle("খুঁজুন")
        }
    }

    private var suggestionsList: some View {
        List(viewModel.suggestions) { suggestion in
            Button {
                // zip: UsernameSuggestion-এ কোনো numeric user id নেই, শুধু username/url —
                // তাই SellerProfileView(userId:)-এ সরাসরি না গিয়ে ইতিমধ্যে বানানো deep-link
                // router (Phase 16) দিয়েই খোলা হচ্ছে, যেটা web URL থেকে সঠিক স্ক্রিন বের করে
                if let url = suggestion.url {
                    DeepLinkRouter.shared.pendingURL = url
                }
            } label: {
                HStack {
                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 36, height: 36)
                    VStack(alignment: .leading) {
                        Text(suggestion.name).font(.subheadline.bold())
                        if let handle = suggestion.handle { Text(handle).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let response = viewModel.response {
            if let usernameUser = response.usernameUser {
                usernameModeView(usernameUser, posts: response.usernamePosts ?? [])
            } else {
                ScrollView {
                    switch viewModel.type {
                    case .user:
                        userResults(response.users ?? [])
                    case .ads:
                        adResults(response.ads ?? [])
                    case .video:
                        videoResults(response.videos ?? [])
                    }
                }
            }
        } else if let error = viewModel.errorMessage {
            Text(error).foregroundStyle(.red).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("খুঁজতে টাইপ করুন").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// zip: @username সরাসরি মিললে (অথবা exact handle) — জেনারিক লিস্টের বদলে প্রোফাইল কার্ড + recent posts
    private func usernameModeView(_ user: ListingPoster, posts: [FeedPost]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                SellerProfileView(userId: user.id)
            } label: {
                HStack {
                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 56, height: 56)
                    VStack(alignment: .leading) {
                        HStack {
                            Text(user.name).font(.headline)
                            if user.isTrusted == true { Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue).font(.caption) }
                        }
                        if let username = user.username { Text("@\(username)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .foregroundStyle(.primary)

            if !posts.isEmpty {
                Text("সাম্প্রতিক পোস্ট").font(.subheadline.bold())
                ForEach(posts) { post in
                    if let body = post.body {
                        Text(body).font(.caption).padding(8).background(Color.gray.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
    }

    private func userResults(_ users: [ListingPoster]) -> some View {
        LazyVStack {
            ForEach(users, id: \.id) { user in
                NavigationLink {
                    SellerProfileView(userId: user.id)
                } label: {
                    HStack {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 44, height: 44)
                        VStack(alignment: .leading) {
                            HStack {
                                Text(user.name).font(.subheadline.bold())
                                if user.isTrusted == true { Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue).font(.caption2) }
                            }
                            if let username = user.username { Text("@\(username)").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .foregroundStyle(.primary)
            }
        }
        .overlay { if users.isEmpty { Text("কোনো ফলাফল নেই").foregroundStyle(.secondary).padding(.top, 40) } }
    }

    private func adResults(_ ads: [Listing]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(ads) { listing in
                NavigationLink { ListingDetailView(slug: listing.slug) } label: { ListingCardView(listing: listing) }
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .overlay { if ads.isEmpty { Text("কোনো বিজ্ঞাপন নেই").foregroundStyle(.secondary).padding(.top, 40) } }
    }

    private func videoResults(_ videos: [FeedPost]) -> some View {
        LazyVStack {
            ForEach(videos) { post in
                VStack(alignment: .leading) {
                    Text(post.user.name).font(.caption.bold())
                    if let body = post.body { Text(body).font(.caption) }
                }
                .padding(.horizontal)
            }
        }
        .overlay { if videos.isEmpty { Text("কোনো ভিডিও নেই").foregroundStyle(.secondary).padding(.top, 40) } }
    }
}
