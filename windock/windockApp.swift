import SwiftUI
import AppKit
import ScreenCaptureKit
import ServiceManagement

@main
struct WinDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window - we only show the preview panel
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: DockViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItem()
        checkPermissionsAndStart()
        UpdateChecker.check(
            repo: "akinalpfdn/windock",
            releasePageURL: URL(string: "https://github.com/akinalpfdn/windock/releases/latest")!
        )
    }

    private func checkPermissionsAndStart() {
        let axTrusted = AXIsProcessTrusted()

        Task {
            let screenGranted = await checkScreenRecordingPermission()

            await MainActor.run {
                if axTrusted && screenGranted {
                    viewModel = DockViewModel()
                } else {
                    showPermissionWindow(accessibilityGranted: axTrusted, screenRecordingGranted: screenGranted)
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

    private func showPermissionWindow(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WinDock — Permissions Required"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal

        let view = PermissionView(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted,
            onContinue: { [weak self] in
                window.close()
                self?.checkPermissionsAndStart()
            }
        )
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func registerLoginItem() {
        try? SMAppService.mainApp.register()
    }
}

struct PermissionView: View {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("WinDock needs permissions to work")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(
                    title: "Accessibility",
                    description: "Monitor Dock hover events",
                    granted: accessibilityGranted,
                    action: {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                    }
                )

                PermissionRow(
                    title: "Screen Recording",
                    description: "Capture window previews",
                    granted: screenRecordingGranted,
                    action: {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                        )
                    }
                )
            }
            .padding(.horizontal)

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 420)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if !granted {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}
