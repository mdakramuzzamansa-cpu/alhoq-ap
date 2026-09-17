import SwiftUI

struct MyListingsView: View {
    @StateObject private var viewModel = MyListingsViewModel()
    @State private var listingPendingDeletion: Listing?
    @State private var showCreateSheet = false
    @State private var editingListing: Listing?

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.grouped, id: \.status) { group in
                    Section(group.status.label) {
                        ForEach(group.items) { listing in
                            row(listing)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.listings.isEmpty {
                    Text("এখনো কোনো লিস্টিং নেই").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("আমার লিস্টিং")
            .toolbar {
                toolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .confirmationDialog(
                "এই লিস্টিং ডিলিট করবেন?",
                isPresented: Binding(get: { listingPendingDeletion != nil }, set: { if !$0 { listingPendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("ডিলিট করুন", role: .destructive) {
                    if let listing = listingPendingDeletion {
                        Task { await viewModel.delete(listing) }
                    }
                }
                Button("বাতিল", role: .cancel) {}
            } message: {
                Text("এই কাজ পূর্বাবস্থায় ফেরানো যাবে না।")
            }
            .sheet(isPresented: $showCreateSheet, onDismiss: { Task { await viewModel.load() } }) {
                CreateEditListingView(editing: nil)
            }
            .sheet(item: $editingListing, onDismiss: { Task { await viewModel.load() } }) { listing in
                CreateEditListingView(editing: listing)
            }
        }
    }

    private func row(_ listing: Listing) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(listing.title).font(.subheadline.bold())
                Text("👁 \(listing.views) ভিউ").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.deletingId == listing.id {
                ProgressView()
            } else {
                Menu {
                    Button("এডিট করুন", systemImage: "pencil") { editingListing = listing }
                    if listing.category?.isBookable == true {
                        NavigationLink {
                            AvailabilityEditView(listingId: listing.id)
                        } label: {
                            Label("বুকিং শিডিউল", systemImage: "calendar")
                        }
                    }
                    NavigationLink {
                        FormBuilderView(listingId: listing.id)
                    } label: {
                        Label("Apply Form বানান", systemImage: "list.clipboard")
                    }
                    NavigationLink {
                        FormResponsesView(listingId: listing.id)
                    } label: {
                        Label("রেসপন্স দেখুন", systemImage: "tray.full")
                    }
                    Button("ডিলিট করুন", systemImage: "trash", role: .destructive) {
                        listingPendingDeletion = listing
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}
