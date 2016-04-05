//
//  RemoteStoreRequestOperation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData


/**
 The purpose of this operation is to construct a partition of a transaction based on a request, and to generate any additional RemoteStoreRequestOperations for requests that emerge from processing.
*/
public class RemoteStoreRequestOperation: Operation {

    /**
     The transaction the partition belongs to.
     */
    var transaction: TransactionOperation? = nil

    /**
     The combined request components that resulted from the partition processing.
     */
    var partitionRequest: RemoteStoreRequest? = nil

    /**
     The URL that resulted from the partition processing.
     */
    var URLRequest: NSMutableURLRequest? = nil

    /**
     The resolved URL generated from the URLRequest
     */
    var resolvedURLRequest: NSMutableURLRequest? = nil

    /**
     The fetch or save changes request that generated the partition.
     */
    private(set) var storeRequest: NetworkStoreRequest? = nil

    /**
     The context the partition uses to record and save any changes. This context is a child of the Transaction Context.
     
     - Note: This context uses the PrivateQueue concurrency model.
     */
    var partitionContext: NSManagedObjectContext? = nil

    /**
     Private initializer for the partition context.
     */
    internal static func initializePartitionContext(transaction: TransactionOperation?) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = transaction?.transactionContext
        return context
    }

    /**
     The session used by the transaction the partition is a part of to execute remote requests.
     */
    var URLSession: NSURLSession? = nil

    /**
     Indicates if the updates to the partition's context have been validated.
     */
    var updatesValidated: Bool = false

    /**
     A partition may generate additional partitions. These are stored here until the source partition completes
     */
    var generatedPartitionRequests = Array<RemoteStoreRequest>()

    // MARK: - Object Lifecycle

    convenience init(storeRequest: NetworkStoreRequest, transaction: TransactionOperation) {

        self.init(transaction: transaction)

        self.storeRequest = storeRequest
        self.addCondition(DataConditionerCondition(partitionOp: self))
    }

    convenience init(partitionRequest: RemoteStoreRequest, transaction: TransactionOperation) {

        self.init(transaction: transaction)

        self.partitionRequest = partitionRequest
        self.addCondition(DataConditionerCondition(partitionOp: self))

    }

    convenience init(transaction: TransactionOperation) {
        self.init()
        self.transaction = transaction
        self.partitionContext = RemoteStoreRequestOperation.initializePartitionContext(transaction)
        self.URLSession = transaction.URLSession

    }

    override init() {
        super.init()
    }

    override func execute() {
        finish()
    }
}


