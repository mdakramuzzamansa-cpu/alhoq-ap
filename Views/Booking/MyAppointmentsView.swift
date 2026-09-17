import SwiftUI

struct MyAppointmentsView: View {
    @StateObject private var viewModel = MyAppointmentsViewModel()

    var body: some View {
        List(viewModel.bookings) { booking in
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.listing?.title ?? "লিস্টিং").font(.subheadline.bold())
                Text("\(booking.bookingDate) — \(booking.bookingTime)").font(.caption)
                HStack {
                    statusBadge(booking.status)
                    Spacer()
                    Text("#\(booking.dailySerial)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.bookings.isEmpty {
                Text("এখনো কোনো বুকিং নেই").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("আমার বুকিং")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func statusBadge(_ status: Booking.Status) -> some View {
        Text(status.label)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color(for: status).opacity(0.15))
            .foregroundStyle(color(for: status))
            .clipShape(Capsule())
    }

    private func color(for status: Booking.Status) -> Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}
