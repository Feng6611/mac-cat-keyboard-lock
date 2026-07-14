import Foundation
import RevenueCat

struct CatKeyboardLockCustomerInfoSnapshot: Equatable, Sendable {
    let hasProAccess: Bool
    let managementURL: URL?

    init(hasProAccess: Bool, managementURL: URL?) {
        self.hasProAccess = hasProAccess
        self.managementURL = managementURL
    }

    init(customerInfo: CustomerInfo) {
        self.init(
            hasProAccess: customerInfo.entitlements[
                CatKeyboardLockRevenueCatConfiguration.entitlementIdentifier
            ]?.isActive == true,
            managementURL: customerInfo.managementURL
        )
    }
}

@MainActor
protocol CatKeyboardLockCustomerInfoProviding {
    func fetchCurrent() async throws -> CatKeyboardLockCustomerInfoSnapshot
}

struct CatKeyboardLockRevenueCatCustomerInfoProvider: CatKeyboardLockCustomerInfoProviding {
    func fetchCurrent() async throws -> CatKeyboardLockCustomerInfoSnapshot {
        let customerInfo = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
        return CatKeyboardLockCustomerInfoSnapshot(customerInfo: customerInfo)
    }
}
