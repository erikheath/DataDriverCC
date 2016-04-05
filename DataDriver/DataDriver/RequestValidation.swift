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

    var partitionOp: RemoteStoreRequestOperation? = nil

    var requestConstructor: RequestConstructionOperation? = nil

    init(partitionOp: RemoteStoreRequestOperation, requestConstructor: RequestConstructionOperation) {
        self.init()
        self.partitionOp = partitionOp
        self.requestConstructor = requestConstructor
    }

    init() {

    }

    func dependencyForOperation(operation: Operation) -> NSOperation? {
        guard let operation = operation as? RequestConstructionOperation, let _ = self.partitionOp, let _ = self.partitionOp?.transaction?.graphManager, let _ = self.partitionOp?.storeRequest else { return nil }

        return RequestValidation(partitionOp: self.partitionOp!, requestConstructor: operation, graphManager: self.partitionOp!.transaction!.graphManager!, storeRequest: self.partitionOp!.storeRequest!)
    }

    func evaluateForOperation(operation: Operation, completion:OperationConditionResult -> Void) {
        guard let operation = operation as? RequestConstructionOperation else {
            completion(.Satisfied)
            return
        }
        switch operation.requestValidated  {
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

    var request: NetworkStoreRequest? = nil

    var graphManager: OperationGraphManager? = nil

    var requestConstructor: RequestConstructionOperation? = nil

    convenience init(partitionOp: RemoteStoreRequestOperation, requestConstructor: RequestConstructionOperation, graphManager: OperationGraphManager, storeRequest: NetworkStoreRequest) {
        self.init()
        self.graphManager = graphManager
        self.request = storeRequest
        self.requestConstructor = requestConstructor
    }

    override init() {
        super.init()
    }

    override func execute() {
        requestProcessor: do {
            if let request = request as? NetworkStoreFetchRequest  {

                var keyToUpdate:NSDate? = nil
                guard let graphManager = self.graphManager, let requestConstructor = self.requestConstructor else { return }

                // Has this request already been made and are the results still valid?
                for (key, value) in graphManager.fetchRequests {
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
                    graphManager.fetchRequests.removeValueForKey(keyToUpdate!)
                    if request.entity!.userInfo?[kTimeToLive] != nil && request.entity!.userInfo?[kTimeToLive] is String {
                        timeToLive = (request.entity!.userInfo![kTimeToLive] as? NSString)!.doubleValue
                    }
                    keyToUpdate = NSDate(timeIntervalSinceNow: timeToLive)
                    graphManager.fetchRequests.updateValue((request.entity!, request.predicate!.description, FulfillmentStatus.pending), forKey: keyToUpdate!)
                }

                // Set the request as being a valid request on the constructor, thereby meeting the condition.
                requestConstructor.requestValidated = true
                finish()
            }
        }
    }
}


