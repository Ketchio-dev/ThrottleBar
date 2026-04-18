import Foundation

enum CPULimitLocator {
    static func locate(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        var candidates: [URL] = []

        if let path = environment["PATH"] {
            let discovered = path
                .split(separator: ":")
                .map(String.init)
                .map { URL(fileURLWithPath: $0).appendingPathComponent("cpulimit") }
            candidates.append(contentsOf: discovered)
        }

        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin/cpulimit"),
            URL(fileURLWithPath: "/usr/local/bin/cpulimit"),
            URL(fileURLWithPath: "/usr/bin/cpulimit")
        ])

        for candidate in candidates {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}
