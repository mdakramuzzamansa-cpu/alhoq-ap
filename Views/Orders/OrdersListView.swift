import SwiftUI

struct OrdersListView: View {
    let currentUserId: Int
    @StateObject private var viewModel = OrderListViewModel()
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $tab) {
                    Text("কিনছি").tag(0)
                    Text("বিক্রি করছি").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                List(tab == 0 ? viewModel.buying : viewModel.selling) { order in
                    NavigationLink {
                        OrderDetailView(orderId: order.id, currentUserId: currentUserId)
                    } label: {
                        row(order)
                    }
                }
                .overlay {
                    if viewModel.isLoading { ProgressView() }
                }
            }
            .navigationTitle("অর্ডার")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    private func row(_ order: AlhoqOrder) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(order.title).font(.subheadline.bold())
            HStack {
                Text(order.status.label).font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.gray.opacity(0.15)).clipShape(Capsule())
                Spacer()
                Text("৳\(Int(order.price))").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
