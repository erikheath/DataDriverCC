//
//  NetworkStoreRequest.swift
//


import CoreData

public protocol NetworkStoreRequest {

    /**
     Assign an NSURLOverrideComponents object to this property to alter the URL used to retrieve network store results.
     */
    var networkStoreURLOverrides: NSURLComponents? { get set }

    /**
     Assign a Dictionary of tokens that should alter the URL used to retrieve network store results.
     */
    var networkStoreOverrideTokens: Dictionary<NSObject, AnyObject>? { get set }
    
}