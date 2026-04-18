import SwiftUI

@main
struct ThrottleBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("ThrottleBar", systemImage: model.statusIconName) {
            StatusMenuView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
