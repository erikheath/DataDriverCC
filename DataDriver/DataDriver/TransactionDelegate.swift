//
//  TransactionDelegate.swift
//  DataDriver
//

import CoreData

/**
 The TransactionDelegate protocol provides insertion points for conditional logic for a TransactionOperation.
 */
@objc public protocol TransactionDelegate: NSObjectProtocol {

    /**
     Implement this method to provide a custom session for a transaction, or to set a custom delegate, queue, etc., for a transaction's NSURLSession.
     
     - Parameter transaction: The transaction that will use the session.
     
     - Parameter defaultURLSession: Each transaction uses its own NSURLSession for all of its partitions. Depending on the type of transaction, there can be hundreds of partitions. The default URL Session uses the its Operation Graph Manager's NSURLConfiguration during creation.
     
     - Returns: A new NSURLSession with the required changes, if any.
     */
    optional func URLSession(transaction: TransactionOperation, defaultURLSession: NSURLSession) -> NSURLSession

    /**
     Implement this method to add information supported by a NetworkStoreSaveRequest.
     
     - Parameter transaction: The transaction that will be servicing the network store request.
     
     - Parameter currentRequest: The request constructed by the transaction from the information received from the NSSaveChangesRequest.
     
     - Parameter originalRequest: The NSSaveChangesRequest received by the transaction.
     
     - Returns: A new NetworkStoreSaveRequest with any additional information needed to process the request. This will often consistent of URL Overrides.
     */
    optional func networkStoreSaveRequest(transaction: TransactionOperation, currentRequest: NetworkStoreSaveRequest, originalRequest: NSSaveChangesRequest) -> NetworkStoreSaveRequest

}

