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
     The combined request components that resulted from the partition processing.
     */
    var partitionRequest: RemoteStoreRequest? = nil

    /**
     The URL that resulted from the partition processing.
     */
    var URLRequest: NSMutableURLRequest? = nil
    /**
     The fetch or save changes request that generated the partition.
     */
    let storeRequest: NetworkStoreRequest

    /**
     The graph manager that is in use by the transaction.
     */
    let graphManager: OperationGraphManager

    /**
     The context the partition uses to record and save any changes.
     */
    let partitionContext: NSManagedObjectContext

    /**
     The session used by the transaction the partition is a part of to execute remote requests.
     */
    let URLSession: NSURLSession

    /**
     A partition may generate additional partitions. These are stored here until the source partition completes
     */
    var generatedPartitionRequests = Array<RemoteStoreRequest>()

    // MARK: - Object Lifecycle
    init(storeRequest: NetworkStoreRequest, graphManager: OperationGraphManager, session: NSURLSession, context: NSManagedObjectContext) {
        // Phase 1 initialization
        self.storeRequest = storeRequest
        self.graphManager = graphManager
        self.URLSession = session
        self.partitionContext = context

        // Phase 2 initialization

    }
}


