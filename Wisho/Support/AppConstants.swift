import Foundation

enum AppGroup {
    /// Must match the App Group entitlement on both the app and widget targets.
    static let identifier = "group.com.wisho.app"
    /// Widget reads PRO status from the shared defaults (StoreKit lives in the app).
    static let isProKey = "wisho.isPro"
}

enum WishoLinks {
    static let privacyPolicy = URL(string: "https://wisho.app/privacy")!
    static let support = URL(string: "https://wisho.app/support")!
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let venmoAppStore = URL(string: "https://apps.apple.com/us/app/venmo/id351727428")!

    static func venmoPay(phone: String) -> URL? {
        URL(string: "venmo://paycharge?txn=pay&recipients=\(phone)")
    }
}
