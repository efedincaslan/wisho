import SwiftUI
import StoreKit

struct PaywallView: View {
    var headline: String? = nil

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(productIDs: StoreManager.productIDs) {
                marketingContent
            }
            .storeButton(.visible, for: .restorePurchases)
            .subscriptionStoreControlStyle(.prominentPicker)
            .onInAppPurchaseCompletion { _, result in
                if case .success(let purchaseResult) = result,
                   case .success = purchaseResult {
                    await store.refreshEntitlements()
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var marketingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            Text("Wisho PRO")
                .font(.largeTitle.bold())

            if let headline {
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 10) {
                feature("Unlimited people", symbol: "person.3.fill")
                feature("Belated Rescue — never leave a miss unfixed", symbol: "clock.arrow.circlepath")
                feature("Advance reminders (1, 3, or 7 days)", symbol: "calendar.badge.clock")
                feature("Custom messages & timezones per person", symbol: "text.bubble.fill")
                feature("Home screen widget", symbol: "square.grid.2x2.fill")
            }
            .padding(.top, 4)
        }
        .padding()
    }

    private func feature(_ text: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
        }
    }
}
