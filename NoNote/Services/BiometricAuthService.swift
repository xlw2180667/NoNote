import LocalAuthentication

enum BiometricAuthService {
    static func canUseBiometrics() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func biometryType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "#unlock")
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "#appLockDescription")
            )
        } catch {
            return false
        }
    }
}
