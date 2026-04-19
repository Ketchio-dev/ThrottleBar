import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerSection
                if model.cpulimitPath == nil {
                    cpulimitSection
                }
                controlsSection
                liveProofSection
                managedRulesSection
                runningAppsSection
                footerSection
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 380, height: 560)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: model.statusIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(model.cpulimitPath == nil ? Color.orange : Color.accentColor)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ThrottleBar")
                        .font(.title3.weight(.semibold))
                    Text(model.cpulimitPath == nil ? "cpulimit required" : "Per-app CPU caps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusPill(
                    title: model.cpulimitPath == nil ? "Setup" : "\(model.activeLimiters.count) live",
                    tint: model.cpulimitPath == nil ? .orange : .green
                )
            }

            HStack(spacing: 8) {
                SummaryTile(title: "Rules", value: "\(model.rules.count)", icon: "slider.horizontal.3")
                SummaryTile(title: "Active", value: "\(model.activeLimiters.count)", icon: "bolt.fill")
                SummaryTile(title: "Login", value: model.launchAtLoginEnabled ? "On" : "Off", icon: "person.crop.circle.badge.checkmark")
            }

            if let lastError = model.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
            }
        }
    }

    private var cpulimitSection: some View {
        cardSection {
            VStack(alignment: .leading, spacing: 10) {
                Label("Install cpulimit to enable throttling", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline)
                Text("ThrottleBar can show apps without it, but real CPU caps will not start until cpulimit is installed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Refresh") {
                        model.refreshEnvironment()
                    }
                    .buttonStyle(.bordered)

                    Button("Install Guide") {
                        model.openCPULimitGuide()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var controlsSection: some View {
        cardSection("System") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                            .font(.subheadline.weight(.medium))
                        Text(model.launchAtLoginDescription())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { model.launchAtLoginEnabled },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )
                    .labelsHidden()
                }

                HStack(spacing: 8) {
                    Button("Refresh Apps") {
                        model.refreshEnvironment()
                    }
                    .buttonStyle(.bordered)

                    if model.launchAtLoginStatus == .requiresApproval {
                        Button("Open Login Items") {
                            model.openLoginItemsSettings()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if let path = model.cpulimitPath {
                        Text(path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var managedRulesSection: some View {
        cardSection("Rules") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.cpuLimitScaleDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.rules.isEmpty {
                    EmptyStateRow(
                        title: "No app rules yet",
                        subtitle: "Pick an app below and add a cap."
                    )
                } else {
                    ForEach(model.rules) { rule in
                        RuleEditorRow(rule: rule, status: model.statusText(for: rule), model: model)
                    }
                }
            }
        }
    }

    private var liveProofSection: some View {
        cardSection("Live Proof") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Shows the actual target PID and helper PID when a rule is really attached.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.ruleDiagnostics.isEmpty {
                    EmptyStateRow(
                        title: "No runtime data yet",
                        subtitle: "Add a rule or launch a managed app to see proof here."
                    )
                } else {
                    ForEach(model.ruleDiagnostics) { diagnostic in
                        RuntimeDiagnosticRow(diagnostic: diagnostic)
                    }
                }
            }
        }
    }

    private var runningAppsSection: some View {
        cardSection("Running Apps") {
            VStack(alignment: .leading, spacing: 8) {
                if model.availableApps.isEmpty {
                    EmptyStateRow(
                        title: "Nothing to add right now",
                        subtitle: "All foreground apps are already managed or unavailable."
                    )
                } else {
                    ForEach(Array(model.availableApps.prefix(8))) { app in
                        RunningAppRow(app: app) {
                            model.addRule(for: app)
                        }
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Label(
                "\(model.ruleDiagnostics.filter { $0.isHealthy }.count) active",
                systemImage: model.activeLimiters.isEmpty ? "pause.circle" : "waveform.path.ecg"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                model.quit()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func cardSection<Content: View>(_ title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct EmptyStateRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct RuleEditorRow: View {
    let rule: AppRule
    let status: String
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let diagnostic = model.diagnostic(for: rule) {
                    StatusPill(
                        title: diagnostic.statusTitle,
                        tint: diagnostic.isHealthy ? .green : (rule.isEnabled ? .orange : .secondary)
                    )
                }

                StatusPill(
                    title: rule.isEnabled ? model.shortLimitLabel(for: rule.cpuLimit) : "Paused",
                    tint: rule.isEnabled ? .accentColor : .secondary
                )

                Toggle(
                    "",
                    isOn: Binding(
                        get: { rule.isEnabled },
                        set: { model.setRuleEnabled(rule.id, isEnabled: $0) }
                    )
                )
                .labelsHidden()
            }

            HStack(spacing: 10) {
                Text("Max CPU")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(rule.cpuLimit) },
                        set: { model.setRuleLimit(rule.id, limit: Int($0.rounded())) }
                    ),
                    in: Double(CPULimitScale.minimumLimit)...Double(model.maxCPULimit),
                    step: 5
                )

                VStack(alignment: .trailing, spacing: 1) {
                    Text(model.shortLimitLabel(for: rule.cpuLimit))
                        .font(.caption.weight(.medium))
                    Text("\(rule.cpuLimit)%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 78, alignment: .trailing)
            }

            HStack {
                Toggle(
                    "Children",
                    isOn: Binding(
                        get: { rule.includeChildren },
                        set: { model.setRuleIncludeChildren(rule.id, includeChildren: $0) }
                    )
                )
                .toggleStyle(.checkbox)
                .font(.caption)

                Spacer()

                Button(role: .destructive) {
                    model.removeRule(rule.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }
}

private struct RuntimeDiagnosticRow: View {
    let diagnostic: RuleRuntimeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(diagnostic.appName)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                StatusPill(
                    title: diagnostic.statusTitle,
                    tint: diagnostic.isHealthy ? .green : diagnostic.state == .failedToStart ? .red : .orange
                )
            }

            Text(diagnostic.statusDetail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(CPULimitScale.detailLabel(for: diagnostic.limit))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
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
                    .font(.subheadline.weight(.medium))
                Text(app.bundleIdentifier ?? app.executablePath ?? "No identifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Add") {
                onAdd()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
