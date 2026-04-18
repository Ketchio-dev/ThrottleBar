import Foundation

struct LimiterSnapshot: Identifiable, Hashable {
    let pid: pid_t
    let ruleID: UUID
    let appName: String
    let limit: Int
    let includeChildren: Bool

    var id: pid_t { pid }
}

@MainActor
final class CPULimitController {
    private struct ManagedLimiter {
        let ruleID: UUID
        let target: RunningAppSnapshot
        let process: Process
        let limit: Int
        let includeChildren: Bool
    }

    private var active: [pid_t: ManagedLimiter] = [:]

    func reconcile(binaryURL: URL?, rules: [AppRule], runningApps: [RunningAppSnapshot]) {
        guard let binaryURL else {
            stopAll()
            return
        }

        var desired: [pid_t: (RunningAppSnapshot, AppRule)] = [:]
        let enabledRules = rules.filter(\.isEnabled)

        for app in runningApps {
            if let rule = enabledRules.first(where: { $0.matches(app) }) {
                desired[app.pid] = (app, rule)
            }
        }

        let obsoletePIDs = Set(active.keys).subtracting(desired.keys)
        obsoletePIDs.forEach(stopLimiter(for:))

        for (pid, payload) in desired {
            let app = payload.0
            let rule = payload.1

            if let existing = active[pid],
               existing.ruleID == rule.id,
               existing.limit == rule.cpuLimit,
               existing.includeChildren == rule.includeChildren {
                continue
            }

            stopLimiter(for: pid)
            startLimiter(binaryURL: binaryURL, app: app, rule: rule)
        }
    }

    func snapshots() -> [LimiterSnapshot] {
        active.values
            .map {
                LimiterSnapshot(
                    pid: $0.target.pid,
                    ruleID: $0.ruleID,
                    appName: $0.target.displayName,
                    limit: $0.limit,
                    includeChildren: $0.includeChildren
                )
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    func stopAll() {
        let pids = Array(active.keys)
        pids.forEach(stopLimiter(for:))
    }

    private func startLimiter(binaryURL: URL, app: RunningAppSnapshot, rule: AppRule) {
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments(for: rule, pid: app.pid)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let pid = app.pid
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.active.removeValue(forKey: pid)
            }
        }

        do {
            try process.run()
            active[pid] = ManagedLimiter(
                ruleID: rule.id,
                target: app,
                process: process,
                limit: rule.cpuLimit,
                includeChildren: rule.includeChildren
            )
        } catch {
            active.removeValue(forKey: pid)
        }
    }

    private func stopLimiter(for pid: pid_t) {
        guard let managed = active.removeValue(forKey: pid) else {
            return
        }

        if managed.process.isRunning {
            managed.process.terminate()
        }
    }

    private func arguments(for rule: AppRule, pid: pid_t) -> [String] {
        var args = ["-p", "\(pid)", "-l", "\(rule.cpuLimit)"]
        if rule.includeChildren {
            args.append("-i")
        }
        return args
    }
}

