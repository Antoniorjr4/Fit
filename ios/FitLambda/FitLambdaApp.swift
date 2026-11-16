import SwiftUI

@main
struct FitLambdaApp: App {
    @StateObject private var demo = DemoStore()
    var body: some Scene {
        WindowGroup {
            FitLambdaRoot()
                .environmentObject(demo)
                .preferredColorScheme(demo.isDark ? .dark : .light)
        }
    }
}
