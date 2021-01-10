//
//  Created by Maxwell Pirtle on 8/25/20
//  Copyright © 2020 Maxwell Pirtle. All rights reserved.
//
//  Abstract:
//  A function builder that generates an array of the given type using the closure to allocate
    

import Foundation
import OSLog

@_functionBuilder struct FallibleArrayAllocator<Output> {
    static func buildBlock<Input>(_ compactMap: (Input) -> Output?, _ input: Input...) -> [Output] {
        input.compactMap(compactMap)
    }
    
    static func buildBlock<Input>(_ compactMap: (Input) -> Output?, _ input: [Input]) -> [Output] {
        input.compactMap(compactMap)
    }
}

@_functionBuilder struct ConvenienceList<T> {
    static func buildBlock(_ input: T...) -> [T] { input }
}

@propertyWrapper struct AutoErrorLog<Value> where Value : Error {
    var wrappedValue: Value { didSet { os_log("Localized error, %s", log: log, wrappedValue.localizedDescription) } }
    
    /// The log to which error messages are printed
    var log: OSLog
    
    // MARK: Initializer
    
    init(log: OSLog, wrappedValue: Value) {
        self.log = log
        self.wrappedValue = wrappedValue
    }
}
