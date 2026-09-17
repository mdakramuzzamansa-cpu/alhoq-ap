import SwiftUI

struct ProviderBookingsView: View {
    @StateObject private var viewModel = ProviderBookingsViewModel()

    var body: some View {
        List(viewModel.bookings) { booking in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(booking.name).font(.subheadline.bold())
                    Spacer()
                    Text("#\(booking.dailySerial)").font(.caption).foregroundStyle(.secondary)
                }
                Text(booking.listing?.title ?? "").font(.caption).foregroundStyle(.secondary)
                Text("\(booking.bookingDate) — \(booking.bookingTime)").font(.caption)
                if let notes = booking.notes, !notes.isEmpty {
                    Text(notes).font(.caption2).italic()
                }

                if viewModel.updatingId == booking.id {
                    ProgressView()
                } else {
                    HStack {
                        statusMenu(booking)
                        Spacer()
                        Text(booking.status.label)
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.bookings.isEmpty {
                Text("এখনো কোনো বুকিং আসেনি").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("বুকিং ম্যানেজ করুন")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func statusMenu(_ booking: Booking) -> some View {
        Menu("স্ট্যাটাস বদলান") {
            ForEach([Booking.Status.pending, .confirmed, .completed, .cancelled], id: \.self) { status in
                Button(status.label) {
                    Task { await viewModel.updateStatus(booking, to: status) }
                }
            }
        }
        .font(.caption)
    }
}
