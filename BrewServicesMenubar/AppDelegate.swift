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

    @IBOutlet weak var statusMenu: NSMenu!

    // Returns a status item from the system menu bar of variable length
    let statusItem = NSStatusBar.system.statusItem(withLength: -1)
    var services: [Service]?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: [
            brewExecutableKey: "/usr/local/bin/brew"
        ])

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
        let service = sender.representedObject as! Service
        sender.state = sender.state == .on ? .off : .on
        
        if service.user == "root" {
            controlServiceRoot(service.name, state: sender.state == .on ? "start" : "stop")
        } else {
            controlService(service.name, state: sender.state == .on ? "start" : "stop")
        }
    }
    
    //
    // Event handlers for Root UI actions
    //
    @objc func handleRootClick(_ sender: NSMenuItem) {
        let service = sender.representedObject as! Service
        sender.state = sender.state == .on ? .off : .on
        controlServiceRoot(service.name, state: sender.state == .on ? "start" : "stop")
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
    func updateMenu(refreshing: Bool) {
        statusMenu.removeAllItems()

        if let services = services {
            for service in services {
                let item = NSMenuItem.init(title: service.name, action: nil, keyEquivalent: "")
                item.representedObject = service

                if service.state == "started" {
                    item.state = NSControl.StateValue.on
                } else if service.state == "stopped" {
                    item.state = NSControl.StateValue.off
                } else {
                    item.state = NSControl.StateValue.mixed
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
                
                let altItem2 = NSMenuItem.init(title: "\(service.name) (Root)", action: #selector(AppDelegate.handleRootClick(_:)), keyEquivalent: "")
                altItem2.representedObject = service
                altItem2.state = item.state
                altItem2.isEnabled = item.isEnabled
                altItem2.isAlternate = true
                altItem2.isHidden = true
                altItem2.keyEquivalentModifierMask = .control
                statusMenu.addItem(altItem2)
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
        updateMenu(refreshing: true)

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.serviceStates()
            DispatchQueue.main.async {
                self.services = result
                self.updateMenu(refreshing: false)
            }
        }
    }

    //
    // Locate homebrew
    //
    func brewExecutable() -> String {
        return UserDefaults.standard.string(forKey: brewExecutableKey)!
    }
    
    func controlServiceRoot(_ name:String, state:String){
        let brew = self.brewExecutable()
        let cmd = "do shell script \"\(brew) services \(state) \(name)\"  with administrator privileges"
        var error: NSDictionary?
        guard let script = NSAppleScript(source: cmd) else {
            return
        }
        script.executeAndReturnError(&error)
        
        if(error != nil) {
            let alert = NSAlert()
            alert.messageText = "Error running \(name)"
            alert.informativeText = "Error with sudo command \(cmd)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            dump(error)
        }
        self.queryServicesAndUpdateMenu()
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
