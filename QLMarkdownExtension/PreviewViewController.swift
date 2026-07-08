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

final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

    private static let logger = Logger(subsystem: "com.jeremynay.qlmarkdown", category: "preview")

    private var webView: WKWebView!
    private var completion: ((Error?) -> Void)?

    override func loadView() {
        let root = AppearanceReportingView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        root.onAppearanceChange = { [weak self] in self?.applyCurrentTheme() }
        view = root

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        // Keep the web view opaque and painting its own background. A transparent
        // web view lets whatever is behind the Quick Look panel bleed through.
        webView.setValue(true, forKey: "drawsBackground")
        view.addSubview(webView)
    }

    // MARK: - QLPreviewingController

    /// How long to wait for `webView(_:didFinish:)` before telling Quick Look
    /// we're ready anyway. Inside a Quick Look extension the web view is not in
    /// an on-screen window while QL waits on the completion handler, and WebKit
    /// does not reliably deliver navigation callbacks to a detached view — so
    /// gating solely on `didFinish` hangs the panel on an infinite spinner.
    /// The preview is a live remote view (not a one-shot snapshot), so firing
    /// the handler before paint completes is safe: content appears as soon as
    /// WebKit commits it.
    private static let completionFallbackDelay: TimeInterval = 0.5

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let start = Date()
        let dark = isDarkAppearance
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MarkdownRenderer.renderDocument(at: url, isDark: dark)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            Self.logger.log("rendered \(url.lastPathComponent, privacy: .public) in \(ms, privacy: .public)ms dark=\(dark, privacy: .public) banner=\(result.banner != nil, privacy: .public)")
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    handler(nil)
                    return
                }
                self.completion = handler
                // baseURL is nil on purpose: all CSS is inlined, so no external
                // resources are needed, and a file:// baseURL trips the extension
                // sandbox (it only has read access to the single previewed file).
                self.webView.loadHTMLString(result.html, baseURL: nil)
                // Race didFinish against a short fallback so Quick Look never
                // waits forever if WebKit drops the navigation callback.
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.completionFallbackDelay) { [weak self] in
                    guard let self, self.completion != nil else { return }
                    Self.logger.log("didFinish not delivered within \(Self.completionFallbackDelay, privacy: .public)s; completing via fallback")
                    self.finishPreview()
                }
            }
        }
    }

    /// Invokes the stored Quick Look completion handler exactly once.
    private func finishPreview(_ error: Error? = nil) {
        guard let handler = completion else { return }
        completion = nil
        handler(error)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishPreview()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Self.logger.error("navigation failed: \(error.localizedDescription, privacy: .public)")
        finishPreview() // Don't fail the preview; show whatever rendered.
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Self.logger.error("provisional navigation failed: \(error.localizedDescription, privacy: .public)")
        finishPreview()
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
