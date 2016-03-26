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
    The owner of the transaction.
    */
    weak private(set) var graphManager: OperationGraphManager?

    /**
    Each transaction has a context that is the parent of each partition it contains. A transaction context aggregates all of the changes made by each partition. In the event of a failure to aggregate the changes of a partition, the transaction will fail unless the context is cleaned up by the transaction's delegate.
    */
    lazy var transactionContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        moc.parentContext = self.graphManager?.coordinator?.dataManager?.mainContext
        return moc
    }()

    /**
     The session used by the transaction. Each transaction maintains its own session on which its requests are dispatched. A custom session can be set by a delegate in the delegate method URLSession(transaction, defaultURLSession)
     */
    lazy var URLSession:NSURLSession = {
        let session = NSURLSession(configuration: self.URLSessionConfiguration, delegate: nil, delegateQueue: nil)
        return self.delegate?.URLSession?(self, defaultURLSession: session) ?? session
    }()

    /**
     Provides the default configuration. Can be overridden with a custom configuration prior to a URLSession being created in the execution methods.
     */
    lazy private(set) var URLSessionConfiguration: NSURLSessionConfiguration = {
        return self.graphManager?.URLConfiguration ?? NSURLSessionConfiguration.defaultSessionConfiguration()
    }()

    /**
     Assign an object to this property to be notified of significant transaction events and to alter the transaction's behavior. This is different from a transaction observer which is simply notified of events without the possibility of intervening.
     */
    weak var delegate: TransactionDelegate? = nil

    // MARK: - Object Lifecycle
    init (request:NetworkStoreRequest, graphManager: OperationGraphManager) {

        self.graphManager = graphManager

        super.init(operations: Array<Operation>())

        // Each of these corresponds to a transaction partition, which is a set of
        // operations that make up the chain of actions necessary to request and
        // process data for a specific URL.
        if let request = request as? NetworkStoreFetchRequest  {
            self.addOperation(RemoteStoreRequestOperation(storeRequest: request, transaction: self))
        } else if let request = request as? NetworkStoreSaveRequest {
            if let deletedObjects = request.deletedObjects {
                let saveReq = NetworkStoreSaveRequest(insertedObjects: nil, updatedObjects: nil, deletedObjects: deletedObjects, lockedObjects: nil)
                self.addOperation(RemoteStoreRequestOperation(storeRequest: saveReq, transaction: self))
            }
            if let insertedObjects = request.insertedObjects {
                let saveReq = NetworkStoreSaveRequest(insertedObjects: insertedObjects, updatedObjects: nil, deletedObjects: nil, lockedObjects: nil)
                self.addOperation(RemoteStoreRequestOperation(storeRequest: saveReq, transaction: self))
            }
            if let updatedObjects = request.updatedObjects {
                let saveReq = NetworkStoreSaveRequest(insertedObjects: nil, updatedObjects: updatedObjects, deletedObjects: nil, lockedObjects: nil)
                self.addOperation(RemoteStoreRequestOperation(storeRequest: saveReq, transaction: self))
            }
        }

    }

    func addRemoteStoreRequest(request: RemoteStoreRequest) {
        
    }

    override func execute() {
        super.execute()
    }
}


