import Darwin
import Foundation

struct LimiterSnapshot: Identifiable, Hashable {
    let pid: pid_t
    let ruleID: UUID
    let appName: String
    let limit: Int
    let includeChildren: Bool
    let helperPID: pid_t

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
    private var runtimeSnapshots: [UUID: RuleRuntimeSnapshot] = [:]

    func reconcile(binaryURL: URL?, rules: [AppRule], runningApps: [RunningAppSnapshot]) {
        runtimeSnapshots.removeAll()

        guard let binaryURL else {
            stopAll()
            for rule in rules {
                runtimeSnapshots[rule.id] = RuleRuntimeSnapshot(
                    ruleID: rule.id,
                    appName: rule.displayName,
                    state: rule.isEnabled ? .missingBinary : .paused,
                    limit: rule.cpuLimit,
                    targetPID: nil,
                    helperPID: nil,
                    note: rule.isEnabled ? "Install cpulimit first" : "Rule disabled"
                )
            }
            return
        }

        let desired = desiredTargets(for: rules, runningApps: runningApps)
        let obsoletePIDs = Set(active.keys).subtracting(desired.map(\.app.pid))
        obsoletePIDs.forEach { stopLimiter(for: $0, binaryPath: binaryURL.path) }

        for rule in rules {
            guard rule.isEnabled else {
                runtimeSnapshots[rule.id] = RuleRuntimeSnapshot(
                    ruleID: rule.id,
                    appName: rule.displayName,
                    state: .paused,
                    limit: rule.cpuLimit,
                    targetPID: nil,
                    helperPID: nil,
                    note: "Rule disabled"
                )
                continue
            }

            guard let target = desired.first(where: { $0.rule.id == rule.id }) else {
                runtimeSnapshots[rule.id] = RuleRuntimeSnapshot(
                    ruleID: rule.id,
                    appName: rule.displayName,
                    state: .waitingForApp,
                    limit: rule.cpuLimit,
                    targetPID: nil,
                    helperPID: nil,
                    note: "Launch the app to start throttling"
                )
                continue
            }

            let app = target.app
            let pid = app.pid
            let externalHelperPIDs = limiterProcessIDs(binaryPath: binaryURL.path, targetPID: pid)

            if let existing = active[pid],
               existing.ruleID == rule.id,
               existing.limit == rule.cpuLimit,
               existing.includeChildren == rule.includeChildren,
               isProcessAlive(existing.process.processIdentifier),
               externalHelperPIDs.contains(existing.process.processIdentifier) || externalHelperPIDs.isEmpty {
                runtimeSnapshots[rule.id] = makeActiveRuntimeSnapshot(for: rule, app: app, helperPID: existing.process.processIdentifier)
                continue
            }

            stopLimiter(for: pid, binaryPath: binaryURL.path)

            if let limiter = startLimiter(binaryURL: binaryURL, app: app, rule: rule) {
                runtimeSnapshots[rule.id] = makeActiveRuntimeSnapshot(for: rule, app: app, helperPID: limiter.process.processIdentifier)
            } else {
                runtimeSnapshots[rule.id] = RuleRuntimeSnapshot(
                    ruleID: rule.id,
                    appName: rule.displayName,
                    state: .failedToStart,
                    limit: rule.cpuLimit,
                    targetPID: pid,
                    helperPID: nil,
                    note: "cpulimit helper failed to start"
                )
            }
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
                    includeChildren: $0.includeChildren,
                    helperPID: $0.process.processIdentifier
                )
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    func diagnostics(for rules: [AppRule]) -> [RuleRuntimeSnapshot] {
        rules.compactMap { runtimeSnapshots[$0.id] }
    }

    func stopAll() {
        let managed = Array(active.values)
        active.removeAll()

        for limiter in managed {
            if limiter.process.isRunning {
                limiter.process.terminate()
            }
            terminateExternalLimiters(binaryPath: limiter.process.executableURL?.path, targetPID: limiter.target.pid)
        }
    }

    @discardableResult
    private func startLimiter(binaryURL: URL, app: RunningAppSnapshot, rule: AppRule) -> ManagedLimiter? {
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments(for: rule, pid: app.pid)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let limiter = ManagedLimiter(
                ruleID: rule.id,
                target: app,
                process: process,
                limit: rule.cpuLimit,
                includeChildren: rule.includeChildren
            )
            active[app.pid] = limiter
            return limiter
        } catch {
            active.removeValue(forKey: app.pid)
            return nil
        }
    }

    private func stopLimiter(for pid: pid_t, binaryPath: String) {
        guard let managed = active.removeValue(forKey: pid) else {
            terminateExternalLimiters(binaryPath: binaryPath, targetPID: pid)
            return
        }

        if managed.process.isRunning {
            managed.process.terminate()
        }

        terminateExternalLimiters(binaryPath: binaryPath, targetPID: pid)
    }

    private func arguments(for rule: AppRule, pid: pid_t) -> [String] {
        var args = ["-p", "\(pid)", "-l", "\(rule.cpuLimit)"]
        if rule.includeChildren {
            args.append("-i")
        }
        return args
    }

    private func terminateExternalLimiters(binaryPath: String?, targetPID: pid_t) {
        guard let binaryPath else {
            return
        }

        for limiterPID in limiterProcessIDs(binaryPath: binaryPath, targetPID: targetPID) {
            kill(limiterPID, SIGTERM)
        }
    }

    private func limiterProcessIDs(binaryPath: String, targetPID: pid_t) -> [pid_t] {
        guard let output = try? processListOutput() else {
            return []
        }

        return Self.parseLimiterProcessIDs(from: output, binaryPath: binaryPath, targetPID: targetPID)
    }

    private func desiredTargets(for rules: [AppRule], runningApps: [RunningAppSnapshot]) -> [(rule: AppRule, app: RunningAppSnapshot)] {
        let enabledRules = rules.filter(\.isEnabled)
        return runningApps.compactMap { app in
            enabledRules.first(where: { $0.matches(app) }).map { ($0, app) }
        }
    }

    private func isProcessAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    private func makeActiveRuntimeSnapshot(for rule: AppRule, app: RunningAppSnapshot, helperPID: pid_t) -> RuleRuntimeSnapshot {
        RuleRuntimeSnapshot(
            ruleID: rule.id,
            appName: rule.displayName,
            state: .active,
            limit: rule.cpuLimit,
            targetPID: app.pid,
            helperPID: helperPID,
            note: "Throttling is live"
        )
    }

    private func processListOutput() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    nonisolated static func parseLimiterProcessIDs(from output: String, binaryPath: String, targetPID: pid_t) -> [pid_t] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> pid_t? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.isEmpty == false else {
                    return nil
                }

                let parts = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard parts.count == 2,
                      let pid = pid_t(parts[0]),
                      parts[1].contains(binaryPath),
                      parts[1].contains("-p \(targetPID)") else {
                    return nil
                }

                return pid
            }
    }
}
