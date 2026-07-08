import Cocoa
import Quartz
import WebKit
import os.log

/// Root view that reports system appearance changes so the preview can restyle
/// live. `viewDidChangeEffectiveAppearance` exists on NSView, not NSViewController.
final class AppearanceReportingView: NSView {
    var onAppearanceChange: (() -> Void)?
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

final class PreviewViewController: NSViewController, QLPreviewingController {

    private static let logger = Logger(subsystem: "com.jeremynay.qlmarkdown", category: "preview")

    private var webView: WKWebView!
    private var renderedHTML: String?

    override func loadView() {
        let root = AppearanceReportingView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        root.onAppearanceChange = { [weak self] in self?.applyCurrentTheme() }
        view = root

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        // Keep the web view opaque and painting its own background. A transparent
        // web view lets whatever is behind the Quick Look panel bleed through.
        webView.setValue(true, forKey: "drawsBackground")
        view.addSubview(webView)
    }

    // MARK: - QLPreviewingController

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let start = Date()
        let dark = isDarkAppearance
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MarkdownRenderer.renderDocument(at: url, isDark: dark)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            Self.logger.log("rendered \(url.lastPathComponent, privacy: .public) in \(ms, privacy: .public)ms dark=\(dark, privacy: .public) banner=\(result.banner != nil, privacy: .public)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.renderedHTML = result.html
                self.webView.loadHTMLString(result.html, baseURL: url.deletingLastPathComponent())
                handler(nil)
            }
        }
    }

    // MARK: - Live appearance switching (E3)

    /// Flip the theme in place (no file re-read) when the user toggles system
    /// appearance while the preview is open.
    private func applyCurrentTheme() {
        guard webView != nil else { return }
        let dark = isDarkAppearance
        webView.evaluateJavaScript(
            "document.documentElement.setAttribute('data-theme', '\(dark ? "dark" : "light")');",
            completionHandler: nil
        )
    }

    private var isDarkAppearance: Bool {
        view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
