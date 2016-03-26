//
//  NotificationProcessor.swift
//

import CoreData

public class NotificationProcessor: NSObject {

    /**
     Dispatches notifications for objectIDs that were created, updated, or deleted as a result of URL response processing.
     
     - Parameter objectIDArray: An array of managed object IDs that were affected during the URL response processing.
     
     - Parameter request: The request associated with the changes made to the objects in the objectIDArray.
     */
    public static func processUpdatedObjects(objectIDArray: Array<NSManagedObjectID>, request: NSURLRequest) {

        let notificationInfo:Dictionary<NSObject, AnyObject>? = [kObjectIDsArray:objectIDArray, kRemoteStoreURLResponse:request]

        let notification = NSNotification(name: kObjectIDsForRequestNotification, object: nil, userInfo: notificationInfo)

        NSNotificationCenter.defaultCenter().performSelectorOnMainThread(#selector(NSNotificationCenter.postNotification(_:)), withObject: notification, waitUntilDone: false)
    }

    /**
     Dispatches notifications for errors received while processing a request.
     
     - Parameter errors: An NSError object that may contain one or more errors.
     
     - Parameter request: The request associated with the generation of the errors.

     */
    public static func processErrors(errors: NSError, request: NSURLRequest) {

        print(errors)
        
        let notificationInfo:Dictionary<NSObject, AnyObject>? = [kUserInfoErrorKey: errors, kRemoteStoreURLResponse:request]

        let notification = NSNotification(name: kErrorNotification, object: nil, userInfo: notificationInfo)

        NSNotificationCenter.defaultCenter().performSelectorOnMainThread(#selector(NSNotificationCenter.postNotification(_:)), withObject: notification, waitUntilDone: false)

    }
}