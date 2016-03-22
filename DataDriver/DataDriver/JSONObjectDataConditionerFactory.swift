//
//  JSONObjectDataConditionerFactory.swift
//

import Foundation
import CoreData

public class JSONObjectDataConditionerFactory {

    private static var objectConditioners:Dictionary<String, JSONObjectConditioner> = Dictionary<String, JSONObjectConditioner>()

    static func registerObjectConditioner(entityName: String, objectConditioner: JSONObjectConditioner) {
        objectConditioners.updateValue(objectConditioner, forKey: entityName)
    }

    static func unregisterObjectConditioner(entityName: String) {
        objectConditioners.removeValueForKey(entityName)
    }

    static func conditionObjects(JSONObjects:Array<Dictionary<NSObject, AnyObject>>, entity:NSEntityDescription) -> Array<Dictionary<NSObject, AnyObject>> {

        guard let entityName = entity.name, let objectConditioner:JSONObjectConditioner = objectConditioners[entityName] else { return JSONObjects }
        var processedJSONObjects:Array<Dictionary<NSObject, AnyObject>> = Array<Dictionary<NSObject, AnyObject>>()

        for object in JSONObjects {
            processedJSONObjects.append(objectConditioner.condition(object) ?? object)
        }

        return processedJSONObjects
    }
}