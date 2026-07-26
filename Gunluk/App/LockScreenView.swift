import SwiftUI

/// Kilit açılana kadar defterin üzerini kapatan ekran.
@MainActor
struct LockScreenView: View {

    @ObservedObject var lock: AppLock

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.accent)

                VStack(spacing: 6) {
                    Text("Günlük kilitli")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ink)

                    Text(lock.lastError ?? "Devam etmek için kimliğini doğrula")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(lock.lastError == nil ? Theme.inkSoft : Theme.accent)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Text(lock.biometryName + " ile aç")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Theme.accent))
                }
                .disabled(lock.isAuthenticating)
                .opacity(lock.isAuthenticating ? 0.6 : 1)
            }
            .padding(32)
        }
        .task {
            // Ekran belirir belirmez bir kez dene; kullanıcı düğmeye basmak
            // zorunda kalmasın.
            await lock.unlock()
        }
    }
}
