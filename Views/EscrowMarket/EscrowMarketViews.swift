import SwiftUI
import PhotosUI

struct EscrowMarketBrowseView: View {
    @StateObject private var viewModel = EscrowMarketBrowseViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.listings) { listing in
                NavigationLink {
                    EscrowOrderCreateView(listing: listing)
                } label: {
                    VStack(alignment: .leading) {
                        Text(listing.title).font(.subheadline.bold())
                        if let price = listing.price { Text("৳\(Int(price))").foregroundStyle(.green) }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "খুঁজুন")
            .onChange(of: viewModel.searchText) { _, _ in Task { await viewModel.load() } }
            .overlay { if viewModel.isLoading { ProgressView() } }
            .navigationTitle("Escrow মার্কেটপ্লেস")
            .task { await viewModel.load() }
        }
    }
}

struct EscrowOrderCreateView: View {
    @StateObject private var viewModel: EscrowOrderCreateViewModel
    @Environment(\.dismiss) private var dismiss

    init(listing: Listing) {
        _viewModel = StateObject(wrappedValue: EscrowOrderCreateViewModel(listing: listing))
    }

    var body: some View {
        if let order = viewModel.createdOrder {
            confirmation(order)
        } else {
            Form {
                Section("বিবরণ") {
                    Text(viewModel.listing.title).font(.subheadline.bold())
                    if let fee = viewModel.feeBreakdown {
                        HStack { Text("মূল্য"); Spacer(); Text("৳\(Int(fee.price))") }
                        HStack { Text("প্ল্যাটফর্ম ফি"); Spacer(); Text("৳\(Int(fee.platformFeeAmount))") }
                        HStack { Text("বিক্রেতা পাবেন"); Spacer(); Text("৳\(Int(fee.sellerReceivesAmount))") }
                    }
                }
                Section("প্রয়োজনীয়তা (ঐচ্ছিক)") {
                    TextField("বিস্তারিত লিখুন", text: $viewModel.requirements, axis: .vertical)
                    TextField("কত দিনে চান (দিন)", text: $viewModel.deliveryDays).keyboardType(.numberPad)
                }
                Section {
                    Toggle("Escrow শর্তাবলীতে সম্মত", isOn: $viewModel.agreeTerms)
                }
                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isSubmitting { ProgressView().frame(maxWidth: .infinity) } else { Text("অর্ডার করুন").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.agreeTerms || viewModel.isSubmitting)
            }
            .navigationTitle("Escrow অর্ডার")
            .task { await viewModel.loadFeeBreakdown() }
        }
    }

    private func confirmation(_ order: EscrowMarketOrder) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 56)).foregroundStyle(.green)
            Text("অর্ডার তৈরি হয়েছে!").font(.title3.bold())
            Text(order.orderNumber).foregroundStyle(.secondary)
            Button("বন্ধ করুন") { dismiss() }.buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EscrowOrdersListView: View {
    let currentUserId: Int
    @StateObject private var viewModel = EscrowOrderListViewModel()
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $tab) {
                    Text("কিনছি").tag(0)
                    Text("বিক্রি করছি").tag(1)
                }
                .pickerStyle(.segmented).padding()

                List(tab == 0 ? viewModel.buying : viewModel.selling) { order in
                    NavigationLink {
                        EscrowOrderDetailView(orderId: order.id, currentUserId: currentUserId)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(order.title).font(.subheadline.bold())
                            Text(order.status.label).font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.gray.opacity(0.15)).clipShape(Capsule())
                        }
                    }
                }
                .overlay { if viewModel.isLoading { ProgressView() } }
            }
            .navigationTitle("Escrow অর্ডার")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
}

struct EscrowOrderDetailView: View {
    @StateObject private var viewModel: EscrowOrderDetailViewModel
    @State private var showPaymentSheet = false
    @State private var showDeliverySheet = false
    @State private var showRevisionAlert = false
    @State private var revisionNotes = ""
    @State private var showDisputeAlert = false
    @State private var disputeReason = ""
    @State private var openedDisputeId: Int?

    init(orderId: Int, currentUserId: Int) {
        _viewModel = StateObject(wrappedValue: EscrowOrderDetailViewModel(orderId: orderId, currentUserId: currentUserId))
    }

