import StoreKit
import SwiftUI
import UsageKit

enum StoreError: LocalizedError {
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found. Please check your StoreKit configuration."
        }
    }
}

@MainActor
final class StoreService: ObservableObject {
    static let productID = "com.greenCross.NoDiary.proFlock"
    @AppStorage("isPro") var isPro = false
    @Published var errorMessage: String?
    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = listenForTransactions()
        Task { await checkEntitlements() }
    }

    deinit {
        updateTask?.cancel()
    }

    func checkEntitlements() async {
        #if DEBUG
        // Screenshot/demo mode: launch with -DemoPro to force the full flock
        if ProcessInfo.processInfo.arguments.contains("-DemoPro") {
            isPro = true
            return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.productID {
                entitled = true
                break
            }
        }
        isPro = entitled
        if entitled { UsageStats.shared.updatePro(true) }
    }

    func purchase() async throws {
        do {
            try await performPurchase()
        } catch {
            UsageStats.shared.recordFailure(DiaryFailure.purchase)
            throw error
        }
    }

    private func performPurchase() async throws {
        let products = try await Product.products(for: [Self.productID])
        guard let product = products.first else {
            throw StoreError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let tx) = verification {
                isPro = true
                UsageStats.shared.updatePro(true)
                UsageStats.shared.record(CoreUsageEvent.purchaseCompleted)
                await tx.finish()
            } else {
                UsageStats.shared.recordFailure(DiaryFailure.purchase)
            }
        case .userCancelled:
            UsageStats.shared.record(DiaryUsageEvent.paywallClosed)
        case .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            // Dismissed the Apple ID prompt — not a failure.
        } catch {
            UsageStats.shared.recordFailure(DiaryFailure.restore)
        }
        await checkEntitlements()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    let isActive = tx.productID == StoreService.productID && tx.revocationDate == nil
                    await MainActor.run { [weak self] in
                        self?.isPro = isActive
                        if isActive { UsageStats.shared.updatePro(true) }
                    }
                    await tx.finish()
                }
            }
        }
    }
}
