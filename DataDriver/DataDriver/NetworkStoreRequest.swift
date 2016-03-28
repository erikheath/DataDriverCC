//
//  NetworkStoreRequest.swift
//


import CoreData

/**
 The NetworkStoreRequest protocol is used to differentiate NSPersistentStoreRequest subclasses that should be processed by the OperationGraphManager of an NSPersistentStore. Any store request subclass that implements the protocol will be routed to the OperationGraphManager, where it will be tested to determine if it is one of the supported request types, currently NetworkStoreSaveRequest and NetworkStoreFetchRequest.
 */
public protocol NetworkStoreRequest: NSObjectProtocol {

    /**
     Assign an NSURLOverrideComponents object to this property to alter the URL used to retrieve network store results.
     */
    var networkStoreURLOverrides: NSURLComponents? { get set }

    /**
     Assign a Dictionary of tokens that should alter the URL used to retrieve network store results.
     */
    var networkStoreOverrideTokens: Dictionary<NSObject, AnyObject>? { get set }
    
}