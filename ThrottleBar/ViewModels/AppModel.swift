import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var rules: [AppRule] = []
    @Published private(set) var runningApps: [RunningAppSnapshot] = []
    @Published private(set) var activeLimiters: [LimiterSnapshot] = []
    @Published private(set) var ruleDiagnostics: [RuleRuntimeSnapshot] = []
    @Published private(set) var cpulimitPath: String?
    @Published private(set) var launchAtLoginStatus: SMAppService.Status = .notRegistered
    @Published var launchAtLoginEnabled = false
    @Published var lastError: String?

    private let controller = CPULimitController()
    private let launchAtLoginService = LaunchAtLoginService()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        rules = RuleStore.load()
        refreshCPULimitPath()
        refreshLaunchAtLoginStatus()
        refreshRunningApps()
        startMonitoring()
        reconcile()
    }

    var statusIconName: String {
        if cpulimitPath == nil {
            return "exclamationmark.triangle.fill"
        }

        return activeLimiters.isEmpty ? "speedometer" : "bolt.circle.fill"
    }

    var availableApps: [RunningAppSnapshot] {
        runningApps.filter { app in
            rules.contains(where: { $0.matches(app) }) == false
        }
    }

    func addRule(for app: RunningAppSnapshot) {
        guard rules.contains(where: { $0.matches(app) }) == false else {
            return
        }

        rules.append(.make(from: app))
        persistAndReconcile()
    }

    func removeRule(_ id: UUID) {
        rules.removeAll { $0.id == id }
        persistAndReconcile()
    }

    func setRuleEnabled(_ id: UUID, isEnabled: Bool) {
        updateRule(id) { $0.isEnabled = isEnabled }
    }

    var maxCPULimit: Int {
        CPULimitScale.maxLimit()
    }

    var cpuLimitScaleDescription: String {
        CPULimitScale.scaleDescription()
    }

    func shortLimitLabel(for limit: Int) -> String {
        CPULimitScale.shortLabel(for: limit)
    }

    func detailLimitLabel(for limit: Int) -> String {
        CPULimitScale.detailLabel(for: limit)
    }

    func setRuleLimit(_ id: UUID, limit: Int) {
        updateRule(id) { $0.cpuLimit = CPULimitScale.clamp(limit) }
    }

    func setRuleIncludeChildren(_ id: UUID, includeChildren: Bool) {
        updateRule(id) { $0.includeChildren = includeChildren }
    }

    func refreshEnvironment() {
        refreshCPULimitPath()
        refreshRunningApps()
        refreshLaunchAtLoginStatus()
        reconcile()
    }

    func openCPULimitGuide() {
        guard let url = URL(string: "https://formulae.brew.sh/formula/cpulimit") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openLoginItemsSettings() {
        launchAtLoginService.openSystemSettings()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func shutdown() {
        controller.stopAll()
        cancellables.removeAll()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
        } catch {
            lastError = error.localizedDescription
            refreshLaunchAtLoginStatus()
        }
    }

    func statusText(for rule: AppRule) -> String {
        diagnostic(for: rule)?.statusDetail ?? "No diagnostics yet"
    }

    func diagnostic(for rule: AppRule) -> RuleRuntimeSnapshot? {
        ruleDiagnostics.first(where: { $0.ruleID == rule.id })
    }

    func launchAtLoginDescription() -> String {
        switch launchAtLoginStatus {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Disabled"
        case .requiresApproval:
            return "Waiting for approval in Login Items"
        case .notFound:
            return "Unavailable in this build"
        @unknown default:
            return "Unknown status"
        }
    }

    private func startMonitoring() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        workspaceCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: workspaceCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification))
            .sink { [weak self] _ in
                self?.refreshRunningApps()
                self?.reconcile()
            }
            .store(in: &cancellables)

        Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshRunningApps()
                self?.reconcile()
            }
            .store(in: &cancellables)
    }

    private func refreshCPULimitPath() {
        cpulimitPath = CPULimitLocator.locate()?.path
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLoginService.status()
        launchAtLoginEnabled = launchAtLoginStatus == .enabled
    }

    private func refreshRunningApps() {
        let currentPID = ProcessInfo.processInfo.processIdentifier

        runningApps = NSWorkspace.shared.runningApplications
            .filter { app in
                app.processIdentifier != currentPID &&
                app.isTerminated == false &&
                app.activationPolicy == .regular &&
                app.localizedName != nil
            }
            .map(RunningAppSnapshot.init(application:))
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func persistAndReconcile() {
        RuleStore.save(rules)
        reconcile()
    }

    private func reconcile() {
        lastError = nil
        let binaryURL = cpulimitPath.map(URL.init(fileURLWithPath:))
        controller.reconcile(binaryURL: binaryURL, rules: rules, runningApps: runningApps)
        activeLimiters = controller.snapshots()
        ruleDiagnostics = controller.diagnostics(for: rules)

        if let failingDiagnostic = ruleDiagnostics.first(where: { $0.state == .failedToStart }) {
            lastError = failingDiagnostic.note
        }
    }

    private func updateRule(_ id: UUID, mutate: (inout AppRule) -> Void) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&rules[index])
        persistAndReconcile()
    }
}
