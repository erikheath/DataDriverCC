//
//  RequestDataOperation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData

struct RequestDataCondition: OperationCondition {

    static let name = "RequestData"

    static let isMutuallyExclusive = false

    let partitionOp: RemoteStoreRequestOperation

    let dataConditioner: DataConditionerOperation

    init(partitionOp: RemoteStoreRequestOperation, dataConditioner: DataConditionerOperation) {
        self.partitionOp = partitionOp
        self.dataConditioner = dataConditioner
    }

    func dependencyForOperation(operation: Operation) -> NSOperation? {
        guard let operation = operation as? DataConditionerOperation else { return nil }

        return RequestDataOperation(partitionOp: self.partitionOp, dataConditioner: operation)
    }

    func evaluateForOperation(operation: Operation, completion:OperationConditionResult -> Void) {
        switch self.dataConditioner.dataRetrieved  {
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


class RequestDataOperation: Operation {

    var requestConstructed: Bool = false

    let partitionOp: RemoteStoreRequestOperation

    let dataConditioner: DataConditionerOperation

    init(partitionOp: RemoteStoreRequestOperation, dataConditioner: DataConditionerOperation) {
        self.partitionOp = partitionOp
        self.dataConditioner = dataConditioner
        super.init()

        self.addCondition(RequestConstructionCondition(partitionOp: self.partitionOp, dataRequestor: self))
    }

    override func execute() {
        do {
            self.partitionOp.resolvedURLRequest = try self.partitionOp.URLRequest?.resolveURL()

            let downloadTask = self.partitionOp.URLSession.delegate != nil ? self.partitionOp.URLSession.downloadTaskWithRequest(self.partitionOp.resolvedURLRequest!) : self.partitionOp.URLSession.downloadTaskWithRequest(self.partitionOp.resolvedURLRequest!, completionHandler: { (location: NSURL?, response: NSURLResponse?, error: NSError?) -> Void in
                if let location = location where error == nil {
                    self.dataConditioner.dataRetrieved = true
                    self.dataConditioner.dataToProcess = NSData(contentsOfURL: location)
                }
                self.finish()
            })
            downloadTask.resume()
        } catch { }
    }


    
}