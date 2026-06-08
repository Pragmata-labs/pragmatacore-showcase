import SwiftUI

// MARK: - Splash Screen

struct SplashScreenView: View {
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("NavalLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .opacity(logoOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5)) {
                        logoOpacity = 1
                    }
                }
        }
    }
}

// MARK: - View modifier

private struct SplashModifier: ViewModifier {
    @State private var visible = true

    func body(content: Content) -> some View {
        ZStack {
            content
            if visible {
                SplashScreenView()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    visible = false
                }
            }
        }
    }
}

extension View {
    func splashScreen() -> some View {
        modifier(SplashModifier())
    }
}
