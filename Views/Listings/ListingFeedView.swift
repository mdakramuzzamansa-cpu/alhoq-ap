import SwiftUI

struct ListingFeedView: View {
    @StateObject private var viewModel = ListingFeedViewModel()
    @State private var showFilterSheet = false
    @State private var showGlobalSearch = false
    @State private var selectedListing: Listing?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("লিস্টিং")
                .toolbar {
                    toolbarItemGroup(placement: .topBarTrailing) {
                        Button { showGlobalSearch = true } label: { Image(systemName: "magnifyingglass") }
                        Button {
                            showFilterSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .task { await viewModel.loadInitial() }
                .sheet(isPresented: $showFilterSheet) {
                    ListingFilterSheet(viewModel: viewModel)
                }
                .sheet(isPresented: $showGlobalSearch) {
                    GlobalSearchView()
                }
                .navigationDestination(item: $selectedListing) { listing in
                    ListingDetailView(slug: listing.slug)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingInitial {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isEmpty {
            emptyState
        } else {
            listGrid
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("কোনো লিস্টিং পাওয়া যায়নি")
                .foregroundStyle(.secondary)
            if viewModel.filter.categorySlug != nil || viewModel.filter.search != nil {
                Button("ফিল্টার রিসেট করুন") {
                    Task { await viewModel.resetFilter() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var listGrid: some View {
        ScrollView {
            // Section 5.2: category chips
            categoryChips

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.listings) { listing in
                    ListingCardView(listing: listing)
                        .onTapGesture { selectedListing = listing }
                        .task {
                            await viewModel.loadMoreIfNeeded(currentItem: listing)
                        }
                }
            }
            .padding(.horizontal)

            if viewModel.isLoadingMore {
                ProgressView().padding()
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).padding()
            }
        }
        .refreshable { await viewModel.refresh() }   // Section 5.1: pull-to-refresh
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip(title: "সব", isSelected: viewModel.filter.categorySlug == nil) {
                    viewModel.filter.categorySlug = nil
                    Task { await viewModel.applyFilter() }
                }
                ForEach(viewModel.categories) { category in
                    chip(title: category.name, isSelected: viewModel.filter.categorySlug == category.slug) {
                        viewModel.filter.categorySlug = category.slug
                        Task { await viewModel.applyFilter() }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct ListingCardView: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // TODO: AsyncImage/Kingfisher দিয়ে listing.images.first?.path বসাতে হবে
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.15))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    listing.isFeatured ?
                    AnyView(Text("Featured").font(.caption2).padding(4).background(.yellow).clipShape(Capsule()).padding(6)) : AnyView(EmptyView()),
                    alignment: .topLeading
                )

            Text(listing.title)
                .font(.subheadline.bold())
                .lineLimit(2)

            priceText

            if let location = listing.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text(listing.posterDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if listing.user?.isTrusted == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private var priceText: some View {
        Group {
            switch listing.priceType {
            case .fixed:
                if let price = listing.price {
                    Text("৳\(Int(price))").font(.subheadline.bold()).foregroundStyle(.green)
                }
            case .negotiable:
                Text("আলোচনা সাপেক্ষ").font(.caption).foregroundStyle(.orange)
            case .free:
                Text("ফ্রি").font(.caption).foregroundStyle(.green)
            case .onRequest:
                Text("জিজ্ঞাসা করুন").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ListingFilterSheet: View {
    @ObservedObject var viewModel: ListingFeedViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var minPrice: String = ""
    @State private var maxPrice: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("খুঁজুন") {
                    TextField("কীওয়ার্ড", text: $searchText)
                }
                Section("মূল্য পরিসর") {
                    TextField("সর্বনিম্ন", text: $minPrice).keyboardType(.numberPad)
                    TextField("সর্বোচ্চ", text: $maxPrice).keyboardType(.numberPad)
                }
                Section("সাজান") {
                    Picker("সাজান", selection: $viewModel.filter.sort) {
                        Text("সাম্প্রতিক").tag(ListingFeedFilter.Sort.latest)
                        Text("মূল্য: কম থেকে বেশি").tag(ListingFeedFilter.Sort.priceLow)
                        Text("মূল্য: বেশি থেকে কম").tag(ListingFeedFilter.Sort.priceHigh)
                        Text("জনপ্রিয়").tag(ListingFeedFilter.Sort.popular)
                    }
                }
            }
            .navigationTitle("ফিল্টার")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("রিসেট") {
                        Task { await viewModel.resetFilter(); dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("প্রয়োগ করুন") {
                        viewModel.filter.search = searchText.isEmpty ? nil : searchText
                        viewModel.filter.minPrice = Double(minPrice)
                        viewModel.filter.maxPrice = Double(maxPrice)
                        Task { await viewModel.applyFilter(); dismiss() }
                    }
                }
            }
        }
    }
}
