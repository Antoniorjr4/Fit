import SwiftUI

@main
struct FitLambdaApp: App {
    @StateObject private var demo = DemoStore()
    @StateObject private var link = BandLink()
    var body: some Scene {
        WindowGroup {
            Group {
                if demo.languageChosen {
                    FitLambdaRoot()
                } else {
                    LanguagePickerScreen(isFirstLaunch: true)
                }
            }
                .environmentObject(demo)
                .environmentObject(link)
                .environment(\.locale, demo.language.locale)
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
