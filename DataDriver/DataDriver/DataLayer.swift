//
//  DataLayer.swift
//

import CoreData

/**
 The DataLayer class is the top-level class in this data management system. Creating an instance of this class creates a ready to use stack with support for local stores, remote network stores, and in-memory stores. You control the type of stores created by passing in an array of one or more StoreReference objects. Each StoreReference object contain all of the information necessary to configure the internal persistent store coordinator to use the store (local, remote, or in-memory). To use more than one store, you must define a configuration with each store.
 
 For example, you can store data that you only need to download infrequently in a local SQLite store, while storing temporary data that should be flushed everytime the app is restarted or returns from being suspended in an in-memory store. Various setups are supported, including the ability to fetch from specific stores. See the documentation for NSFetchRequest for a complete list of options.

 - Note: 

 Due to the initialization chain in swift, it's not possible to refer to instance methods or to self until phase one of the initialization process is complete. As a result, variables that are declared with let that refer to values inside of the object being instantiated must be changed to an optional var to allow for an initial nil state that can be changed in phase two of initialization, or changed to a lazy var allowing the initialization to be put off until a later time (potentially even post initialization). For private variables, this is less of a concern as a class can usually control mutation, however, for public variables that should really be constant, this creates a challenge that should be remedied to give as much dependability as possible.

 This data management system uses private class (static) methods to deal with this design decision in swift. While it might seem strange to have static initialization methods for properties as factory-type static methods are generally only associated with entire class instances, private static methods have a number of advantages for this more complex initialization scenario that allow them to fit into the swift's two-phase initialization system.
 - As class methods, they are immediately accessible during initialization, and like phase one of initialization, can not refer to the instance (self) being created.
 - As class methods, each one operates in a very encapsulted manner, meaning you need to pass whatever you want to use in versus referring to instance properties.
 - Because they are so encapsulated, they are easily testable: you can test both the construction and the assignment independently as well as in sequence.

 What this doesn't solve, and in fact where there is no current solution, is the phase one initialization of properties where the creation process can throw an error. You can not throw an error in phase one, which effectively means that if you have an initialization of a constant property that can throw and should make initialization fail, you can not declare it as a constant as all properties must have an initial known state before phase two where throwing is supported. There are ways to mask vars, for example with private setters or by making the var private with a computed property. The missed opportunity with these techniques is that they circumvent the intention of declaring something with let: it should only be set to a value once and the programmer should be prevented from accidentally setting it again. This is an extremely powerful construct that not only prevents problems, but also quickly localizes them (it's only set in one place after all).

 Using private class methods goes in the direction of keeping properties that should be declared with let stay declared with let while supporting more complex initialization requirements.
*/
public class DataLayer: NSObject {

    /**
     A unique identifier provided at initialization that is used to retrieve various processing objects like data conditioners, url processor objects, etc. If you do not provide a stack ID at initialization, one will be created and assigned.
     */
    public let stackID: String

    public enum DataLayerStatus: String {
        case Loading = "DataLayerLoading"
        case NotLoading = "DataLayerNotLoading"
    }

    public private(set) var loadingStatus: DataLayerStatus = .NotLoading

    /**
     If / when the preload fetch completes, this property will be set to true. This value is KVO compliant.
     */
    dynamic public private(set) var preloadComplete: Bool = false

    /**
     The number of seconds to wait before refreshing (re-executing the preload in this case) the data from the remote store. The minimum value is 10 minutes
     */
    public var refreshSeconds: Int {
        set {
            if newValue > 1200 {
                refreshDelay = newValue
            } else {
                refreshDelay = 1200
            }
        }

        get {
            return refreshDelay
        }
    }

    private var refreshDelay: Int = 1200
    public private(set) var lastRefresh: NSDate? = nil

    /**
     Turns auto-refresh on/off. By default, the data layer will not auto-refresh. If you set the data layer to auto-refresh, it will do so when the app comes to the foreground at intervals approximating the refreshSeconds property.
     */
    public var autoRefresh: Bool {
        set {
            objc_sync_enter(self)
            refreshData = newValue
            objc_sync_exit(self)
        }

        get {
            return refreshData
        }
    }

    private var refreshData: Bool = false

