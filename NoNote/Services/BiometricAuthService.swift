import LocalAuthentication

enum BiometricAuthService {
    enum Outcome {
        case success
        /// Dismissed by the user, or by the system because the app was not frontmost.
        /// Nothing failed — the lock screen just waits for the Unlock button.
        case cancelled
        case failed(LAError.Code?)
    }

    static func canUseBiometrics() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func biometryType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    static func authenticate() async -> Bool {
        if case .success = await evaluate() { return true }
        return false
    }

    static func evaluate() async -> Outcome {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "#unlock")
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "#appLockDescription")
            )
            return ok ? .success : .failed(nil)
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel, .notInteractive, .userFallback:
                return .cancelled
            default:
                return .failed(error.code)
            }
        } catch {
            return .failed(nil)
        }
    }
}
