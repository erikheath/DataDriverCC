//
//  PUTFactory.swift
//

import Foundation
import CoreData

public class UpdateFactory {

    private static var processors:Dictionary<String, Dictionary<String, EntityProcessor>> = Dictionary<String, Dictionary<String, EntityProcessor>>()

    static func registerProcessor(entityName: String, entityProcessor: EntityProcessor, stackID: String) {
        processors.updateValue([entityName: entityProcessor], forKey: stackID)
    }

    static func unregisterProcessor(entityName: String, stackID: String) {
        processors[stackID]?.removeValueForKey(entityName)
    }

    static func process(updates:Set<NSManagedObject>, stackID: String) -> Array<RemoteStoreRequest> {
        var changeRequests:Array<RemoteStoreRequest> = Array<RemoteStoreRequest>()
        for object in updates {
            guard let entityName = object.entity.name else { break }
            guard let entityProcessor:EntityProcessor = processors[stackID]?[entityName] else { break }
            guard let request = entityProcessor.process(object) else { break }
            changeRequests.append(request)
        }

        return Array<RemoteStoreRequest>()
    }
}