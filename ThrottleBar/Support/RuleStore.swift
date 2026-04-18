import Foundation

enum RuleStore {
    private static let defaultsKey = "ThrottleBar.rules"

    static func load(defaults: UserDefaults = .standard) -> [AppRule] {
        guard let data = defaults.data(forKey: defaultsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([AppRule].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ rules: [AppRule], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(rules) else {
            return
        }

        defaults.set(data, forKey: defaultsKey)
    }
}

