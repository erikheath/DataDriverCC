//
//  EntityProcessor.swift
//

import Foundation
import CoreData

// Implement this to create a method body.

protocol EntityProcessor {

    func process(object:NSManagedObject) -> RemoteStoreRequest?

}