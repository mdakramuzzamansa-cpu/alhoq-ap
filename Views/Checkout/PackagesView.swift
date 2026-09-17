import SwiftUI

struct PackagesView: View {
    @StateObject private var viewModel = PackagesViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let active = viewModel.activePackage {
                    activeCard(active)
                }

                ForEach(viewModel.packages) { package in
                    packageCard(package)
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let success = viewModel.successMessage {
                    Text(success).foregroundStyle(.green)
                }
            }
            .padding()
        }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .navigationTitle("প্যাকেজ")
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: Binding(get: { viewModel.checkoutURL != nil }, set: { if !$0 { viewModel.checkoutURL = nil } })) {
            if let url = viewModel.checkoutURL {
                NavigationStack {
                    CheckoutWebView(
                        checkoutURL: url,
                        successPath: CheckoutWebRoutes.packageSuccessPath,
                        cancelPath: CheckoutWebRoutes.packageCancelPath
                    ) { outcome in
                        Task { await viewModel.handleOutcome(outcome) }
                    }
                    .navigationTitle("পেমেন্ট")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        cancelToolbarItem("বাতিল") { Task { await viewModel.handleOutcome(.cancelled) } }
                    }
                }
            }
        }
    }

    private func activeCard(_ active: UserPackage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("সক্রিয় প্যাকেজ", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            Text(active.package?.name ?? "")
                .font(.headline)
            Text("লিস্টিং ব্যবহৃত: \(active.listingsUsed)/\(active.package?.listingLimit ?? 0)")
                .font(.caption).foregroundStyle(.secondary)
            Text("মেয়াদ শেষ: \(active.expiresAt.formatted())")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func packageCard(_ package: SubscriptionPackage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(package.name).font(.headline)
            if let description = package.description { Text(description).font(.caption).foregroundStyle(.secondary) }
            Text("\(package.listingLimit)টা লিস্টিং — \(package.durationDays) দিন").font(.caption)
            HStack {
                Text("$\(String(format: "%.2f", package.price))").font(.title3.bold())
                Spacer()
                Button {
                    Task { await viewModel.startCheckout(for: package) }
                } label: {
                    if viewModel.isStartingCheckout { ProgressView() } else { Text("কিনুন") }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
