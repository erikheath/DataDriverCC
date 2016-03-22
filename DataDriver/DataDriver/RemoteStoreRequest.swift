//
// RemoteStoreRequest.swift
//

import CoreData

public class RemoteStoreRequest: NSObject {
    let entity: NSEntityDescription
    let property: NSPropertyDescription?
    let predicate: NSPredicate?
    let URLOverrides: NSURLComponents?
    let overrideTokens: Dictionary<NSObject, AnyObject>?
    var methodBody: NSData?
    let methodType: RequestType
    let destinationID: NSManagedObjectID?

    enum RequestType: String, CustomStringConvertible {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case PATCH = "PATCH"
        case DELETE = "DELETE"

        var description:String { return self.rawValue }

    }

    init(entity: NSEntityDescription, property: NSPropertyDescription?, predicate: NSPredicate?, URLOverrides: NSURLComponents?, overrideTokens:Dictionary<NSObject, AnyObject>?, methodType: RequestType, methodBody: NSData?, destinationID: NSManagedObjectID?) {
        self.entity = entity
        self.property = property
        self.predicate = predicate
        self.URLOverrides = URLOverrides
        self.overrideTokens = overrideTokens
        self.methodType = methodType
        self.methodBody = methodBody
        self.destinationID = destinationID
    }
    
}
