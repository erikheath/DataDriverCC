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

    var partitionOp: RemoteStoreRequestOperation? = nil

    var dataConditioner: DataConditionerOperation? = nil

    convenience init(partitionOp: RemoteStoreRequestOperation, dataConditioner: DataConditionerOperation) {
        self.init()

        self.partitionOp = partitionOp
        self.dataConditioner = dataConditioner
        self.addCondition(RequestConstructionCondition(partitionOp: self.partitionOp!, dataRequestor: self))
    }

    override init() {
        super.init()
    }

    override func execute() {

        do {
            guard let partitionOp = self.partitionOp, let dataConditioner = self.dataConditioner, let URLSession = partitionOp.URLSession else {
                throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
            }
            partitionOp.resolvedURLRequest = try partitionOp.URLRequest?.resolveURL()
            guard let resolvedURLRequest = partitionOp.resolvedURLRequest else { throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
            }
            let downloadTask = URLSession.delegate != nil ? URLSession.downloadTaskWithRequest(resolvedURLRequest) : URLSession.downloadTaskWithRequest(resolvedURLRequest, completionHandler: { (location: NSURL?, response: NSURLResponse?, error: NSError?) -> Void in
                if let location = location where error == nil {
                    dataConditioner.dataRetrieved = true
                    dataConditioner.dataToProcess = NSData(contentsOfURL: location)
                }

            })
            downloadTask.resume()
        } catch { }

        self.finish()
    }


    
}