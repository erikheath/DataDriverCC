//
//  JSONEntityProcessor.swift
//


import CoreData

public class JSONEntityProcessor: NSObject {

    /**
     The processedObjectIDs contains a list of all managed object IDs that have been processed during the lifetime of a JSONEntityProcessor.
     */
    var processedObjectIDs:Array<NSManagedObjectID> = Array()

    private var transaction: TransactionOperation

    private var stackID: String

    init(transaction: TransactionOperation, stackID: String) {
        self.stackID = stackID
        self.transaction = transaction
    }

    /**
     The main entry point for filling out (fulfilling) a managed object from a JSON representation. Create a new JSONEntityProcessor for each root object (essentially treat it as an operation). The processor manages state that should not be transferred from run to run.

     - Important: Beginning with this method, a recursive stack is created that traverses the relationships of an entity. One-to-One, One-to-Many, Many-to-One, and Many-to-Many relationships are all supported. When objects refer to one another, infinite loops are prevented by the discrete nature of JSON files (i.e. they are not infinitely long) which are traversed from top to bottom and then are exited, as well as by keeping track of objects that have been created during the current processing run.

     However, an infinite loop can be set up by referencing transformable URL attributes that cause the downloading of JSON objects that refer to the object triggering the download. This can happen only if the file(s) that are downloaded describe a value for the transformable URL property in the referenced object. Simply referring to an object will not trigger a download of its transformable URL attributes, nor will setting any of its properties or attributes that do not trigger URL downloads.
     
     - Note: The JSON representation of objects are eligible for conditioning within this method. It's important to put in the necessary type and key checks within any JSON Object conditioners to make sure the JSON isn't over-conditioned.

     - Parameter managedObject: The managed object that should serve as the root object for applying the values contained in the valueSource dictionary.

     - Parameter valueSource: The data source that should be used for filling out the managed objects, beginning with the root object.

     - Parameter parentRelationship: If called in response to filling out a relationship of an object, the relationship that should be fulfilled.

     - Throws: In the event of an error, throws a Managed Object, Managed Object Context, JSON Parsing, or other related error.

     */
    func fulfillManagedObject(managedObject:NSManagedObject, valueSource:NSDictionary, parentRelationship:NSRelationshipDescription?) throws -> Void {

        // Newly encountered objects are allowed to be processed. All others trigger a return, preventing infinite loops.
        if self.processedObjectIDs.contains(managedObject.objectID) {
            return
        } else {
            self.processedObjectIDs.append(managedObject.objectID)
        }

        do {

            let conditionedValueSource = JSONObjectDataConditionerFactory.conditionObjects([valueSource as! Dictionary<NSObject, AnyObject>], entity: managedObject.entity)

            self.assignRuntimeEntitySettings(managedObject)

            try JSONAttributeProcessor(transaction: self.transaction, stackID: self.stackID).fulfillManagedObject(managedObject, valueSource: conditionedValueSource.first!)

            try self.fullfilManagedObject(managedObject, parentRelationship: parentRelationship, relationshipsValueSource: conditionedValueSource.first!)

        } catch {
            throw error
        }

    }

    /**
     This is the entry point for the control flow that fulfills the relationships of an entity. This method supports to-one and to-many relationships.

     - Important: When processing the relationships, it's necessary to account for an error being thrown that should stop the processing of other relationships. As is not possible to determine ahead of processing the complete file whether a relationship will be valid, only non-validation errors occur during processing of the JSON collection. These errors are not recoverable and will cause the entire file to be discarded.

     Because of this, it is possible for the local cache to enter into an inconsistent state with the server, particularly if additional requests have been spawned. When file based parsing failures occur, consider resetting the local cache entirely, or design the database in such as way that responses to spawned requests will be discarded by not being able to be saved to the local cache.

     - Important: An object is not prevented from traversing back to the relationship that generated it. This means that if some or all of the definition of a parent object is contained in a relationship, the attributes will be processed and inserted into the parent object. The final value of an attribute is the last value for that attribute that is processed. This also means that attributes that are listed with empty values will overwrite any existing data in an object. If you do not want to overwrite an attribute value, ensure that the last value for the attribute in any nexted objects in the JSON file has the correct value.

     - Warning: This framework makes extensive use of Swift error handling to provide consistent and informative feedback. It also uses those errors to determine if processing is recoverable on a file to file basis. However, there are certain methods that can trigger the throwing of exceptions which are not handled by the Swift error system. Most of these are legacy methods that are being replaced with new implementations and/or signatures by Apple, Inc. Key-Value coding methods (specifically valueForKeyPath) are a known source of exceptions. This framework uses the runtime to manage as many of these known exceptions as possible. However, depending on the reliability of your data service, it may be necessary to manage exceptions generated from data processing that are specific to your implementation.

     - Parameter managedObject: The managed object that should serve as the root object for applying the values contained in the valueSource dictionary.

     - Parameter valueSource: The data source that should be used for filling out the managed objects, beginning with the root object.

     - Parameter parentRelationship: If called in response to filling out a relationship of an object, the relationship that should be fulfilled.

     - Throws: In the event of an error, throws a Managed Object, Managed Object Context, JSON Parsing, or other related error.

     */
    func fullfilManagedObject(managedObject:NSManagedObject, parentRelationship:NSRelationshipDescription?, relationshipsValueSource valueSource:NSDictionary) throws -> Void {

        // Filter out the parent relationship to prevent infinite loops.
        do {
            for (_,relationship) in managedObject.entity.relationshipsByName where relationship.inverseRelationship != parentRelationship {
                if relationship.toMany == false {
                    try self.fulfillManagedObject(managedObject, toOneRelationship: relationship, valueSource: valueSource)
                } else {
                    try self.fulfillManagedObject(managedObject, toManyRelationship: relationship, valueSource: valueSource)
                }
            }

        } catch {
            throw error
        }
    }

