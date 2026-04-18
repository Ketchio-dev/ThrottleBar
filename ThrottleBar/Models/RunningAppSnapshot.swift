import AppKit

struct RunningAppSnapshot: Identifiable, Hashable {
    let pid: pid_t
    let bundleIdentifier: String?
    let bundleURLPath: String?
    let executablePath: String?
    let displayName: String
    let icon: NSImage?

    var id: String {
        bundleIdentifier ?? executablePath ?? "\(pid)"
    }

    init(
        pid: pid_t,
        bundleIdentifier: String?,
        bundleURLPath: String?,
        executablePath: String?,
        displayName: String,
        icon: NSImage? = nil
    ) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.bundleURLPath = bundleURLPath
        self.executablePath = executablePath
        self.displayName = displayName
        self.icon = icon
    }

    init(application: NSRunningApplication) {
        self.init(
            pid: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            bundleURLPath: application.bundleURL?.path,
            executablePath: application.executableURL?.path,
            displayName: application.localizedName ?? application.bundleIdentifier ?? "Unknown App",
            icon: application.icon
        )
    }
}

