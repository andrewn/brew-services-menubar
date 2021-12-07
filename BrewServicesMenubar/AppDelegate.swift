//
//  AppDelegate.swift
//  BrewServicesMenubar
//
//  Created by Andrew on 30/04/2016.
//  Copyright © 2016 andrewnicolaou. All rights reserved.
//

import Cocoa

let brewExecutableKey = "brewExecutable"

struct Service {
    var name = ""
    var state = "unknown" // "started", "stopped", "none", "error", "unknown"
    var user = ""
}

enum BrewServicesMenubarErrors: Error {
    case homebrewNotFound
    case homebrewError
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!

    // Returns a status item from the system menu bar of variable length
    let statusItem = NSStatusBar.system.statusItem(withLength: -1)
    var services: [Service]?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Homebrew can now be located in two different locations depending on how it was installed and what architecture the computer is running
        // Define the most likely path first based on the architecture
        #if arch(arm64)
            UserDefaults.standard.register(defaults: [
                brewExecutableKey: [ "/opt/Homebrew/bin/brew", "/usr/local/bin/brew" ]
            ])
        #elseif arch(x86_64)
            UserDefaults.standard.register(defaults: [
                brewExecutableKey: [ "/usr/local/bin/brew", "/opt/Homebrew/bin/brew" ]
            ])
        #endif

        let icon = NSImage(named: "icon")
        icon?.isTemplate = true

        if let button = statusItem.button {
            button.image = icon
            button.action = #selector(AppDelegate.handleMenuOpen(_:))
        }

