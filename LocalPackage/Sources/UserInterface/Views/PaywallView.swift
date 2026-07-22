//
//  PaywallView.swift
//  UserInterface
//

import DataSource
import Model
import SwiftUI

public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var iapManager = IAPManager.shared
    @State private var queueTracker = NaviQueueTracker.shared
    var store: Browser?

    public init(store: Browser? = nil) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header / Badge
                    headerView

                    // Daily limit banner
                    limitBannerView

                    // Plan selection section
                    planSelectionView

                    // Action buttons (Assinar & Restaurar)
                    actionButtonsView

                    // Terms and security disclaimer
                    footerDisclaimerView
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await store?.send(.paywallDismissed)
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await iapManager.fetchProducts()
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)

                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            Text("Navi Premium")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Automatize sem interrupções")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var limitBannerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Limite atingido para hoje")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(queueTracker.countToday) de \(NaviQueueConfig.dailyLimit) envios na NaviQueue utilizados")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.blue)

                Text("O seu limite diário será zerado amanhã e permitirá novos envios, ou assine um plano abaixo para liberar o envio ilimitado agora mesmo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var planSelectionView: some View {
        VStack(spacing: 14) {
            ForEach(iapManager.availablePlans) { plan in
                let isSelected = iapManager.selectedPlanID == plan.id

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        iapManager.selectedPlanID = plan.id
                    }
                } label: {
                    HStack(spacing: 16) {
                        // Radio indicator
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                        // Details
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(plan.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let badge = plan.savingsBadge {
                                    Text(badge)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.green.opacity(0.2)))
                                        .foregroundStyle(.green)
                                }
                            }

                            Text("Envios ilimitados na NaviQueue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Price
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(plan.priceText)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(plan.periodText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.tertiarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            // Success / Error alerts
            if let successMsg = iapManager.purchaseSuccessMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(successMsg)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.1)))
            }

            if let errorMsg = iapManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMsg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.1)))
            }

            // Primary "Assinar" button
            Button {
                Task {
                    if let selectedPlan = iapManager.availablePlans.first(where: { $0.id == iapManager.selectedPlanID }) {
                        let success = await iapManager.purchase(plan: selectedPlan)
                        if success {
                            try? await Task.sleep(for: .seconds(1.5))
                            await store?.send(.paywallDismissed)
                            dismiss()
                        }
                    }
                }
            } label: {
                HStack {
                    if iapManager.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    }
                    Text("Assinar")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(iapManager.isLoading)

            // Secondary "Restaurar IAP" button
            Button {
                Task {
                    let restored = await iapManager.restorePurchases()
                    if restored {
                        try? await Task.sleep(for: .seconds(1.5))
                        await store?.send(.paywallDismissed)
                        dismiss()
                    }
                }
            } label: {
                Text("Restaurar IAP")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(iapManager.isLoading)
        }
    }

    private var footerDisclaimerView: some View {
        VStack(spacing: 6) {
            Text("Renovado automaticamente. Cancele a qualquer momento nas configurações da App Store.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }
}

#Preview {
    PaywallView(store: .init(.testDependencies()))
}