    /**
     Assigns or updates the managed object's runtime entity settings includeing remote update and remote expiration timestamps, reflecting when the object was last updated, as well as a creation date, reflecting both the creation time and order objects were processed in (usually the order listed in the incoming data). Setting a remote update timestamp requires the lastRemoteUpdate property to be specified for an entity as a date in the managed object model. Setting a remote expiration timestamp requires the remoteUpdateExpiration property to be specified for an entity as a date in the managed object model. Setting a creation position requires the remoteOrderPosition property to be specified for an entity as a date in the managed object model.
     
     - Note: Once a creation position has been specified for an object, it will not be changed by updating the object.
     
     - Parameter managedObject: The managed object that will be updated.
     */
    func assignRuntimeEntitySettings(managedObject: NSManagedObject) -> Void {

        if let _ = managedObject.entity.attributesByName[kLastRemoteUpdate] {
            let lastRemoteUpdate = NSDate()
            managedObject.setValue(lastRemoteUpdate, forKey: kLastRemoteUpdate)
        }

        expiration: if let expirationAttribute = managedObject.entity.attributesByName[kRemoteUpdateExpiration], let expirationInterval = expirationAttribute.userInfo?[kRemoteUpdateInterval] {

            var interval: NSNumber
            switch expirationInterval {
            case is String, is NSString:
                interval = NSNumber(integer: (expirationInterval as! NSString).integerValue)
            case is NSNumber:
                interval = expirationInterval as! NSNumber
            default:
                break expiration
            }

            let expirationDate = NSDate().dateByAddingTimeInterval(interval.doubleValue * 60.0)
            managedObject.setValue(expirationDate, forKey: kRemoteUpdateExpiration)
        }

        if let _ = managedObject.entity.attributesByName[kRemoteOrderPosition] where managedObject.valueForKey(kRemoteOrderPosition) == nil {
            managedObject.setValue(NSDate(), forKey: kRemoteOrderPosition)
        }

    }

    /**
     Creates and returns a managed object associated with the passed in context that has a permanent id.

     - Parameter context: The context in which the managed object should be inserted.

     - Parameter entity: The NSEntityDescription that should be used to create the managed object.

     - Returns: A new managed object associated with the passed in context that has a permanent id.

     - Throws: If a permanent id can not be created, throws the resulting managed object context error.

     */
    func managedObjectForContext( context: NSManagedObjectContext, entity:NSEntityDescription, valueSource: NSDictionary ) throws -> NSManagedObject? {

        var objectIDError: ErrorType? = nil
        guard let modelEntityID = (entity.userInfo?[kModelEntityID] as? String) else {
            return nil
        }

        if modelEntityID != "AUTOGENERATEKEY" {
            guard let keyPath:String = entity.userInfo?[kEntityID] as? String,
                let _ = valueSource.valueForKeyPath(keyPath) as? String,
                let _ = entity.name else {
                    return nil
            }
        }

        let managedObject = NSManagedObject(entity: entity, insertIntoManagedObjectContext: context)
        context.performBlockAndWait({ () -> Void in
            do {
                try context.obtainPermanentIDsForObjects([managedObject])
            } catch { objectIDError = error  }
        })

        if objectIDError != nil { throw objectIDError! }

        return managedObject

    }
    
