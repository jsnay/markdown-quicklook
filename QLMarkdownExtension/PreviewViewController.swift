import Cocoa
import Quartz
import WebKit

final class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        // Let the page's CSS background (light/dark aware) show through.
        webView.setValue(false, forKey: "drawsBackground")
        view.addSubview(webView)
    }

    // MARK: - QLPreviewingController

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let html = MarkdownRenderer.renderDocument(at: url)
            DispatchQueue.main.async { [weak self] in
                self?.webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
                handler(nil)
            }
        }
    }
}
