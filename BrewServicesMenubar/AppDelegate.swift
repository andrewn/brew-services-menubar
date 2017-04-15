//
//  AppDelegate.swift
//  BrewServicesMenubar
//
//  Created by Andrew on 30/04/2016.
//  Copyright © 2016 andrewnicolaou. All rights reserved.
//

import Cocoa

struct Service {
    var name = ""
    var state = "unknown" // "started", "stopped", "error", "unknown"
    var user = ""
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!

    // Returns a status item from the system menu bar of variable length
    let statusItem = NSStatusBar.system().statusItem(withLength: -1)
    var services: [Service]?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let icon = NSImage(named: "icon")
        icon?.isTemplate = true

        if let button = statusItem.button {
            button.image = icon
            button.action = #selector(AppDelegate.handleMenuOpen(_:))
        }
    }

    //
    // Event handlers for UI actions
    //
    func handleClick(_ sender: NSMenuItem) {
        if (sender.state == NSOnState) {
            sender.state = NSOffState
            controlService(sender.title, state: "stop")
        } else {
            sender.state = NSOnState
            controlService(sender.title, state: "start")
        }
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
    func updateMenu() {
        statusMenu.removeAllItems()

        if let services = services {
            let user = NSUserName()
            for service in services {
                let item = NSMenuItem.init(title: service.name, action: nil, keyEquivalent: "")

                if service.state == "started" {
                    item.state = NSOnState
                } else if service.state == "stopped" {
                    item.state = NSOffState
                } else {
                    item.state = NSMixedState
                    item.isEnabled = false
                }

                if service.user != "" && service.user != user {
                    item.isEnabled = false
                }

                if item.isEnabled {
                    item.action = #selector(AppDelegate.handleClick(_:))
                }

                statusMenu.addItem(item)
            }
        } else {
            let item = NSMenuItem.init(title: "Querying services...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            statusMenu.addItem(item)
        }

        statusMenu.addItem(.separator())
        statusMenu.addItem(
            .init(title: "Quit", action:#selector(AppDelegate.handleQuit(_:)), keyEquivalent: "q")
        )
    }

    func queryServicesAndUpdateMenu() {
        services = nil
        updateMenu()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.serviceStates()
            DispatchQueue.main.async {
                self.services = result
                self.updateMenu()
            }
        }
    }

    //
    // Changes a service state
    //
    func controlService(_ name:String, state:String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/local/bin/brew"
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
        }
    }

    //
    // Queries and parses the output of:
    //      brew services list
    //
    func serviceStates() -> [Service] {
        let task = Process()
        let outpipe = Pipe()
        task.launchPath = "/usr/local/bin/brew"
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
