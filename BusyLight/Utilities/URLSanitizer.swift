import Foundation

enum URLSanitizer {
    /// Cleans a user-entered Home Assistant base URL:
    /// 1. Trims leading/trailing whitespace
    /// 2. Strips trailing slashes
    /// 3. Prepends `http://` if no scheme is present
    static func sanitize(_ input: String) -> String {
        var result = input.trimmingCharacters(in: .whitespaces)

        guard !result.isEmpty else { return result }

        // Prepend scheme if missing
        if !result.lowercased().hasPrefix("http://") && !result.lowercased().hasPrefix("https://") {
            result = "http://" + result
        }

        // Strip trailing slashes
        while result.hasSuffix("/") {
            result.removeLast()
        }

        return result
    }

    /// Returns `true` if the sanitized URL can be parsed by `URL(string:)`
    /// and has a non-empty host.
    static func isValid(_ url: String) -> Bool {
        guard !url.isEmpty,
              let parsed = URL(string: url),
              let host = parsed.host(),
              !host.isEmpty else {
            return false
        }
        return true
    }
}
