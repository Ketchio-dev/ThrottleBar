import XCTest
@testable import ThrottleBar

final class ThrottleBarTests: XCTestCase {
    func testRuleMatchesBundleIdentifier() {
        let rule = AppRule(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            executablePath: nil,
            cpuLimit: 100,
            includeChildren: true,
            isEnabled: true
        )

        let app = RunningAppSnapshot(
            pid: 1,
            bundleIdentifier: "com.apple.Safari",
            bundleURLPath: "/Applications/Safari.app",
            executablePath: "/Applications/Safari.app/Contents/MacOS/Safari",
            displayName: "Safari"
        )

        XCTAssertTrue(rule.matches(app))
    }

    func testRuleMatchesExecutablePathFallback() {
        let rule = AppRule(
            displayName: "CLI Tool",
            bundleIdentifier: nil,
            executablePath: "/usr/local/bin/my-tool",
            cpuLimit: 50,
            includeChildren: false,
            isEnabled: true
        )

        let app = RunningAppSnapshot(
            pid: 2,
            bundleIdentifier: nil,
            bundleURLPath: nil,
            executablePath: "/usr/local/bin/my-tool",
            displayName: "My Tool"
        )

        XCTAssertTrue(rule.matches(app))
    }

    func testLocatorFindsExecutableInProvidedPath() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let binaryURL = tempDirectory.appendingPathComponent("cpulimit")
        FileManager.default.createFile(atPath: binaryURL.path, contents: Data("echo test".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryURL.path)

        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let located = CPULimitLocator.locate(environment: ["PATH": tempDirectory.path])
        XCTAssertEqual(located?.path, binaryURL.path)
    }
    func testCPULimitScaleExplainsPerCorePercentages() {
        XCTAssertEqual(CPULimitScale.shortLabel(for: 100), "1.0 core")
        XCTAssertEqual(CPULimitScale.shortLabel(for: 250), "2.5 cores")
        XCTAssertEqual(
            CPULimitScale.scaleDescription(logicalCPUCount: 18),
            "100% = 1 CPU core · This Mac max 1800% (18 cores)"
        )
    }

    func testCPULimitScaleClampsToMachineMaximum() {
        XCTAssertEqual(CPULimitScale.clamp(1, logicalCPUCount: 18), 5)
        XCTAssertEqual(CPULimitScale.clamp(5000, logicalCPUCount: 18), 1800)
    }

}
