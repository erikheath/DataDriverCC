//
//  RequestValidation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData

struct RequestValidationCondition: OperationCondition {

    static let name = "RequestValidation"

    static let isMutuallyExclusive = false

    let partitionOp: RemoteStoreRequestOperation

    let requestConstructor: RequestConstructionOperation

    init(partitionOp: RemoteStoreRequestOperation, requestConstructor: RequestConstructionOperation) {
        self.partitionOp = partitionOp
        self.requestConstructor = requestConstructor
    }

    func dependencyForOperation(operation: Operation) -> NSOperation? {
        guard let operation = operation as? RequestConstructionOperation else { return nil }

        return RequestValidation(partitionOp: self.partitionOp, requestConstructor: operation)
    }

    func evaluateForOperation(operation: Operation, completion:OperationConditionResult -> Void) {
        switch self.requestConstructor.requestValidated  {
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

/**
 This operation is designed to determine if the operation chain should proceed. It validates that a request to the remote store should be made by looking at the incoming request and comparing the current time with the ttl of a previous matching request. If the request has expired, it sets the calling operation, a request constructor, to a valid request state, otherwise, it does nothing, causing the request constructor to fail.
*/
class RequestValidation: Operation {

    let request: NetworkStoreRequest

    let graphManager: OperationGraphManager

    let requestConstructor: RequestConstructionOperation

    init(partitionOp: RemoteStoreRequestOperation, requestConstructor: RequestConstructionOperation) {
        self.graphManager = partitionOp.graphManager
        self.request = partitionOp.storeRequest
        self.requestConstructor = requestConstructor
    }

    override func execute() {
        requestProcessor: do {
            if let request = request as? NetworkStoreFetchRequest  {
                var keyToUpdate:NSDate? = nil

                // Has this request already been made and are the results still valid?
                for (key, value) in self.graphManager.fetchRequests {
                    if request.entity! == value.entity && request.predicate?.description == value.predicateString {
                        if value.status == FulfillmentStatus.pending {
                            break requestProcessor
                        } else if key.compare(NSDate()) != NSComparisonResult.OrderedDescending {
                            keyToUpdate = key
                            break
                        } else {
                            break requestProcessor
                        }
                    }
                }

                // Update the ttl for the expried key
                if keyToUpdate != nil {
                    var timeToLive:Double = 0.0
                    self.graphManager.fetchRequests.removeValueForKey(keyToUpdate!)
                    if request.entity!.userInfo?[kTimeToLive] != nil && request.entity!.userInfo?[kTimeToLive] is String {
                        timeToLive = (request.entity!.userInfo![kTimeToLive] as? NSString)!.doubleValue
                    }
                    keyToUpdate = NSDate(timeIntervalSinceNow: timeToLive)
                    self.graphManager.fetchRequests.updateValue((request.entity!, request.predicate!.description, FulfillmentStatus.pending), forKey: keyToUpdate!)
                }

                // Set the request as being a valid request on the constructor, thereby meeting the condition.
                self.requestConstructor.requestValidated = true
            }
        }
    }
}


