//
//  JSONObjectConditioner.swift
//

import Foundation
import CoreData

// Implement this to create a method body.

protocol JSONObjectConditioner {

    static var entityName: String { get }

    func condition(object:Dictionary<NSObject, AnyObject>) -> Dictionary<NSObject, AnyObject>?
    
}