        queryServicesAndUpdateMenu()
    }

    //
    // Event handlers for UI actions
    //
    @objc func handleClick(_ sender: NSMenuItem) {
        if sender.state == NSControl.StateValue.off {
            controlService(sender.title, state: "start")
        } else {
            controlService(sender.title, state: "stop")
        }
    }

    @objc func handleRestartClick(_ sender: NSMenuItem) {
        let service = sender.representedObject as! Service
        controlService(service.name, state: "restart")
    }

    @objc func handleStartAll(_ sender: NSMenuItem) {
        controlService("--all", state: "start")
    }

    @objc func handleStopAll(_ sender: NSMenuItem) {
        controlService("--all", state: "stop")
    }

    @objc func handleRestartAll(_ sender: NSMenuItem) {
        controlService("--all", state: "restart")
    }

    @objc func handleQuit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    @objc func handleMenuOpen(_ sender: AnyObject?) {
        queryServicesAndUpdateMenu()
        statusItem.popUpMenu(statusMenu)
    }

    //
    // Update menu of services
    //
    func updateMenu(refreshing: Bool = false, notFound: Bool = false, error: Bool = false) {
        statusMenu.removeAllItems()

        if notFound {
            let item = NSMenuItem.init(title: "Homebrew not found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            statusMenu.addItem(item)
        }
        else if error {
            let item = NSMenuItem.init(title: "Homebrew error", action: nil, keyEquivalent: "")
            item.isEnabled = false
            statusMenu.addItem(item)
        }
        else if let services = services {
            let user = NSUserName()
            for service in services {
                let item = NSMenuItem.init(title: service.name, action: nil, keyEquivalent: "")

                if service.state == "started" {
                    item.state = NSControl.StateValue.on
                } else if service.state == "stopped"  || service.state == "none" {
                    item.state = NSControl.StateValue.off
                } else {
                    item.state = NSControl.StateValue.mixed
                }

                if service.user != "" && service.user != user {
                    item.isEnabled = false
                }

                if item.isEnabled {
                    item.action = #selector(AppDelegate.handleClick(_:))
                }

                statusMenu.addItem(item)

                let altItem = NSMenuItem.init(title: "Restart "+service.name, action: #selector(AppDelegate.handleRestartClick(_:)), keyEquivalent: "")
                altItem.representedObject = service
                altItem.state = item.state
                altItem.isEnabled = item.isEnabled
                altItem.isAlternate = true
                altItem.isHidden = true
                altItem.keyEquivalentModifierMask = .option
                statusMenu.addItem(altItem)
            }
            if services.count == 0 {
                let item = NSMenuItem.init(title: "No services available", action: nil, keyEquivalent: "")
                item.isEnabled = false
                statusMenu.addItem(item)
            }
            else {
                statusMenu.addItem(.separator())
                statusMenu.addItem(
                    .init(title: "Start all", action:#selector(AppDelegate.handleStartAll(_:)), keyEquivalent: "s")
                )
                statusMenu.addItem(
                    .init(title: "Stop all", action:#selector(AppDelegate.handleStopAll(_:)), keyEquivalent: "x")
                )
                statusMenu.addItem(
                    .init(title: "Restart all", action:#selector(AppDelegate.handleRestartAll(_:)), keyEquivalent: "r")
                )
            }
        }

        statusMenu.addItem(.separator())
        statusMenu.addItem(
            .init(title: "Quit", action:#selector(AppDelegate.handleQuit(_:)), keyEquivalent: "q")
        )

        if refreshing {
            statusMenu.addItem(.separator())
            let item = NSMenuItem.init(title: "Refreshing...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            statusMenu.addItem(item)
        }
    }

    func queryServicesAndUpdateMenu() {
        do {
            let launchPath = try self.brewExecutable()

            updateMenu(refreshing: true)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.serviceStates(launchPath: launchPath)
                    DispatchQueue.main.async {
                        self.services = result
                        self.updateMenu()
                    }
                } catch {
                    self.updateMenu(error: true)
                }
            }
        } catch {
            updateMenu(notFound: true)
        }
    }

    //
    // Locate homebrew
    //
    func brewExecutable() throws -> String {
        // if an array value is set: (the default)
        if let value = UserDefaults.standard.array(forKey: brewExecutableKey) as? [String] {
            for path in value {
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        // if a string value is set:
        if let path = UserDefaults.standard.string(forKey: brewExecutableKey) {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // if homebrew can't be found:
        throw BrewServicesMenubarErrors.homebrewNotFound
    }

    //
    // Changes a service state
    //
    func controlService(_ name:String, state:String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            do {
                task.launchPath = try self.brewExecutable()
            } catch {
                let alert = NSAlert.init()
                alert.alertStyle = .critical
                alert.messageText = "Error locating Homebrew"
                alert.runModal()
                return
            }
            task.arguments = ["services", state, name]

            task.launch()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                DispatchQueue.main.async {
                    let alert = NSAlert.init()
                    alert.alertStyle = .critical
                    alert.messageText = "Could not \(state) \(name)"
                    alert.informativeText = "You will need to manually resolve the issue."
                    alert.runModal()
                }
            }

            self.queryServicesAndUpdateMenu()
        }
    }

    //
    // Queries and parses the output of:
    //      brew services list
    //
    func serviceStates(launchPath: String) throws -> [Service] {
        let task = Process()
        let outpipe = Pipe()
        task.launchPath = launchPath
        task.arguments = ["services", "list"]
        task.standardOutput = outpipe

        task.launch()
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw BrewServicesMenubarErrors.homebrewError
        }

        if var string = String(data: outdata, encoding: String.Encoding.utf8) {
            string = string.trimmingCharacters(in: CharacterSet.newlines)
            return parseServiceList(string)
        }

        return []
    }

    func parseServiceList(_ raw: String) -> [Service] {
        let rawServices = raw.components(separatedBy: "\n")
        return rawServices[1..<rawServices.count].map(parseService)
    }

    func parseService(_ raw:String) -> Service {
        let parts = raw.components(separatedBy: " ").filter() { $0 != "" }
        return Service(
            name: parts[0],
            state: parts.count >= 2 ? parts[1] : "unknown",
            user: parts.count >= 3 ? parts[2] : ""
        )
    }
}