    /**
     Searches for, and if found, returns a managed object context by searching for an object that matches the search criteria in the valueSource in the context for the specified entity type.

     - Parameter context: The context in which the managed object should searche for.

     - Parameter entity: The NSEntityDescription that should be used when searching for the managed object.

     - Parameter valueSource: The data to search when looking for a local identifier to use when searching the local store for an existing object.

     - Returns: A managed object matching the passed in criteria if it exists, otherwise nil.

     - Throws: If a fetch request can not be executed.

     */
    func managedObjectInContext( context:NSManagedObjectContext, entity:NSEntityDescription, valueSource:NSDictionary) throws -> NSManagedObject? {

        do {

            guard let modelEntityID = (entity.userInfo?[kModelEntityID] as? String) else {
                return nil
            }

            if modelEntityID != "AUTOGENERATEKEY" {

                guard let keyPath:String = entity.userInfo?[kEntityID] as? String,
                    let propertyID:String = valueSource.valueForKey(keyPath) as? String,
                    let entityName = entity.name else {
                        return nil
                }

                let request = NSFetchRequest(entityName: entityName)
                request.sortDescriptors = [NSSortDescriptor(key: modelEntityID, ascending: false)]

                let leftExpression = NSExpression(forKeyPath: modelEntityID)
                let rightExpression = NSExpression(forConstantValue: propertyID)

                request.predicate = NSComparisonPredicate(leftExpression:leftExpression , rightExpression: rightExpression, modifier: NSComparisonPredicateModifier.DirectPredicateModifier, type: NSPredicateOperatorType.EqualToPredicateOperatorType, options:NSComparisonPredicateOptions(rawValue: 0))

                var results:Array<AnyObject> = Array()
                var contextError: ErrorType? = nil
                context.performBlockAndWait({ () -> Void in
                    do {
                        results = try context.executeFetchRequest(request)
                    } catch {
                        contextError = error
                    }
                })

                if contextError != nil { throw contextError! }
                
                return (results as NSArray).firstObject as? NSManagedObject
            }
            
        } catch {
            
            throw error
        }

        return nil
    }


    /**
     This method fulfills the destination object of a to-one relationship for the passed in managed object.
     
     - Important: It is a requirement for all remote driven objects that they have a remote store id that can be matched to a local store id. This behavior is a Data Layer requirement, not a CoreData requirement. If an entity does not have remote and local entity id keys and values in it's user info, it will not be processed. Further, if the data source does not have the remote entity key or a value for the remote entity key, the data for that object (even if the rest of it exists) will not be processed.

     - Parameter managedObject: The managed object whose relationship should be fulfilled.

     - Parameter toOneRelationship: The relationship of the managed object that should be fulfilled.

     - Parameter valueSource: The data that should be used to fulfill destination object of the to-one relationship and to search for the destination object if it already exists within the context.

     - Throws: JSONCollectionProcessor errors for missing entities as well as managed object context fetch errors.

     */
    func fulfillManagedObject(managedObject:NSManagedObject, toOneRelationship relationship:NSRelationshipDescription, valueSource:NSDictionary) throws -> Void {

        do {
            // Determine if a relationship object exists, either on the parent object or in the context.
            guard let destinationEntity = relationship.destinationEntity, let context = managedObject.managedObjectContext else { throw JSONCollectionProcessor.JSONParserError.missingEntity }

            var relationshipObject:NSManagedObject

            if let contextObject = try self.managedObjectInContext(context, entity: destinationEntity, valueSource: valueSource) {
                // An object exists in the context corresponding to the key and value in the data. Update the existing object.
                relationshipObject = contextObject
            } else if let contextObject = try self.managedObjectForContext(context, entity: destinationEntity, valueSource: valueSource) {
                // A key and required value for key exists for the destination object, or the object is set as autoGenerateKey. Create a new object in the context.
                relationshipObject = contextObject
            } else if let keyPath:String = destinationEntity.userInfo?[kEntityID] as? String where (valueSource.allKeys as NSArray).containsObject(keyPath) == true {
                // The key exists in the data source, but not the value for the object. Nullify the relationship and return.
                managedObject.setValue(nil, forKey: relationship.name)
                return
            } else {
                // Neither key nor value exist in the data source. No action can be taken.
                return
            }

            // Fulfill the relationship.
            managedObject.setValue(relationshipObject, forKey: relationship.name)

            // Fulfill the target of the to-one relatioship by calling into (effectively recursing) the JSON processor entry point.
            try self.fulfillManagedObject(relationshipObject, valueSource: valueSource, parentRelationship: relationship)

        } catch {
            throw error
        }
    }

