import SwiftUI

struct SectionBrowseView: View {
    @State private var currentSection: AppSection

    init(initialSection: AppSection = .services) {
        _currentSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("সেকশন", selection: $currentSection) {
                ForEach(AppSection.allCases, id: \.self) { section in
                    Text(section.label).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // zip: "Strict scope isolation" — section বদলালে সম্পূর্ণ নতুন query,
            // আগের section-এর কোনো data mix হয় না, তাই id দিয়ে view সম্পূর্ণ রিফ্রেশ করা হচ্ছে
            SectionContentView(section: currentSection)
                .id(currentSection)
        }
        .navigationTitle("সেকশন")
    }
}

private struct SectionContentView: View {
    @StateObject private var viewModel: SectionBrowseViewModel
    @State private var selectedListing: Listing?

    init(section: AppSection) {
        _viewModel = StateObject(wrappedValue: SectionBrowseViewModel(section: section))
    }

    var body: some View {
        ScrollView {
            categoryChips

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.filteredListings) { listing in
                    ListingCardView(listing: listing)
                        .onTapGesture { selectedListing = listing }
                        .task {
                            if listing.id == viewModel.filteredListings.last?.id {
                                await viewModel.loadMore()
                            }
                        }
                }
            }
            .padding(.horizontal)

            if viewModel.isLoadingMore { ProgressView().padding() }
        }
        .searchable(text: $viewModel.searchText, prompt: "এই সেকশনে খুঁজুন")
        .onSubmit(of: .search) { Task { await viewModel.load() } }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.filteredListings.isEmpty {
                Text("কোনো লিস্টিং নেই").foregroundStyle(.secondary)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .navigationDestination(item: $selectedListing) { listing in
            ListingDetailView(slug: listing.slug)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip(title: "সব", count: nil, isSelected: viewModel.selectedCategorySlug == nil) {
                    viewModel.selectedCategorySlug = nil
                }
                ForEach(viewModel.categories) { item in
                    chip(
                        title: item.category.name, count: item.listingsCount,
                        isSelected: viewModel.selectedCategorySlug == item.category.slug
                    ) {
                        viewModel.selectedCategorySlug = item.category.slug
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(title: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let count { Text("(\(count))").font(.caption2) }
            }
            .font(.caption)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

/// zip: root PostController@show — Share বাটনের পার্মালিংক টার্গেট, DeepLinkRouter-এ
/// "posts/{id}" প্যাটার্নে ম্যাপ করা যাবে (এই টার্নে যোগ করা হয়েছে)
struct PostDetailView: View {
    let currentUserId: Int
    @StateObject private var viewModel: PostDetailViewModel

    init(postId: Int, currentUserId: Int) {
        self.currentUserId = currentUserId
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(postId: postId))
    }

    var body: some View {
        ScrollView {
            if let post = viewModel.post {
                FeedCardView(item: .post(post), currentUserId: currentUserId, onDeletePost: { _ in })
                    .padding()
            } else if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).padding()
            }
        }
        .navigationTitle("পোস্ট")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
