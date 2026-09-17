import SwiftUI

struct OrderCreateView: View {
    @StateObject private var viewModel: OrderCreateViewModel
    @Environment(\.dismiss) private var dismiss

    init(listing: Listing) {
        _viewModel = StateObject(wrappedValue: OrderCreateViewModel(listing: listing))
    }

    var body: some View {
        NavigationStack {
            if let order = viewModel.createdOrder {
                confirmation(order)
            } else {
                Form {
                    Section("অর্ডারের বিবরণ") {
                        Text(viewModel.listing.title).font(.subheadline.bold())
                        if let price = viewModel.listing.price {
                            Text("৳\(Int(price))").foregroundStyle(.green)
                        }
                    }
                    Section("আপনার প্রয়োজন লিখুন") {
                        TextField("বিস্তারিত বলুন — কী চান, কবে লাগবে ইত্যাদি", text: $viewModel.buyerNotes, axis: .vertical)
                            .lineLimit(5...12)
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
                            Text("অর্ডার করুন").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSubmit)
                }
                .navigationTitle("অর্ডার করুন")
                .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
            }
        }
    }

    private func confirmation(_ order: AlhoqOrder) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
            Text("অর্ডার তৈরি হয়েছে!").font(.title3.bold())
            Text("অর্ডার নম্বর: \(order.orderNumber)").foregroundStyle(.secondary)
            Text("পেমেন্ট সম্পন্ন করতে অর্ডার ডিটেইলে যান।").font(.footnote).foregroundStyle(.secondary)
            Button("অর্ডার দেখুন") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