    /**
     This is the entry point for fulfilling a to-many relationship. This method determines whether the relationship uses a set or ordered set, whether it has the necessary information to process the relationship, and whether the data structure contains any elements to process once it has been reset with the new collection root (always an array). If the data structure contains no elements but the root key path is present, the method will set the relationship to nil and return without further processing. If there is no root key path, this method will return without any further processing and will not reset the relationship.

     - Parameter managedObject: The managed object whose to-many relationship needs to be fulfilled.
     
     - Parameter toManyRelationship: The to-many relationship to fulfill.
     
     - Parameter valueSource: The source of the data that should be used to fulfill the relationship objects.
     
     - Throws: JSONCollectionParser errors, managed object context errors from underlying methods, etc.

    */
    func fulfillManagedObject(managedObject: NSManagedObject, toManyRelationship relationship: NSRelationshipDescription, valueSource: NSDictionary) throws -> Void {

        do {
            // If a root key path is absent in the entity, there can be no action taken.
            guard let rootKeyPath = relationship.destinationEntity?.userInfo?[kJSONRootKeyPath] as? String else { return }

            guard let dataStructure = valueSource.valueForKeyPath(rootKeyPath) as? [Dictionary<NSObject, AnyObject>] else {
                // There is no data to process for the root key path. If the root is null, nullify the relationship.
                if let _ = valueSource.valueForKeyPath(rootKeyPath) as? NSNull {
                    managedObject.setValue(nil, forKey: relationship.name)
                }
                return
            }

            if dataStructure.count == 0 {
                // Nullify the relationship
                managedObject.setValue(nil, forKey: relationship.name)
            }

            let relationshipSet = managedObject.valueForKey(relationship.name)

            switch relationshipSet {
            case is NSSet:
                managedObject.setValue(try self.processSetRelationship(relationship, managedObject: managedObject, dataStructure: dataStructure).set, forKey: relationship.name)

            case is NSOrderedSet:
                managedObject.setValue(try self.processSetRelationship(relationship, managedObject: managedObject, dataStructure: dataStructure), forKey: relationship.name)
            default:
                return
            }

        } catch {
            throw error
        }
    }

    /** 
     Processes the objects of a to-many relationship when they are an unordered, unkeyed collection, i.e. a set.
     
     - Note: The JSON representation of objects are eligible for conditioning within this method. It's important to put in the necessary type and key checks within any JSON Object conditioners to make sure the JSON isn't over-conditioned.
     
     - Parameter relationship: The to-many relationship that should be processed.
     
     - Parameter managedObject: The managed object containing the to-many relationship.
     
     - Parameter dataStructure: The data structure that should be used to fulfill the to-many relationship.
     
     - Throws: Various JSONParserError and NSManagedObjectContext related errors.
     
     - Returns: An ordered set of managed objects to add to the passed in relationship.

     */
    func processSetRelationship(relationship: NSRelationshipDescription, managedObject: NSManagedObject, dataStructure: [Dictionary<NSObject, AnyObject>]) throws -> NSOrderedSet {

        guard let context = managedObject.managedObjectContext else { throw JSONCollectionProcessor.JSONParserError.missingContext }

        guard let destinationEntity = relationship.destinationEntity else {
                throw JSONCollectionProcessor.JSONParserError.missingEntity
        }

        let relationshipSet = NSMutableOrderedSet()

        let conditionedValueSource = JSONObjectDataConditionerFactory.conditionObjects(dataStructure, entity: destinationEntity)

        dataProcessor: for valueSource: NSDictionary in conditionedValueSource {

            var relationshipObject:NSManagedObject?

            // Search for a local store object that matches the object described in the incoming dataStructure
            if let contextObject = try self.managedObjectInContext(context, entity: destinationEntity, valueSource: valueSource) {
                // An object exists in the context corresponding to the key and value in the data. Update the existing object.
                relationshipObject = contextObject
            } else if let contextObject = try self.managedObjectForContext(context, entity: destinationEntity, valueSource: valueSource) {
                // A key and value exist for the destination object. Create a new object in the context.
                relationshipObject = contextObject
            } else {
                // The value source does not have a value for the entity ID. This is a processing error that will stop processing of the current object.
                throw JSONCollectionProcessor.JSONParserError.formatError
            }

            // Fulfill the object that has been created for the relationship set.
            try self.fulfillManagedObject(relationshipObject!, valueSource: valueSource, parentRelationship: relationship)
            relationshipSet.addObject(relationshipObject!)

        }
        
        return relationshipSet

    }

}