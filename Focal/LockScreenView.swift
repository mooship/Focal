import SwiftUI

/// Full-screen cover shown over app content while `AppLockManager.isUnlocked` is false. Triggers
/// authentication as soon as it appears and offers a manual retry if it fails or is cancelled.
struct LockScreenView: View {
    let appLock: AppLockManager

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Focal is locked")
                    .font(.title2.weight(.semibold))
                Button("Unlock") {
                    Task { await appLock.authenticate() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appLock.isAuthenticating)
            }
            .padding()
        }
        .task {
            await appLock.authenticate()
        }
    }
}
