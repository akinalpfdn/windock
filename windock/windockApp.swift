import SwiftUI
import AppKit
import ScreenCaptureKit
import ServiceManagement

@main
struct WinDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: DockViewModel?
    private var onboardingWindow: NSWindow?
    private var toastWindow: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItem()
        checkPermissionsAndStart()
        UpdateChecker.check(
            repo: "akinalpfdn/windock",
            releasePageURL: URL(string: "https://github.com/akinalpfdn/windock/releases/latest")!
        )
    }

    // MARK: - Permission Flow

    private func checkPermissionsAndStart() {
        let axTrusted = AXIsProcessTrusted()

        Task {
            let screenGranted = await checkScreenRecordingPermission()

            await MainActor.run {
                if axTrusted && screenGranted {
                    startApp()
                } else if !axTrusted {
                    showOnboarding(step: .accessibility)
                } else {
                    showOnboarding(step: .screenRecording)
                }
            }
        }
    }

    private func checkScreenRecordingPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }

    private func startApp() {
        viewModel = DockViewModel()
        showWelcomeToastIfNeeded()
    }

    // MARK: - Onboarding

    func showOnboarding(step: OnboardingStep) {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.center()
            window.level = .floating
            onboardingWindow = window
        }

        let view = OnboardingView(
            step: step,
            onOpenAccessibilitySettings: {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            },
            onAccessibilityGranted: { [weak self] in
                self?.showOnboarding(step: .screenRecording)
            },
            onOpenScreenRecordingSettings: {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
            }
        )

        onboardingWindow?.contentView = NSHostingView(rootView: view)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Welcome Toast

    private func showWelcomeToastIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "welcomeToastShown") else { return }
        UserDefaults.standard.set(true, forKey: "welcomeToastShown")
        showWelcomeToast()
    }

    private func showWelcomeToast() {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 300
        let height: CGFloat = 64
        let margin: CGFloat = 16

        let frame = NSRect(
            x: screen.visibleFrame.maxX - width - margin,
            y: screen.visibleFrame.maxY - height - margin,
            width: width,
            height: height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.alphaValue = 0

        panel.contentView = NSHostingView(rootView: WelcomeToastView())
        panel.orderFront(nil)
        toastWindow = panel

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                self?.toastWindow?.animator().alphaValue = 0
            }) {
                self?.toastWindow?.orderOut(nil)
                self?.toastWindow = nil
            }
        }
    }

    // MARK: - Login Item

    private func registerLoginItem() {
        try? SMAppService.mainApp.register()
    }
}

// MARK: - Onboarding Step

enum OnboardingStep {
    case accessibility
    case screenRecording
}

// MARK: - Onboarding View

struct OnboardingView: View {
    let step: OnboardingStep
    let onOpenAccessibilitySettings: () -> Void
    let onAccessibilityGranted: () -> Void
    let onOpenScreenRecordingSettings: () -> Void

    @State private var accessibilityCheckFailed = false

    var body: some View {
        VStack(spacing: 0) {
            // Step dots
            HStack(spacing: 6) {
                Circle()
                    .fill(step == .accessibility ? Color.accentColor : Color.accentColor.opacity(0.3))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(step == .screenRecording ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
            .padding(.top, 28)

            Spacer()

            if step == .accessibility {
                accessibilityStep
            } else {
                screenRecordingStep
            }

            Spacer()
        }
        .frame(width: 480, height: 420)
        .background(.windowBackground)
    }

    // MARK: Accessibility Step

    @ViewBuilder
    private var accessibilityStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                Text("Allow Accessibility Access")
                    .font(.title2.bold())

                VStack(spacing: 6) {
                    Text("WinDock uses Accessibility to detect when you hover over Dock icons.")
                        .foregroundStyle(.secondary)
                    Text("It cannot read your screen, keystrokes, or any other app's content.")
                        .foregroundStyle(.secondary)

                    Link("Verify on GitHub →", destination: URL(string: "https://github.com/akinalpfdn/windock")!)
                        .font(.footnote)
                        .padding(.top, 2)
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            VStack(spacing: 10) {
                Button {
                    accessibilityCheckFailed = false
                    onOpenAccessibilitySettings()
                } label: {
                    Label("Open Accessibility Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(width: 280)

                Button("I've allowed it") {
                    if AXIsProcessTrusted() {
                        accessibilityCheckFailed = false
                        onAccessibilityGranted()
                    } else {
                        accessibilityCheckFailed = true
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(width: 280)

                if accessibilityCheckFailed {
                    Text("Permission not detected yet — make sure WinDock is checked and try again.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: accessibilityCheckFailed)
        }
        .padding(.horizontal, 48)
    }

    // MARK: Screen Recording Step

    @ViewBuilder
    private var screenRecordingStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.inset.filled.and.person.filled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                Text("Allow Screen Recording")
                    .font(.title2.bold())

                VStack(spacing: 6) {
                    Text("WinDock uses Screen Recording to show live window previews on hover.")
                        .foregroundStyle(.secondary)
                    Text("Nothing is recorded, stored, or transmitted anywhere.")
                        .foregroundStyle(.secondary)

                    Link("Verify on GitHub →", destination: URL(string: "https://github.com/akinalpfdn/windock")!)
                        .font(.footnote)
                        .padding(.top, 2)
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            VStack(spacing: 10) {
                Button {
                    onOpenScreenRecordingSettings()
                } label: {
                    Label("Open Screen Recording Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(width: 300)

                Text("After allowing, macOS will ask you to quit and reopen WinDock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .padding(.horizontal, 48)
    }
}

// MARK: - Welcome Toast

struct WelcomeToastView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("WinDock is running")
                    .font(.subheadline.bold())
                Text("Hover over a Dock app to try it")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