    var body: some View {
        ScrollView {
            if let order = viewModel.order {
                VStack(alignment: .leading, spacing: 16) {
                    Text(order.title).font(.title3.bold())
                    Text(order.status.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15)).foregroundStyle(.blue).clipShape(Capsule())
                    Text("৳\(Int(order.price))").font(.headline).foregroundStyle(.green)

                    if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }

                    if viewModel.isBuyer && order.status == .paymentPending {
                        Button("পেমেন্ট প্রমাণ জমা দিন") { showPaymentSheet = true }
                            .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    }
                    // zip: EscrowOrderPolicy::deliver() শুধু 'seller_working' — funds_held এখানেও
                    // (Direct-Deal-এর মতোই) auto-transition-এর মাধ্যমে মুহূর্তের জন্য থাকে,
                    // স্থায়ী state না, তাই আগের `.fundsHeld` চেক বাস্তবে কখনো মিলত না
                    if viewModel.isSeller && order.status == .sellerWorking {
                        Button(order.revisionCount > 0 ? "রিভাইজড ডেলিভারি জমা দিন" : "ডেলিভার করুন") {
                            showDeliverySheet = true
                        }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    }
                    if viewModel.isBuyer && order.status == .sellerDelivered {
                        Button("গ্রহণ করুন") { Task { await viewModel.accept() } }
                            .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                        if order.revisionCount < order.maxRevisions {
                            Button("রিভিশন চান") { showRevisionAlert = true }
                                .buttonStyle(.bordered).frame(maxWidth: .infinity)
                        }
                    }
                    // zip: EscrowOrderPolicy::dispute() — buyer/seller যে কেউ, প্রায় যেকোনো
                    // active status-এ (শুধু created/cancelled/completed/payout-related বাদে) —
                    // আগে শুধু buyer + sellerDelivered-এ সীমাবদ্ধ ছিল, অনেক বেশি সংকীর্ণ
                    if viewModel.isBuyer || viewModel.isSeller {
                        let nonDisputableStatuses: [AlhoqOrder.Status] = [
                            .created, .cancelled, .completed, .payoutPending, .paidOut, .refunded, .partiallyRefunded
                        ]
                        if !nonDisputableStatuses.contains(order.status) {
                            Button("বিরোধ খুলুন", role: .destructive) { showDisputeAlert = true }
                                .buttonStyle(.bordered).frame(maxWidth: .infinity)
                        }
                    }
                    // zip: EscrowOrderPolicy::cancel() — buyer_id মিলতেই হবে (আগে role-check ছাড়া
                    // শুধু status চেক করা হচ্ছিল, seller-কেও বাটন দেখাচ্ছিল)
                    if viewModel.isBuyer && order.isCancellable {
                        Button("বাতিল করুন", role: .destructive) { Task { await viewModel.cancel() } }
                            .buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }
                    if viewModel.isActing { ProgressView() }
                }
                .padding()
            } else if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            }
        }
        .navigationTitle(viewModel.order?.orderNumber ?? "Escrow অর্ডার")
        .task { await viewModel.load() }
        .sheet(isPresented: $showPaymentSheet) { EscrowPaymentSheet(viewModel: viewModel) }
        .sheet(isPresented: $showDeliverySheet) { EscrowDeliverySheet(viewModel: viewModel) }
        .alert("রিভিশন চান?", isPresented: $showRevisionAlert) {
            TextField("বিস্তারিত", text: $revisionNotes)
            Button("পাঠান") { Task { await viewModel.requestRevision(notes: revisionNotes) } }
            Button("বাতিল", role: .cancel) {}
        }
        .alert("বিরোধ খুলবেন?", isPresented: $showDisputeAlert) {
            TextField("কারণ (কমপক্ষে ২০ ক্যারেক্টার)", text: $disputeReason)
            Button("খুলুন", role: .destructive) {
                Task { openedDisputeId = await viewModel.openDisputeAndReturnId(reason: disputeReason) }
            }
            Button("বাতিল", role: .cancel) {}
        }
        .navigationDestination(item: $openedDisputeId) { id in
            EscrowDisputeView(disputeId: id)
        }
    }
}

