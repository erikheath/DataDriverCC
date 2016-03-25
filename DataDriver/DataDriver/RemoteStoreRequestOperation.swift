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
class RemoteStoreRequestOperation: Operation {

    /**
     The transaction the partition belongs to.
     */
    let transaction: TransactionOperation

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
    let storeRequest: NetworkStoreRequest

    /**
     The context the partition uses to record and save any changes. This context is a child of the Transaction Context.
     
     - Note: This context uses the PrivateQueue concurrency model.
     */
    lazy private(set) var partitionContext: NSManagedObjectContext = {

    }()

    /**
     The session used by the transaction the partition is a part of to execute remote requests.
     */
    let URLSession: NSURLSession

    /**
     Indicates if the updates to the partition's context have been validated.
     */
    var updatesValidated: Bool = false

    /**
     A partition may generate additional partitions. These are stored here until the source partition completes
     */
    var generatedPartitionRequests = Array<RemoteStoreRequest>()

    // MARK: - Object Lifecycle
    init(storeRequest: NetworkStoreRequest, transaction: TransactionOperation) {
        // Phase 1 initialization
        self.storeRequest = storeRequest
        self.transaction = transaction

        // Phase 2 initialization

    }
}


