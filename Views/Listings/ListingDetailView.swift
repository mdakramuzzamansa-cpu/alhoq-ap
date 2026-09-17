import SwiftUI

struct ListingDetailView: View {
    @StateObject private var viewModel: ListingDetailViewModel
    @State private var showReportSheet = false
    @State private var openConversationId: Int?
    @State private var isStartingChat = false
    @State private var showBookingSheet = false
    @State private var showOrderSheet = false
    @State private var showReviewSheet = false
    @State private var showHandshakeSheet = false
    @State private var showApplyFormSheet = false

    init(slug: String) {
        _viewModel = StateObject(wrappedValue: ListingDetailViewModel(slug: slug))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            } else if let listing = viewModel.listing {
                VStack(alignment: .leading, spacing: 16) {
                    imageCarousel(listing)

                    Text(listing.title).font(.title2.bold())

                    priceRow(listing)

                    if let location = listing.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                    }

                    sellerCard(listing)

                    if let description = listing.description {
                        Text(description)
                    }

                    // Section 5.4: booking / direct order / custom-form application —
                    // Phase 6/7/9/22-এ পূর্ণাঙ্গ ফ্লো হিসেবে বসবে, এখানে entry point
                    actionButtons(listing)

                    reviewsSummary

                    if !viewModel.relatedListings.isEmpty {
                        relatedSection
                    }
                }
                .padding()
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).padding()
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showBookingSheet) {
            if let listing = viewModel.listing {
                BookingCreateView(listing: listing)
            }
        }
        .sheet(isPresented: $showOrderSheet) {
            if let listing = viewModel.listing {
                OrderCreateView(listing: listing)
            }
        }
        .sheet(isPresented: $showReviewSheet, onDismiss: { Task { await viewModel.load() } }) {
            if let listing = viewModel.listing {
                ReviewSubmitView(listingId: listing.id)
            }
        }
        .sheet(isPresented: $showApplyFormSheet) {
            if let listing = viewModel.listing {
                FormFillView(listingId: listing.id)
            }
        }
        .toolbar {
            toolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("শেয়ার করুন", systemImage: "square.and.arrow.up") { /* Phase 19: Engagement */ }
                    Button("রিপোর্ট করুন", systemImage: "flag", role: .destructive) { showReportSheet = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func imageCarousel(_ listing: Listing) -> some View {
        TabView {
            ForEach(listing.images) { image in
                // TODO: AsyncImage(url: URL(string: image.path))
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
            }
        }
        .tabViewStyle(.page)
        .frame(height: 260)
    }

    private func priceRow(_ listing: Listing) -> some View {
        HStack {
            switch listing.priceType {
            case .fixed:
                if let price = listing.price {
                    Text("৳\(Int(price))").font(.title3.bold()).foregroundStyle(.green)
                }
            case .negotiable: Text("আলোচনা সাপেক্ষ").foregroundStyle(.orange)
            case .free: Text("ফ্রি").foregroundStyle(.green)
            case .onRequest: Text("জিজ্ঞাসা করুন").foregroundStyle(.secondary)
            }
            Spacer()
            Label("\(listing.views)", systemImage: "eye")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sellerCard(_ listing: Listing) -> some View {
        HStack {
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 44, height: 44)
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(listing.posterDisplayName).font(.subheadline.bold())
                    if listing.user?.isTrusted == true {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue).font(.caption)
                    }
                }
                if listing.canShowPosterProfile, let user = listing.user {
                    NavigationLink {
                        SellerProfileView(userId: user.id)
                    } label: {
                        Text("প্রোফাইল দেখুন").font(.caption).foregroundStyle(.accentColor)
                    }
                }
            }
            Spacer()
            if !listing.isAnonymous {
                Button {
                    Task {
                        isStartingChat = true
                        defer { isStartingChat = false }
                        // web ChatController@startWithListing — একই listing-এ আগের থ্রেড থাকলে সেটাই খোলে
                        openConversationId = try? await ChatAPI().startWithListing(listingId: listing.id)
                    }
                } label: {
                    if isStartingChat { ProgressView() } else { Image(systemName: "message") }
                }
                Button { showHandshakeSheet = true } label: {
                    Text("🤝")
                }
            }
        }
        .sheet(isPresented: $showHandshakeSheet) {
            if let user = listing.user {
                SendHandshakeSheet(userId: user.id, userName: user.name)
            }
        }
        .background(
            NavigationLink(isActive: Binding(get: { openConversationId != nil }, set: { if !$0 { openConversationId = nil } })) {
                if let id = openConversationId { ChatThreadView(conversationId: id) }
            } label: { EmptyView() }
        )
        .padding()
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func actionButtons(_ listing: Listing) -> some View {
        VStack(spacing: 8) {
            if listing.requiresPayment {
                Button("অর্ডার করুন") { showOrderSheet = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            // canBeBooked সার্ভার-নির্ধারিত — category.isBookable + listing এর availabilitySlots থাকলে দেখাবে
            Button("বুকিং করুন") { showBookingSheet = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            Button("আবেদন করুন (Apply Now)") { showApplyFormSheet = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }

    private var reviewsSummary: some View {
        HStack {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
            Text(String(format: "%.1f", viewModel.averageRating))
            Text("(\(viewModel.reviewCount) রিভিউ)").foregroundStyle(.secondary)
            Spacer()
            if !viewModel.userHasReviewed {
                Button("রিভিউ দিন") { showReviewSheet = true }
            }
        }
        .font(.subheadline)
    }

    private var relatedSection: some View {
        VStack(alignment: .leading) {
            Text("সম্পর্কিত বিজ্ঞাপন").font(.headline)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.relatedListings) { related in
                        ListingCardView(listing: related).frame(width: 140)
                    }
                }
            }
        }
    }
}
