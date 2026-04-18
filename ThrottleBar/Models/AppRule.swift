import Foundation

struct AppRule: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var bundleIdentifier: String?
    var executablePath: String?
    var cpuLimit: Int
    var includeChildren: Bool
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        bundleIdentifier: String?,
        executablePath: String?,
        cpuLimit: Int = 100,
        includeChildren: Bool = true,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
        self.cpuLimit = cpuLimit
        self.includeChildren = includeChildren
        self.isEnabled = isEnabled
    }

    static func make(from app: RunningAppSnapshot) -> AppRule {
        AppRule(
            displayName: app.displayName,
            bundleIdentifier: app.bundleIdentifier,
            executablePath: app.executablePath,
            cpuLimit: 100,
            includeChildren: true,
            isEnabled: true
        )
    }

    func matches(_ app: RunningAppSnapshot) -> Bool {
        if let bundleIdentifier, bundleIdentifier == app.bundleIdentifier {
            return true
        }

        if let executablePath, executablePath == app.executablePath {
            return true
        }

        return false
    }
}

