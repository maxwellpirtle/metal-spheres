//
//  Created by Maxwell Pirtle on 12/16/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A window controller that is responsible for managing the window housing all of the views
//  so that the user can interact with the scene
    

import Cocoa
import Combine

class MetalContentWindowController: NSWindowController {
    
    /// Observes changes to the window's size
    private var windowFrameSizeObserver: AnyCancellable!
    
    override func windowDidLoad() {
        super.windowDidLoad()

        window?.title = ""
        window?.isRestorable = true
        window?.restorationClass = MSAppDelegateOSX.self
        window?.identifier = windowRestorationIdentifier
        
        windowFrameSizeObserver = window?.publisher(for: \.frame).sink { [unowned self] frame in
            invalidateRestorableState()
        }
    }

    // MARK: - Restorable State -
    
    private let windowRestorationIdentifier = NSUserInterfaceItemIdentifier("MetalContentWindow")
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encode(with: coder)
        
        // Save the size of the window for later use
        coder.encode(window!.frame.size)
    }
    
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        
        let windowSize = coder.decodeSize()
        window?.setContentSize(windowSize)
    }

    override var acceptsFirstResponder: Bool { false }
    override func noResponder(for eventSelector: Selector) {}
}
