import SwiftUI
import PhotosUI

struct OrderDetailView: View {
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var showPaymentSheet = false
    @State private var showDeliverySheet = false
    @State private var showPayoutSheet = false
    @State private var showRevisionAlert = false
    @State private var revisionReason = ""
    @State private var showDisputeAlert = false
    @State private var disputeReason = ""
    @State private var showCancelAlert = false

    init(orderId: Int, currentUserId: Int) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderId: orderId, currentUserId: currentUserId))
    }

    var body: some View {
        ScrollView {
            if let order = viewModel.order {
                VStack(alignment: .leading, spacing: 16) {
                    header(order)
                    statusTimeline
                    if !viewModel.deliveries.isEmpty { deliveriesSection }
                    if !viewModel.revisionRequests.isEmpty { revisionsSection }
                    if let dispute = viewModel.activeDispute {
                        NavigationLink {
                            DisputeView(disputeId: dispute.id, currentUserId: viewModel.currentUserId)
                        } label: {
                            Label("বিরোধ দেখুন (\(dispute.status.label))", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                    actions(order)
                }
                .padding()
            } else if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).padding()
            }
        }
        .navigationTitle(viewModel.order?.orderNumber ?? "অর্ডার")
        .task { await viewModel.load() }
        .sheet(isPresented: $showPaymentSheet) { PaymentSubmitSheet(viewModel: viewModel) }
        .sheet(isPresented: $showDeliverySheet) { DeliverySubmitSheet(viewModel: viewModel) }
        .sheet(isPresented: $showPayoutSheet) { PayoutDestinationSheet(viewModel: viewModel) }
        .alert("রিভিশন চান?", isPresented: $showRevisionAlert) {
            TextField("কারণ লিখুন", text: $revisionReason)
            Button("পাঠান") { Task { await viewModel.requestRevision(reason: revisionReason) } }
            Button("বাতিল", role: .cancel) {}
        }
        .alert("বিরোধ খুলবেন?", isPresented: $showDisputeAlert) {
            TextField("কারণ লিখুন", text: $disputeReason)
            Button("বিরোধ খুলুন", role: .destructive) { Task { await viewModel.openDispute(reason: disputeReason) } }
            Button("বাতিল", role: .cancel) {}
        } message: {
            Text("বিরোধ খুললে একজন মডারেটর রিভিউ করবেন। নিশ্চিত হয়ে এগোন।")
        }
        .alert("অর্ডার বাতিল করবেন?", isPresented: $showCancelAlert) {
            Button("বাতিল করুন", role: .destructive) { Task { await viewModel.cancel(reason: nil) } }
            Button("না", role: .cancel) {}
        }
    }

    private func header(_ order: AlhoqOrder) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(order.title).font(.title3.bold())
            HStack {
                Text(order.status.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColor(order.status).opacity(0.15))
                    .foregroundStyle(statusColor(order.status))
                    .clipShape(Capsule())
                Spacer()
                Text("৳\(Int(order.price))").font(.headline).foregroundStyle(.green)
            }
            if let deadline = order.deliveryDeadlineAt {
                Label("ডেলিভারি সময়সীমা: \(deadline.formatted())", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("রিভিশন: \(order.revisionCount)/\(order.maxRevisions)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var statusTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("অগ্রগতি").font(.headline)
            ForEach(viewModel.statusHistory) { entry in
                HStack(alignment: .top) {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8).padding(.top, 5)
                    VStack(alignment: .leading) {
                        Text(entry.status.label).font(.caption.bold())
                        if let note = entry.note { Text(note).font(.caption2).foregroundStyle(.secondary) }
                        Text(entry.createdAt).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var deliveriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ডেলিভারি").font(.headline)
            ForEach(viewModel.deliveries) { delivery in
                VStack(alignment: .leading, spacing: 4) {
                    if let note = delivery.note { Text(note).font(.caption) }
                    Text("\(delivery.fileUrls.count)টা ফাইল — \(delivery.deliveredAt)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var revisionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("রিভিশন অনুরোধ").font(.headline)
            ForEach(viewModel.revisionRequests) { revision in
                VStack(alignment: .leading) {
                    Text(revision.reason).font(.caption)
                    Text(revision.requestedAt).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func actions(_ order: AlhoqOrder) -> some View {
        VStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            // zip: OrderPolicy::submitPayment() — payment_pending তো বটেই, payment_rejected
            // হলেও আবার জমা দেওয়া যায় (রিট্রাই) — আগে এই দ্বিতীয় কেসটা মিস ছিল
            if viewModel.isBuyer && [.paymentPending, .paymentRejected].contains(order.status) {
                Button(order.status == .paymentRejected ? "আবার পেমেন্ট প্রমাণ জমা দিন" : "পেমেন্ট প্রমাণ জমা দিন") {
                    showPaymentSheet = true
                }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                if order.status == .paymentRejected {
                    Text("আগের পেমেন্ট প্রমাণ প্রত্যাখ্যাত হয়েছে — সঠিক তথ্য দিয়ে আবার জমা দিন।")
                        .font(.caption2).foregroundStyle(.red)
                }
            }

            // zip: PaymentVerificationService — funds_held থেকে seller_working-এ **তৎক্ষণাৎ,
            // একই কলে** system-transition হয়ে যায় (funds_held স্থায়ী state না, শুধু status-history
            // log-এ থাকে) — DeliveryService/OrderPolicy::deliver() শুধু SELLER_WORKING accept করে।
            // আগে এখানে `.fundsHeld` চেক করা ছিল, যেটা বাস্তবে কখনো মিলতই না — Deliver বাটন
            // কার্যত কখনো দেখাই যেত না। এখন সঠিক অবস্থা অনুযায়ী ঠিক করা হলো।
            if viewModel.isSeller && order.status == .sellerWorking {
                Button("পেআউট ঠিকানা সেট করুন") { showPayoutSheet = true }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
                Button(order.revisionCount > 0 ? "রিভাইজড ডেলিভারি জমা দিন" : "ডেলিভার করুন") {
                    showDeliverySheet = true
                }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }

            // buyer: delivered হলে accept/revision (যদি limit না ছাড়ায়)
            if viewModel.isBuyer && order.status == .sellerDelivered {
                Button("গ্রহণ করুন") { Task { await viewModel.accept() } }
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                if order.revisionCount < order.maxRevisions {
                    Button("রিভিশন চান") { showRevisionAlert = true }
                        .buttonStyle(.bordered).frame(maxWidth: .infinity)
                } else {
                    Text("সর্বোচ্চ রিভিশন সংখ্যা শেষ হয়ে গেছে।").font(.caption2).foregroundStyle(.secondary)
                }
            }

            // zip: OrderPolicy::openDispute() — শুধু delivered না, seller_working ও
            // seller_missed_deadline অবস্থাতেও দুই পক্ষের যে কেউ বিরোধ খুলতে পারেন
            if [.sellerWorking, .sellerDelivered, .sellerMissedDeadline].contains(order.status) {
                Button("বিরোধ খুলুন", role: .destructive) { showDisputeAlert = true }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }

            // zip: OrderPolicy::cancel() — শুধু buyer_id মিললেই, seller না (আগে দুজনকেই দেখানো
            // হচ্ছিল, যেটা seller-এর জন্য চাপলে 403 দিত)
            if viewModel.isBuyer && !order.status.isTerminal && [.created, .paymentPending].contains(order.status) {
                Button("অর্ডার বাতিল করুন", role: .destructive) { showCancelAlert = true }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }

            if viewModel.isActing { ProgressView() }
        }
    }

    private func statusColor(_ status: AlhoqOrder.Status) -> Color {
        switch status {
        case .completed, .paidOut, .buyerAccepted, .autoCompleted: return .green
        case .disputed, .cancelled, .paymentRejected, .sellerMissedDeadline: return .red
        case .revisionRequested, .refunded, .partiallyRefunded: return .orange
        default: return .blue
        }
    }
}

private struct PaymentSubmitSheet: View {
    @ObservedObject var viewModel: OrderDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var methods: [PaymentMethodInfo] = []
    @State private var selectedMethod: PaymentMethodInfo?
    @State private var isLoadingMethods = false
    @State private var referenceNumber = ""
    @State private var senderInfo = ""
    @State private var proofItem: PhotosPickerItem?
    @State private var proofFileURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("পেমেন্ট মাধ্যম বাছুন") {
                    if isLoadingMethods {
                        ProgressView()
                    } else {
                        Picker("মাধ্যম", selection: $selectedMethod) {
                            Text("নির্বাচন করুন").tag(Optional<PaymentMethodInfo>.none)
                            ForEach(methods) { method in
                                Text(method.label).tag(Optional(method))
                            }
                        }
                    }
                }

                // zip: শুধু নাম না — আসল রিসিভিং নম্বর/QR/ব্যাংক ডিটেইল দেখানো জরুরি,
                // নাহলে ইউজার জানতেই পারবে না টাকা কোথায় পাঠাতে হবে
                if let selectedMethod {
                    Section("এখানে পেমেন্ট পাঠান") {
                        if let number = selectedMethod.number {
                            HStack { Text("নম্বর"); Spacer(); Text(number).font(.system(.body, design: .monospaced)) }
                        }
                        if let bankName = selectedMethod.bankName {
                            HStack { Text("ব্যাংক"); Spacer(); Text(bankName) }
                        }
                        if let accountName = selectedMethod.accountName {
                            HStack { Text("অ্যাকাউন্টের নাম"); Spacer(); Text(accountName) }
                        }
                        if let routingNumber = selectedMethod.routingNumber {
                            HStack { Text("রাউটিং নম্বর"); Spacer(); Text(routingNumber) }
                        }
                        // TODO: selectedMethod.qrPath থাকলে AsyncImage দিয়ে QR কোড দেখাতে হবে
                    }
                }

                Section("পেমেন্টের তথ্য") {
                    TextField("রেফারেন্স/ট্রানজেকশন নম্বর (ঐচ্ছিক)", text: $referenceNumber)
                    TextField("প্রেরকের তথ্য (ঐচ্ছিক)", text: $senderInfo)
                }
                Section("পেমেন্টের প্রমাণ (স্ক্রিনশট)") {
                    if proofFileURL != nil {
                        Label("ছবি বেছে নেওয়া হয়েছে", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    PhotosPicker(selection: $proofItem, matching: .images) { Text("ছবি বেছে নিন") }
                        .onChange(of: proofItem) { _, item in
                            guard let item else { return }
                            Task {
                                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                                try? data.write(to: tempURL)
                                proofFileURL = tempURL
                            }
                        }
                }
                Button {
                    guard let proofFileURL, let selectedMethod else { return }
                    Task {
                        await viewModel.submitPayment(
                            method: selectedMethod.key, referenceNumber: referenceNumber.isEmpty ? nil : referenceNumber,
                            senderInfo: senderInfo.isEmpty ? nil : senderInfo, proofFileURL: proofFileURL
                        )
                        dismiss()
                    }
                } label: {
                    if viewModel.isActing { ProgressView().frame(maxWidth: .infinity) } else { Text("জমা দিন").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(proofFileURL == nil || selectedMethod == nil || viewModel.isActing)
            }
            .navigationTitle("পেমেন্ট প্রমাণ")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
            .task {
                isLoadingMethods = true
                defer { isLoadingMethods = false }
                methods = (try? await OrderAPI().availablePaymentMethods()) ?? []
            }
        }
    }
}

private struct DeliverySubmitSheet: View {
    @ObservedObject var viewModel: OrderDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var items: [PhotosPickerItem] = []
    @State private var fileURLs: [URL] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("নোট") {
                    TextField("ডেলিভারি নোট", text: $note, axis: .vertical)
                }
                Section("ফাইল (সর্বোচ্চ ১০টা)") {
                    Text("\(fileURLs.count)টা ফাইল বেছে নেওয়া হয়েছে").font(.caption)
                    PhotosPicker(selection: $items, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                        Text("ফাইল বেছে নিন")
                    }
                    .onChange(of: items) { _, newItems in
                        Task {
                            for item in newItems {
                                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                                try? data.write(to: tempURL)
                                fileURLs.append(tempURL)
                            }
                        }
                    }
                }
                Button {
                    Task {
                        await viewModel.deliver(note: note.isEmpty ? nil : note, fileURLs: fileURLs)
                        dismiss()
                    }
                } label: {
                    if viewModel.isActing { ProgressView().frame(maxWidth: .infinity) } else { Text("ডেলিভার করুন").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isActing)
            }
            .navigationTitle("ডেলিভারি জমা দিন")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}

private struct PayoutDestinationSheet: View {
    @ObservedObject var viewModel: OrderDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethodId: Int?
    @State private var account = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("পেআউট মাধ্যম", selection: $selectedMethodId) {
                    Text("নির্বাচন করুন").tag(Optional<Int>.none)
                    ForEach(viewModel.payoutMethods) { method in
                        Text(method.name).tag(Optional(method.id))
                    }
                }
                TextField("অ্যাকাউন্ট নম্বর", text: $account)

                Button {
                    guard let selectedMethodId else { return }
                    Task {
                        await viewModel.setPayoutDestination(methodId: selectedMethodId, account: account)
                        dismiss()
                    }
                } label: {
                    Text("সেভ করুন").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedMethodId == nil || account.isEmpty)
            }
            .navigationTitle("পেআউট ঠিকানা")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}
