import Foundation

public enum RuntimeConfig {
    public static func apiKey(at url: URL) throws -> String {
        try apiKey(fromYAML: String(contentsOf: url, encoding: .utf8))
    }

    public static func apiKey(fromYAML yaml: String) throws -> String {
        var apiKeysIndent: Int?
        for rawLine in yaml.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "api_keys:" {
                apiKeysIndent = indent
                continue
            }
            guard let sectionIndent = apiKeysIndent else { continue }
            if !trimmed.isEmpty && indent <= sectionIndent {
                apiKeysIndent = nil
                continue
            }
            guard trimmed.hasPrefix("key:") else { continue }
            let value = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        throw RuntimeConfigError.apiKeyMissing
    }
}

public enum RuntimeConfigError: LocalizedError {
    case apiKeyMissing

    public var errorDescription: String? {
        "No API key was found under web.authentication.api_keys."
    }
}
