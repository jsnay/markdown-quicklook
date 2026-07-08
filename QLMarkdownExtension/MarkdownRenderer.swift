import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Renders a Markdown file to a complete, styled HTML document.
/// Never throws: on any failure it degrades to escaped plain text with an error banner.
enum MarkdownRenderer {

    struct Rendered {
        let html: String
        let banner: String?
    }

    // MARK: - Public

    static func renderDocument(at url: URL) -> Rendered {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            let banner = "Could not read file: \(escape(error.localizedDescription))"
            return Rendered(html: htmlDocument(body: "<pre></pre>", banner: banner), banner: banner)
        }

        var banner: String? = nil
        let markdown: String
        if let utf8 = String(data: data, encoding: .utf8) {
            markdown = utf8
        } else {
            // Invalid UTF-8: decode lossily (invalid bytes become U+FFFD) and warn.
            markdown = String(decoding: data, as: UTF8.self)
            banner = "This file contains invalid UTF-8; some characters were replaced."
        }

        if let body = gfmToHTML(markdown) {
            return Rendered(html: htmlDocument(body: body, banner: banner), banner: banner)
        }

        // Parser failure: show raw text rather than a blank panel.
        let failBanner = banner ?? "Markdown could not be parsed; showing raw text."
        return Rendered(
            html: htmlDocument(body: "<pre>\(escape(markdown))</pre>", banner: failBanner),
            banner: failBanner
        )
    }

    // MARK: - cmark-gfm

    private static func gfmToHTML(_ markdown: String) -> String? {
        cmark_gfm_core_extensions_ensure_registered()

        let options = CMARK_OPT_DEFAULT | CMARK_OPT_FOOTNOTES
        guard let parser = cmark_parser_new(options) else { return nil }
        defer { cmark_parser_free(parser) }

        for name in ["table", "autolink", "strikethrough", "tasklist"] {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        var result: String?
        markdown.withCString { cString in
            cmark_parser_feed(parser, cString, strlen(cString))
            guard let doc = cmark_parser_finish(parser) else { return }
            defer { cmark_node_free(doc) }
            if let html = cmark_render_html(doc, options, cmark_parser_get_syntax_extensions(parser)) {
                defer { free(html) }
                result = String(cString: html)
            }
        }
        return result
    }

    // MARK: - HTML assembly

    private static func htmlDocument(body: String, banner: String?) -> String {
        let bannerHTML = banner.map {
            #"<div class="error-banner">⚠️ \#($0)</div>"#
        } ?? ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>\(stylesheet)</style>
        </head>
        <body>
        \(bannerHTML)
        <article class="markdown-body">
        \(body)
        </article>
        </body>
        </html>
        """
    }

    private static let stylesheet: String = {
        guard
            let url = Bundle(for: PreviewViewController.self).url(forResource: "style", withExtension: "css"),
            let css = try? String(contentsOf: url, encoding: .utf8)
        else {
            // Minimal fallback so a missing resource never yields an unstyled wall of text.
            return "body{font-family:-apple-system,sans-serif;max-width:52em;margin:2em auto;padding:0 1em;}pre,code{font-family:ui-monospace,monospace;}"
        }
        return css
    }()

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
