import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            if let dashboard = viewModel.dashboard {
                VStack(alignment: .leading, spacing: 16) {
                    statsGrid(dashboard.stats)

                    if let package = dashboard.activePackage {
                        packageCard(package, remaining: dashboard.listingsRemaining, limit: dashboard.listingLimit)
                    }

                    quickActions(dashboard)

                    if !dashboard.needsAvailabilityListingIds.isEmpty {
                        Label("\(dashboard.needsAvailabilityListingIds.count)টা লিস্টিংয়ে বুকিং শিডিউল সেট করা হয়নি", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !dashboard.handshakeConnections.isEmpty {
                        handshakeWidget(dashboard)
                    }
                }
                .padding()
            } else if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            }
        }
        .navigationTitle("ড্যাশবোর্ড")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func statsGrid(_ stats: DashboardStats.Counts) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("মোট লিস্টিং", "\(stats.total)")
            statCard("প্রকাশিত", "\(stats.published)")
            statCard("অনুমোদনের অপেক্ষায়", "\(stats.pending)")
            statCard("মোট ভিউ", "\(stats.views)")
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func packageCard(_ package: UserPackage, remaining: Int, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(package.package?.name ?? "সক্রিয় প্যাকেজ").font(.subheadline.bold())
            Text("\(remaining)/\(limit) লিস্টিং বাকি").font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func quickActions(_ dashboard: DashboardStats) -> some View {
        VStack(spacing: 8) {
            NavigationLink { MyListingsView() } label: { Label("লিস্টিং ম্যানেজ করুন", systemImage: "list.bullet.rectangle") }
            NavigationLink { ProviderBookingsView() } label: {
                Label("বুকিং (\(dashboard.bookingsCount))", systemImage: "calendar")
            }
            NavigationLink { HandshakesPanelView() } label: {
                Label("Handshake (\(dashboard.handshakePendingCount) নতুন)", systemImage: "hand.raised")
            }
        }
        .buttonStyle(.bordered)
    }

    private func handshakeWidget(_ dashboard: DashboardStats) -> some View {
        VStack(alignment: .leading) {
            Text("সাম্প্রতিক সংযোগ").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(dashboard.handshakeConnections, id: \.id) { user in
                        VStack {
                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 48, height: 48)
                            Text(user.name).font(.caption2).lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
            }
        }
    }
}
