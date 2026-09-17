import SwiftUI
import WebKit

struct StaticPageView: View {
    let slug: StaticPageSlug
    @State private var page: StaticPage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let api: StaticPageAPIProtocol = StaticPageAPI()

    var body: some View {
        Group {
            if let page {
                HTMLContentView(html: page.content)
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle(page?.title ?? slug.titleBn)
        .task {
            isLoading = true
            defer { isLoading = false }
            do { page = try await api.page(slug: slug.rawValue) }
            catch { errorMessage = "লোড করা যায়নি।" }
        }
    }
}

/// zip: Page.content HTML স্ট্রিং (CMS-এর মতো) — plain Text দেখালে ফরম্যাটিং হারিয়ে যেত,
/// তাই WKWebView দিয়ে সরাসরি HTML render করা হচ্ছে (Cloudinary/API কল না, শুধু local render)
private struct HTMLContentView: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) {
        // ডিভাইসের ফন্ট সাইজ স্কেলের সাথে মিলিয়ে viewport বসানো, নাহলে খুব ছোট দেখাতে পারে
        let styled = "<html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"></head><body style=\"font-family:-apple-system;padding:12px;\">\(html)</body></html>"
        webView.loadHTMLString(styled, baseURL: nil)
    }
}

struct ContactFormView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSend = false
    private let api: StaticPageAPIProtocol = StaticPageAPI()

    var body: some View {
        if didSend {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
                Text("মেসেজ পাঠানো হয়েছে!").font(.title3.bold())
                Text("দ্রুত সাড়া দেওয়া হবে।").font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                TextField("নাম", text: $name)
                TextField("ইমেইল", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                TextField("ফোন (ঐচ্ছিক)", text: $phone).keyboardType(.phonePad)
                TextField("বিষয় (ঐচ্ছিক)", text: $subject)
                TextField("মেসেজ", text: $message, axis: .vertical).lineLimit(4...10)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Button {
                    Task { await send() }
                } label: {
                    if isSending { ProgressView().frame(maxWidth: .infinity) } else { Text("পাঠান").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || email.isEmpty || message.isEmpty || isSending)
            }
            .navigationTitle("যোগাযোগ করুন")
        }
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await api.sendContactMessage(ContactMessageRequest(
                name: name, email: email, phone: phone.isEmpty ? nil : phone,
                subject: subject.isEmpty ? nil : subject, message: message
            ))
            didSend = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "পাঠানো যায়নি।"
        }
    }
}
