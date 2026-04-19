import Foundation

enum CPULimitScale {
    static let minimumLimit = 5

    static func maxLimit(logicalCPUCount: Int = ProcessInfo.processInfo.processorCount) -> Int {
        max(100, logicalCPUCount * 100)
    }

    static func clamp(_ limit: Int, logicalCPUCount: Int = ProcessInfo.processInfo.processorCount) -> Int {
        min(max(limit, minimumLimit), maxLimit(logicalCPUCount: logicalCPUCount))
    }

    static func shortLabel(for limit: Int) -> String {
        let cores = Double(limit) / 100
        let rounded = (cores * 10).rounded() / 10

        if rounded == 1 {
            return "1.0 core"
        }

        return String(format: "%.1f cores", rounded)
    }

    static func detailLabel(for limit: Int) -> String {
        "\(shortLabel(for: limit)) · \(limit)%"
    }

    static func scaleDescription(logicalCPUCount: Int = ProcessInfo.processInfo.processorCount) -> String {
        let maxLimit = maxLimit(logicalCPUCount: logicalCPUCount)
        let coreLabel = logicalCPUCount == 1 ? "1 core" : "\(logicalCPUCount) cores"
        return "100% = 1 CPU core · This Mac max \(maxLimit)% (\(coreLabel))"
    }
}
