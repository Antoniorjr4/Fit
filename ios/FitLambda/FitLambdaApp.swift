import SwiftUI

@main
struct FitLambdaApp: App {
    @StateObject private var demo = DemoStore()
    var body: some Scene {
        WindowGroup {
            FitLambdaRoot()
                .environmentObject(demo)
                .preferredColorScheme(demo.isDark ? .dark : .light)
                .modifier(PreviewTextSize())
        }
    }
}

/// Exercises Dynamic Type in UI tests without changing the device's settings.
/// Normal launches always follow the user's system preference.
private struct PreviewTextSize: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fit-ui-large-text") {
            content.dynamicTypeSize(.accessibility3)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
