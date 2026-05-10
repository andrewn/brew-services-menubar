//
//  AppDelegate.swift
//  BrewServicesMenubar
//

import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var services: [BrewService] = []
    private var isRefreshing = false
    private var lastError: BrewError?

    nonisolated static func main() {
        // The runtime entry point runs on the main thread, but the compiler
        // has no way to know that — so explicitly take the main-actor lane
        // before touching any AppKit types or main-actor state.
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.run()
            withExtendedLifetime(delegate) {}
        }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        UserDefaults.standard.register(defaults: [
            BrewLocator.defaultsKey: BrewLocator.defaultPaths
        ])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let icon = NSImage(named: "icon") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        rebuildMenu()
        Task { await refresh() }
    }

    // MARK: NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        Task { await refresh() }
    }

    // MARK: Refresh

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        rebuildMenu()
        defer {
            isRefreshing = false
            rebuildMenu()
        }

        guard let brew = currentBrewURL() else {
            services = []
            lastError = .homebrewNotFound
            return
        }

        do {
            let data = try await runBrew(brew, arguments: ["services", "list", "--json"])
            services = try BrewServicesParser.parse(data)
            lastError = nil
        } catch let err as BrewError {
            lastError = err
        } catch {
            lastError = .launchFailed(error.localizedDescription)
        }
    }

    private func currentBrewURL() -> URL? {
        BrewLocator.locate(
            rawDefault: UserDefaults.standard.object(forKey: BrewLocator.defaultsKey)
        )
    }

    // MARK: Menu construction

    private func rebuildMenu() {
        menu.removeAllItems()

        if let error = lastError {
            switch error {
            case .homebrewNotFound:
                menu.addItem(disabledItem("Homebrew not found"))
            default:
                menu.addItem(disabledItem("Homebrew error"))
            }
        } else if services.isEmpty {
            menu.addItem(disabledItem(isRefreshing ? "Refreshing…" : "No services available"))
        } else {
            let user = NSUserName()
            for service in services {
                addServiceItems(service, currentUser: user)
            }
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Start all", action: #selector(handleStartAll), key: "s"))
            menu.addItem(actionItem(title: "Stop all", action: #selector(handleStopAll), key: "x"))
            menu.addItem(actionItem(title: "Restart all", action: #selector(handleRestartAll), key: "r"))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Quit", action: #selector(handleQuit), key: "q"))

        if isRefreshing && !services.isEmpty {
            menu.addItem(.separator())
            menu.addItem(disabledItem("Refreshing…"))
        }
    }

    private func addServiceItems(_ service: BrewService, currentUser: String) {
        let item = NSMenuItem(title: service.name, action: nil, keyEquivalent: "")
        switch service.status {
        case .started:
            item.state = .on
        case .stopped, .none:
            item.state = .off
        default:
            item.state = .mixed
        }

        let runByOtherUser = !(service.user ?? "").isEmpty && service.user != currentUser
        item.isEnabled = !runByOtherUser
        if item.isEnabled {
            item.action = #selector(handleClick(_:))
            item.target = self
        }
        item.representedObject = service.name
        menu.addItem(item)

        let restart = NSMenuItem(
            title: "Restart \(service.name)",
            action: #selector(handleRestart(_:)),
            keyEquivalent: ""
        )
        restart.target = self
        restart.representedObject = service.name
        restart.state = item.state
        restart.isEnabled = item.isEnabled
        restart.isAlternate = true
        restart.isHidden = true
        restart.keyEquivalentModifierMask = .option
        menu.addItem(restart)
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: Actions

    @objc private func handleClick(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let action = sender.state == .on ? "stop" : "start"
        Task { await control(service: name, action: action) }
    }

    @objc private func handleRestart(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Task { await control(service: name, action: "restart") }
    }

    @objc private func handleStartAll(_ sender: NSMenuItem) {
        Task { await control(service: "--all", action: "start") }
    }

    @objc private func handleStopAll(_ sender: NSMenuItem) {
        Task { await control(service: "--all", action: "stop") }
    }

    @objc private func handleRestartAll(_ sender: NSMenuItem) {
        Task { await control(service: "--all", action: "restart") }
    }

    @objc private func handleQuit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func control(service: String, action: String) async {
        guard let brew = currentBrewURL() else {
            presentAlert(title: "Homebrew not found",
                         message: "Could not locate the brew executable.")
            return
        }
        do {
            _ = try await runBrew(brew, arguments: ["services", action, service])
        } catch {
            presentAlert(title: "Could not \(action) \(service)",
                         message: "You will need to manually resolve the issue.")
        }
        await refresh()
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        _ = alert.runModal()
    }
}

/// Runs `brew` off the main actor and returns stdout as `Data`. Throws
/// `BrewError.commandFailed` on non-zero exit and `BrewError.launchFailed`
/// if the process can't be started (e.g. binary missing or blocked).
func runBrew(_ executable: URL, arguments: [String]) async throws -> Data {
    try await Task.detached(priority: .userInitiated) {
        let task = Process()
        task.executableURL = executable
        task.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr

        do {
            try task.run()
        } catch {
            throw BrewError.launchFailed(error.localizedDescription)
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let errString = String(data: errData, encoding: .utf8) ?? ""
            throw BrewError.commandFailed(exitCode: task.terminationStatus, stderr: errString)
        }

        return outData
    }.value
}