private struct EscrowPaymentSheet: View {
    @ObservedObject var viewModel: EscrowOrderDetailViewModel
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
                    }
                }

                Section("পেমেন্টের তথ্য") {
                    TextField("রেফারেন্স (ঐচ্ছিক)", text: $referenceNumber)
                    TextField("প্রেরকের তথ্য (ঐচ্ছিক)", text: $senderInfo)
                }
                Section("প্রমাণ") {
                    PhotosPicker(selection: $proofItem, matching: .images) {
                        Text(proofFileURL == nil ? "প্রমাণের ছবি বেছে নিন" : "ছবি বেছে নেওয়া হয়েছে ✅")
                    }
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
                        await viewModel.submitPayment(method: selectedMethod.key, referenceNumber: referenceNumber.isEmpty ? nil : referenceNumber, senderInfo: senderInfo.isEmpty ? nil : senderInfo, proofFileURL: proofFileURL)
                        dismiss()
                    }
                } label: { Text("জমা দিন").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(proofFileURL == nil || selectedMethod == nil)
            }
            .navigationTitle("পেমেন্ট প্রমাণ")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
            .task {
                isLoadingMethods = true
                defer { isLoadingMethods = false }
                methods = (try? await EscrowMarketAPI().availablePaymentMethods()) ?? []
            }
        }
    }
}

private struct EscrowDeliverySheet: View {
    @ObservedObject var viewModel: EscrowOrderDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var fileItem: PhotosPickerItem?
    @State private var fileURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                TextField("ডেলিভারি নোট (আবশ্যক)", text: $note, axis: .vertical)
                PhotosPicker(selection: $fileItem, matching: .any(of: [.images, .videos])) {
                    Text(fileURL == nil ? "ফাইল যোগ করুন (ঐচ্ছিক)" : "ফাইল যোগ হয়েছে ✅")
                }
                .onChange(of: fileItem) { _, item in
                    guard let item else { return }
                    Task {
                        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                        try? data.write(to: tempURL)
                        fileURL = tempURL
                    }
                }
                Button {
                    Task { await viewModel.deliver(note: note, fileURL: fileURL); dismiss() }
                } label: { Text("ডেলিভার করুন").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("ডেলিভারি")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}

struct EscrowDisputeView: View {
    @StateObject private var viewModel: EscrowDisputeViewModel
    @State private var evidenceItem: PhotosPickerItem?

    init(disputeId: Int) {
        _viewModel = StateObject(wrappedValue: EscrowDisputeViewModel(disputeId: disputeId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if let dispute = viewModel.dispute {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(dispute.status.label).font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15)).foregroundStyle(.orange).clipShape(Capsule())
                        Text(dispute.reason)

                        Text("এভিডেন্স").font(.headline)
                        ForEach(viewModel.evidence) { item in
                            Label(item.fileType, systemImage: "paperclip").font(.caption)
                        }
                        // zip: EscrowDisputePolicy::addEvidence()/addMessage() — dispute->isOpen()
                        // না হলে (decided/closed) আর এভিডেন্স/মেসেজ যোগ করা যাবে না
                        if dispute.status == .open {
                            PhotosPicker(selection: $evidenceItem, matching: .any(of: [.images, .videos])) {
                                Text("এভিডেন্স যোগ করুন")
                            }
                            .onChange(of: evidenceItem) { _, item in
                                guard let item else { return }
                                Task {
                                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                                    try? data.write(to: tempURL)
                                    await viewModel.addEvidence(fileURL: tempURL, description: nil)
                                }
                            }
                        }

                        Text("মডারেটরের সাথে মেসেজ").font(.headline)
                        ForEach(viewModel.messages) { message in
                            VStack(alignment: message.isMine ? .trailing : .leading) {
                                Text(message.authorName).font(.caption2).foregroundStyle(.secondary)
                                Text(message.body)
                                    .padding(8)
                                    .background(message.isMine ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
                        }
                    }
                    .padding()
                } else if viewModel.isLoading {
                    ProgressView().padding(.top, 60)
                }
            }
            if viewModel.dispute?.status == .open {
                HStack {
                    TextField("মেসেজ লিখুন", text: $viewModel.messageText)
                        .textFieldStyle(.roundedBorder)
                    Button("পাঠান") { Task { await viewModel.sendMessage() } }
                        .disabled(viewModel.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle("বিরোধ নিষ্পত্তি")
        .task { await viewModel.load() }
    }
}
