//
//  OperationGraphManager.swift
//

import CoreData

/**
 The OperationGraphManager manages a serial queue of transactions that request and transmit data to remote stores.
 
 In addition to its public methods, access to underlying objects, including the transaction queue are provided to allow for additional customization and management of critical code paths.
*/
public class OperationGraphManager: NSObject, OperationQueueDelegate {

    // MARK : Properties

    /**
    The URLConfiguration used by default for transaction sessions. You can override the URLConfiguration by returning a different configuration in the DataLayer delegate method URLConfiguration(dataLayer, defaultURLConfiguration) which is called during initialization.
    */
    public let URLConfiguration: NSURLSessionConfiguration

    /**
     Private initializer for the URLConfiguration property.
     */
    private static func initializeURLConfiguration(dataManager: DataLayer?) -> NSURLSessionConfiguration {

        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = 300

        guard let dataManager = dataManager else {
            return configuration
        }

        return dataManager.delegate?.URLConfiguration?(dataManager, defaultURLConfiguration: configuration) ?? configuration

    }
    
    /**
     The PersistentStoreCoordinator(PSC). The PSC is only set on initialization.
     */
    private(set) weak var coordinator: PersistentStoreCoordinator?

    /**
     A convenience reference to the stack ID of the parent DataLayer object.
     */
    public var stackID: String { return self.coordinator?.dataManager?.stackID ?? "" }

    /**
     The fetch requests dictionary contains all of the fetch requests successfully processed by an OperationGraphManager instance. You can use this list to reissue all of the requests made during a particular period of time as an easy way to return the local cached data to a specific state.
     
     - Note: The entire operation graph is destroyed and recreated when the parent DataLayer is reset. To reissue the requests, make a copy of this list prior to resetting the DataLayer.
     */
    public var fetchRequests:Dictionary<NSDate, (entity: NSEntityDescription, predicateString: String?, status: FulfillmentStatus)> = Dictionary()

    /**
     The operation queue used by the operation graph manager to dispatch transaction operations.
     */
    lazy public private(set) var queue: OperationQueue = {
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.name = "com.datadriverlayer.operationGraphManagerQueue"
        opQueue.delegate = self
        return opQueue
    }()

    /**
     The delegate will receive DataLayerDelegate messages from the graph manager.
     */
    private weak var delegate: DataLayerDelegate?

    // MARK: Object Life-Cycle

    /**
    An OperationGraphManager object is constructed by passing in a coordinator and optional delegate. On initialization, the object will send setup messages to its delegate, enabling limited customization of the graph manager.
    
    - Parameter coordinator: The PersistentStoreCoordinator that owns the graph manager.
    
    - Parameter delegate: An optional DataLayerDelegate instance that will receive all outbound delegate protocol messages.
    */
    init (coordinator:PersistentStoreCoordinator, delegate: DataLayerDelegate?) {
        self.coordinator = coordinator
        self.delegate = delegate

        self.URLConfiguration = OperationGraphManager.initializeURLConfiguration(coordinator.dataManager)
        super.init()
    }

    /**
     Adds a transaction based on a NSPersistentStoreRequest to the OperationGraphManager's internal queue.
     
     - Parameter transactionRequest: An NSPersistentStoreRequest. The actual type of the request subclass must be a NetworkStoreFetchRequest or NetworkStoreSaveRequest to generate a transaction. All other requests are processed and do not result in the creation of a transaction.
     */
    func addTransaction(transactionRequest: NSPersistentStoreRequest) -> Void {
        // Add the request processing as a block on the internal queue that depends on the pre-existing transactions to complete.
        objc_sync_enter(self)
        let blockOp = BlockOperation() { (continuation: Void -> Void) in
            if let transactionRequest = transactionRequest as? NetworkStoreRequest  {
                let proposedTransaction = TransactionOperation(request: transactionRequest, graphManager: self)
                let currentOperations = self.queue.operations
                for op in currentOperations {
                    proposedTransaction.addDependency(op)
                }
                self.queue.addOperation(proposedTransaction)
            }
            continuation()
        }
        self.queue.addOperation(blockOp)
        objc_sync_exit(self)
    }

}
