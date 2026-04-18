import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                cpulimitSection
                controlsSection
                managedRulesSection
                runningAppsSection
                footerSection
            }
            .padding(16)
        }
        .frame(width: 420, height: 620)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ThrottleBar")
                .font(.title2.weight(.semibold))
            Text("Per-app CPU caps for macOS menu bar workflows.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let lastError = model.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var cpulimitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("cpulimit")
                .font(.headline)

            if let path = model.cpulimitPath {
                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("Not found. Install it with Homebrew before enabling limits.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Refresh Environment") {
                    model.refreshEnvironment()
                }

                if model.cpulimitPath == nil {
                    Button("Open Install Guide") {
                        model.openCPULimitGuide()
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("System")
                .font(.headline)

            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            )

            Text(model.launchAtLoginDescription())
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.launchAtLoginStatus == .requiresApproval {
                Button("Open Login Items Settings") {
                    model.openLoginItemsSettings()
                }
            }
        }
    }

    private var managedRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Managed Apps")
                .font(.headline)

            if model.rules.isEmpty {
                Text("No rules yet. Add one from the running apps list below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.rules) { rule in
                    RuleEditorRow(rule: rule, status: model.statusText(for: rule), model: model)
                    if rule.id != model.rules.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var runningAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Running Apps")
                .font(.headline)

            if model.availableApps.isEmpty {
                Text("No unmanaged foreground apps found right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.availableApps.prefix(10))) { app in
                    RunningAppRow(app: app) {
                        model.addRule(for: app)
                    }
                    if app.id != model.availableApps.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Text("\(model.activeLimiters.count) active limiter\(model.activeLimiters.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") {
                model.quit()
            }
        }
    }
}

private struct RuleEditorRow: View {
    let rule: AppRule
    let status: String
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(rule.displayName)
                    .font(.body.weight(.medium))
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { rule.isEnabled },
                        set: { model.setRuleEnabled(rule.id, isEnabled: $0) }
                    )
                )
                .labelsHidden()
            }

            HStack {
                Stepper(
                    value: Binding(
                        get: { rule.cpuLimit },
                        set: { model.setRuleLimit(rule.id, limit: $0) }
                    ),
                    in: 5...1800,
                    step: 5
                ) {
                    Text("CPU cap \(rule.cpuLimit)%")
                }

                Spacer()
                Button(role: .destructive) {
                    model.removeRule(rule.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            Toggle(
                "Include child processes",
                isOn: Binding(
                    get: { rule.includeChildren },
                    set: { model.setRuleIncludeChildren(rule.id, includeChildren: $0) }
                )
            )
            .toggleStyle(.switch)

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RunningAppRow: View {
    let app: RunningAppSnapshot
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "app")
                        .resizable()
                        .padding(4)
                }
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.body)
                Text(app.bundleIdentifier ?? app.executablePath ?? "No identifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Add") {
                onAdd()
            }
        }
    }
}

