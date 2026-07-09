import SwiftUI

/// A concise, three-page onboarding shown on first launch. Emphasises the smart,
/// identifier-driven detection and the safety guarantees.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "sparkles",
            title: "Welcome to Uninstally",
            subtitle: "The cleanest way to completely remove apps and every file they leave behind.",
            tint: .accentColor
        ),
        OnboardingPage(
            symbol: "scope",
            title: "Smart Detection",
            subtitle: "Uninstally matches files by bundle identifier — not just by name — across every Library location, so nothing gets missed and nothing unrelated gets touched.",
            tint: .purple
        ),
        OnboardingPage(
            symbol: "checkmark.shield.fill",
            title: "Safe by Design",
            subtitle: "You review everything before it's removed. Files go to the Trash where possible, and admin actions ask for permission only when needed.",
            tint: .green
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(pages.indices, id: \.self) { index in
                    if index == page {
                        OnboardingPageView(page: pages[index])
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .frame(height: 340)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: page)

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .animation(.spring, value: page)
                }
            }
            .padding(.vertical, 12)

            HStack {
                Button("Skip", action: onFinish)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(page == pages.count - 1 ? "Get Started" : "Continue") {
                    if page == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { page += 1 }
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(24)
        }
        .frame(width: 460, height: 470)
        .background(.regularMaterial)
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: page.symbol)
                .font(.system(size: 76))
                .foregroundStyle(page.tint)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            Text(page.title)
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }
}
