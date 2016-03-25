//
//  DataLayer.swift
//

import CoreData

/**
 The DataLayer class is the top-level class in this data management system. Creating an instance of this class creates a ready to use stack with support for local stores, remote network stores, and in-memory stores. You control the type of stores created by passing in an array of one or more StoreReference objects. Each StoreReference object contains all of the information necessary to configure the internal persistent store coordinator to use the store (local, remote, or in-memory). To use more than one store, you must define a configuration.
 
 For example, you can store data that you only need to download infrequently in a local SQLite store, while storing temporary data that should be flushed everytime the app is restarted or returns from being suspended in an in-memory store. Various setups are supported, including the ability to fetch from specific stores. See the documentation for NSFetchRequest for a complete list of options.

 - Note: 

 Due to the initialization chain in swift, it's not possible to refer to instance methods or to self until phase one of the initialization process is complete. As a result, variables that are declared with let that refer to values inside of the object being instantiated must be changed to an optional var to allow for an initial nil state that can be changed in phase two of initialization, or changed to a lazy var allowing the initialization to be put off until a later time (potentially even post initialization). For private variables, this is less of a concern as a class can usually control mutation, however, for public variables that should really be constant, this creates a challenge that should be remedied to give as much dependability as possible.

 This data management system uses private class (static) methods to deal with this design decision in swift. While it might seem strange to have static initialization methods for properties as factory-type static methods are generally only associated with entire class instances, private static methods have a number of advantages for this more complex initialization scenario that allow them to fit into swift's two-phase initialization system.

 - As class methods, they are immediately accessible during initialization, and like phase one of initialization, can not refer to the instance (self) being created.

 - As class methods, each one operates in a very encapsulted manner, meaning you need to pass whatever you want to use in versus referring to instance properties.

 - Because they are so encapsulated, they are easily testable: you can test both the construction and the assignment independently as well as in sequence.

 What this doesn't solve, and in fact where there is no current solution, is the phase one initialization of properties where the creation process can throw an error. You can not throw an error in phase one, which effectively means that if you have an initialization of a constant property that can throw and should make initialization fail, you can not declare it as a constant as all properties must have an initial known state before phase two where throwing is supported. There are ways to mask vars, for example with private setters or by making the var private with a computed property. The missed opportunity with these techniques is that they circumvent the intention of declaring something with let: it should only be set to a value once and the programmer should be prevented from accidentally setting it again. This is an extremely powerful construct that not only prevents problems, but also quickly localizes them (it's only set in one place after all).

 Using private class methods goes in the direction of keeping properties that should be declared with let stay declared with let while supporting more complex initialization requirements.
*/
public class DataLayer: NSObject {

    /**
     The DataLayer delegate provides a complete access point for all delegate methods exposed by the various DataLayer protocols. Similar to NSURLSession and its set of protocols, you assign a delegate on initialization to handle delegate messages. The delegate of the DataLayer will receive all of the messages for any of the following protocols: DataLayerDelegate and TransactionDelegate.
     */
    public private(set) weak var delegate: DataLayerDelegate? = nil

    /**
     A unique identifier provided at initialization that is used to retrieve various processing objects like data conditioners, url processor objects, etc. If you do not provide a stack ID at initialization, one will be created and assigned.
     */
    public let stackID: String

    /**
     A preloadFetch is one or more NSFetchRequests that should be executed immediately upon successful object creation. Typically this will involve triggering an asynchronous fetch over the network for data that is not in one or more local stores. Because a preload does not return results to the initialization caller, it is strongly recommended that the request only be for object ids, and not for fully populated objects as this creates unnecessary processing overhead. All standard notifications are processed and dispatched with a preload fetch, which means that, depending on your initialization sequence, you may receive multiple notifications for requests you have not issued directly. Because of this, is essential to inspect the id of a notification to make certain that it corresponds to your request.
    */
    public let preloadFetch: Array<NSFetchRequest>?

    /**
     The persistent stores used by the DataLayer represented as StoreReference objects.
     */
    public private(set) var persistentStores: Array<StoreReference>

    /**
     The master context serves as the context that coordinates writing to the various stores. It is the ultimate parent context and operates on a private queue so that updates to the rather slow disk or network stores can be processed without interupting the UI or slowing down the processing of incoming network data (which is handled on the Network Context).
    */
    public let masterContext: NSManagedObjectContext

    /**
     Initializer for the master context.
     
     - Parameter coordinator: A persistent store coordinator, typically a custom subclass.
     
     - Returns: An initialized managed object context with the name com.datadriverlayer.masterContext.
    */
    private static func initializeMasterContext(coordinator: NSPersistentStoreCoordinator) -> NSManagedObjectContext {

        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        managedObjectContext.undoManager = nil
        managedObjectContext.name = "com.datadriverlayer.masterContext"

        return managedObjectContext
    }
    
