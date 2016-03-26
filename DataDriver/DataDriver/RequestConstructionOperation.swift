//
//  RequestConstructionOperation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData

/**
 A condition to determine if a request needs to be constructed prior to a data request being made.
 */
struct RequestConstructionCondition: OperationCondition {

    static let name = "RequestConstruction"

    static let isMutuallyExclusive = false

    let partitionOp: RemoteStoreRequestOperation

    let dataRequestor: RequestDataOperation

    init(partitionOp: RemoteStoreRequestOperation, dataRequestor: RequestDataOperation) {
        self.partitionOp = partitionOp
        self.dataRequestor = dataRequestor
    }

    func dependencyForOperation(operation: Operation) -> NSOperation? {
        guard let operation = operation as? RequestDataOperation where partitionOp.partitionRequest == nil else { return nil }

        return RequestConstructionOperation(partitionOp: self.partitionOp, dataRequestor: operation)
    }

    func evaluateForOperation(operation: Operation, completion:OperationConditionResult -> Void) {
        switch self.dataRequestor.requestConstructed  {
        case true:
            completion(.Satisfied)

        default:
            let error = NSError(code: .ConditionFailed, userInfo: [
                OperationConditionKey: self.dynamicType.name
                ])

            completion(.Failed(error))
        }
    }
}


class RequestConstructionOperation: Operation {

    let partitionOp: RemoteStoreRequestOperation

    let dataRequestor: RequestDataOperation

    var processedRequest: NSMutableURLRequest? = nil

    var requestValidated: Bool = false

    // MARK: - Object Lifecycle
    init (partitionOp: RemoteStoreRequestOperation, dataRequestor: RequestDataOperation) {

        self.partitionOp = partitionOp

        self.dataRequestor = dataRequestor

        super.init()

        addCondition(RequestValidationCondition(partitionOp: self.partitionOp, requestConstructor: self))

    }

    func processStoreFetchRequest() throws -> RemoteStoreRequest {
        guard let request = self.partitionOp.storeRequest as? NetworkStoreFetchRequest,
              let requestEntity = request.entity as NSEntityDescription! else {
              throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
        }

        let context = self.partitionOp.partitionContext

        let overrideComponents:NSURLComponents? = context.userInfo[kOverrideComponents] as? NSURLComponents

        let overrideTokens:Dictionary<NSObject, AnyObject>? = context.userInfo[kOverrideTokens] as? Dictionary<NSObject, AnyObject>

        return RemoteStoreRequest(entity: requestEntity, property: nil, predicate: request.predicate, URLOverrides: overrideComponents, overrideTokens: overrideTokens, methodType: .GET, methodBody: nil, destinationID: nil)

    }

    func generateRemoteStoreFetchRequest(request: RemoteStoreRequest) -> NSMutableURLRequest {
        return NSMutableURLRequest(entity: request.entity, property: request.property, predicate: request.predicate, URLOverrides: request.URLOverrides, overrideTokens: request.overrideTokens, destinationID: request.destinationID)
    }

    func processStoreSaveRequest() throws -> RemoteStoreRequest {
        guard let request = self.partitionOp.storeRequest as? NetworkStoreSaveRequest else {
            throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
        }
        if let insertedObjects = request.insertedObjects {
            guard let insertion = InsertionFactory.process(insertedObjects, stackID: self.partitionOp.transaction.graphManager!.stackID).first else {
                throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
            }
            return insertion
        }
        if let updatedObjects = request.updatedObjects {
            guard let update = UpdateFactory.process(updatedObjects, stackID: self.partitionOp.transaction.graphManager!.stackID).first else {
                throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
            }
            return update
        }
        if let deletedObjects = request.deletedObjects {
            guard let deletion = DeletionFactory.process(deletedObjects, stackID: self.partitionOp.transaction.graphManager!.stackID).first else {
                throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
            }
            return deletion
        }

        // It is an error to reach this point.
        throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
    }

    func generateRemoteStoreSaveRequest(request: RemoteStoreRequest) -> NSMutableURLRequest {
        let baseRequest = NSMutableURLRequest(entity: request.entity, property: request.property, predicate: request.predicate, URLOverrides: request.URLOverrides, overrideTokens: request.overrideTokens, destinationID: request.destinationID)
        baseRequest.HTTPMethod = request.methodType.rawValue
        baseRequest.HTTPBody = request.methodBody

        return baseRequest
    }

    override func execute() {
        do {
            switch self.partitionOp.storeRequest {
            case is NetworkStoreFetchRequest:
                self.partitionOp.partitionRequest = try self.processStoreFetchRequest()
                self.partitionOp.URLRequest = self.generateRemoteStoreFetchRequest(self.partitionOp.partitionRequest!)
            case is NetworkStoreSaveRequest:
                self.partitionOp.partitionRequest = try self.processStoreSaveRequest()
                self.partitionOp.URLRequest = self.generateRemoteStoreSaveRequest(self.partitionOp.partitionRequest!)
            default:
                throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
            }
            // Set the requestConstructed flag to true to indicate that the request has been constructed successfully, thereby meeting the condition.
            self.dataRequestor.requestConstructed = true
        } catch { }

        finish()
    }

}