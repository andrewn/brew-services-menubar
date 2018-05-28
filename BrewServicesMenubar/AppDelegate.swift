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
    var state = "unknown" // "started", "stopped", "error", "unknown"
    var user = ""
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system().statusItem(withLength: -1)
    var statusMenu: NSMenu!
    var noServicesItem: NSMenuItem!
    var refreshingSeparator: NSMenuItem!
    var refreshingItem: NSMenuItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: [
            brewExecutableKey: "/usr/local/bin/brew"
        ])

        if let button = statusItem.button {
            let icon = NSImage(named: "icon")
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(AppDelegate.handleMenuOpen(_:))
        }

        // Create and add all menu items except the services themselves
        noServicesItem = NSMenuItem.init(title: "No services available", action: nil, keyEquivalent: "")
        noServicesItem.isEnabled = false
        refreshingSeparator = NSMenuItem.separator()
        refreshingItem = NSMenuItem.init(title: "Refreshing...", action: nil, keyEquivalent: "")
        refreshingItem.isEnabled = false

        statusMenu.addItem(noServicesItem)
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
        statusMenu.addItem(.separator())
        statusMenu.addItem(
            .init(title: "Quit", action:#selector(AppDelegate.handleQuit(_:)), keyEquivalent: "q")
        )
        statusMenu.addItem(refreshingSeparator)
        statusMenu.addItem(refreshingItem)

        queryServicesAndUpdateMenu()
    }

    //
    // Event handlers for UI actions
    //
    func handleClick(_ sender: NSMenuItem) {
        if sender.state == NSOnState {
            controlService(sender.title, state: "stop")
        }
        else {
            controlService(sender.title, state: "start")
        }
        sender.state = NSMixedState
        let altItem = sender.menu!.item(withTitle: "Restart "+sender.title)
        altItem!.state = NSMixedState
    }

    func handleRestartClick(_ sender: NSMenuItem) {
        let service = sender.representedObject as! Service
        controlService(service.name, state: "restart")
    }

    func handleStartAll(_ sender: NSMenuItem) {
        controlService("--all", state: "start")
    }

    func handleStopAll(_ sender: NSMenuItem) {
        controlService("--all", state: "stop")
    }

    func handleRestartAll(_ sender: NSMenuItem) {
        controlService("--all", state: "restart")
    }

    func handleQuit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    func handleMenuOpen(_ sender: AnyObject?) {
        queryServicesAndUpdateMenu()
        statusItem.popUpMenu(statusMenu)
    }

    //
    // Update menu of services
    //
    func updateMenu(_ services: [Service]) {
        noServicesItem.isHidden = (services.count != 0)

        // Loop over menu items, and update as necessary. Stop when encountering noServicesItem.
        let user = NSUserName()
        var i = 0
        for service in services {
            guard var item = statusMenu.item(at: i) else {
                return assertionFailure("Could not get menu item.")
            }
            guard var altItem = statusMenu.item(at: i+1) else {
                return assertionFailure("Could not get menu item.")
            }

            // Delete the item if it's the name is lexicographically greater than what we expected (i.e., a service was uninstalled)
            if item != noServicesItem && item.title.lexicographicallyPrecedes(service.name) {
                statusMenu.removeItem(altItem)
                statusMenu.removeItem(item)
            }

            // Insert a new menu item if we hit the end or if this is a new service
            if item == noServicesItem || service.name != item.title {
                item = NSMenuItem.init(title: service.name, action: #selector(AppDelegate.handleClick(_:)), keyEquivalent: "")
                altItem = NSMenuItem.init(title: "Restart "+service.name, action: #selector(AppDelegate.handleRestartClick(_:)), keyEquivalent: "")
                altItem.representedObject = service
                altItem.isAlternate = true
                altItem.isHidden = true
                altItem.keyEquivalentModifierMask = NSAlternateKeyMask
                statusMenu.insertItem(item, at: i)
                statusMenu.insertItem(altItem, at: i+1)
            }

            // Update the item
            if service.state == "started" {
                item.state = NSOnState
            }
            else if service.state == "stopped" {
                item.state = NSOffState
            }
            else {
                item.state = NSMixedState
                item.isEnabled = false
            }
            if service.user != "" && service.user != user {
                item.isEnabled = false
            }
            altItem.state = item.state
            altItem.isEnabled = item.isEnabled

            // Increment iterator
            i += 2
        }

        // Delete any unexpected menu items at the end (happens if the user uninstalled services that were at the end)
        while (true) {
            let item = statusMenu.item(at: i) as NSMenuItem?
            if item == noServicesItem {
                break
            }
            statusMenu.removeItem(item!)
        }
    }

    func queryServicesAndUpdateMenu() {
        refreshingItem.isHidden = false
        refreshingSeparator.isHidden = false

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.serviceStates()
            DispatchQueue.main.async {
                self.refreshingItem.isHidden = true
                self.refreshingSeparator.isHidden = true
                self.updateMenu(result)
            }
        }
    }

    //
    // Locate homebrew
    //
    func brewExecutable() -> String {
        return UserDefaults.standard.string(forKey: brewExecutableKey)!
    }

    //
    // Changes a service state
    //
    func controlService(_ name:String, state:String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = self.brewExecutable()
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
    func serviceStates() -> [Service] {
        let launchPath = self.brewExecutable()
        if !FileManager.default.isExecutableFile(atPath: launchPath) {
            return []
        }

        let task = Process()
        let outpipe = Pipe()
        task.launchPath = launchPath
        task.arguments = ["services", "list"]
        task.standardOutput = outpipe

        task.launch()
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            return []
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
