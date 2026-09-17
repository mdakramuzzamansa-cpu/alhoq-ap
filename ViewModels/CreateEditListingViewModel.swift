import Foundation

@MainActor
final class CreateEditListingViewModel: ObservableObject {
    struct FormState {
        var categoryId: Int?
        var title: String = ""
        var description: String = ""
        var metaTitle: String = ""
        var metaDescription: String = ""
        var price: String = ""
        var priceType: Listing.PriceType = .fixed
        var requiresPayment: Bool = false
        var alhoqDeliveryHours: String = ""
        var alhoqMaxRevisions: String = ""
        var location: String = ""
        var targetScope: Listing.TargetScope = .everywhere
        var latitude: Double?
        var longitude: Double?
        var contactPhone: String = ""
        var contactEmail: String = ""
        var isAnonymous: Bool = false
        var imageUrls: [String] = []          // Universal Media Upload থেকে পাওয়া URL
        var removeImageIds: [Int] = []        // edit mode-এ existing image মুছার জন্য
        var enableBookingSchedule: Bool = false
        var schedule = BookingSchedule()
    }

    @Published var form = FormState()
    @Published var categories: [Category] = []
    @Published var isSaving = false
    @Published var isLoadingCategories = false
    @Published var fieldErrors: [String: [String]] = [:]
    @Published var generalError: String?
    @Published var didSaveSuccessfully = false
    @Published var uploadingImageCount = 0
    @Published var imageUploadError: String?

    /// nil হলে "create" মোড, নাহলে "edit" মোড — web-এর মতোই একই form দুই কাজে ব্যবহৃত হচ্ছে
    private let editingListing: Listing?
    private let api: ListingAPIProtocol
    private let uploader: MediaUploader

    init(editing listing: Listing? = nil, api: ListingAPIProtocol = ListingAPI(), uploader: MediaUploader? = nil) {
        self.editingListing = listing
        self.api = api
        self.uploader = uploader ?? MediaUploader()
        if let listing {
            form = FormState(
                categoryId: listing.categoryId,
                title: listing.title,
                description: listing.description ?? "",
                metaTitle: listing.metaTitle ?? "",
                metaDescription: listing.metaDescription ?? "",
                price: listing.price.map { String($0) } ?? "",
                priceType: listing.priceType,
                requiresPayment: listing.requiresPayment,
                alhoqDeliveryHours: listing.alhoqDeliveryHours.map(String.init) ?? "",
                alhoqMaxRevisions: listing.alhoqMaxRevisions.map(String.init) ?? "",
                location: listing.location ?? "",
                targetScope: listing.targetScope,
                latitude: listing.latitude,
                longitude: listing.longitude,
                contactPhone: listing.contactPhone ?? "",
                contactEmail: listing.contactEmail ?? "",
                isAnonymous: listing.isAnonymous,
                imageUrls: listing.images.map(\.path)
            )
        }
    }

    var selectedCategory: Category? {
        categories.first { $0.id == form.categoryId }
    }

    var isEditing: Bool { editingListing != nil }

    func loadCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        categories = (try? await api.categories()) ?? []
    }

    /// Section 5.5: "image_urls required|array|min:1|max:10" (create), edit-এ nullable কিন্তু max:10 বজায় থাকে
    func uploadAndAddImage(fileURL: URL) async {
        guard form.imageUrls.count + uploadingImageCount < 10 else { return }
        uploadingImageCount += 1
        defer { uploadingImageCount -= 1 }
        do {
            let secureURL = try await uploader.upload(fileURL: fileURL)
            form.imageUrls.append(secureURL)
        } catch let error as APIError {
            imageUploadError = error.localizedDescription
        } catch {
            imageUploadError = "ছবি আপলোড ব্যর্থ হয়েছে।"
        }
    }

    func removeNewImage(at index: Int) {
        form.imageUrls.remove(at: index)
    }

    /// edit mode: বিদ্যমান ছবি মুছার জন্য আলাদাভাবে ট্র্যাক করা হয় (web: remove_images[])
    func markExistingImageForRemoval(_ imageId: Int) {
        form.removeImageIds.append(imageId)
    }

    func submit() async {
        fieldErrors = [:]
        generalError = nil

        guard let categoryId = form.categoryId else {
            fieldErrors["category_id"] = ["ক্যাটাগরি নির্বাচন করুন।"]
            return
        }
        if form.title.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors["title"] = ["শিরোনাম আবশ্যক।"]
        }
        if form.description.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors["description"] = ["বিবরণ আবশ্যক।"]
        }
        if !isEditing && form.imageUrls.isEmpty {
            fieldErrors["image_urls"] = ["কমপক্ষে ১টা ছবি আপলোড করুন।"]
        }
        guard fieldErrors.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        let request = ListingFormRequest(
            categoryId: categoryId,
            title: form.title,
            description: form.description,
            metaTitle: form.metaTitle.isEmpty ? nil : form.metaTitle,
            metaDescription: form.metaDescription.isEmpty ? nil : form.metaDescription,
            price: Double(form.price),
            priceType: form.priceType,
            requiresPayment: form.requiresPayment,
            alhoqDeliveryHours: Int(form.alhoqDeliveryHours),
            alhoqMaxRevisions: Int(form.alhoqMaxRevisions),
            location: form.location.isEmpty ? nil : form.location,
            targetScope: form.targetScope,
            latitude: form.latitude,
            longitude: form.longitude,
            contactPhone: form.contactPhone.isEmpty ? nil : form.contactPhone,
            contactEmail: form.contactEmail.isEmpty ? nil : form.contactEmail,
            isAnonymous: form.isAnonymous,
            imageUrls: form.imageUrls,
            removeImageIds: form.removeImageIds.isEmpty ? nil : form.removeImageIds,
            enableBookingSchedule: form.enableBookingSchedule,
            schedule: form.enableBookingSchedule ? form.schedule : nil
        )

        do {
            if let editingListing {
                _ = try await api.update(id: editingListing.id, request)
            } else {
                _ = try await api.create(request)
            }
            didSaveSuccessfully = true
        } catch let error as APIError {
            switch error {
            case .validation(let errors):
                fieldErrors = errors
            case .forbidden:
                // web: "You need to get Trusted in {category} before posting here." / listing-limit error
                generalError = error.localizedDescription
            default:
                generalError = error.localizedDescription
            }
        } catch {
            generalError = "কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।"
        }
    }
}
