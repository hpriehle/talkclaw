import SwiftUI
import WebKit
import SharedModels

/// WKWebView wrapper that renders a widget's HTML page.
/// Each widget gets its own WKProcessPool for isolation.
/// Communicates with the host app via WKScriptMessageHandler.
struct WidgetWebView: UIViewRepresentable {
    let slug: String
    let serverURL: String
    let apiKey: String
    var allowsScrolling: Bool = false
    var isDashboard: Bool = false
    var onMessage: ((WidgetBridgeMessage) -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(slug: slug, allowsScrolling: allowsScrolling, isDashboard: isDashboard, onMessage: onMessage, onHeightChange: onHeightChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Enable inline media playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Register JS bridge handler
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "talkclaw")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = context.coordinator.allowsScrolling
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false

        // Load widget URL
        if let url = URL(string: "\(serverURL)/w/\(slug)?token=\(apiKey)") {
            webView.load(URLRequest(url: url))
        }

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // No dynamic updates needed — widget reloads via WS event
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "talkclaw")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let slug: String
        let allowsScrolling: Bool
        let isDashboard: Bool
        var onMessage: ((WidgetBridgeMessage) -> Void)?
        var onHeightChange: ((CGFloat) -> Void)?
        weak var webView: WKWebView?

        init(slug: String, allowsScrolling: Bool, isDashboard: Bool, onMessage: ((WidgetBridgeMessage) -> Void)?, onHeightChange: ((CGFloat) -> Void)?) {
            self.slug = slug
            self.allowsScrolling = allowsScrolling
            self.isDashboard = isDashboard
            self.onMessage = onMessage
            self.onHeightChange = onHeightChange
            super.init()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleWidgetUpdated(_:)),
                name: .widgetUpdated,
                object: nil
            )
        }

        @objc private func handleWidgetUpdated(_ notification: Notification) {
            guard let payload = notification.userInfo?["payload"] as? WidgetPayload,
                  payload.slug == slug else { return }
            reload()
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "talkclaw",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String,
                  let payload = body["payload"] as? [String: Any] else { return }

            switch action {
            case "reportHeight":
                if let height = payload["height"] as? CGFloat {
                    DispatchQueue.main.async { [weak self] in
                        self?.onHeightChange?(height)
                    }
                }
            case "sendMessage":
                if let text = payload["message"] as? String {
                    onMessage?(.sendMessage(text))
                }
            case "sendStructured":
                if let type = payload["type"] as? String,
                   let data = payload["data"] as? [String: Any] {
                    onMessage?(.sendStructured(type: type, data: data))
                }
            case "setVars":
                if let vars = payload["vars"] as? [String: String] {
                    onMessage?(.setVars(vars))
                }
            case "pinToDashboard":
                let sizeStr = payload["size"] as? String ?? "small"
                let size = WidgetSize(rawValue: sizeStr) ?? .small
                onMessage?(.pinToDashboard(size: size))
            case "dismiss":
                onMessage?(.dismiss)
            default:
                break
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Remove top border-radius when rendered inside dashboard card header
            if isDashboard {
                let css = "var s=document.createElement('style');s.textContent='.tc-glass{border-top-left-radius:0!important;border-top-right-radius:0!important}';document.head.appendChild(s);"
                webView.evaluateJavaScript(css, completionHandler: nil)
            }

            // Query height after page loads
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self?.onHeightChange?(height)
                    }
                }
            }
        }

        /// Reload the widget content (called when widgetUpdated WS event fires)
        func reload() {
            webView?.reload()
        }
    }
}

// MARK: - Bridge Messages

enum WidgetBridgeMessage {
    case sendMessage(String)
    case sendStructured(type: String, data: [String: Any])
    case setVars([String: String])
    case pinToDashboard(size: WidgetSize)
    case dismiss
}

