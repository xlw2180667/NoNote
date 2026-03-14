import StoreKit
import SwiftUI

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
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.productID {
                entitled = true
                break
            }
        }
        isPro = entitled
    }

    func purchase() async throws {
        let products = try await Product.products(for: [Self.productID])
        guard let product = products.first else {
            throw StoreError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let tx) = verification {
                isPro = true
                await tx.finish()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    let isActive = tx.productID == StoreService.productID && tx.revocationDate == nil
                    await MainActor.run { [weak self] in
                        self?.isPro = isActive
                    }
                    await tx.finish()
                }
            }
        }
    }
}
