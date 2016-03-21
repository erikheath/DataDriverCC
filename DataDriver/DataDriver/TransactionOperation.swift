//
//  TransactionOperation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData

/**
*/
class TransactionOperation: GroupOperation {

    // MARK: - Properties

    /**
     The session used by the transaction. Each transaction maintains its own session on which its requests are dispatched. A custom session can be set.
     */
    lazy var URLSession:NSURLSession = {
        return NSURLSession(configuration: self.URLSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    /**
     Provides the default configuration. Can be overridden with a custom configuration prior to a URLSession being created in the execution methods.
     */
    var URLSessionConfiguration: NSURLSessionConfiguration = {
        return NSURLSessionConfiguration.defaultSessionConfiguration()
    }()

    /**
     Assign an object to this property to be notified of significant transaction events and to alter the transaction's behavior. This is different from a transaction observer which is simply notified of events without the possibility of intervening.
     */
    weak var delegate: AnyObject? = nil

    // MARK: - Object Lifecycle
    init (requests:Array<RemoteStoreRequest>, graphManager: OperationGraphManager ) {

        // Each of these corresponds to a transaction partition, which is a set of
        // operations that make up the chain of actions necessary to request and
        // process data for a specific URL.
        var operations = Array<Operation>()
        for request in requests {
            operations.append(RemoteStoreRequestOperation(request: request))
        }

        super.init(operations: operations)
    }

    override func execute() {
        super.execute()
    }
}