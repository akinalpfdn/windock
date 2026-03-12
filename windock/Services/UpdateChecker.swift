import AppKit

final class UpdateChecker {

    // MARK: - Public

    static func check(repo: String, releasePageURL: URL) {
        // Run off the main thread — silent if network is unavailable
        Task.detached(priority: .utility) {
            guard let release = try? await fetchLatestRelease(repo: repo),
                  isNewer(release.tagName) else { return }
            await MainActor.run {
                showAlert(version: release.tagName, releasePageURL: releasePageURL)
            }
        }
    }

    // MARK: - Private

    private struct Release: Decodable {
        let tagName: String
        enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
    }

    private static func fetchLatestRelease(repo: String) async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Release.self, from: data)
    }

    private static func isNewer(_ tagName: String) -> Bool {
        let remote = versionComponents(tagName)
        let current = versionComponents(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
        for (r, c) in zip(remote, current) {
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    /// Strips any leading "v", splits on ".", pads to 3 components.
    private static func versionComponents(_ tag: String) -> [Int] {
        tag.trimmingCharacters(in: .letters)
           .split(separator: ".")
           .compactMap { Int($0) }
           .padded(to: 3)
    }

    private static func showAlert(version: String, releasePageURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "WinDock \(version) is available on GitHub."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releasePageURL)
        }
    }
}

private extension Array where Element == Int {
    func padded(to length: Int) -> [Int] {
        self + Array(repeating: 0, count: Swift.max(0, length - count))
    }
}
