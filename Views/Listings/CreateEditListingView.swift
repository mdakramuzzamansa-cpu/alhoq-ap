import SwiftUI
import PhotosUI

struct CreateEditListingView: View {
    @StateObject private var viewModel: CreateEditListingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    init(editing listing: Listing?) {
        _viewModel = StateObject(wrappedValue: CreateEditListingViewModel(editing: listing))
    }

    var body: some View {
        NavigationStack {
            Form {
                categorySection
                basicInfoSection
                pricingSection
                mediaSection
                locationSection
                contactSection
                if viewModel.selectedCategory?.allowAnonymous == true {
                    anonymitySection
                }
                if viewModel.selectedCategory?.isBookable == true {
                    bookingSection
                }
                seoSection

                if let generalError = viewModel.generalError {
                    Text(generalError).foregroundStyle(.red)
                }

                submitButton
            }
            .navigationTitle(viewModel.isEditing ? "লিস্টিং এডিট" : "নতুন লিস্টিং")
            .toolbar {
                cancelToolbarItem("বাতিল") { dismiss() }
            }
            .task { await viewModel.loadCategories() }
            .onChange(of: viewModel.didSaveSuccessfully) { _, saved in
                if saved { dismiss() }
            }
        }
    }

    private var categorySection: some View {
        Section("ক্যাটাগরি") {
            if viewModel.isLoadingCategories {
                ProgressView()
            } else {
                Picker("ক্যাটাগরি", selection: $viewModel.form.categoryId) {
                    Text("নির্বাচন করুন").tag(Optional<Int>.none)
                    ForEach(viewModel.categories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                fieldError("category_id")

                // web: is_verification_required হলে "Get Trusted" ছাড়া পোস্ট করা যাবে না
                if let category = viewModel.selectedCategory, category.isVerificationRequired {
                    NavigationLink {
                        CategoryVerificationView(categoryId: category.id, categoryName: category.name)
                    } label: {
                        Label(
                            "এই ক্যাটাগরিতে পোস্ট করতে আগে 'Get Trusted' ভেরিফিকেশন করতে হবে।",
                            systemImage: "exclamationmark.shield"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var basicInfoSection: some View {
        Section("বিস্তারিত") {
            TextField("শিরোনাম", text: $viewModel.form.title)
            fieldError("title")
            TextField("বিবরণ", text: $viewModel.form.description, axis: .vertical)
                .lineLimit(4...10)
            fieldError("description")
        }
    }

    private var pricingSection: some View {
        Section("মূল্য") {
            Picker("মূল্যের ধরন", selection: $viewModel.form.priceType) {
                ForEach(Listing.PriceType.allCases, id: \.self) { type in
                    Text(type.label).tag(type)
                }
            }
            if viewModel.form.priceType == .fixed || viewModel.form.priceType == .negotiable {
                TextField("মূল্য (৳)", text: $viewModel.form.price)
                    .keyboardType(.numberPad)
            }
            Toggle("Alhoq Direct-Deal পেমেন্ট আবশ্যক", isOn: $viewModel.form.requiresPayment)
            if viewModel.form.requiresPayment {
                TextField("ডেলিভারি সময় (ঘণ্টা)", text: $viewModel.form.alhoqDeliveryHours)
                    .keyboardType(.numberPad)
                TextField("সর্বোচ্চ রিভিশন সংখ্যা", text: $viewModel.form.alhoqMaxRevisions)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var mediaSection: some View {
        Section("ছবি (সর্বোচ্চ ১০টা)") {
            ForEach(Array(viewModel.form.imageUrls.enumerated()), id: \.offset) { index, url in
                HStack {
                    Text(url).lineLimit(1).font(.caption)
                    Spacer()
                    Button(role: .destructive) {
                        viewModel.removeNewImage(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
            }
            fieldError("image_urls")

            if viewModel.uploadingImageCount > 0 {
                HStack {
                    ProgressView()
                    Text("\(viewModel.uploadingImageCount)টা ছবি আপলোড হচ্ছে…").font(.caption)
                }
            }
            if let uploadError = viewModel.imageUploadError {
                Text(uploadError).font(.caption2).foregroundStyle(.red)
            }

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: max(0, 10 - viewModel.form.imageUrls.count),
                matching: .images
            ) {
                Label("ছবি যোগ করুন", systemImage: "photo.badge.plus")
            }
            .onChange(of: selectedPhotoItems) { _, items in
                Task {
                    for item in items {
                        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".jpg")
                        try? data.write(to: tempURL)
                        await viewModel.uploadAndAddImage(fileURL: tempURL)
                    }
                    selectedPhotoItems = []
                }
            }
        }
    }

    private var locationSection: some View {
        Section("অবস্থান") {
            TextField("লোকেশন", text: $viewModel.form.location)
            Picker("কারা দেখতে পাবে", selection: $viewModel.form.targetScope) {
                ForEach(Listing.TargetScope.allCases, id: \.self) { scope in
                    Text(scope.label).tag(scope)
                }
            }
        }
    }

    private var contactSection: some View {
        Section("যোগাযোগ") {
            TextField("ফোন নম্বর", text: $viewModel.form.contactPhone)
                .keyboardType(.phonePad)
            TextField("ইমেইল", text: $viewModel.form.contactEmail)
                .keyboardType(.emailAddress)
        }
    }

    private var anonymitySection: some View {
        Section("গোপনীয়তা") {
            Toggle("Anonymous হিসেবে পোস্ট করুন", isOn: $viewModel.form.isAnonymous)
            if viewModel.form.isAnonymous {
                Text("আপনার নাম, ফোন ও ইমেইল কারো কাছে দেখানো হবে না।")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bookingSection: some View {
        Section("বুকিং শিডিউল") {
            Toggle("বুকিং চালু করুন", isOn: $viewModel.form.enableBookingSchedule)
            if viewModel.form.enableBookingSchedule {
                Picker("প্রতি স্লট (মিনিট)", selection: $viewModel.form.schedule.slotDurationMinutes) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                        Text("\(minutes) মিনিট").tag(minutes)
                    }
                }
                ForEach(0..<7, id: \.self) { day in
                    dayRow(day)
                }
            }
        }
    }

    private func dayRow(_ day: Int) -> some View {
        let binding = Binding(
            get: { viewModel.form.schedule.days[day] ?? BookingSchedule.DaySchedule() },
            set: { viewModel.form.schedule.days[day] = $0 }
        )
        return VStack(alignment: .leading) {
            Toggle(BookingSchedule.weekdayLabels[day] ?? "", isOn: binding.active)
            if binding.wrappedValue.active {
                HStack {
                    TextField("শুরু (HH:mm)", text: binding.startTime)
                    TextField("শেষ (HH:mm)", text: binding.endTime)
                }
                .font(.caption)
            }
        }
    }

    private var seoSection: some View {
        Section("SEO (ঐচ্ছিক)") {
            TextField("Meta Title", text: $viewModel.form.metaTitle)
            TextField("Meta Description", text: $viewModel.form.metaDescription, axis: .vertical)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            if viewModel.isSaving {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(viewModel.isEditing ? "আপডেট করুন" : "প্রকাশ করুন").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isSaving)
    }

    @ViewBuilder
    private func fieldError(_ key: String) -> some View {
        if let messages = viewModel.fieldErrors[key], let first = messages.first {
            Text(first).font(.caption2).foregroundStyle(.red)
        }
    }
}
