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
}

func matchesForRegexInText(_ regex: String!, text: String!) -> [String] {
    do {
        let regex = try NSRegularExpression(pattern: regex, options: [])
        let nsString = text as NSString
        let results = regex.matches(in: text,
                                            options: [], range: NSMakeRange(0, nsString.length))
        return results.map { nsString.substring(with: $0.range)}
    } catch let error as NSError {
        print("invalid regex: \(error.localizedDescription)")
        return []
    }
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    
    // Returns a status item from the system menu bar of variable length
    let statusItem = NSStatusBar.system().statusItem(withLength: -1)
    var services = [Service]()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let icon = NSImage(named: "icon")
        icon?.isTemplate = true
        
        if let button = statusItem.button {
            button.image = icon
            button.action = #selector(AppDelegate.handleMenuOpen(_:))
        }
        
        queryServicesAndUpdateMenu()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
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
        NSApplication.shared().terminate(nil)
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
        for service in services {
            let item = NSMenuItem.init(title: service.name, action:nil, keyEquivalent: "")

            if service.state == "started" {
                item.state = NSOnState
            } else if service.state == "stopped" {
                item.state = NSOffState
            } else {
                item.state = NSMixedState
                item.isEnabled = false
            }

            if item.isEnabled {
                item.action = #selector(AppDelegate.handleClick(_:))
            }

            statusMenu.addItem(item)
        }
        statusMenu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem.init(title: "Quit", action:#selector(AppDelegate.handleQuit(_:)), keyEquivalent: "q")
        statusMenu.addItem(quit)
    }
    
    func queryServicesAndUpdateMenu() {
        services = serviceStates()
        updateMenu()
    }
    
    //
    // Changes a service state
    //
    func controlService(_ name:String, state:String) {
        let task = Process()
        let outpipe = Pipe()
        task.standardOutput = outpipe
        
        task.launchPath = "/usr/local/bin/brew"
        task.arguments = ["services", state, name]
        task.launch()
    }
    
    //
    // Queries and parses the output of:
    //      brew services list
    //
    func serviceStates() -> [Service] {
        let task = Process()
        let outpipe = Pipe()
        task.standardOutput = outpipe
        
        task.launchPath = "/usr/local/bin/brew"
        task.arguments = ["services", "list"]
        task.launch()
        
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: String.Encoding.utf8) {
            string = string.trimmingCharacters(in: CharacterSet.newlines)
            return parseServiceList(string)
        }
        
        return []
    }
    
    let matcher = "([^ ]+)([^ ]+)"

    func parseServiceList(_ raw: String) -> [Service] {
        let rawServices = raw.components(separatedBy: "\n")
        return rawServices[1..<rawServices.count].map(parseService)
    }
    
    func parseService(_ raw:String) -> Service {
        let parts = matchesForRegexInText(matcher, text: raw)
        let service = Service(name: parts[0], state: parts[1])
        return service;
    }
}

