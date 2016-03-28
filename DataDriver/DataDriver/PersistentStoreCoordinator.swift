//
//  PersistentStoreCoordinator.swift
//

import CoreData

/**
 The PersistentStoreCoordinator object is a subclass of NSPersistentStoreCoordinator that has been adapted to provide network store retrieval capabilities when requesting data.
*/
public class PersistentStoreCoordinator: NSPersistentStoreCoordinator {

    /**
     The parent data manager the coordinator supports.
    */
    public weak var dataManager: DataLayer?

    /**
     The operation graph manager used by the coordinator to prioritize and dispatch network operations.
    */
    lazy public private(set) var operationGraphManager: OperationGraphManager = OperationGraphManager(coordinator: self, delegate: self.dataManager?.delegate)

    // MARK: Conditional Processing

    /**
     The override of the execute request method is used to insert conditional processing for network based requests. See the documentation for the parent class for a complete explanation of this method external to the changes made in this override.
    */
    override public func executeRequest(request: NSPersistentStoreRequest, withContext context: NSManagedObjectContext) throws -> AnyObject {
        self.operationGraphManager.addTransaction(request)
        return try super.executeRequest(request, withContext: context)
    }
}


