import AppKit
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            usesAppIcon: true,
            title: "Uninstally",
            subtitle: "Uninstally completely removes macOS applications and every file they create \u{2014} caches, preferences, containers, and more. Unlike dragging an app to the Trash, Uninstally finds and removes all the supporting files applications leave behind.",
            tint: .accentColor
        ),
        OnboardingPage(
            symbol: "lock.shield.fill",
            title: "Permissions & Safety",
            subtitle: "Uninstally only removes files it can confidently link to the application being uninstalled, using bundle identifiers and path validation. It never runs shell commands or scripts. Administrator files are only touched with your explicit approval.",
            tint: .blue
        ),
        OnboardingPage(
            symbol: "arrow.triangle.branch",
            title: "Trash vs Permanent Delete",
            subtitle: "By default, Uninstally moves files to the Trash so you can recover them. You can switch to permanent deletion in Settings, but Trash mode is always safer. Either way, you review every file before anything is removed.",
            tint: .orange
        ),
        OnboardingPage(
            symbol: "checkmark.seal.fill",
            title: "Open Source & Privacy",
            subtitle: "Uninstally is open source software. Updates are verified with cryptographic signatures from the official GitHub repository. No analytics are collected, no data is sent anywhere, and everything stays on your Mac.",
            tint: .green,
            footer: AnyView(
                Link(destination: URL(string: "https://github.com/gostonx/uninstally")!) {
                    Label("View on GitHub", systemImage: "arrow.up.forward.app")
                        .font(.callout.weight(.medium))
                }
            )
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
            .frame(height: 380)
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
        .frame(width: 500, height: 510)
        .background(.regularMaterial)
    }
}

private struct OnboardingPage {
    let symbol: String?
    let usesAppIcon: Bool
    let title: String
    let subtitle: String
    let tint: Color
    let footer: AnyView?

    init(symbol: String? = nil, usesAppIcon: Bool = false, title: String, subtitle: String, tint: Color, footer: AnyView? = nil) {
        self.symbol = symbol
        self.usesAppIcon = usesAppIcon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.footer = footer
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 22) {
            if page.usesAppIcon {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                }
            } else if let symbol = page.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 72))
                    .foregroundStyle(page.tint)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
            }
            Text(page.title)
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            if let footer = page.footer {
                footer
                    .padding(.top, 8)
            }
        }
        .padding(.top, 32)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }
}
