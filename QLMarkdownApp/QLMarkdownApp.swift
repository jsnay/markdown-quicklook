import SwiftUI

@main
struct QLMarkdownApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 460, height: 300)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("QLMarkdown is installed")
                .font(.title2.bold())

            Text("""
            Launching this app registers the Markdown Quick Look extension. \
            If previews don't appear, enable it under:
            System Settings → General → Login Items & Extensions → Quick Look
            """)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal)

            Button("Open Extension Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.quicklook.preview") {
                    NSWorkspace.shared.open(url)
                }
            }

            Text("Then press Space on any .md file in Finder.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
