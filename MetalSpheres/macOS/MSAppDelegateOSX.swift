//
//  Created by Maxwell Pirtle on 8/23/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//
    

import Cocoa

@NSApplicationMain
class MSAppDelegateOSX: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    
    
    func application(_ app: NSApplication, willEncodeRestorableState coder: NSCoder) {
        
    }
    
    func application(_ app: NSApplication, didDecodeRestorableState coder: NSCoder) {
        
    }
}

extension MSAppDelegateOSX: NSWindowRestoration {
    static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        completionHandler(NSApp.windows[0], nil)
    }
}
