import SwiftUI

struct SplashView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        VStack(spacing: 16) {
            // TODO: web resources/css/app.css থেকে আসল brand mark/color বসাতে হবে — এখানে placeholder
            Text("Alhoq")
                .font(.system(size: 40, weight: .bold))
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await session.restoreSession()
        }
    }
}
