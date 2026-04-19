import Foundation

enum RuleRuntimeState: Hashable {
    case active
    case waitingForApp
    case paused
    case missingBinary
    case failedToStart
}

struct RuleRuntimeSnapshot: Identifiable, Hashable {
    let ruleID: UUID
    let appName: String
    let state: RuleRuntimeState
    let limit: Int
    let targetPID: pid_t?
    let helperPID: pid_t?
    let note: String

    var id: UUID { ruleID }

    var isHealthy: Bool {
        state == .active
    }

    var statusTitle: String {
        switch state {
        case .active:
            return "Active"
        case .waitingForApp:
            return "Waiting"
        case .paused:
            return "Paused"
        case .missingBinary:
            return "Setup"
        case .failedToStart:
            return "Error"
        }
    }

    var statusDetail: String {
        switch state {
        case .active:
            if let targetPID, let helperPID {
                return "Target PID \(targetPID) · Helper PID \(helperPID)"
            }
            if let targetPID {
                return "Target PID \(targetPID)"
            }
            return note
        case .waitingForApp, .paused, .missingBinary, .failedToStart:
            return note
        }
    }
}