    func applicationEnteredForeground(notification: NSNotification) {
        // Check the data refresh to see if it should be performed.
        if self.autoRefresh == true && NSTimeInterval(self.refreshSeconds) < abs((self.lastRefresh?.timeIntervalSinceNow)!) {
                self.reset(true)
        } else if preloadComplete == true {
            loadingStatus = .NotLoading
            preloadComplete = true
        }
    }

    /**
     A preloadFetch is one or more NSFetchRequests that should be executed immediately upon successful object creation. Typically this will involve triggering an asynchronous fetch over the network for data that is not in one or more local stores. Because a preload does not return results to the initialization caller, it is strongly recommended that the request only be for object ids, and not for fully populated objects as this creates unnecessary processing overhead. All standard notifications are processed and dispatched with a preload fetch, which means that, depending on your initialization sequence, you may receive multiple notifications for requests you have not issued directly. Because of this, is essential to inspect the id of a notification to make certain that it corresponds to your request.
    */
    public let preloadFetch: Array<NSFetchRequest>?

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
     The network context serves as the context that coordinates receipt and posting of data from network store operations to the main context. The network context serves as the parent of various contexts that are temporarily created to handle data retrieval from one or more network stores / endpoints as well as a stable reference for asynchronous activity that needs to have a reliable path into the data management system.
    */
    public let networkContext: NSManagedObjectContext

    /**
     Initializer for the network context.
     
     - Parameter parentContext: The context that should be assigned as the parent of the newly created context.
     
     - Returns: An initialized managed context object with the name com.datadriverlayer.networkContext and the passed in context set as its parent.
     */
    private static func initializeNetworkContext(parentContext: NSManagedObjectContext) -> NSManagedObjectContext {

        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.parentContext = parentContext
        managedObjectContext.undoManager = nil
        managedObjectContext.name = "com.datadriverlayer.networkContext"

        return managedObjectContext
    }

    /**
     The persistent store coordinator serves to coordinate write and reads from one or more stores. The coordinator provides access to the model, array of stores (local and in-memory), and coordinates reads and writes from / to network stores.
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

    public var status: Bool = false

    func preloadComplete(notification: NSNotification) {
        self.preloadComplete = true
        self.loadingStatus = .NotLoading
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
    public init(stores: [StoreReference], model: NSManagedObjectModel, preload: Array<NSFetchRequest>?, stackID: String?) throws {

        self.stackID = stackID != nil ? stackID! : NSUUID().UUIDString

        // Begin Phase One Initialization

        self.preloadFetch = preload

        // Set up the stack
        let coordinator = DataLayer.initializeCoordinator(model)
        let master = DataLayer.initializeMasterContext(coordinator)
        let main = DataLayer.initializeMainContext(master)
        let network = DataLayer.initializeNetworkContext(main)

        // Assign the stack
        self.persistentStoreCoordinator = coordinator
        self.masterContext = master
        self.mainContext = main
        self.networkContext = network
        self.persistentStores = stores

        super.init()

        // End of Phase One Initialization. Begin Phase Two Initialization

        // Add the stores
//        do {
//            for store in stores {
//                let result = try coordinator.addPersistentStoreWithType(store.storeType, configuration: store.configuration, URL: store.URL, options: store.options)
//            }
//        } catch { }

        // Assign delegates, parent references to child objects, etc.
        self.persistentStoreCoordinator.dataManager = self

        // Register for the notification for the preload fetch.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "preloadComplete:", name: "preloadComplete", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationEnteredForeground:", name: UIApplicationWillEnterForegroundNotification, object: nil)

        // Execute the preload fetch
        self.reset(true)
        // Initialization complete
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func reset(reload:Bool) -> Void {
        do {
            self.preloadComplete = false
            self.loadingStatus = .Loading
            lastRefresh = NSDate()
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
            self.networkContext.performBlockAndWait({ () -> Void in
                self.networkContext.reset()
            })
            self.persistentStoreCoordinator.operationGraphManager.requestCount = 0
            self.persistentStoreCoordinator.operationGraphManager.responseCount = 0
        } catch { }

        guard let _ = self.preloadFetch where reload == true else { return }
        for request in self.preloadFetch! {
            self.masterContext.performBlock { () -> Void in
                do {
                    try self.masterContext.executeFetchRequest(request)
                } catch {
                    /*
                    TODO: Add a notification dispatch for any error

                    */
                }
            }
        }

    }


}


