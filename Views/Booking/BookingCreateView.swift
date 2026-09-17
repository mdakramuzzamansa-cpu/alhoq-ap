import SwiftUI

struct BookingCreateView: View {
    @StateObject private var viewModel: BookingCreateViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bookingCheckoutURL: URL?
    @State private var isStartingPayment = false

    init(listing: Listing) {
        _viewModel = StateObject(wrappedValue: BookingCreateViewModel(listing: listing))
    }

    var body: some View {
        NavigationStack {
            if let booking = viewModel.createdBooking {
                confirmation(booking)
            } else {
                form
            }
        }
        .task { await viewModel.loadWeekdays() }
    }

    private var form: some View {
        Form {
            Section("তারিখ বেছে নিন") {
                DatePicker(
                    "তারিখ", selection: $viewModel.selectedDate, in: Date()..., displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .onChange(of: viewModel.selectedDate) { _, _ in
                    Task { await viewModel.dateChanged() }
                }
            }

            Section("সময় বেছে নিন") {
                if viewModel.isLoadingSlots {
                    ProgressView()
                } else if viewModel.availableSlots.isEmpty {
                    Text("এই দিনে কোনো স্লট খালি নেই।").foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(viewModel.availableSlots, id: \.self) { slot in
                            Button(slot) { viewModel.selectedSlot = slot }
                                .padding(8)
                                .background(viewModel.selectedSlot == slot ? Color.accentColor : Color.gray.opacity(0.15))
                                .foregroundStyle(viewModel.selectedSlot == slot ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            Section("নোট (ঐচ্ছিক)") {
                TextField("কোনো বিশেষ অনুরোধ থাকলে লিখুন", text: $viewModel.notes, axis: .vertical)
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.submit() }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("বুকিং নিশ্চিত করুন").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedSlot == nil || viewModel.isSubmitting)
        }
        .navigationTitle("বুকিং করুন")
        .toolbar {
            cancelToolbarItem("বাতিল") { dismiss() }
        }
    }

    private func confirmation(_ booking: Booking) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
            Text("বুকিং সফল হয়েছে!").font(.title3.bold())
            VStack(spacing: 6) {
                Text("তারিখ: \(booking.bookingDate)")
                Text("সময়: \(booking.bookingTime)")
                Text("আপনার সিরিয়াল নম্বর: #\(booking.dailySerial)")
                    .font(.headline)
            }
            .foregroundStyle(.secondary)

            if booking.paymentStatus == .unpaid {
                Text("পেমেন্ট এখনো বাকি — Checkout সম্পন্ন করুন।")
                    .font(.footnote).foregroundStyle(.orange)
                Button {
                    Task { await startBookingPayment(booking) }
                } label: {
                    if isStartingPayment { ProgressView() } else { Text("এখনই পেমেন্ট করুন") }
                }
                .buttonStyle(.borderedProminent)
            }

            Button("বন্ধ করুন") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fullScreenCover(isPresented: Binding(get: { bookingCheckoutURL != nil }, set: { if !$0 { bookingCheckoutURL = nil } })) {
            if let url = bookingCheckoutURL {
                NavigationStack {
                    CheckoutWebView(
                        checkoutURL: url,
                        successPath: CheckoutWebRoutes.bookingSuccessPath(bookingId: booking.id),
                        cancelPath: CheckoutWebRoutes.bookingCancelPath(bookingId: booking.id)
                    ) { outcome in
                        bookingCheckoutURL = nil
                        if case .success(let sessionId) = outcome, let sessionId {
                            Task { _ = try? await CheckoutAPI().confirmBookingFulfillment(bookingId: booking.id, sessionId: sessionId) }
                        }
                    }
                    .navigationTitle("পেমেন্ট")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private func startBookingPayment(_ booking: Booking) async {
        isStartingPayment = true
        defer { isStartingPayment = false }
        if let session = try? await CheckoutAPI().startBookingCheckout(bookingId: booking.id) {
            bookingCheckoutURL = URL(string: session.checkoutUrl)
        }
    }
}
