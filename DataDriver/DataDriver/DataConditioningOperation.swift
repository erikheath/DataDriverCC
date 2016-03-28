//
//  DataConditioningOperation.swift
//  DataDriver
//
//  Created by ERIKHEATH A THOMAS on 3/15/16.
//  Copyright © 2016 Curated Cocoa LLC. All rights reserved.
//

import Foundation
import CoreData

struct DataConditionerCondition: OperationCondition {

    static let name = "DataConditioner"

    static let isMutuallyExclusive = false

    let partitionOp: RemoteStoreRequestOperation

    init(partitionOp: RemoteStoreRequestOperation) {
        self.partitionOp = partitionOp
    }

    func dependencyForOperation(operation: Operation) -> NSOperation? {
        guard let operation = operation as? DataConditionerOperation else { return nil }

        return RequestDataOperation(partitionOp: partitionOp, dataConditioner: operation)
    }

    func evaluateForOperation(operation: Operation, completion:OperationConditionResult -> Void) {
        switch self.partitionOp.updatesValidated  {
        case true:
            completion(.Satisfied)

        default:
            let error = NSError(code: .ConditionFailed, userInfo: [
                OperationConditionKey: self.dynamicType.name
                ])

            completion(.Failed(error))
        }
    }
}

class DataConditionerOperation: Operation {

    var dataRetrieved: Bool = false

    var dataToProcess: NSData? = nil

    var partitionOp: RemoteStoreRequestOperation? = nil

    convenience init(partitionOp: RemoteStoreRequestOperation) {
        self.init()
        self.partitionOp = partitionOp
    }

    override init() {
        super.init()
    }

    override func execute() {

        defer {
            finish()
        }

        guard let partitionOp = self.partitionOp, let partitionContext = self.partitionOp?.partitionContext, let transaction = partitionOp.transaction, let stackID = transaction.graphManager?.stackID, let dataToProcess = self.dataToProcess, let URLRequest = partitionOp.URLRequest else {
            return
        }

        partitionContext.performBlockAndWait({
            processor: do {

                let processingType = try self.validateURLResponseType()

                switch processingType {

                case .JSON:
                    try JSONCollectionProcessor(transaction: transaction, stackID: stackID).processJSONDataStructure(dataToProcess, request: URLRequest, context: partitionContext)

                case .Image:
                    try ImageDataProcessor().processImageData(dataToProcess, request: URLRequest, context: partitionContext)
                }

                try self.saveContexts()
                partitionOp.updatesValidated = true
            } catch {
                // The save failed or has left the context in an inconsistent state.
                partitionOp.updatesValidated = false
            }
            
        })
        
    }

    // MARK: Utilities

    // MARK: Error Management
    enum DataConditionerError: Int, ErrorType {
        case missingEntity = 7000
        case missingProperty = 7001
        case missingEntityUserInfo = 7002
        case missingPropertyUserInfo = 7003
        case unknownRemoteStoreType = 7004
    }

    /**
    Supported URL response types that can be processed by the data conditioning system.
    */
    enum URLResponseProcessingType: String, CustomStringConvertible {
        case Image = "Image"
        case JSON = "JSON"

        var description:String { return self.rawValue }

    }

    /**
     Determines the type of URL Response received by interrogating the response, determining if it has the necessary components to attempt processing.

     - Throws: If a supported type can not be determined, an error is thrown.

     - Returns: A URL response processing type corresponding to the supported types.

     */
    func validateURLResponseType() throws -> URLResponseProcessingType {

        guard let partitionOp = self.partitionOp else {
            throw NSError(domain: "DataLayer", code: 1000, userInfo: nil)
        }

        guard let entity = partitionOp.URLRequest?.requestEntity else {
            throw DataConditionerError.missingEntity
        }

        guard let _ = entity.userInfo else {
            throw DataConditionerError.missingEntityUserInfo
        }

        switch partitionOp.URLRequest?.requestProperty {

        case let targetProperty where targetProperty is NSRelationshipDescription:

            guard let _ = targetProperty?.userInfo else { throw DataConditionerError.missingPropertyUserInfo }

            return URLResponseProcessingType.JSON

        case let targetProperty where targetProperty is NSAttributeDescription:

            guard let userInfo = targetProperty?.userInfo else { throw DataConditionerError.missingPropertyUserInfo }

            switch userInfo[kRemoteStoreURLType] as? String {

            case let x where x == kRemoteStoreURLTypeImage:
                return URLResponseProcessingType.Image

            case let x where x == kRemoteStoreURLTypeFeed:
                return URLResponseProcessingType.JSON

            default:
                throw DataConditionerError.unknownRemoteStoreType
            }
            
        default:
            return URLResponseProcessingType.JSON
            
        }
    }

    /**
     Attempts to save the passed in context, optionally attempting to fix validation errors if any are encountered.

     - Throws: If errors are encountered or if they can not be repaired, throws the error generated by trying to save the context.
     */
    func saveContext( context: NSManagedObjectContext, fixValidationErrors: Bool) throws {

        var saveError: ErrorType? = nil

        var caughtError: NSError? = nil

        do {
            if context.hasChanges {
                try context.save()
                return
            } else {
                return
            }
        } catch {
            caughtError = error as NSError
        }

        do {
            if caughtError != nil && fixValidationErrors == true {
                try self.processValidationErrors(caughtError!, context: context)
                try context.save()
                //                    print("Saved without errors now")
                return
            }
        } catch {
            caughtError = error as NSError
            //                print(caughtError)
        }

        saveError = caughtError


        if let _ = saveError {
            throw saveError!
        }

    }

    /**
     Saves the contexts, pushing all changes to the master context and persistent store if one exists.

     - Throws: In the event of a save error, returns the NSManagedObjectContext save error.
     */
    func saveContexts() throws {

        do {
            guard let partitionContext = self.partitionOp?.partitionContext else { throw NSError(domain: "DataLayer", code: 1000, userInfo: nil) }
            try self.saveContext(partitionContext, fixValidationErrors: true)

        } catch {
            throw error as NSError

        }
    }

    /**
     Processes the internal context to remove objects that have been invalidated by the changes made resulting from processing.
     */
    func processValidationErrors(errors: NSError, context: NSManagedObjectContext) throws {
        // This method removes objects listed in the NSAffectedObjectsErrorKey when trying to save.

        if errors.domain == NSCocoaErrorDomain && errors.code == NSValidationMultipleErrorsError && errors.userInfo[NSDetailedErrorsKey] != nil {
            // There were multiple validation errors. Remove the objects generating the errors.
            guard let detailedErrors = errors.userInfo[NSDetailedErrorsKey] as? Array<NSError> else { return }
            for error in detailedErrors {
                guard let objectToDelete = error.userInfo[NSValidationObjectErrorKey] as? NSManagedObject else { continue }
                objectToDelete.managedObjectContext?.deleteObject(objectToDelete)

            }

        } else if errors.domain == NSCocoaErrorDomain && errors.userInfo[NSValidationObjectErrorKey] != nil {
            guard let objectToDelete = errors.userInfo[NSValidationObjectErrorKey] as? NSManagedObject else { return }
            objectToDelete.managedObjectContext?.deleteObject(objectToDelete)
        }
        
    }

}