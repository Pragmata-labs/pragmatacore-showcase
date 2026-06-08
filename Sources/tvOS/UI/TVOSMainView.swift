import SwiftUI

struct TVOSMainView: View {
    var pragmataStore: PragmataViewStore

    var body: some View {
        TVOSBoatConfiguratorView(pragmataStore: pragmataStore)
            .ignoresSafeArea()
            .splashScreen()
    }
}
