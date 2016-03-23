//
//  OperationGraphManager.swift
//

import CoreData

/**
 The OperationGraphManager manages a serial queue of transactions that request and transmit data to remote stores. All of its public methods are thread-safe, and it can be managed through the public DataLayer interface and instance.
 
 In addition to its public methods, access to underlying objects, including the transaction queue are provided to allow for additional customization and management of critical code paths.
*/
public class OperationGraphManager: NSObject, OperationQueueDelegate {

    // MARK : Properties

    /**
    The URLConfiguration used by default for transaction sessions. You can override the URLConfiguration by returning a different configuration in the DataLayer delegate method URLConfiguration(dataLayer, defaultURLConfiguration).
    */
    lazy var URLConfiguration: NSURLSessionConfiguration = {
        var configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = 300

        return self.coordinator.dataManager?.delegate?.URLConfiguration?(self.coordinator.dataManager!, defaultURLConfiguration: configuration) ?? configuration
        }()

    /**
     The internal setter for the PersistentStoreCoordinator(PSC). The PSC should only be set on initialization.
     */
    private(set) var coordinator: PersistentStoreCoordinator

    /**
     A convenience reference to the stack ID of the parent DataLayer object.
     */
    var stackID: String { return self.coordinator.dataManager?.stackID ?? "" }

    /**
     The fetch requests dictionary contains all of the fetch requests successfully processed by an OperationGraphManager instance. You can use this list to reissue all of the requests made during a particular period of time as an easy way to return the local cached data to a specific state.
     
     - Note: The entire operation graph is destroyed and recreated when the parent DataLayer is reset. To reissue the requests, make a copy of this list prior to resetting the DataLayer.
     */
    var fetchRequests:Dictionary<NSDate, (entity: NSEntityDescription, predicateString: String?, status: FulfillmentStatus)> = Dictionary()

    /**
     The operation queue used by the operation graph manager to dispatch transaction operations.
     */
    lazy private(set) var queue: OperationQueue = {
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.name = "com.datadriverlayer.operationGraphManagerQueue"
        opQueue.delegate = self
        return opQueue
    }()

    // MARK: Object Life-Cycle

    init (coordinator:PersistentStoreCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    func addTransactions(transactionRequest: NSPersistentStoreRequest) -> Void {
        // Add the request processing as a block on the internal queue that depends on the pre-existing transactions to complete.
    }

//requestProcessor: do {
//
//    if let request = request as? NetworkStoreFetchRequest  {
//        var keyToUpdate:NSDate? = nil
//
//        // Has this request already been made and are the results still valid?
//        for (key, value) in fetchRequests {
//            if request.entity! == value.entity && request.predicate?.description == value.predicateString {
//                if value.status == FulfillmentStatus.pending {
//                    break requestProcessor
//                } else if key.compare(NSDate()) != NSComparisonResult.OrderedDescending {
//                    keyToUpdate = key
//                    break
//                } else {
//                    break requestProcessor
//                }
//            }
//        }
//
//        // Update the ttl for the expried key
//        if keyToUpdate != nil {
//            var timeToLive:Double = 0.0
//            fetchRequests.removeValueForKey(keyToUpdate!)
//            if request.entity!.userInfo?[kTimeToLive] != nil && request.entity!.userInfo?[kTimeToLive] is String {
//                timeToLive = (request.entity!.userInfo![kTimeToLive] as? NSString)!.doubleValue
//            }
//            keyToUpdate = NSDate(timeIntervalSinceNow: timeToLive)
//            fetchRequests.updateValue((request.entity!, request.predicate!.description, FulfillmentStatus.pending), forKey: keyToUpdate!)
//        }
//
//        // if it's expired or doesn't exist, rerequest it.
//        let overrideComponents:NSURLComponents? = context.userInfo[kOverrideComponents] as? NSURLComponents
//        let overrideTokens:Dictionary<NSObject, AnyObject>? = context.userInfo[kOverrideTokens] as? Dictionary<NSObject, AnyObject>
//        guard let requestEntity = request.entity as NSEntityDescription! else { break requestProcessor }
//        let changeRequest = RemoteStoreRequest(entity: requestEntity, property: nil, predicate: request.predicate, URLOverrides: overrideComponents, overrideTokens: overrideTokens, methodType: .GET, methodBody: nil, destinationID: nil)
//        self.operationGraphManager.requestNetworkStoreOperations([changeRequest])
//
//
//    } else if let request = request as? NetworkStoreSaveRequest {
//        saveRequests: do {
//            guard let stackID = self.dataManager?.stackID else { break saveRequests }
//            var changes:Array<RemoteStoreRequest> = []
//            if let insertedObjects = request.insertedObjects {
//                changes.appendContentsOf(InsertionFactory.process(insertedObjects, stackID: stackID))
//            }
//            if let updatedObjects = request.updatedObjects {
//                changes.appendContentsOf(UpdateFactory.process(updatedObjects, stackID: stackID))
//            }
//            if let deletedObjects = request.deletedObjects {
//                changes.appendContentsOf(DeletionFactory.process(deletedObjects, stackID: stackID))
//            }
//            self.operationGraphManager.requestNetworkStoreOperations(changes)
//        }
//    }

}
