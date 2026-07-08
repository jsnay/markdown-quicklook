import Cocoa
import Quartz
import WebKit
import os.log

final class PreviewViewController: NSViewController, QLPreviewingController {

    private static let logger = Logger(subsystem: "com.jeremynay.qlmarkdown", category: "preview")

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
        let start = Date()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MarkdownRenderer.renderDocument(at: url)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            Self.logger.log("rendered \(url.lastPathComponent, privacy: .public) in \(ms, privacy: .public)ms banner=\(result.banner != nil, privacy: .public)")
            DispatchQueue.main.async { [weak self] in
                self?.webView.loadHTMLString(result.html, baseURL: url.deletingLastPathComponent())
                handler(nil)
            }
        }
    }
}