    /**
     The main context serves as the context that coordinates providing data on the main / UI thread. It's parent is the master context and it operates on the main queue as part of the update cycle. Writes to the main context should be optimized to be small and many rather than large and few. If data is not part of the local store, whatever data is available will return.
     */
    public let mainContext: NSManagedObjectContext

    /**
     Initializer for the main context.
    
     - Parameter parentContext: The context that should be assigned as the parent of the newly created context.
     
     - Returns: An initialized managed context object with the name com.datadriverlayer.mainContext and the passed in context set as its parent.
    */
    private static func initializeMainContext(parentContext: NSManagedObjectContext) -> NSManagedObjectContext {

        let managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.parentContext = parentContext
        managedObjectContext.undoManager = nil
        managedObjectContext.name = "com.datadriverlayer.mainContext"

        return managedObjectContext

    }

    /**
     The persistent store coordinator serves to coordinate writes and reads from one or more stores. The coordinator provides access to the model, array of stores (local and in-memory), and is part of the coordination chain for reads and writes from / to network stores.
    */
    public let persistentStoreCoordinator: PersistentStoreCoordinator

    /**
     Initializes the internal persistent store coordinator.
     
     - Parameter model: The NSManagedObjectModel that should be used by the persistent store coordinator.
     
     - Returns: An initialized PersistentStoreCoordinator object.
    */
    private static func initializeCoordinator(model: NSManagedObjectModel) -> PersistentStoreCoordinator {

        let coordinator = PersistentStoreCoordinator(managedObjectModel: model)

        return coordinator

    }

    // MARK: Object Lifecycle

    /**
    Initialize the Data Layer by passing in one or more store types, a model, and a fetch request if data should be immediately loaded.
    
    - Parameter stores: An array of one or more StoreReference objects that define the stores that should be enabled for the internal Persistent Store Coordinator.
    
    - Parameter model: The model that the internal persistent store coordinator should use.

    - Parameter preload: An array of fetch requests that should be used to trigger the initial loading of data, typically from a network store. May also be used to populate row caches to speed up data retrieval by subsequent requests. Requests are executed in order one at a time.
    
    - Parameter stackID: A unique ID for the stack that can be used to register processing helper objects.
    
    - Throws: If a store can not be added, an error will be re-thrown from the internal persistent store coordinator.
    
    - Returns: On successful initialization, a fully prepared Core Data Stack.
    */
    public init(stores: [StoreReference], model: NSManagedObjectModel, preload: Array<NSFetchRequest>?, stackID: String?, delegate: DataLayerDelegate?) throws {

        // Begin Phase One Initialization

        self.stackID = stackID != nil ? stackID! : NSUUID().UUIDString

        self.delegate = delegate

        self.preloadFetch = preload

        // Set up the stack
        let coordinator = DataLayer.initializeCoordinator(model)
        let master = DataLayer.initializeMasterContext(coordinator)
        let main = DataLayer.initializeMainContext(master)

        // Assign the stack
        self.persistentStoreCoordinator = coordinator
        self.masterContext = master
        self.mainContext = main
        self.persistentStores = stores

        super.init()

        // Begin Phase Two Initialization

        // Assign delegates, parent references to child objects, etc.
        self.persistentStoreCoordinator.dataManager = self

        // Add the stores and execute the preload fetch, if any.
        try self.reset(true)

        // Initialization complete
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    /**
     Use this method to reset the DataLayer without changing the stores.
     
     - Parameter reload: If true, will cause the DataLayer to execute the preload fetch after resetting the DataLayer.
     
     - Warning: When the DataLayer is reset, the main context will be reset. This means that all managedObjects will become instantly invalid, all row counts incorrect, etc. Resetting is a completely destructive process. As a result, it is necessary to remove any dependencies to the main context prior to calling this method. For example, an instance of NSFetchedResultsController attached to a table can have problems when its context resets.
     */
    func reset(reload:Bool) throws -> Void {

        // Remove the stores from the coordinator
        for store in self.persistentStoreCoordinator.persistentStores {
            try self.persistentStoreCoordinator.removePersistentStore(store)
        }

        // Add the stores
        for store in persistentStores {
            try persistentStoreCoordinator.addPersistentStoreWithType(store.storeType, configuration: store.configuration, URL: store.URL, options: store.options)
        }

        self.masterContext.performBlockAndWait({ () -> Void in
            self.masterContext.reset()
        })

        self.mainContext.reset()

        guard let _ = self.preloadFetch where reload == true else { return }

        var error: NSError? = nil
        for request in self.preloadFetch! {
            self.masterContext.performBlock { () -> Void in
                do {
                    try self.masterContext.executeFetchRequest(request)
                } catch let internalError as NSError {
                    error = internalError
                }
            }
        }

        if error != nil { throw error! }
    }

}


