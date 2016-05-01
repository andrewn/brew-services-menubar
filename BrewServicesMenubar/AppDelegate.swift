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
    var state = "unknown" // "started", "stopped", "unknown"
}

func matchesForRegexInText(regex: String!, text: String!) -> [String] {
    do {
        let regex = try NSRegularExpression(pattern: regex, options: [])
        let nsString = text as NSString
        let results = regex.matchesInString(text,
                                            options: [], range: NSMakeRange(0, nsString.length))
        return results.map { nsString.substringWithRange($0.range)}
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
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    var services = [Service]()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let icon = NSImage(named: "statusIcon")
        
        if let button = statusItem.button {
            button.image = icon
            button.action = #selector(AppDelegate.handleMenuOpen(_:))
        }
        
        queryServicesAndUpdateMenu()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    //
    // Event handlers for UI actions
    //
    func handleClick(sender: NSMenuItem) {
        if (sender.state == NSOnState) {
            sender.state = NSOffState
            controlService(sender.title, state: "stop")
        } else {
            sender.state = NSOnState
            controlService(sender.title, state: "start")
        }
    }
    
    func handleQuit(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(nil)
    }
    
    func handleMenuOpen(sender: AnyObject?) {
        queryServicesAndUpdateMenu()
        statusItem.popUpStatusItemMenu(statusMenu)
    }
    
    //
    // Update menu of services 
    //
    func updateMenu() {
        statusMenu.removeAllItems()
        for service in services {
            let item = NSMenuItem.init(title: service.name, action:#selector(AppDelegate.handleClick(_:)), keyEquivalent: "")
            if service.state == "started" {
                item.state = NSOnState
            }
            statusMenu.addItem(item)
        }
        statusMenu.addItem(NSMenuItem.separatorItem())
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
    func controlService(name:String, state:String) {
        let task = NSTask()
        let outpipe = NSPipe()
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
        let task = NSTask()
        let outpipe = NSPipe()
        task.standardOutput = outpipe
        
        task.launchPath = "/usr/local/bin/brew"
        task.arguments = ["services", "list"]
        task.launch()
        
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String.fromCString(UnsafePointer(outdata.bytes)) {
            string = string.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
            return parseServiceList(string)
        }
        
        return []
    }
    
    let matcher = "([^ ]+)([^ ]+)"

    func parseServiceList(raw: String) -> [Service] {
        let rawServices = raw.componentsSeparatedByString("\n")
        return rawServices[1..<rawServices.count].map(parseService)
    }
    
    func parseService(raw:String) -> Service {
        let parts = matchesForRegexInText(matcher, text: raw)
        let service = Service(name: parts[0], state: parts[1])
        return service;
    }
}

