import SwiftUI
import WebKit

enum CheckoutOutcome {
    case success(sessionId: String?)
    case cancelled
}

/// zip-এ কনফার্ম হওয়া Stripe Checkout সেশন হোস্টেড পেজ — SFSafariViewController-এর বদলে
/// WKWebView ব্যবহার করা হয়েছে কারণ SFSafariViewController-এ navigation intercept করার কোনো
/// delegate নেই, তাই success/cancel URL শনাক্ত করা যেত না। এখানে WKNavigationDelegate দিয়ে
/// প্রতিটা navigation চেক করে matchPath-এর সাথে মিললেই ফলাফল রিপোর্ট করা হয়।
struct CheckoutWebView: UIViewControllerRepresentable {
    let checkoutURL: URL
    let successPath: String
    let cancelPath: String
    let onFinish: (CheckoutOutcome) -> Void

    func makeUIViewController(context: Context) -> CheckoutWebViewController {
        CheckoutWebViewController(
            checkoutURL: checkoutURL, successPath: successPath, cancelPath: cancelPath, onFinish: onFinish
        )
    }

    func updateUIViewController(_ uiViewController: CheckoutWebViewController, context: Context) {}
}

final class CheckoutWebViewController: UIViewController, WKNavigationDelegate {
    private let checkoutURL: URL
    private let successPath: String
    private let cancelPath: String
    private let onFinish: (CheckoutOutcome) -> Void
    private var webView: WKWebView!
    private var finished = false

    init(checkoutURL: URL, successPath: String, cancelPath: String, onFinish: @escaping (CheckoutOutcome) -> Void) {
        self.checkoutURL = checkoutURL
        self.successPath = successPath
        self.cancelPath = cancelPath
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.load(URLRequest(url: checkoutURL))
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !finished, let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        if url.path == successPath {
            finished = true
            let sessionId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "session_id" })?.value
            onFinish(.success(sessionId: sessionId))
            decisionHandler(.cancel)
            return
        }
        if url.path == cancelPath {
            finished = true
            onFinish(.cancelled)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
