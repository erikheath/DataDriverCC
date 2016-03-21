//
//  StoreReference.swift
//

import Foundation

/**
 A StoreReference object represents all of the information needed to add a store of a supported store type to a persistent store coordinator. When used with a Data Layer object, one or more StoreReference objects are passed as a parameter during Data Layer initialization.
 */
public class StoreReference: NSObject {

    /**
     One of the available store types defined by Core Data: NSSQLiteStoreType, NSBinaryStoreType, NSXMLStoreType, or NSInMemoryStoreType.
     */
    public let storeType: String

    /**
     An configuration name defined in a model. If multiple stores will be used, the configuration parameter may not be nil.
     */
    public let configuration: String?

    /**
     The URL of the store, if it is to be persisted locally. This property is nil if the store reference is for an in-memory store.
     */
    public let URL: NSURL?

    /**
     A Dictionary containing any of the option key value pairs defined and supported for the store type by the NSPersistentStoreCoordinator class.
     */
    public let options: [NSObject : AnyObject]?

    /**
     Creates a new storeReference object that can be used when initializing a Data Layer. If multiple stores will be used, the configuration parameter may not be nil.

     - parameter storeType: One of the available store types defined by Core Data: NSSQLiteStoreType, NSBinaryStoreType, NSXMLStoreType, or NSInMemoryStoreType.

     - parameter configuration: If the model has configurations, one of the configuration names.

     - parameter URL: If the store type is persistent (i.e. not NSInMemoryStoreType), then a URL must be specified.

     - parameter options: Any of the available Store Options or Migration Options defined and supported for a store type by the NSPersistentStoreCoordinator class.

     - Returns: An initialzed StoreReference object suitable for use during DataLayer initialization.
     */
    public init (storeType: String, configuration: String?, URL: NSURL?, options: [NSObject : AnyObject]?) {

        self.storeType = storeType
        self.configuration = configuration
        self.URL = URL
        self.options = options
    }
}

